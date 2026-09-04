import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../services/api_service.dart';
import '../../services/sync_refresh_service.dart';
import 'return_detail_screen.dart';

/// Sales return invoices created in the field. Every successful submission is
/// stored in ERP Sales → Return Entry through the mobile sales-returns route.
class ReturnProductsScreen extends StatefulWidget {
  const ReturnProductsScreen({super.key});

  @override
  State<ReturnProductsScreen> createState() => _ReturnProductsScreenState();
}

class _ReturnProductsScreenState extends State<ReturnProductsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  int _listRefreshId = 0;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text('Return Products',
              style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w700)),
          backgroundColor: AppTheme.primaryAccent,
          foregroundColor: Colors.white,
          bottom: TabBar(
            controller: _tab,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            tabs: const [Tab(text: 'Return List'), Tab(text: 'New Return')],
          ),
        ),
        body: TabBarView(
          controller: _tab,
          children: [
            _ReturnListTab(refreshId: _listRefreshId),
            _NewReturnTab(onCreated: () {
              setState(() => _listRefreshId++);
              _tab.animateTo(0);
            }),
          ],
        ),
      );
}

class _ReturnListTab extends StatefulWidget {
  final int refreshId;
  const _ReturnListTab({required this.refreshId});

  @override
  State<_ReturnListTab> createState() => _ReturnListTabState();
}

