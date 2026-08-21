import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../data/wintech_catalog.dart';
import '../../models/order_model.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../services/local_storage_service.dart';
import '../../services/offline_queue_service.dart';

/// Wintech Agro order entry — modeled after the ERP web "Orders Entry" page:
/// party search with previous-due badge, product search with pack sizes,
/// locked TP price, per-line totals, bonus (free) items, payment + paid amount.
class PosOrderScreen extends StatefulWidget {
  const PosOrderScreen({super.key});

  @override
  State<PosOrderScreen> createState() => _PosOrderScreenState();
}

class _LineItem {
  String productId = '';
  String productName = '';
  String packSize = '';
  double rate = 0;
  double quantity = 1;
  bool isBonus = false;
  List<Map<String, dynamic>> packOptions = [];
  double availableStock = -1; // -1 means offline stock is not known.

  bool get isValid => productName.isNotEmpty && quantity > 0;
  double get total => isBonus ? 0 : quantity * rate;
  String get displayName =>
      packSize.isEmpty ? productName : '$productName $packSize';
}

class _PosOrderScreenState extends State<PosOrderScreen> {
  UserModel? _user;
  bool _saving = false;
  bool _erpConnected = false;

  // Party
  String _partyId = '';
  String _partyName = '';
  String _partyZone = '';
  double _partyDue = 0;

  // Lines
  final List<_LineItem> _lines = [];

  // Payment
  String _paymentType = 'Cash';
  DateTime? _probablePaymentDate; // expected payment date (like ERP)
  bool _requestCashCommission = false;
  final _paidCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  static const _paymentTypes = [
    'Cash', 'Bank Transfer', 'Cheque', 'Mobile Banking', 'Credit'
  ];

  final _invoiceNo = 'INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

  // Wintech catalog (offline/demo) — replaced by live ERP data when connected
  List<Map<String, dynamic>> _parties = WintechCatalog.parties
      .map((p) => <String, dynamic>{...p})
      .toList();
  List<Map<String, dynamic>> _products = WintechCatalog.products
      .map((p) => <String, dynamic>{...p})
      .toList();

