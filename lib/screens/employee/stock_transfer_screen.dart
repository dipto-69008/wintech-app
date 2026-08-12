import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../services/local_storage_service.dart';
import '../../services/offline_queue_service.dart';

/// Native stock-transfer screen.
/// — CREATE: submits directly to ERP via API; if offline, queues locally.
/// — LIST  : loads live ERP data; falls back to local queue preview.
class StockTransferScreen extends StatefulWidget {
  const StockTransferScreen({super.key});
  @override
  State<StockTransferScreen> createState() => _StockTransferScreenState();
}

class _StockTransferScreenState extends State<StockTransferScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }
  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Stock Transfer',
            style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w700)),
        backgroundColor: AppTheme.primaryAccent,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tab,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w700, fontSize: 13),
          unselectedLabelStyle: GoogleFonts.hindSiliguri(fontSize: 13),
          tabs: const [Tab(text: 'List'), Tab(text: 'New Transfer')],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _TransferListTab(),
          _NewTransferTab(onCreated: () {
            _tab.animateTo(0);
          }),
        ],
      ),
    );
  }
}

// ── Transfer List Tab ─────────────────────────────────────────────────────────

class _TransferListTab extends StatefulWidget {
  @override
  State<_TransferListTab> createState() => _TransferListTabState();
}

class _TransferListTabState extends State<_TransferListTab>
    with AutomaticKeepAliveClientMixin {
  bool _loading = true;
  bool _erpConnected = false;
  List<Map<String, dynamic>> _transfers = [];
  List<QueueItem> _queued = [];
  final _fmt = NumberFormat('#,##0.##', 'en_US');

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final queuedItems = await OfflineQueueService.getQueue();
    final pendingTransfers = queuedItems.where((q) => q.type == QueueItemType.stockTransfer).toList();

    if (await ApiService.isConnected) {
      try {
        final data = await ApiService.stockTransfers(mineOnly: true);
        if (!mounted) return;
        setState(() {
          _erpConnected = true;
          _transfers = data;
          _queued = pendingTransfers;
          _loading = false;
        });
        return;
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _erpConnected = false;
      _transfers = [];
      _queued = pendingTransfers;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryAccent));
    }

    final all = [
      ..._queued.map((q) => {'_queued': true, ...q.payload,
        'date': q.createdAt.toIso8601String(),
        'transferredBy': 'Pending (Offline)',
      }),
      ..._transfers,
    ];

    if (all.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.swap_horiz_rounded, size: 64,
              color: AppTheme.textGrey.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text('No transfers found',
              style: GoogleFonts.hindSiliguri(color: AppTheme.textGrey, fontSize: 15)),
          const SizedBox(height: 8),
          TextButton(onPressed: _load,
              child: Text('Refresh', style: GoogleFonts.hindSiliguri())),
        ]),
      );
    }

    return RefreshIndicator(
      color: AppTheme.primaryAccent,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (!_erpConnected)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                const Icon(Icons.wifi_off_rounded, color: Colors.orange, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text('Offline Mode — No ERP connection',
                    style: GoogleFonts.hindSiliguri(fontSize: 12, color: Colors.orange))),
              ]),
            ),
          ...all.map((t) => _TransferCard(t: t, fmt: _fmt, isDark: isDark)),
        ],
      ),
    );
  }
}