class _ReturnListTabState extends State<_ReturnListTab>
    with AutomaticKeepAliveClientMixin {
  bool _loading = true;
  String? _deletingId;
  List<Map<String, dynamic>> _returns = [];

  String _money(dynamic value) {
    final amount =
        value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
    return NumberFormat('#,##0.00', 'en_US').format(amount);
  }

  double _totalAmount(Map<String, dynamic> item, List<dynamic> products) {
    final saved = item['totalAmount'];
    if (saved is num) return saved.toDouble();
    return products.fold<double>(0, (sum, raw) {
      if (raw is! Map) return sum;
      final quantity = raw['quantity'] is num
          ? (raw['quantity'] as num).toDouble()
          : double.tryParse('${raw['quantity']}') ?? 0;
      final rate = raw['rate'] is num
          ? (raw['rate'] as num).toDouble()
          : double.tryParse('${raw['rate']}') ?? 0;
      return sum + quantity * rate;
    });
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    SyncRefreshService.revision.addListener(_refreshFromSync);
    _load();
  }

  void _refreshFromSync() {
    if (mounted) _load(showLoading: false);
  }

  @override
  void dispose() {
    SyncRefreshService.revision.removeListener(_refreshFromSync);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _ReturnListTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshId != widget.refreshId) _load();
  }

  Future<void> _load({bool showLoading = true}) async {
    if (showLoading && mounted) setState(() => _loading = true);
    try {
      final data = await ApiService.salesReturns();
      if (mounted) setState(() => _returns = data);
    } catch (_) {
      // Keep the last-known ERP list visible during a transient failure.
      // Clearing it would make an API error look like "no returns".
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _message(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text, style: GoogleFonts.hindSiliguri()),
      backgroundColor: error ? AppTheme.error : AppTheme.success,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _deleteReturn(Map<String, dynamic> item) async {
    final status = (item['status'] ?? 'pending').toString().toLowerCase();
    if (status != 'pending') {
      _message('Only pending returns can be deleted', error: true);
      return;
    }

    final returnNo = item['returnNo']?.toString() ?? 'this return';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete Return?',
            style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w700)),
        content: Text(
            'Delete $returnNo from the app and ERP? This is only allowed before approval.',
            style: GoogleFonts.hindSiliguri()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.hindSiliguri()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: Text('Delete',
                style: GoogleFonts.hindSiliguri(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final id = (item['_id'] ?? item['id'] ?? '').toString();
    if (id.isEmpty) {
      _message('This return has no ERP ID and cannot be deleted',
          error: true);
      return;
    }

    setState(() => _deletingId = id);
    try {
      await ApiService.deleteSalesReturn(id);
      _message('$returnNo deleted from ERP');
      await _load();
    } catch (e) {
      _message(
        e is ApiException ? e.message : 'Could not delete the ERP return',
        error: true,
      );
    } finally {
      if (mounted) setState(() => _deletingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryAccent));
    }
    if (_returns.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(children: [
          const SizedBox(height: 170),
          Icon(Icons.assignment_return_outlined,
              size: 62, color: AppTheme.textGrey.withValues(alpha: .35)),
          const SizedBox(height: 12),
          Center(
              child: Text('No return invoices found',
                  style: GoogleFonts.hindSiliguri(color: AppTheme.textGrey))),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(14),
        itemCount: _returns.length,
        itemBuilder: (_, index) {
          final item = _returns[index];
          final products = List<dynamic>.from(item['items'] ?? const []);
           final totalAmount = _totalAmount(item, products);
          final date = DateTime.tryParse((item['returnDate'] ??
                  item['createdAt'] ??
                  '')
              .toString());
          final status = (item['status'] ?? 'pending').toString().toLowerCase();
          final statusColor = status == 'approved' || status == 'refunded'
              ? AppTheme.success
              : status == 'replace'
                  ? Colors.blue
                  : status == 'rejected'
                      ? AppTheme.error
                      : AppTheme.warning;
          final statusLabel =
              status.isEmpty ? 'Pending' : '${status[0].toUpperCase()}${status.substring(1)}';
           final returnId = (item['_id'] ?? item['id'] ?? '').toString();
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
             child: InkWell(
               borderRadius: BorderRadius.circular(12),
               onTap: () => Navigator.of(context).push(
                 MaterialPageRoute(
                   builder: (_) => ReturnDetailScreen(returnData: item),
                 ),
               ),
               child: Padding(
                 padding: const EdgeInsets.all(14),
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(8)),
                      child: Text(item['returnNo']?.toString() ?? 'RETURN',
                          style: GoogleFonts.hindSiliguri(
                              color: Colors.orange.shade800,
                              fontWeight: FontWeight.w800,
                              fontSize: 11)),
                    ),
                    const Spacer(),
                    Text(
                        date == null
                            ? '—'
                            : DateFormat('dd MMM yy, hh:mm a').format(date),
                        style: GoogleFonts.hindSiliguri(
                            fontSize: 11, color: AppTheme.textGrey)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(statusLabel,
                          style: GoogleFonts.hindSiliguri(
                              color: statusColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w700)),
                    ),
                  ]),
                  const SizedBox(height: 9),
                  Text(item['partyName']?.toString() ?? 'Customer',
                      style: GoogleFonts.hindSiliguri(
                          fontSize: 15, fontWeight: FontWeight.w800)),
                  if ((item['invoiceNo'] ?? '').toString().isNotEmpty)
                    Text('Invoice: ${item['invoiceNo']}',
                        style: GoogleFonts.hindSiliguri(
                            fontSize: 12, color: AppTheme.textGrey)),
                  const SizedBox(height: 6),
                  Text(
                      products
                          .map((p) =>
                              '${p['productName'] ?? 'Product'} × ${p['quantity'] ?? 0}')
                          .join(' • '),
                      style: GoogleFonts.hindSiliguri(fontSize: 12)),
                   const SizedBox(height: 9),
                   Container(
                     width: double.infinity,
                     padding: const EdgeInsets.symmetric(
                         horizontal: 11, vertical: 8),
                     decoration: BoxDecoration(
                       color: AppTheme.primaryAccent.withValues(alpha: .09),
                       borderRadius: BorderRadius.circular(9),
                     ),
                     child: Row(
                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                       children: [
                         Text('Total Return Amount',
                             style: GoogleFonts.hindSiliguri(
                                 fontSize: 12,
                                 fontWeight: FontWeight.w700,
                                 color: AppTheme.primaryAccent)),
                         Text('৳ ${_money(totalAmount)}',
                             style: GoogleFonts.hindSiliguri(
                                 fontSize: 14,
                                 fontWeight: FontWeight.w800,
                                 color: AppTheme.primaryAccent)),
                       ],
                     ),
                   ),
                   if ((item['reason'] ?? '').toString().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('Reason: ${item['reason']}',
                        style: GoogleFonts.hindSiliguri(
                            fontSize: 11, color: AppTheme.textGrey)),
                  ],
                   if (status == 'pending') ...[
                     const SizedBox(height: 6),
                     Row(
                       mainAxisAlignment: MainAxisAlignment.end,
                       children: [
                         Text('Can delete before approval',
                             style: GoogleFonts.hindSiliguri(
                                 fontSize: 10, color: AppTheme.textGrey)),
                         const SizedBox(width: 4),
                         IconButton(
                           tooltip: 'Delete return',
                           visualDensity: VisualDensity.compact,
                           onPressed: _deletingId == returnId
                               ? null
                               : () => _deleteReturn(item),
                           icon: _deletingId == returnId
                               ? const SizedBox(
                                   width: 18,
                                   height: 18,
                                   child: CircularProgressIndicator(
                                       strokeWidth: 2,
                                       color: AppTheme.error))
                               : const Icon(Icons.delete_outline_rounded,
                                   size: 20, color: AppTheme.error),
                         ),
                       ],
                     ),
                   ],
                   ],
                 ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NewReturnTab extends StatefulWidget {
  final VoidCallback onCreated;
  const _NewReturnTab({required this.onCreated});

  @override
  State<_NewReturnTab> createState() => _NewReturnTabState();
}

class _NewReturnTabState extends State<_NewReturnTab> {
  final _partyCtrl = TextEditingController();
  final _invoiceCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  bool _isExpired = false;
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _parties = [];
  Map<String, dynamic>? _product;
  final List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await Future.wait([ApiService.products(), ApiService.parties(allBranches: true)]);
      if (mounted) {
        setState(() {
          _products = data[0];
          _parties = data[1];
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _message(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text, style: GoogleFonts.hindSiliguri()),
      backgroundColor: error ? AppTheme.error : AppTheme.success,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _chooseParty() async {
    final party = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SearchPicker(
          title: 'Select Customer',
          items: _parties,
          label: (p) => (p['name'] ?? '').toString(),
          detail: (p) =>
              [(p['code'] ?? '').toString(), (p['mobile'] ?? '').toString()]
                  .where((v) => v.isNotEmpty)
                  .join(' • ')),
    );
    if (party != null) setState(() => _partyCtrl.text = '${party['name'] ?? ''}');
  }

  Future<void> _chooseProduct() async {
    final product = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SearchPicker(
          title: 'Select Product',
          items: _products,
          label: (p) => (p['name'] ?? '').toString(),
          detail: (p) =>
              [(p['packSize'] ?? '').toString(), (p['unit'] ?? '').toString()]
                  .where((v) => v.isNotEmpty)
                  .join(' • ')),
    );
    if (product != null) {
      final rate = (product['sellingPrice'] as num?)?.toDouble() ??
          (product['wholesaleRate'] as num?)?.toDouble() ??
          0;
      setState(() {
        _product = product;
        _rateCtrl.text = rate > 0 ? rate.toStringAsFixed(2) : '';
      });
    }
  }

  /// Builds a return line from the currently-filled product/quantity fields.
  /// Returns null (and reports why) when the entry is incomplete.
  Map<String, dynamic>? _currentEntry({bool showErrors = true}) {
    if (_product == null) {
      if (showErrors) _message('Please select a product', error: true);
      return null;
    }
    final qty = double.tryParse(_qtyCtrl.text.trim()) ?? 0;
    if (qty <= 0) {
      if (showErrors) _message('Please enter a valid quantity', error: true);
      return null;
    }
    final rate = double.tryParse(_rateCtrl.text.trim()) ?? 0;
    if (rate < 0) {
      if (showErrors) _message('Please enter a valid rate', error: true);
      return null;
    }
    return {
      'productName': _product!['name'].toString(),
      'quantity': qty,
      'rate': rate,
      'packSize': (_product!['packSize'] ?? '').toString(),
    };
  }

  void _addProduct() {
    final entry = _currentEntry();
    if (entry == null) return;
    setState(() {
      _items.add(entry);
      _product = null;
      _qtyCtrl.clear();
      _rateCtrl.clear();
    });
  }

  Future<void> _submit() async {
    if (_partyCtrl.text.trim().isEmpty) {
      _message('Please select a customer', error: true);
      return;
    }
    if (!_isExpired && _reasonCtrl.text.trim().isEmpty) {
      _message('Please enter the return reason', error: true);
      return;
    }
    // Fold an unfinished entry into the submission so a single-product return
    // does not need a separate "Add Product" tap.
    final items = [..._items];
    if (_product != null || _qtyCtrl.text.trim().isNotEmpty) {
      final entry = _currentEntry(showErrors: items.isEmpty);
      if (entry != null) {
        items.add(entry);
      } else if (items.isEmpty) {
        return;
      }
    }
    if (items.isEmpty) {
      _message('Please add at least one product', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final result = await ApiService.createSalesReturn(
          partyName: _partyCtrl.text.trim(),
          invoiceNo: _invoiceCtrl.text.trim(),
          items: items
              .map((item) => {
                    'productName': item['productName'],
                    'packSize': item['packSize'],
                    'quantity': item['quantity'],
                    'rate': item['rate'],
                  })
              .toList(),
           reason: _reasonCtrl.text.trim(),
           isExpired: _isExpired,
          returnDate: DateTime.now());
      if (!mounted) return;
      _message('Return invoice ${result['returnNo']} created in ERP');
      setState(() {
        _partyCtrl.clear();
        _invoiceCtrl.clear();
        _reasonCtrl.clear();
        _isExpired = false;
        _qtyCtrl.clear();
        _rateCtrl.clear();
        _product = null;
        _items.clear();
      });
      widget.onCreated();
    } catch (_) {
      if (mounted) _message('Could not create the ERP return invoice', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryAccent));
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = isDark ? AppTheme.darkCard : Colors.white;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Return details',
            style: GoogleFonts.hindSiliguri(
                color: AppTheme.primaryAccent, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        _pickerField('Customer *', _partyCtrl.text, Icons.storefront_rounded,
            _chooseParty, card),
        const SizedBox(height: 12),
        TextField(
          controller: _invoiceCtrl,
          style: GoogleFonts.hindSiliguri(),
          decoration: const InputDecoration(
              labelText: 'Original Invoice No. (optional)',
              prefixIcon: Icon(Icons.receipt_long_rounded)),
        ),
        const SizedBox(height: 12),
         Container(
           decoration: BoxDecoration(
             color: _isExpired
                 ? AppTheme.warning.withValues(alpha: .12)
                 : Theme.of(context).cardColor,
             borderRadius: BorderRadius.circular(12),
             border: Border.all(
               color: _isExpired
                   ? AppTheme.warning
                   : AppTheme.divider,
             ),
           ),
           child: SwitchListTile(
             contentPadding: const EdgeInsets.symmetric(horizontal: 12),
             secondary: Icon(
               Icons.event_busy_rounded,
               color: _isExpired ? AppTheme.warning : AppTheme.textGrey,
             ),
             value: _isExpired,
             onChanged: (value) => setState(() {
               _isExpired = value;
               if (value) _reasonCtrl.text = 'Expired';
               else if (_reasonCtrl.text.trim().toLowerCase() == 'expired') {
                 _reasonCtrl.clear();
               }
             }),
             title: Text('Is Expired',
                 style: GoogleFonts.hindSiliguri(
                     fontWeight: FontWeight.w800)),
             subtitle: Text(
                 'Mark this as an expired return. Stock will not be added.',
                 style: GoogleFonts.hindSiliguri(fontSize: 11)),
             activeColor: AppTheme.warning,
           ),
         ),
         const SizedBox(height: 12),
        TextField(
          controller: _reasonCtrl,
          maxLines: 2,
          enabled: !_isExpired,
          style: GoogleFonts.hindSiliguri(),
          decoration: const InputDecoration(
              labelText: 'Return Reason',
              prefixIcon: Icon(Icons.notes_rounded)),
        ),
        const SizedBox(height: 22),
        Text('Products',
            style: GoogleFonts.hindSiliguri(
                color: AppTheme.primaryAccent, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        _pickerField(
            'Product *',
            _product == null
                ? 'Search and select a product'
                : '${_product!['name']}${(_product!['packSize'] ?? '').toString().isEmpty ? '' : ' • ${_product!['packSize']}'}',
            Icons.inventory_2_rounded,
            _chooseProduct,
            card),
        if (_product != null &&
            (_product!['packSize'] ?? '').toString().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 5, left: 5),
            child: Text('Pack size: ${_product!['packSize']}',
                style: GoogleFonts.hindSiliguri(
                    fontSize: 11, color: AppTheme.textGrey)),
          ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _qtyCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,3}'))
                ],
                style: GoogleFonts.hindSiliguri(),
                decoration: const InputDecoration(
                    labelText: 'Quantity *',
                    prefixIcon: Icon(Icons.numbers_rounded)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _rateCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
                ],
                style: GoogleFonts.hindSiliguri(),
                decoration: const InputDecoration(
                    labelText: 'Rate *',
                    prefixIcon: Icon(Icons.price_change_outlined)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
            onPressed: _addProduct,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Product')),
        if (_items.isNotEmpty) ...[
          const SizedBox(height: 12),
          ..._items.asMap().entries.map((entry) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.inventory_2_outlined,
                    color: AppTheme.primaryAccent),
                title: Text(entry.value['productName'].toString(),
                    style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w700)),
                subtitle: Text(
                    '${entry.value['packSize']}  •  Qty: ${entry.value['quantity']}',
                    style: GoogleFonts.hindSiliguri(fontSize: 12)),
                trailing: IconButton(
                    onPressed: () =>
                        setState(() => _items.removeAt(entry.key)),
                    icon: const Icon(Icons.close_rounded, color: AppTheme.error)),
              )),
        ],
        const SizedBox(height: 14),
        Text('Current date and time are added automatically.',
            style: GoogleFonts.hindSiliguri(fontSize: 11, color: AppTheme.textGrey)),
        const SizedBox(height: 20),
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
              onPressed: _saving ? null : _submit,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryAccent,
                  foregroundColor: Colors.white),
              icon: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.assignment_return_rounded),
              label: Text(_saving ? 'Creating Invoice...' : 'Create Return Invoice',
                  style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w800))),
        ),
      ],
    );
  }

  Widget _pickerField(String label, String value, IconData icon,
          VoidCallback onTap, Color card) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.divider)),
          child: Row(children: [
            Icon(icon, color: AppTheme.primaryAccent),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(label,
                      style: GoogleFonts.hindSiliguri(
                          fontSize: 11, color: AppTheme.textGrey)),
                  Text(value.isEmpty ? 'Select' : value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.hindSiliguri(fontSize: 14)),
                ])),
            const Icon(Icons.arrow_drop_down_rounded,
                color: AppTheme.primaryAccent),
          ]),
        ),
      );

  @override
  void dispose() {
    _partyCtrl.dispose();
    _invoiceCtrl.dispose();
    _reasonCtrl.dispose();
    _qtyCtrl.dispose();
    _rateCtrl.dispose();
    super.dispose();
  }
}