  final _fmt = NumberFormat('#,##0', 'en_US');
  final _fmt2 = NumberFormat('#,##0.00', 'en_US');

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadErpData();
    _lines.add(_LineItem());
  }

  Future<void> _loadUser() async {
    final user = await LocalStorageService.getCurrentUser();
    if (!mounted) return;
    setState(() => _user = user);
  }

  /// Pull live parties + product catalog from the ERP (real-time).
  Future<void> _loadErpData() async {
    if (!await ApiService.isConnected) return;
    try {
      final results = await Future.wait([
        ApiService.parties(allBranches: true),
        ApiService.products(),
      ]);
      if (!mounted) return;
      setState(() {
        _erpConnected = true;
        if (results[0].isNotEmpty) {
          _parties = results[0]
              .map((p) => <String, dynamic>{
                    'id': p['_id']?.toString() ?? '',
                    'name': p['name']?.toString() ?? '',
                    'zone': p['branchName']?.toString() ??
                        p['zone']?.toString() ?? '',
                    'previousDue':
                        (p['previousDue'] as num?)?.toDouble() ?? 0,
                  })
              .toList();
        }
        if (results[1].isNotEmpty) {
          _products = results[1]
              .map((p) => <String, dynamic>{
                    'id': p['_id']?.toString() ?? '',
                    'name': p['name']?.toString() ?? '',
                    'packSize': p['packSize']?.toString() ?? '',
                    'unit': p['unit']?.toString() ?? 'Pcs',
                    'price': (p['sellingPrice'] as num?)?.toDouble() ?? 0.0,
                     'stock': (p['stock'] as num?)?.toDouble() ?? 0.0,
                  })
              .toList();
        }
      });
    } catch (_) {
      // ERP unreachable — keep Wintech offline catalog
    }
  }

  // ── Totals ────────────────────────────────────────────────────────────
  List<_LineItem> get _validLines => _lines.where((l) => l.isValid).toList();
  List<_LineItem> get _chargedLines =>
      _validLines.where((l) => !l.isBonus).toList();
  List<_LineItem> get _bonusLines =>
      _validLines.where((l) => l.isBonus).toList();
  double get _subTotal => _chargedLines.fold(0.0, (s, l) => s + l.total);
  double get _paid => double.tryParse(_paidCtrl.text) ?? 0;

  /// The employee can request a full-cash commission manually. The ERP still
  /// validates full payment and an admin must approve the request.
  bool get _isFullCashPayment =>
      _paymentType == 'Cash' && _subTotal > 0 && _paid >= _subTotal;
  double get _cashCommissionPct =>
      _isFullCashPayment && _requestCashCommission ? 3 : 0;
  double get _commissionAmount => _subTotal * _cashCommissionPct / 100;
  double get _grandTotal => _subTotal - _commissionAmount;
  double get _due => (_grandTotal - _paid).clamp(0, double.infinity);

  bool _hasAvailableStock(_LineItem line) => line.availableStock >= 0;

  bool _validateStock() {
    final requestedByProduct = <String, double>{};
    final linesByProduct = <String, _LineItem>{};
    for (final line in _validLines) {
      if (!_hasAvailableStock(line)) continue;
      final key = line.productId.isNotEmpty ? line.productId : line.displayName;
      requestedByProduct[key] = (requestedByProduct[key] ?? 0) + line.quantity;
      linesByProduct[key] = line;
    }
    for (final entry in requestedByProduct.entries) {
      final line = linesByProduct[entry.key]!;
      if (entry.value > line.availableStock) {
        _showError(
          'Only ${line.availableStock.toStringAsFixed(0)} pcs of ${line.displayName} are available in your branch.',
        );
        return false;
      }
    }
    return true;
  }

  void _increaseQuantity(_LineItem line) {
    final next = line.quantity + 1;
    if (_hasAvailableStock(line) && next > line.availableStock) {
      _showError(
        'Only ${line.availableStock.toStringAsFixed(0)} pcs are available in your branch.',
      );
      return;
    }
    setState(() => line.quantity = next);
  }

  // ── Pickers ───────────────────────────────────────────────────────────
  void _pickParty() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SearchSheet(
        title: 'Select Party',
        hint: 'Search party name or zone…',
        items: _parties,
        itemBuilder: (p, isDark) {
          final due = (p['previousDue'] as num?)?.toDouble() ?? 0;
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(vertical: 2),
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppTheme.primaryAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.store_rounded,
                  color: AppTheme.primaryAccent, size: 20),
            ),
            title: Text(p['name'] as String,
                style: GoogleFonts.hindSiliguri(
                    fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: Text(p['zone'] as String? ?? '',
                style: GoogleFonts.hindSiliguri(
                    fontSize: 11, color: AppTheme.textGrey)),
            trailing: due > 0
                ? Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('Due ৳${_fmt.format(due)}',
                        style: GoogleFonts.hindSiliguri(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.error)),
                  )
                : null,
          );
        },
        matcher: (p, q) =>
            (p['name'] as String).toLowerCase().contains(q) ||
            (p['zone'] as String? ?? '').toLowerCase().contains(q),
        onSelect: (p) => setState(() {
          _partyId = p['id']?.toString() ?? '';
          _partyName = p['name'] as String;
          _partyZone = p['zone'] as String? ?? '';
          _partyDue = (p['previousDue'] as num?)?.toDouble() ?? 0;
        }),
      ),
    );
  }

  void _pickProduct(int index) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SearchSheet(
        title: 'Select Product',
        hint: 'Search Wintech products…',
        items: _products,
        itemBuilder: (p, isDark) {
          final stock = (p['stock'] as num?)?.toDouble() ?? 0;
          final outOfStock = _erpConnected && stock <= 0;
          return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 2),
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.primaryAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.science_rounded,
                color: AppTheme.primaryAccent, size: 20),
          ),
          title: Text(p['name'] as String,
              style: GoogleFonts.hindSiliguri(
                  fontSize: 14, fontWeight: FontWeight.w600)),
          subtitle: Text(
              [
                if ((p['packSize'] as String? ?? '').isNotEmpty)
                  p['packSize'] as String,
                'TP ৳${_fmt.format((p['price'] as num?) ?? 0)}',
              ].join(' · '),
              style: GoogleFonts.hindSiliguri(
                  fontSize: 11, color: AppTheme.textGrey)),
          trailing: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.primaryAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
                _erpConnected
                    ? (outOfStock ? 'Out of stock' : '${stock.toStringAsFixed(0)} pcs')
                    : 'Add',
                style: GoogleFonts.hindSiliguri(
                    fontSize: 12,
                    color: outOfStock ? AppTheme.error : AppTheme.primaryAccent,
                    fontWeight: FontWeight.w700)),
          ),
        );
        },
        matcher: (p, q) =>
            (p['name'] as String).toLowerCase().contains(q) ||
            (p['packSize'] as String? ?? '').toLowerCase().contains(q),
        onSelect: (p) => setState(() {
          final line = _lines[index];
          final wasBlank = line.productName.isEmpty;
          line.productId = p['id']?.toString() ?? '';
          line.productName = p['name'] as String;
          line.packSize = p['packSize'] as String? ?? '';
          line.rate = (p['price'] as num?)?.toDouble() ?? 0;
          line.availableStock = _erpConnected
              ? (p['stock'] as num?)?.toDouble() ?? 0
              : -1;
          if (line.quantity <= 0) line.quantity = 1;
          // Pack-size variants of the same base product
          line.packOptions = _products
              .where((x) => x['name'] == p['name'])
              .toList();
          // Keep the product search row at the top and chosen products below.
          if (wasBlank) _lines.insert(0, _LineItem());
        }),
      ),
    );
  }

  // ── Submit ────────────────────────────────────────────────────────────
  Future<void> _submitOrder() async {
    if (_partyName.isEmpty) {
      _showError('Please select a party');
      return;
    }
    if (_chargedLines.isEmpty) {
      _showError('Add at least one (non-bonus) product');
      return;
    }
    if (!_validateStock()) return;

    setState(() => _saving = true);

    final apiItems = _validLines
        .map((l) => {
              if (l.productId.isNotEmpty) 'productId': l.productId,
              'productName': l.displayName + (l.isBonus ? ' (Bonus)' : ''),
              'quantity': l.quantity,
              'rate': l.isBonus ? 0 : l.rate,
              'unit': 'Pcs',
              'isBonus': l.isBonus,
            })
        .toList();
    final partyId = _partyId.startsWith('WP-') || _partyId.isEmpty
        ? null
        : _partyId;
    final payload = {
      if (partyId != null) 'partyId': partyId,
      'partyName': _partyName,
      'items': apiItems,
      'paymentType': _paymentType,
      'paidAmount': _paid,
      'notes': _notesCtrl.text.trim(),
      'requestCommission': _requestCashCommission && _isFullCashPayment,
      if (_probablePaymentDate != null)
        'probablePaymentDate': _probablePaymentDate!.toIso8601String(),
    };

    // 1) Push to ERP live when connected; queue offline otherwise.
    bool sentToErp = false;
    bool queuedOffline = false;
    String? erpError;
    if (await ApiService.isConnected) {
      try {
        await ApiService.createOrder(
          partyId: partyId,
          partyName: _partyName,
          items: apiItems,
          paymentType: _paymentType,
          paidAmount: _paid,
          notes: _notesCtrl.text.trim(),
          probablePaymentDate: _probablePaymentDate,
          requestCommission: _requestCashCommission && _isFullCashPayment,
        );
        sentToErp = true;
      } on ApiException catch (e) {
        erpError = e.message; // e.g. credit limit full
      } catch (_) {
        await OfflineQueueService.enqueueOrder(payload);
        queuedOffline = true;
      }
    } else if (await ApiService.getToken() != null) {
      await OfflineQueueService.enqueueOrder(payload);
      queuedOffline = true;
    }

    if (erpError != null) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showError(erpError);
      return;
    }

    // 2) Always keep a local copy for offline viewing.
    final order = OrderModel(
      id: _invoiceNo,
      srId: _user?.id ?? '',
      srName: _user?.name ?? '',
      customerId: _partyId,
      customerName: _partyName,
      items: _validLines
          .map((l) => OrderItem(
                productName: l.displayName,
                quantity: l.quantity,
                unit: 'Pcs',
                unitPrice: l.isBonus ? 0 : l.rate,
                isBonus: l.isBonus,
              ))
          .toList(),
      total: _subTotal,
      date: DateTime.now(),
      status: OrderModel.statusPending,
      notes: _notesCtrl.text.trim(),
      probablePaymentDate: _probablePaymentDate,
      paidAmount: _paid,
      paymentType: _paymentType,
      commissionPct: _cashCommissionPct,
    );
    await LocalStorageService.saveOrder(order);

    if (!mounted) return;
    setState(() => _saving = false);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          sentToErp
              ? '✅ Order submitted to ERP!'
              : queuedOffline
                  ? '📥 Offline — order will sync to ERP automatically'
                  : '✅ Order saved (offline)!',
          style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600)),
      backgroundColor: AppTheme.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
    Navigator.pop(context);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600)),
      backgroundColor: AppTheme.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ── UI ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppTheme.darkCard : Colors.white;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Orders Entry',
                style: GoogleFonts.hindSiliguri(
                    fontSize: 17, fontWeight: FontWeight.w700)),
            Text('#$_invoiceNo',
                style: GoogleFonts.hindSiliguri(
                    fontSize: 11, color: Colors.white70)),
          ],
        ),
        backgroundColor: AppTheme.primaryAccent,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_erpConnected)
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Row(children: [
                const Icon(Icons.cloud_done_rounded,
                    size: 15, color: Colors.white70),
                const SizedBox(width: 4),
                Text('ERP live',
                    style: GoogleFonts.hindSiliguri(
                        fontSize: 11, color: Colors.white70)),
              ]),
            ),
        ],
      ),
      body: Column(
        children: [
          // Pending banner (web parity)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: AppTheme.warning.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppTheme.warning.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded,
                  size: 15, color: AppTheme.warning),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                    'Orders stay Pending in the ERP until an admin approves them.',
                    style: GoogleFonts.hindSiliguri(
                        fontSize: 11.5, color: AppTheme.warning)),
              ),
            ]),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPartyCard(isDark, cardBg),
                  const SizedBox(height: 18),
                  _buildLinesHeader(isDark),
                  const SizedBox(height: 8),
                  ..._lines.asMap().entries.map(
                      (e) => _buildLineCard(e.key, e.value, isDark, cardBg)),
                  if (_bonusLines.isNotEmpty) _buildBonusSummary(isDark),
                  const SizedBox(height: 16),
                  _buildPaymentCard(isDark, cardBg),
                  const SizedBox(height: 14),
                  // Notes
                  Container(
                    decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.divider)),
                    child: TextField(
                      controller: _notesCtrl,
                      maxLines: 2,
                      style: GoogleFonts.hindSiliguri(fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Notes (optional)',
                        labelStyle: GoogleFonts.hindSiliguri(
                            fontSize: 13, color: AppTheme.textGrey),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 90),
                ],
              ),
            ),
          ),
          _buildBottomBar(isDark, cardBg),
        ],
      ),
    );
  }

  Widget _buildPartyCard(bool isDark, Color cardBg) {
    final selected = _partyName.isNotEmpty;
    return GestureDetector(
      onTap: _pickParty,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppTheme.primaryAccent : AppTheme.divider,
            width: selected ? 2 : 1.5,
          ),
        ),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: AppTheme.primaryAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.store_rounded,
                color: AppTheme.primaryAccent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Party *',
                    style: GoogleFonts.hindSiliguri(
                        fontSize: 11, color: AppTheme.textGrey)),
                Text(
                  selected ? _partyName : 'Search & select party',
                  style: GoogleFonts.hindSiliguri(
                      fontSize: 14,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w400,
                      color: selected
                          ? (isDark ? AppTheme.darkText : AppTheme.textDark)
                          : AppTheme.textGrey),
                ),
                if (selected && (_partyZone.isNotEmpty || _partyDue > 0))
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Wrap(spacing: 6, children: [
                      if (_partyZone.isNotEmpty)
                        Text(_partyZone,
                            style: GoogleFonts.hindSiliguri(
                                fontSize: 11, color: AppTheme.textGrey)),
                      if (_partyDue > 0)
                        Text('Prev Due: ৳${_fmt.format(_partyDue)}',
                            style: GoogleFonts.hindSiliguri(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.error)),
                    ]),
                  ),
              ],
            ),
          ),
          const Icon(Icons.arrow_drop_down_rounded,
              color: AppTheme.primaryAccent),
        ]),
      ),
    );
  }

  Widget _buildLinesHeader(bool isDark) {
    return Row(children: [
      Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
              color: AppTheme.primaryAccent,
              borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text('Products',
          style: GoogleFonts.hindSiliguri(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isDark ? AppTheme.darkText : AppTheme.textDark)),
    ]);
    );
  }

  Widget _buildLineCard(int index, _LineItem line, bool isDark, Color cardBg) {
    final hasProduct = line.productName.isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: line.isBonus && hasProduct
            ? AppTheme.warning.withValues(alpha: isDark ? 0.08 : 0.06)
            : cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: line.isBonus && hasProduct
                ? AppTheme.warning.withValues(alpha: 0.45)
                : AppTheme.divider),
      ),
      child: Column(children: [
        // Product selector row
        Row(children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _pickProduct(index),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : AppTheme.primaryAccent.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Row(children: [
                  Icon(
                      hasProduct
                          ? Icons.science_rounded
                          : Icons.search_rounded,
                      size: 17,
                      color: hasProduct
                          ? AppTheme.primaryAccent
                          : AppTheme.textGrey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hasProduct ? line.productName : 'Search product…',
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.hindSiliguri(
                          fontSize: 13.5,
                          fontWeight: hasProduct
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: hasProduct
                              ? (isDark
                                  ? AppTheme.darkText
                                  : AppTheme.textDark)
                              : AppTheme.textGrey),
                    ),
                  ),
                ]),
              ),
            ),
          ),
          if (hasProduct) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => setState(() => _lines.removeAt(index)),
              child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                      color: AppTheme.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.delete_outline_rounded,
                      color: AppTheme.error, size: 18)),
            ),
          ],
        ]),
        if (hasProduct) ...[
          const SizedBox(height: 10),
          Row(children: [
            // Pack size dropdown (variants from price list)
            Expanded(
              flex: 3,
              child: line.packOptions.length > 1
                  ? DropdownButtonFormField<String>(
                      value: line.packSize,
                      isDense: true,
                      style: GoogleFonts.hindSiliguri(
                          fontSize: 13,
                          color: isDark
                              ? AppTheme.darkText
                              : AppTheme.textDark),
                      decoration: _fieldDeco('Pack Size'),
                      items: line.packOptions
                          .map((o) => DropdownMenuItem(
                                value: o['packSize'] as String,
                                child: Text(o['packSize'] as String,
                                    style: GoogleFonts.hindSiliguri(
                                        fontSize: 13)),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() {
                        final opt = line.packOptions
                            .firstWhere((o) => o['packSize'] == v);
                        line.packSize = v ?? '';
                        line.productId = opt['id']?.toString() ?? '';
                        line.rate =
                            (opt['price'] as num?)?.toDouble() ?? 0;
                        line.availableStock = _erpConnected
                            ? (opt['stock'] as num?)?.toDouble() ?? 0
                            : -1;
                      }),
                    )
                  : InputDecorator(
                      decoration: _fieldDeco('Pack Size'),
                      child: Text(
                          line.packSize.isEmpty ? '—' : line.packSize,
                          style: GoogleFonts.hindSiliguri(fontSize: 13)),
                    ),
            ),
            const SizedBox(width: 8),
            // Qty stepper
            Expanded(
              flex: 4,
              child: InputDecorator(
                decoration: _fieldDeco('Qty'),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _qtyBtn(Icons.remove_rounded, () {
                      if (line.quantity > 1) {
                        setState(() => line.quantity--);
                      }
                    }),
                    Text(line.quantity.toStringAsFixed(0),
                        style: GoogleFonts.hindSiliguri(
                            fontSize: 15, fontWeight: FontWeight.w800)),
                    _qtyBtn(Icons.add_rounded, () => _increaseQuantity(line)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            // TP price — locked (web parity for employees)
            Expanded(
              flex: 3,
              child: InputDecorator(
                decoration: _fieldDeco('TP ৳'),
                child: Row(children: [
                  Expanded(
                    child: Text(
                        line.isBonus ? 'FREE' : _fmt.format(line.rate),
                        style: GoogleFonts.hindSiliguri(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: line.isBonus
                                ? AppTheme.warning
                                : (isDark
                                    ? AppTheme.darkText
                                    : AppTheme.textDark))),
                  ),
                  const Icon(Icons.lock_rounded,
                      size: 11, color: AppTheme.textGrey),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          if (_hasAvailableStock(line))
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: line.quantity > line.availableStock
                    ? AppTheme.error.withValues(alpha: 0.08)
                    : AppTheme.success.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                line.quantity > line.availableStock
                    ? 'Requested quantity is above your branch stock (${line.availableStock.toStringAsFixed(0)} pcs).'
                    : 'Available in your branch: ${line.availableStock.toStringAsFixed(0)} pcs',
                style: GoogleFonts.hindSiliguri(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: line.quantity > line.availableStock
                      ? AppTheme.error
                      : AppTheme.success,
                ),
              ),
            ),
          Row(children: [
            // Bonus tick — mark this line as a free bonus item
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => line.isBonus = !line.isBonus),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                      line.isBonus
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded,
                      size: 19,
                      color: line.isBonus
                          ? AppTheme.warning
                          : AppTheme.textGrey),
                  const SizedBox(width: 6),
                  Text('Bonus (free — not charged)',
                      style: GoogleFonts.hindSiliguri(
                          fontSize: 12,
                          fontWeight: line.isBonus
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: line.isBonus
                              ? AppTheme.warning
                              : AppTheme.textGrey)),
                ]),
              ),
            ),
            Text(
              line.isBonus ? '৳ 0' : '৳ ${_fmt2.format(line.total)}',
              style: GoogleFonts.hindSiliguri(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: line.isBonus
                      ? AppTheme.warning
                      : AppTheme.primaryAccent),
            ),
          ]),
        ],
      ]),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: AppTheme.primaryAccent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: AppTheme.primaryAccent),
      ),
    );
  }

  InputDecoration _fieldDeco(String label) => InputDecoration(
        labelText: label,
        labelStyle:
            GoogleFonts.hindSiliguri(fontSize: 11, color: AppTheme.textGrey),
        border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        isDense: true,
      );

  Widget _buildBonusSummary(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(top: 2, bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        const Text('🎁', style: TextStyle(fontSize: 14)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
              '${_bonusLines.length} bonus item(s) · ${_bonusLines.fold<double>(0, (s, l) => s + l.quantity).toStringAsFixed(0)} pcs free — not charged',
              style: GoogleFonts.hindSiliguri(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.warning)),
        ),
      ]),
    );
  }

  Widget _buildPaymentCard(bool isDark, Color cardBg) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(children: [
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _paymentType,
              isDense: true,
              style: GoogleFonts.hindSiliguri(
                  fontSize: 13,
                  color: isDark ? AppTheme.darkText : AppTheme.textDark),
              decoration: _fieldDeco('Payment Type'),
              items: _paymentTypes
                  .map((t) => DropdownMenuItem(
                      value: t,
                      child: Text(t,
                          style: GoogleFonts.hindSiliguri(fontSize: 13))))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _paymentType = v ?? 'Cash'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _paidCtrl,
              onChanged: (_) => setState(() {}),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: GoogleFonts.hindSiliguri(fontSize: 13.5),
              decoration: _fieldDeco('Paid Amount (৳)'),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        // Probable payment date (like ERP)
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _probablePaymentDate ??
                  DateTime.now().add(const Duration(days: 7)),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (picked != null) {
              setState(() => _probablePaymentDate = picked);
            }
          },
          child: InputDecorator(
            decoration: _fieldDeco('Probable Payment Date'),
            child: Row(children: [
              const Icon(Icons.event_rounded,
                  size: 16, color: AppTheme.primaryAccent),
              const SizedBox(width: 8),
              Text(
                  _probablePaymentDate == null
                      ? 'Select date (optional)'
                      : DateFormat('dd MMM yyyy')
                          .format(_probablePaymentDate!),
                  style: GoogleFonts.hindSiliguri(
                      fontSize: 13,
                      color: _probablePaymentDate == null
                          ? AppTheme.textGrey
                          : (isDark
                              ? AppTheme.darkText
                              : AppTheme.textDark))),
              const Spacer(),
              if (_probablePaymentDate != null)
                GestureDetector(
                  onTap: () =>
                      setState(() => _probablePaymentDate = null),
                  child: const Icon(Icons.close_rounded,
                      size: 16, color: AppTheme.textGrey),
                ),
            ]),
          ),
        ),
        if (_cashCommissionPct > 0) ...[
          const SizedBox(height: 10),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppTheme.success.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.percent_rounded,
                  size: 15, color: AppTheme.success),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                    'Cash Commission 3% requested: ৳${_fmt2.format(_commissionAmount)} (ERP admin approval required)',
                    style: GoogleFonts.hindSiliguri(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.success)),
              ),
            ]),
          ),
        ],
        if (_isFullCashPayment) ...[
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _requestCashCommission,
            activeColor: AppTheme.primaryAccent,
            onChanged: (value) =>
                setState(() => _requestCashCommission = value),
            title: Text('Request 3% cash commission',
                style: GoogleFonts.hindSiliguri(
                    fontSize: 13, fontWeight: FontWeight.w700)),
            subtitle: Text(
                'Full payment received — turn this on or off before saving.',
                style: GoogleFonts.hindSiliguri(
                    fontSize: 11.5, color: AppTheme.textGrey)),
          ),
        ] else if (_requestCashCommission) ...[
          const SizedBox(height: 8),
          Text('Commission request is off until the full cash amount is entered.',
              style: GoogleFonts.hindSiliguri(
                  fontSize: 11.5, color: AppTheme.textGrey)),
        ],
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(
              _due <= 0 && _subTotal > 0 ? 'Fully Paid' : 'Due Amount',
              style: GoogleFonts.hindSiliguri(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: _due <= 0 && _subTotal > 0
                      ? AppTheme.success
                      : AppTheme.error)),
          Text('৳ ${_fmt2.format(_due)}',
              style: GoogleFonts.hindSiliguri(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: _due <= 0 && _subTotal > 0
                      ? AppTheme.success
                      : AppTheme.error)),
        ]),
      ]),
    );
  }

  Widget _buildBottomBar(bool isDark, Color cardBg) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
      decoration: BoxDecoration(
        color: cardBg,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
              blurRadius: 16,
              offset: const Offset(0, -4))
        ],
      ),
      child: Column(children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
                '${_chargedLines.length} item(s)'
                '${_bonusLines.isNotEmpty ? ' + ${_bonusLines.length} bonus' : ''}',
                style: GoogleFonts.hindSiliguri(
                    fontSize: 12.5, color: AppTheme.textGrey)),
            Text('৳ ${_fmt2.format(_subTotal)}',
                style: GoogleFonts.hindSiliguri(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryAccent)),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _saving ? null : _submitOrder,
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation(Colors.white)))
                : const Icon(Icons.check_circle_rounded, size: 20),
            label: Text(_saving ? 'Saving…' : 'Save Order',
                style: GoogleFonts.hindSiliguri(
                    fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }

  @override
  void dispose() {
    _paidCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }
}

