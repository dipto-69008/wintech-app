import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../models/stock_transfer_model.dart';
import '../../models/user_model.dart';
import '../../services/local_storage_service.dart';

class StockTransferScreen extends StatefulWidget {
  const StockTransferScreen({super.key});

  @override
  State<StockTransferScreen> createState() => _StockTransferScreenState();
}

class _StockTransferScreenState extends State<StockTransferScreen> {
  UserModel? _user;
  List<StockTransferModel> _transfers = [];
  bool _loading = true;
  String _filter = 'all';
  final _fmt = NumberFormat('#,##0.##', 'en_US');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final user = await LocalStorageService.getCurrentUser();
    final all = await LocalStorageService.getStockTransfers();
    if (!mounted) return;
    setState(() {
      _user = user;
      _transfers = (user?.isAdmin ?? false)
          ? all
          : all.where((t) => t.srId == (user?.id ?? '')).toList();
      _loading = false;
    });
  }

  List<StockTransferModel> get _filtered {
    final now = DateTime.now();
    return _transfers.where((t) {
      if (_filter == 'today') {
        return t.date.year == now.year &&
            t.date.month == now.month &&
            t.date.day == now.day;
      } else if (_filter == 'month') {
        return t.date.year == now.year && t.date.month == now.month;
      }
      return true;
    }).toList();
  }

  void _openDialog({StockTransferModel? edit}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TransferDialog(
        user: _user,
        existing: edit,
        onSave: (t) async {
          await LocalStorageService.saveStockTransfer(t);
          await _load();
        },
      ),
    );
  }

  Future<void> _delete(StockTransferModel t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete?',
            style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w700)),
        content: Text('This transfer will be deleted.',
            style: GoogleFonts.hindSiliguri()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('No', style: GoogleFonts.hindSiliguri())),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.error,
                  minimumSize: const Size(80, 40)),
              child: Text('Yes', style: GoogleFonts.hindSiliguri())),
        ],
      ),
    );
    if (ok == true) {
      await LocalStorageService.deleteStockTransfer(t.id);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryAccent))
          : RefreshIndicator(
              color: AppTheme.primaryAccent,
              onRefresh: _load,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _buildHeader(isDark)),
                  SliverToBoxAdapter(child: _buildFilters(isDark)),
                  SliverToBoxAdapter(child: _buildSummary(isDark)),
                  if (_filtered.isEmpty)
                    SliverToBoxAdapter(child: _buildEmpty(isDark))
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => _buildTile(_filtered[i], isDark),
                        childCount: _filtered.length,
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openDialog(),
        backgroundColor: AppTheme.primaryAccent,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('New Transfer',
            style: GoogleFonts.hindSiliguri(
                color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.primaryAccent,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
          20, MediaQuery.of(context).padding.top + 14, 20, 20),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back_rounded,
              color: Colors.white, size: 24),
        ),
        const SizedBox(width: 12),
        const Icon(Icons.swap_horiz_rounded, color: Colors.white, size: 24),
        const SizedBox(width: 10),
        Text('Stock Transfer',
            style: GoogleFonts.hindSiliguri(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white)),
        const Spacer(),
        Text('Total: ${_transfers.length}',
            style: GoogleFonts.hindSiliguri(
                fontSize: 13, color: Colors.white70)),
      ]),
    );
  }

  Widget _buildFilters(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(children: [
        _chip('all', 'All', isDark),
        const SizedBox(width: 8),
        _chip('today', 'Today', isDark),
        const SizedBox(width: 8),
        _chip('month', 'This Month', isDark),
      ]),
    );
  }

  Widget _chip(String val, String label, bool isDark) {
    final sel = _filter == val;
    return GestureDetector(
      onTap: () => setState(() => _filter = val),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: sel
              ? AppTheme.primaryAccent
              : (isDark ? AppTheme.darkCard : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: sel ? AppTheme.primaryAccent : AppTheme.divider),
        ),
        child: Text(label,
            style: GoogleFonts.hindSiliguri(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: sel
                    ? Colors.white
                    : (isDark ? AppTheme.darkText : AppTheme.textDark))),
      ),
    );
  }

  Widget _buildSummary(bool isDark) {
    final cardBg = isDark ? AppTheme.darkCard : Colors.white;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: AppTheme.primaryAccent.withValues(alpha: 0.2)),
        ),
        child: Row(children: [
          const Icon(Icons.swap_horiz_rounded,
              color: AppTheme.primaryAccent, size: 18),
          const SizedBox(width: 8),
          Text('${_filtered.length} transfers',
              style: GoogleFonts.hindSiliguri(
                  fontSize: 13, color: AppTheme.textGrey)),
        ]),
      ),
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(children: [
          Icon(Icons.swap_horiz_rounded,
              size: 64,
              color: isDark ? AppTheme.darkTextGrey : AppTheme.divider),
          const SizedBox(height: 14),
          Text('No transfers',
              style: GoogleFonts.hindSiliguri(
                  fontSize: 15, color: AppTheme.textGrey)),
          const SizedBox(height: 6),
          Text('Tap + to add a new transfer',
              style: GoogleFonts.hindSiliguri(
                  fontSize: 12, color: AppTheme.textGrey)),
        ]),
      ),
    );
  }

  Widget _buildTile(StockTransferModel t, bool isDark) {
    final cardBg = isDark ? AppTheme.darkCard : Colors.white;
    final statusColor = t.status == StockTransferModel.statusApproved
        ? AppTheme.success
        : t.status == StockTransferModel.statusRejected
            ? AppTheme.error
            : AppTheme.warning;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
              blurRadius: 4)
        ],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12)),
          child:
              Icon(Icons.swap_horiz_rounded, color: statusColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t.productName,
                style: GoogleFonts.hindSiliguri(
                    fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text('${t.fromWarehouse} → ${t.toWarehouse}',
                style: GoogleFonts.hindSiliguri(
                    fontSize: 12, color: AppTheme.textGrey)),
            Text(
                '${t.date.day}/${t.date.month}/${t.date.year} · ${_fmt.format(t.quantity)} ${t.unit}',
                style: GoogleFonts.hindSiliguri(
                    fontSize: 12, color: AppTheme.textGrey)),
            if (t.notes.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(t.notes,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.hindSiliguri(
                      fontSize: 11,
                      color: isDark ? AppTheme.darkTextGrey : AppTheme.textGrey)),
            ],
          ]),
        ),
        Column(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20)),
            child: Text(t.statusLabel,
                style: GoogleFonts.hindSiliguri(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: statusColor)),
          ),
          const SizedBox(height: 6),
          Row(children: [
            GestureDetector(
              onTap: () => _openDialog(edit: t),
              child: const Icon(Icons.edit_rounded,
                  size: 18, color: AppTheme.primaryAccent),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _delete(t),
              child: const Icon(Icons.delete_outline_rounded,
                  size: 18, color: AppTheme.error),
            ),
          ]),
        ]),
      ]),
    );
  }
}