class _TransferCard extends StatelessWidget {
  final Map<String, dynamic> t;
  final NumberFormat fmt;
  final bool isDark;
  const _TransferCard({required this.t, required this.fmt, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final queued = t['_queued'] == true;
    final date = t['date'] != null
        ? DateFormat('dd MMM yy, hh:mm a').format(DateTime.tryParse(t['date'].toString()) ?? DateTime.now())
        : '—';

    // Build quantity display: pcs + carton/bucket
    final qty = (t['quantity'] as num?)?.toDouble() ?? 0;
    final unitLabel = t['quantityUnit']?.toString() ?? 'Pcs';
    final carton = t['cartonCount'] != null ? '${t['cartonCount']} Ctn' : null;
    final bucket = t['bucketCount'] != null ? '${t['bucketCount']} Bkt' : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: queued ? Colors.orange.withValues(alpha: 0.6) : AppTheme.divider,
          width: queued ? 1.5 : 1,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: queued
                  ? Colors.orange.withValues(alpha: 0.12)
                  : AppTheme.primaryAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(queued ? 'Offline' : 'ERP ✓',
                style: GoogleFonts.hindSiliguri(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: queued ? Colors.orange : AppTheme.primaryAccent)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(t['productName']?.toString() ?? '—',
                style: GoogleFonts.hindSiliguri(
                    fontSize: 14, fontWeight: FontWeight.w700,
                    color: isDark ? AppTheme.darkText : AppTheme.textDark),
                overflow: TextOverflow.ellipsis),
          ),
          Text(
            '× ${fmt.format(qty)} $unitLabel'
            '${carton != null ? ' ($carton)' : ''}'
            '${bucket != null ? ' ($bucket)' : ''}',
            style: GoogleFonts.hindSiliguri(
                fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primaryAccent)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          const Icon(Icons.arrow_forward_rounded, size: 14, color: AppTheme.textGrey),
          const SizedBox(width: 4),
          Expanded(child: Text(
              '${t['fromBranch'] ?? '—'}  →  ${t['toBranch'] ?? '—'}',
              style: GoogleFonts.hindSiliguri(fontSize: 12, color: AppTheme.textGrey))),
        ]),
        // Weight row
        if ((t['totalWeight'] ?? '') != '') ...[
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.scale_rounded, size: 12, color: AppTheme.textGrey),
            const SizedBox(width: 4),
            Text('${t['totalWeight']} ${t['weightUnit'] ?? 'g'}',
                style: GoogleFonts.hindSiliguri(fontSize: 11, color: AppTheme.textGrey)),
          ]),
        ],
        if ((t['transferredBy'] ?? '').toString().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(t['transferredBy'].toString(),
              style: GoogleFonts.hindSiliguri(fontSize: 11, color: AppTheme.textGrey)),
        ],
        const SizedBox(height: 4),
        Text(date, style: GoogleFonts.hindSiliguri(fontSize: 11, color: AppTheme.textGrey)),
        if ((t['notes'] ?? '').toString().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('📝 ${t['notes']}',
              style: GoogleFonts.hindSiliguri(fontSize: 11, color: AppTheme.textGrey)),
        ],
      ]),
    );
  }
}

// ── New Transfer Tab ──────────────────────────────────────────────────────────

class _NewTransferTab extends StatefulWidget {
  final VoidCallback onCreated;
  const _NewTransferTab({required this.onCreated});
  @override
  State<_NewTransferTab> createState() => _NewTransferTabState();
}

class _NewTransferTabState extends State<_NewTransferTab> {
  UserModel? _user;
  bool _saving = false;
  bool _erpConnected = false;

  // Products from ERP
  List<Map<String, dynamic>> _products = [];
  Map<String, dynamic>? _selectedProduct;

  // Branches from ERP (fallback: canonical operational branches)
  List<String> _branches = [
    'Bogura-1', 'Bogura-2',
    'Comilla-1', 'Comilla-2', 'Comilla-3', 'Comilla-4',
    'Feni-1', 'Feni-2',
    'Fulbaria', 'Fulpur', 'Gouripur',
    'Jessore-1', 'Jessore-2 [Bakra]',
    'Muktagasa', 'Netrokona', 'Tarakanda',
  ];

  String? _fromBranch;
  String? _toBranch;

  // Quantity
  final _qtyCtrl = TextEditingController();
  String _qtyUnit = 'Pcs'; // Pcs | Carton | Bucket
  static const _qtyUnits = ['Pcs', 'Carton', 'Bucket'];

  // Weight
  final _weightCtrl = TextEditingController();
  String _weightUnit = 'g'; // g | ml | kg | L
  static const _weightUnits = ['g', 'ml', 'kg', 'L'];

  final _notesCtrl = TextEditingController();
  final _productSearchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = await LocalStorageService.getCurrentUser();
    if (!mounted) return;
    setState(() {
      _user = user;
      if (user?.branch != null && user!.branch.isNotEmpty) {
        _fromBranch = user.branch;
      }
    });