// ── Reusable searchable bottom sheet ──────────────────────────────────────
class _SearchSheet extends StatefulWidget {
  final String title;
  final String hint;
  final List<Map<String, dynamic>> items;
  final Widget Function(Map<String, dynamic>, bool isDark) itemBuilder;
  final bool Function(Map<String, dynamic>, String lowercaseQuery) matcher;
  final ValueChanged<Map<String, dynamic>> onSelect;

  const _SearchSheet({
    required this.title,
    required this.hint,
    required this.items,
    required this.itemBuilder,
    required this.matcher,
    required this.onSelect,
  });

  @override
  State<_SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<_SearchSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final q = _query.toLowerCase().trim();
    final filtered = q.isEmpty
        ? widget.items
        : widget.items.where((p) => widget.matcher(p, q)).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (ctx, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 14),
              decoration: BoxDecoration(
                  color: AppTheme.divider,
                  borderRadius: BorderRadius.circular(4)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Expanded(
                  child: Text(widget.title,
                      style: GoogleFonts.hindSiliguri(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppTheme.darkText
                              : AppTheme.textDark)),
                ),
                Text('${filtered.length} results',
                    style: GoogleFonts.hindSiliguri(
                        fontSize: 11, color: AppTheme.textGrey)),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: const Icon(Icons.close_rounded,
                      color: AppTheme.textGrey, size: 22),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: GoogleFonts.hindSiliguri(fontSize: 14),
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: widget.hint,
                  hintStyle: GoogleFonts.hindSiliguri(
                      fontSize: 13, color: AppTheme.textGrey),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: AppTheme.textGrey, size: 20),
                  suffixIcon: _query.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                          child: const Icon(Icons.clear_rounded,
                              color: AppTheme.textGrey, size: 18),
                        )
                      : null,
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : AppTheme.primaryAccent.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.divider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: AppTheme.primaryAccent, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (filtered.isEmpty)
              Expanded(
                child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.search_off_rounded,
                        color: AppTheme.textGrey, size: 40),
                    const SizedBox(height: 8),
                    Text('No results found',
                        style: GoogleFonts.hindSiliguri(
                            fontSize: 14, color: AppTheme.textGrey)),
                  ]),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 56),
                  itemBuilder: (_, i) => InkWell(
                    onTap: () {
                      widget.onSelect(filtered[i]);
                      Navigator.pop(ctx);
                    },
                    child: widget.itemBuilder(filtered[i], isDark),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
