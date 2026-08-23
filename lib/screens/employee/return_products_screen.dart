import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../services/api_service.dart';

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
  List<Map<String, dynamic>> _returns = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _ReturnListTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshId != widget.refreshId) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.salesReturns();
      if (mounted) setState(() => _returns = data);
    } catch (_) {
      if (mounted) setState(() => _returns = []);
    } finally {
      if (mounted) setState(() => _loading = false);
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
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
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
                  if ((item['reason'] ?? '').toString().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('Reason: ${item['reason']}',
                        style: GoogleFonts.hindSiliguri(
                            fontSize: 11, color: AppTheme.textGrey)),
                  ],
                ],
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
    if (product != null) setState(() => _product = product);
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
    final rate = (_product!['sellingPrice'] as num?)?.toDouble() ??
        (_product!['wholesaleRate'] as num?)?.toDouble() ??
        0;
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
    });
  }

  Future<void> _submit() async {
    if (_partyCtrl.text.trim().isEmpty) {
      _message('Please select a customer', error: true);
      return;
    }
    if (_reasonCtrl.text.trim().isEmpty) {
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
                    'quantity': item['quantity'],
                    'rate': item['rate'],
                  })
              .toList(),
          reason: _reasonCtrl.text.trim(),
          returnDate: DateTime.now());
      if (!mounted) return;
      _message('Return invoice ${result['returnNo']} created in ERP');
      setState(() {
        _partyCtrl.clear();
        _invoiceCtrl.clear();
        _reasonCtrl.clear();
        _qtyCtrl.clear();
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
        TextField(
          controller: _reasonCtrl,
          maxLines: 2,
          style: GoogleFonts.hindSiliguri(),
          decoration: const InputDecoration(
              labelText: 'Return Reason *',
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
        TextField(
          controller: _qtyCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,3}'))
          ],
          style: GoogleFonts.hindSiliguri(),
          decoration: const InputDecoration(
              labelText: 'Quantity *',
              prefixIcon: Icon(Icons.numbers_rounded)),
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