    if (!await ApiService.isConnected) return;
    try {
      final results = await Future.wait([
        ApiService.products(),
        ApiService.branches(),
      ]);
      if (!mounted) return;
      final prods = results[0];
      final branches = results[1];
      setState(() {
        _erpConnected = true;
        if (prods.isNotEmpty) _products = prods;
        if (branches.isNotEmpty) {
          _branches = branches
              .map((b) => b['name']?.toString() ?? '')
              .where((n) => n.isNotEmpty)
              .toList();
        }
      });
    } catch (_) {
      setState(() => _erpConnected = false);
    }
  }

  /// Converts quantity to pieces based on product's pcs-per-carton / pcs-per-bucket.
  /// Returns (pcs, cartonCount, bucketCount).
  (double, int?, int?) _resolveQuantity() {
    final raw = double.tryParse(_qtyCtrl.text.trim()) ?? 0;
    if (_qtyUnit == 'Carton') {
      final ppc = (_selectedProduct?['pcsPerCarton'] as num?)?.toInt() ?? 1;
      final pcs = raw * ppc;
      return (pcs, raw.toInt(), null);
    } else if (_qtyUnit == 'Bucket') {
      final ppb = (_selectedProduct?['pcsPerBucket'] as num?)?.toInt() ?? 1;
      final pcs = raw * ppb;
      return (pcs, null, raw.toInt());
    }
    return (raw, null, null);
  }

  Future<void> _submit() async {
    final productName = _selectedProduct?['name']?.toString() ??
        _productSearchCtrl.text.trim();
    if (productName.isEmpty) { _snack('Please select a product', error: true); return; }
    if (_fromBranch == null || _fromBranch!.isEmpty) { _snack('Please select source branch', error: true); return; }
    if (_toBranch == null || _toBranch!.isEmpty) { _snack('Please select destination branch', error: true); return; }
    if (_fromBranch == _toBranch) { _snack('Source and destination branch cannot be the same', error: true); return; }
    final rawQty = double.tryParse(_qtyCtrl.text.trim()) ?? 0;
    if (rawQty <= 0) { _snack('Please enter quantity', error: true); return; }

    setState(() => _saving = true);

    final (pcs, cartons, buckets) = _resolveQuantity();
    final weight = _weightCtrl.text.trim();

    final payload = {
      'productName': productName,
      if (_selectedProduct?['_id'] != null) 'productId': _selectedProduct!['_id'].toString(),
      if ((_selectedProduct?['packSize'] ?? '').toString().isNotEmpty)
        'packSize': _selectedProduct!['packSize'].toString(),
      'fromBranch': _fromBranch!,
      'toBranch': _toBranch!,
      'quantity': pcs,
      'quantityUnit': _qtyUnit,
      if (cartons != null) 'cartonCount': cartons,
      if (buckets != null) 'bucketCount': buckets,
      if (weight.isNotEmpty) 'totalWeight': weight,
      if (weight.isNotEmpty) 'weightUnit': _weightUnit,
      'notes': _notesCtrl.text.trim(),
      'transferredBy': '${_user?.name ?? 'Mobile User'} (Mobile)',
    };

    bool sentToErp = false;
    if (_erpConnected || await ApiService.isConnected) {
      try {
        await ApiService.createStockTransfer(
          productName: productName,
          fromBranch: _fromBranch!,
          toBranch: _toBranch!,
          quantity: pcs,
          productId: payload['productId'] as String?,
          packSize: payload['packSize'] as String?,
          notes: payload['notes'] as String? ?? '',
          extraFields: {
            'quantityUnit': _qtyUnit,
            if (cartons != null) 'cartonCount': cartons,
            if (buckets != null) 'bucketCount': buckets,
            if (weight.isNotEmpty) 'totalWeight': weight,
            if (weight.isNotEmpty) 'weightUnit': _weightUnit,
          },
        );
        sentToErp = true;
      } catch (_) {}
    }

    if (!sentToErp) {
      await OfflineQueueService.enqueueStockTransfer(payload);
    }

    if (!mounted) return;
    setState(() => _saving = false);

    _snack(sentToErp
        ? '✅ Transfer submitted to ERP!'
        : '📥 Offline — will sync to ERP when connected');

    setState(() {
      _selectedProduct = null;
      _productSearchCtrl.clear();
      _qtyCtrl.clear();
      _weightCtrl.clear();
      _notesCtrl.clear();
      _toBranch = null;
      _qtyUnit = 'Pcs';
      _weightUnit = 'g';
    });

    widget.onCreated();
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600)),
      backgroundColor: error ? AppTheme.error : AppTheme.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  void _pickProduct() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProductPickerSheet(
        products: _products,
        onSelect: (p) {
          setState(() {
            _selectedProduct = p;
            _productSearchCtrl.text = [
              p['name'] ?? '',
              if ((p['packSize'] ?? '').toString().isNotEmpty) p['packSize'],
            ].join(' ');
          });
        },
      ),
    );
  }

  Widget _branchDropdown(String label, String? value, ValueChanged<String?> onChanged) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      style: GoogleFonts.hindSiliguri(
          fontSize: 14, color: isDark ? AppTheme.darkText : AppTheme.textDark),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.hindSiliguri(fontSize: 13, color: AppTheme.textGrey),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      items: _branches.map((b) => DropdownMenuItem(value: b,
          child: Text(b, style: GoogleFonts.hindSiliguri(fontSize: 14),
              overflow: TextOverflow.ellipsis))).toList(),
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppTheme.darkCard : Colors.white;

    // Derived: pcs-per-carton / pcs-per-bucket from selected product
    final ppc = (_selectedProduct?['pcsPerCarton'] as num?)?.toInt();
    final ppb = (_selectedProduct?['pcsPerBucket'] as num?)?.toInt();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Connection badge
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: (_erpConnected
                  ? AppTheme.success
                  : Colors.orange).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(_erpConnected ? Icons.cloud_done_rounded : Icons.wifi_off_rounded,
                  size: 14, color: _erpConnected ? AppTheme.success : Colors.orange),
              const SizedBox(width: 5),
              Text(_erpConnected ? 'ERP Connected' : 'Offline Mode',
                  style: GoogleFonts.hindSiliguri(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: _erpConnected ? AppTheme.success : Colors.orange)),
            ]),
          ),
        ]),
        const SizedBox(height: 16),

        // Product field
        GestureDetector(
          onTap: _products.isEmpty ? null : _pickProduct,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: _selectedProduct != null
                      ? AppTheme.primaryAccent
                      : AppTheme.divider,
                  width: _selectedProduct != null ? 2 : 1),
            ),
            child: Row(children: [
              const Icon(Icons.inventory_2_rounded,
                  color: AppTheme.primaryAccent, size: 20),
              const SizedBox(width: 10),
              Expanded(child: _products.isEmpty
                  ? TextField(
                controller: _productSearchCtrl,
                style: GoogleFonts.hindSiliguri(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Enter product name',
                  hintStyle: GoogleFonts.hindSiliguri(
                      fontSize: 13, color: AppTheme.textGrey),
                  border: InputBorder.none, isDense: true,
                ),
              )
                  : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Product *',
                    style: GoogleFonts.hindSiliguri(
                        fontSize: 11, color: AppTheme.textGrey)),
                const SizedBox(height: 2),
                Text(
                  _selectedProduct == null
                      ? 'Select a product'
                      : [_selectedProduct!['name'],
                    if ((_selectedProduct!['packSize'] ?? '').toString().isNotEmpty)
                      _selectedProduct!['packSize'],
                  ].join(' '),
                  style: GoogleFonts.hindSiliguri(
                      fontSize: 14,
                      fontWeight: _selectedProduct == null
                          ? FontWeight.w400
                          : FontWeight.w700,
                      color: _selectedProduct == null
                          ? AppTheme.textGrey
                          : (isDark ? AppTheme.darkText : AppTheme.textDark)),
                ),
              ])),
              if (_products.isNotEmpty)
                const Icon(Icons.arrow_drop_down_rounded,
                    color: AppTheme.primaryAccent),
            ]),
          ),
        ),
        const SizedBox(height: 14),

        // From branch
        _branchDropdown('Source Branch (From) *', _fromBranch,
                (v) => setState(() => _fromBranch = v)),
        const SizedBox(height: 14),

        // To branch
        _branchDropdown('Destination Branch (To) *', _toBranch,
                (v) => setState(() => _toBranch = v)),
        const SizedBox(height: 14),

        // ── Quantity with unit selector ───────────────────────────────
        Container(
          decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.divider)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _qtyCtrl,
                onChanged: (_) => setState(() {}),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,3}'))
                ],
                style: GoogleFonts.hindSiliguri(fontSize: 15),
                decoration: InputDecoration(
                  labelText: 'Quantity *',
                  labelStyle: GoogleFonts.hindSiliguri(
                      fontSize: 13, color: AppTheme.textGrey),
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: _qtyUnit,
              underline: const SizedBox(),
              style: GoogleFonts.hindSiliguri(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryAccent),
              items: _qtyUnits
                  .map((u) => DropdownMenuItem(
                      value: u,
                      child: Text(u,
                          style: GoogleFonts.hindSiliguri(fontSize: 13))))
                  .toList(),
              onChanged: (v) => setState(() => _qtyUnit = v ?? 'Pcs'),
            ),
          ]),
        ),

        // Conversion hint
        if (_qtyUnit == 'Carton' && ppc != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(
              '1 Carton = $ppc Pcs  •  '
              '${(double.tryParse(_qtyCtrl.text) ?? 0) * ppc} total pcs',
              style: GoogleFonts.hindSiliguri(
                  fontSize: 11, color: AppTheme.primaryAccent),
            ),
          )
        else if (_qtyUnit == 'Carton' && ppc == null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text('Pcs/Carton not yet configured for this product',
                style: GoogleFonts.hindSiliguri(
                    fontSize: 11, color: Colors.orange)),
          ),
        if (_qtyUnit == 'Bucket' && ppb != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(
              '1 Bucket = $ppb Pcs  •  '
              '${(double.tryParse(_qtyCtrl.text) ?? 0) * ppb} total pcs',
              style: GoogleFonts.hindSiliguri(
                  fontSize: 11, color: AppTheme.primaryAccent),
            ),
          )
        else if (_qtyUnit == 'Bucket' && ppb == null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text('Pcs/Bucket not yet configured for this product',
                style: GoogleFonts.hindSiliguri(
                    fontSize: 11, color: Colors.orange)),
          ),

        const SizedBox(height: 14),

        // ── Total Weight with unit selector ──────────────────────────
        Container(
          decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.divider)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _weightCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,3}'))
                ],
                style: GoogleFonts.hindSiliguri(fontSize: 15),
                decoration: InputDecoration(
                  labelText: 'Total Weight (optional)',
                  labelStyle: GoogleFonts.hindSiliguri(
                      fontSize: 13, color: AppTheme.textGrey),
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: _weightUnit,
              underline: const SizedBox(),
              style: GoogleFonts.hindSiliguri(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryAccent),
              items: _weightUnits
                  .map((u) => DropdownMenuItem(
                      value: u,
                      child: Text(u,
                          style: GoogleFonts.hindSiliguri(fontSize: 13))))
                  .toList(),
              onChanged: (v) => setState(() => _weightUnit = v ?? 'g'),
            ),
          ]),
        ),
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
        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _saving ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryAccent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            icon: _saving
                ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation(Colors.white)))
                : const Icon(Icons.swap_horiz_rounded,
                size: 20, color: Colors.white),
            label: Text(
                _saving ? 'Submitting...' : 'Submit Transfer',
                style: GoogleFonts.hindSiliguri(
                    fontSize: 16, fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _weightCtrl.dispose();
    _notesCtrl.dispose();
    _productSearchCtrl.dispose();
    super.dispose();
  }
}

