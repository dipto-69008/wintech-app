import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../services/api_service.dart';
import '../../services/sync_refresh_service.dart';

class PartyLedgerScreen extends StatefulWidget {
  const PartyLedgerScreen({super.key});

  @override
  State<PartyLedgerScreen> createState() => _PartyLedgerScreenState();
}

class _PartyLedgerScreenState extends State<PartyLedgerScreen> {
  final _searchController = TextEditingController();
  final _money = NumberFormat('#,##0.00', 'en_US');
  List<Map<String, dynamic>> _parties = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    SyncRefreshService.revision.addListener(_refreshFromSync);
    _load();
  }

  @override
  void dispose() {
    SyncRefreshService.revision.removeListener(_refreshFromSync);
    _searchController.dispose();
    super.dispose();
  }

  void _refreshFromSync() {
    if (mounted) _load(showLoading: false);
  }

  Future<void> _load({bool showLoading = true}) async {
    if (showLoading && mounted) setState(() => _loading = true);
    try {
      final parties = await ApiService.parties();
      if (!mounted) return;
      setState(() {
        _parties = parties;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _visibleParties {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _parties;
    return _parties.where((party) {
      final haystack = [
        party['name'],
        party['code'],
        party['mobile'],
        party['phone'],
        party['area'],
      ].whereType<Object>().join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  String _text(dynamic value, [String fallback = '—']) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _moneyValue(dynamic value) => '৳${_money.format(_number(value))}';

  void _openDetails(Map<String, dynamic> party) {
    final id = _text(party['_id'], '');
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('This party does not have a valid ERP ID'),
      ));
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PartyLedgerDetailScreen(party: party),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final parties = _visibleParties;
    return Scaffold(
      appBar: AppBar(
        title: Text('Party Ledger', style: GoogleFonts.hindSiliguri(
          fontWeight: FontWeight.w700,
        )),
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(showLoading: false),
        color: AppTheme.primaryAccent,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildIntro(isDark)),
            SliverToBoxAdapter(child: _buildSearch(isDark)),
            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildError(),
              )
            else if (parties.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmpty(),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, index) => _buildPartyCard(
                      parties[index],
                      isDark,
                    ),
                    childCount: parties.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntro(bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryAccent, Color(0xFF0F766E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              color: Colors.white,
              size: 25,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your territory parties',
                  style: GoogleFonts.hindSiliguri(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tap a party to view invoices and payment history',
                  style: GoogleFonts.hindSiliguri(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearch(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'Search party, code, phone or Area',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                  icon: const Icon(Icons.close_rounded),
                ),
          filled: true,
          fillColor: isDark ? AppTheme.darkCard : Colors.white,
        ),
      ),
    );
  }

  Widget _buildPartyCard(Map<String, dynamic> party, bool isDark) {
    final name = _text(party['name']);
    final due = _number(party['currentDue'] ?? party['previousDue']);
    final area = _text(party['area']);
    final code = _text(party['code']);
    return InkWell(
      onTap: () => _openDetails(party),
      borderRadius: BorderRadius.circular(17),
      child: Container(
        margin: const EdgeInsets.only(bottom: 11),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(17),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.13 : 0.045),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppTheme.primaryAccent.withValues(alpha: 0.12),
              child: Text(
                name.substring(0, 1).toUpperCase(),
                style: GoogleFonts.hindSiliguri(
                  color: AppTheme.primaryAccent,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.hindSiliguri(
                      color: isDark ? AppTheme.darkText : AppTheme.textDark,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$code  •  $area',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.hindSiliguri(
                      color: isDark ? AppTheme.darkTextGrey : AppTheme.textGrey,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _text(party['mobile'] ?? party['phone']),
                    style: GoogleFonts.hindSiliguri(
                      color: isDark ? AppTheme.darkTextGrey : AppTheme.textGrey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _moneyValue(due),
                  style: GoogleFonts.hindSiliguri(
                    color: due > 0 ? AppTheme.error : AppTheme.success,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  due > 0 ? 'Due' : 'Clear',
                  style: GoogleFonts.hindSiliguri(
                    color: isDark ? AppTheme.darkTextGrey : AppTheme.textGrey,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 5),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.primaryAccent,
                  size: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48, color: AppTheme.textGrey),
            const SizedBox(height: 12),
            Text(
              'Could not load party ledger',
              style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 5),
            Text(
              'Connect to ERP and try again.',
              textAlign: TextAlign.center,
              style: GoogleFonts.hindSiliguri(color: AppTheme.textGrey),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () => _load(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Text(
          _searchController.text.trim().isEmpty
              ? 'No parties found in your territory.'
              : 'No matching party found.',
          textAlign: TextAlign.center,
          style: GoogleFonts.hindSiliguri(color: AppTheme.textGrey),
        ),
      ),
    );
  }
}

class PartyLedgerDetailScreen extends StatefulWidget {
  final Map<String, dynamic> party;

  const PartyLedgerDetailScreen({super.key, required this.party});

  @override
  State<PartyLedgerDetailScreen> createState() => _PartyLedgerDetailScreenState();
}

class _PartyLedgerDetailScreenState extends State<PartyLedgerDetailScreen> {
  final _money = NumberFormat('#,##0.00', 'en_US');
  final _date = DateFormat('dd MMM yyyy');
  Map<String, dynamic> _party = {};
  List<Map<String, dynamic>> _invoices = [];
  List<Map<String, dynamic>> _payments = [];
  Map<String, dynamic> _summary = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _party = Map<String, dynamic>.from(widget.party);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final body = await ApiService.partyLedger(_text(widget.party['_id'], ''));
      if (!mounted) return;
      setState(() {
        if (body['party'] is Map) {
          _party = Map<String, dynamic>.from(body['party'] as Map);
        }
        _invoices = _maps(body['invoices']);
        _payments = _maps(body['payments']);
        _summary = body['summary'] is Map
            ? Map<String, dynamic>.from(body['summary'] as Map)
            : {};
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> _maps(dynamic value) {
    if (value is! List) return [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  String _text(dynamic value, [String fallback = '—']) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _moneyValue(dynamic value) => '৳${_money.format(_number(value))}';

  String _dateValue(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    return parsed == null ? _text(value) : _date.format(parsed.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: Text('Party Details', style: GoogleFonts.hindSiliguri(
          fontWeight: FontWeight.w700,
        )),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppTheme.primaryAccent,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
                    children: [
                      _buildPartyHeader(isDark),
                      const SizedBox(height: 12),
                      _buildSummary(isDark),
                      const SizedBox(height: 12),
                      _buildContactCard(isDark),
                      const SizedBox(height: 14),
                      _buildSectionTitle('Invoice History', Icons.receipt_long_rounded),
                      const SizedBox(height: 8),
                      _buildInvoices(isDark),
                      const SizedBox(height: 16),
                      _buildSectionTitle('Payment Ledger', Icons.payments_rounded),
                      const SizedBox(height: 8),
                      _buildPayments(isDark),
                    ],
                  ),
                ),
    );
  }

  Widget _buildPartyHeader(bool isDark) {
    final name = _text(_party['name']);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryAccent, Color(0xFF0F766E)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 29,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: Text(
              name.substring(0, 1).toUpperCase(),
              style: GoogleFonts.hindSiliguri(
                color: Colors.white,
                fontSize: 23,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.hindSiliguri(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${_text(_party['code'])}  •  ${_text(_party['area'])}',
                  style: GoogleFonts.hindSiliguri(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(bool isDark) {
    final values = [
      ('Invoices', _text(_summary['invoiceCount'], '0'), Icons.receipt_long_rounded, AppTheme.primaryAccent),
      ('Sales', _moneyValue(_summary['totalSales']), Icons.shopping_cart_rounded, AppTheme.primaryAccent),
      ('Paid', _moneyValue(_summary['totalPaid']), Icons.check_circle_rounded, AppTheme.success),
      ('Due', _moneyValue(_summary['totalDue']), Icons.credit_card_rounded, AppTheme.error),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: values.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.2,
      ),
      itemBuilder: (_, index) {
        final item = values[index];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            children: [
              Icon(item.$3, color: item.$4, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.$2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.hindSiliguri(
                        color: item.$4,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      item.$1,
                      style: GoogleFonts.hindSiliguri(
                        color: isDark ? AppTheme.darkTextGrey : AppTheme.textGrey,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContactCard(bool isDark) {
    final rows = [
      ('Mobile', _party['mobile'] ?? _party['phone'], Icons.phone_rounded),
      ('Address', _party['address'], Icons.location_on_rounded),
      ('Owner', _party['ownerName'], Icons.person_rounded),
      ('Market / Bazar', _party['bazarName'], Icons.storefront_rounded),
      ('Credit Limit', _moneyValue(_party['creditLimit']), Icons.credit_score_rounded),
      ('Previous Due', _moneyValue(_party['previousDue']), Icons.history_rounded),
    ];
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Column(
        children: rows
            .where((row) => _text(row.$2, '').isNotEmpty && _text(row.$2, '') != '৳0.00')
            .map((row) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(row.$3, size: 17, color: AppTheme.primaryAccent),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 105,
                        child: Text(
                          row.$1,
                          style: GoogleFonts.hindSiliguri(
                            color: isDark ? AppTheme.darkTextGrey : AppTheme.textGrey,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          _text(row.$2),
                          style: GoogleFonts.hindSiliguri(
                            color: isDark ? AppTheme.darkText : AppTheme.textDark,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 19, color: AppTheme.primaryAccent),
        const SizedBox(width: 7),
        Text(
          title,
          style: GoogleFonts.hindSiliguri(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildInvoices(bool isDark) {
    if (_invoices.isEmpty) return _emptySection('No invoice history yet.');
    return Column(
      children: _invoices.map((invoice) {
        final due = _number(invoice['dueAmount']);
        return Container(
          margin: const EdgeInsets.only(bottom: 9),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _text(invoice['invoiceNo']),
                      style: GoogleFonts.hindSiliguri(
                        color: AppTheme.primaryAccent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    _moneyValue(invoice['totalAmount'] ?? invoice['subTotal']),
                    style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  Text(
                    _dateValue(invoice['saleDate']),
                    style: GoogleFonts.hindSiliguri(
                      color: isDark ? AppTheme.darkTextGrey : AppTheme.textGrey,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  Text('Paid ${_moneyValue(invoice['paidAmount'])}',
                      style: GoogleFonts.hindSiliguri(
                        color: AppTheme.success,
                        fontSize: 12,
                      )),
                  const SizedBox(width: 10),
                  Text('Due ${_moneyValue(due)}',
                      style: GoogleFonts.hindSiliguri(
                        color: due > 0 ? AppTheme.error : AppTheme.success,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      )),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPayments(bool isDark) {
    if (_payments.isEmpty) return _emptySection('No payment ledger entries yet.');
    return Column(
      children: _payments.map((payment) {
        final status = _text(payment['status']).toLowerCase();
        final statusColor = status == 'confirmed'
            ? AppTheme.success
            : status == 'rejected'
                ? AppTheme.error
                : AppTheme.warning;
        return Container(
          margin: const EdgeInsets.only(bottom: 9),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            children: [
              Icon(Icons.payments_rounded, color: statusColor, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _moneyValue(payment['amount']),
                      style: GoogleFonts.hindSiliguri(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '${_dateValue(payment['date'])}  •  ${_text(payment['paymentMethod'])}',
                      style: GoogleFonts.hindSiliguri(
                        color: isDark ? AppTheme.darkTextGrey : AppTheme.textGrey,
                        fontSize: 12,
                      ),
                    ),
                    if (_text(payment['invoiceNo'], '').isNotEmpty)
                      Text(
                        'Invoice ${_text(payment['invoiceNo'])}',
                        style: GoogleFonts.hindSiliguri(
                          color: isDark ? AppTheme.darkTextGrey : AppTheme.textGrey,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  status,
                  style: GoogleFonts.hindSiliguri(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _emptySection(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppTheme.darkCard
            : Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.hindSiliguri(color: AppTheme.textGrey),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 46, color: AppTheme.textGrey),
            const SizedBox(height: 12),
            Text(
              'Could not load party details',
              style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}