class _SearchPicker extends StatefulWidget {
  final String title;
  final List<Map<String, dynamic>> items;
  final String Function(Map<String, dynamic>) label;
  final String Function(Map<String, dynamic>) detail;
  const _SearchPicker(
      {required this.title,
      required this.items,
      required this.label,
      required this.detail});

  @override
  State<_SearchPicker> createState() => _SearchPickerState();
}

class _SearchPickerState extends State<_SearchPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final results = widget.items
        .where((item) =>
            '${widget.label(item)} ${widget.detail(item)}'.toLowerCase().contains(_query.toLowerCase()))
        .toList();
    return DraggableScrollableSheet(
      initialChildSize: .75,
      minChildSize: .4,
      maxChildSize: .94,
      expand: false,
      builder: (_, controller) => Material(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Column(children: [
          const SizedBox(height: 12),
          Text(widget.title,
              style: GoogleFonts.hindSiliguri(
                  fontSize: 17, fontWeight: FontWeight.w800)),
          Padding(
            padding: const EdgeInsets.all(14),
            child: TextField(
              autofocus: true,
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(
                  hintText: 'Search...',
                  prefixIcon: Icon(Icons.search_rounded)),
            ),
          ),
          Expanded(
            child: ListView.builder(
                controller: controller,
                itemCount: results.length,
                itemBuilder: (_, index) {
                  final item = results[index];
                  return ListTile(
                    title: Text(widget.label(item),
                        style: GoogleFonts.hindSiliguri(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: Text(widget.detail(item),
                        style: GoogleFonts.hindSiliguri(
                            fontSize: 12, color: AppTheme.textGrey)),
                    onTap: () => Navigator.pop(context, item),
                  );
                }),
          ),
        ]),
      ),
    );
  }
}