// ── Product picker bottom sheet ───────────────────────────────────────────────

class _ProductPickerSheet extends StatefulWidget {
  final List<Map<String, dynamic>> products;
  final ValueChanged<Map<String, dynamic>> onSelect;
  const _ProductPickerSheet({required this.products, required this.onSelect});
  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  final _searchCtrl = TextEditingController();
  String _q = '';

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = widget.products.where((p) {
      final name = [p['name'] ?? '', p['packSize'] ?? ''].join(' ').toLowerCase();
      return name.contains(_q.toLowerCase());
    }).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.75, maxChildSize: 0.95, minChildSize: 0.4,
      expand: false,
      builder: (ctx, sc) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(children: [
          Container(width: 40, height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                  color: AppTheme.divider,
                  borderRadius: BorderRadius.circular(4))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _q = v),
              style: GoogleFonts.hindSiliguri(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search product...',
                hintStyle: GoogleFonts.hindSiliguri(
                    fontSize: 13, color: AppTheme.textGrey),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AppTheme.primaryAccent),
                filled: true,
                fillColor: isDark
                    ? AppTheme.darkBg
                    : AppTheme.primaryAccent.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: sc,
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final p = filtered[i];
                final label = [p['name'] ?? '',
                  if ((p['packSize'] ?? '').toString().isNotEmpty) p['packSize'],
                ].join(' ');
                // Show carton/bucket info if available
                final ppc = p['pcsPerCarton'] != null ? '${p['pcsPerCarton']} pcs/ctn' : null;
                final ppb = p['pcsPerBucket'] != null ? '${p['pcsPerBucket']} pcs/bkt' : null;
                final convInfo = [ppc, ppb].where((x) => x != null).join(' • ');
                return ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppTheme.lightAccent,
                    child: Icon(Icons.inventory_2_rounded,
                        color: AppTheme.primaryAccent, size: 18),
                  ),
                  title: Text(label,
                      style: GoogleFonts.hindSiliguri(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    [
                      p['unit']?.toString() ?? '',
                      if (convInfo.isNotEmpty) convInfo,
                    ].where((s) => s.isNotEmpty).join(' • '),
                    style: GoogleFonts.hindSiliguri(fontSize: 12),
                  ),
                  onTap: () {
                    widget.onSelect(p);
                    Navigator.pop(ctx);
                  },
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}