// ── Add/Edit Dialog ───────────────────────────────────────────────────────

class _TransferDialog extends StatefulWidget {
  final UserModel? user;
  final StockTransferModel? existing;
  final Future<void> Function(StockTransferModel) onSave;

  const _TransferDialog(
      {required this.user, required this.existing, required this.onSave});

  @override
  State<_TransferDialog> createState() => _TransferDialogState();
}

class _TransferDialogState extends State<_TransferDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _fromCtrl;
  late TextEditingController _toCtrl;
  late TextEditingController _productCtrl;
  late TextEditingController _qtyCtrl;
  late TextEditingController _notesCtrl;
  String _unit = 'KG';
  DateTime _date = DateTime.now();
  bool _saving = false;

  static const _units = ['KG', 'Liter', 'Piece', 'Box', 'Carton', 'Sack', 'Dozen'];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _fromCtrl    = TextEditingController(text: e?.fromWarehouse ?? '');
    _toCtrl      = TextEditingController(text: e?.toWarehouse ?? '');
    _productCtrl = TextEditingController(text: e?.productName ?? '');
    _qtyCtrl     = TextEditingController(
        text: e != null ? e.quantity.toString() : '');
    _notesCtrl   = TextEditingController(text: e?.notes ?? '');
    _unit = e?.unit ?? 'KG';
    _date = e?.date ?? DateTime.now();
  }

  @override
  void dispose() {
    _fromCtrl.dispose();
    _toCtrl.dispose();
    _productCtrl.dispose();
    _qtyCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final model = StockTransferModel(
      id: widget.existing?.id ??
          'ST-${DateTime.now().millisecondsSinceEpoch}',
      fromWarehouse: _fromCtrl.text.trim(),
      toWarehouse: _toCtrl.text.trim(),
      productName: _productCtrl.text.trim(),
      quantity: double.tryParse(_qtyCtrl.text.trim()) ?? 0,
      unit: _unit,
      date: _date,
      notes: _notesCtrl.text.trim(),
      status: widget.existing?.status ?? StockTransferModel.statusPending,
      srId: widget.user?.id ?? '',
      srName: widget.user?.name ?? '',
    );
    await widget.onSave(model);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.darkCard : Colors.white;
    return Container(
      decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppTheme.divider,
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            Text(
                widget.existing == null
                    ? 'New Stock Transfer'
                    : 'Edit Transfer',
                style: GoogleFonts.hindSiliguri(
                    fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            _label('From (Warehouse)'),
            TextFormField(
              controller: _fromCtrl,
              decoration: const InputDecoration(hintText: 'Sender warehouse'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            _label('To (Warehouse)'),
            TextFormField(
              controller: _toCtrl,
              decoration: const InputDecoration(hintText: 'Receiver warehouse'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            _label('Product Name'),
            TextFormField(
              controller: _productCtrl,
              decoration: const InputDecoration(hintText: 'Enter product name'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                flex: 3,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Quantity'),
                      TextFormField(
                        controller: _qtyCtrl,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(hintText: '0'),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          if (double.tryParse(v.trim()) == null) {
                            return 'Enter a number';
                          }
                          return null;
                        },
                      ),
                    ]),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Unit'),
                      DropdownButtonFormField<String>(
                        value: _unit,
                        items: _units
                            .map((u) => DropdownMenuItem(
                                value: u,
                                child: Text(u,
                                    style: GoogleFonts.hindSiliguri())))
                            .toList(),
                        onChanged: (v) => setState(() => _unit = v!),
                        decoration: const InputDecoration(),
                      ),
                    ]),
              ),
            ]),
            const SizedBox(height: 12),
            _label('Date'),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkCard2 : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.divider, width: 1.5),
                ),
                child: Row(children: [
                  const Icon(Icons.calendar_today_rounded,
                      size: 16, color: AppTheme.primaryAccent),
                  const SizedBox(width: 8),
                  Text(
                      '${_date.day}/${_date.month}/${_date.year}',
                      style: GoogleFonts.hindSiliguri(fontSize: 14)),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            _label('Notes (optional)'),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: const InputDecoration(hintText: 'Additional info...'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(
                      widget.existing == null ? 'Save' : 'Update',
                      style: GoogleFonts.hindSiliguri(
                          fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(t,
          style: GoogleFonts.hindSiliguri(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textGrey)));
}
