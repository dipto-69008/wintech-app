import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../models/payment_collection_model.dart';
import '../../models/user_model.dart';
import '../../services/local_storage_service.dart';

class PaymentCollectionScreen extends StatefulWidget {
  const PaymentCollectionScreen({super.key});

  @override
  State<PaymentCollectionScreen> createState() =>
      _PaymentCollectionScreenState();
}

class _PaymentCollectionScreenState extends State<PaymentCollectionScreen> {
  UserModel? _user;
  List<PaymentCollectionModel> _payments = [];
  bool _loading = true;
  String _filter = 'all';
  final _fmt = NumberFormat('#,##0', 'en_US');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final user = await LocalStorageService.getCurrentUser();
    final all = await LocalStorageService.getPaymentCollections();
    if (!mounted) return;
    setState(() {
      _user = user;
      _payments = (user?.isAdmin ?? false)
          ? all
          : all.where((p) => p.srId == (user?.id ?? '')).toList();
      _loading = false;
    });
  }

  List<PaymentCollectionModel> get _filtered {
    final now = DateTime.now();
    return _payments.where((p) {
      if (_filter == 'today') {
        return p.date.year == now.year &&
            p.date.month == now.month &&
            p.date.day == now.day;
      } else if (_filter == 'month') {
        return p.date.year == now.year && p.date.month == now.month;
      }
      return true;
    }).toList();
  }

  double get _filteredTotal =>
      _filtered.fold(0.0, (s, p) => s + p.amount);

  void _openDialog({PaymentCollectionModel? edit}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CollectionDialog(
        user: _user,
        existing: edit,
        onSave: (p) async {
          await LocalStorageService.savePaymentCollection(p);
          await _load();
        },
      ),
    );
  }

  Future<void> _delete(PaymentCollectionModel p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete?',
            style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w700)),
        content: Text('This collection will be deleted.',
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
      await LocalStorageService.deletePaymentCollection(p.id);
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
        label: Text('New Collection',
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
        const Icon(Icons.payments_rounded, color: Colors.white, size: 24),
        const SizedBox(width: 10),
        Text('Payment Collection',
            style: GoogleFonts.hindSiliguri(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white)),
        const Spacer(),
        Text('Total: ${_payments.length}',
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
          const Icon(Icons.payments_rounded,
              color: AppTheme.primaryAccent, size: 18),
          const SizedBox(width: 8),
          Text('${_filtered.length} collections · ',
              style: GoogleFonts.hindSiliguri(
                  fontSize: 13, color: AppTheme.textGrey)),
          Text('৳ ${_fmt.format(_filteredTotal)}',
              style: GoogleFonts.hindSiliguri(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryAccent)),
        ]),
      ),
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(children: [
          Icon(Icons.payments_rounded,
              size: 64,
              color: isDark ? AppTheme.darkTextGrey : AppTheme.divider),
          const SizedBox(height: 14),
          Text('No collections',
              style: GoogleFonts.hindSiliguri(
                  fontSize: 15, color: AppTheme.textGrey)),
          const SizedBox(height: 6),
          Text('Tap + to add a new collection',
              style: GoogleFonts.hindSiliguri(
                  fontSize: 12, color: AppTheme.textGrey)),
        ]),
      ),
    );
  }

  Widget _buildTile(PaymentCollectionModel p, bool isDark) {
    final cardBg = isDark ? AppTheme.darkCard : Colors.white;
    final statusColor = p.status == PaymentCollectionModel.statusConfirmed
        ? AppTheme.success
        : p.status == PaymentCollectionModel.statusRejected
            ? AppTheme.error
            : AppTheme.warning;

    final methodColors = {
      'cash':   const Color(0xFF2E7D32),
      'cheque': const Color(0xFF1565C0),
      'bKash':  const Color(0xFFD81B60),
      'nagad':  const Color(0xFFE65100),
      'bank':   AppTheme.primaryAccent,
    };
    final methodColor =
        methodColors[p.paymentMethod] ?? AppTheme.primaryAccent;

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
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
              color: AppTheme.primaryAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.payments_rounded,
              color: AppTheme.primaryAccent, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.customerName,
                style: GoogleFonts.hindSiliguri(
                    fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Row(children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                    color: methodColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: Text(p.methodLabel,
                    style: GoogleFonts.hindSiliguri(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: methodColor)),
              ),
              const SizedBox(width: 6),
              Text(
                  '${p.date.day}/${p.date.month}/${p.date.year}',
                  style: GoogleFonts.hindSiliguri(
                      fontSize: 11, color: AppTheme.textGrey)),
            ]),
            if (p.notes.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(p.notes,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.hindSiliguri(
                      fontSize: 11, color: AppTheme.textGrey)),
            ],
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('৳ ${_fmt.format(p.amount)}',
              style: GoogleFonts.hindSiliguri(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryAccent)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20)),
            child: Text(p.statusLabel,
                style: GoogleFonts.hindSiliguri(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: statusColor)),
          ),
          const SizedBox(height: 4),
          Row(children: [
            GestureDetector(
              onTap: () => _openDialog(edit: p),
              child: const Icon(Icons.edit_rounded,
                  size: 18, color: AppTheme.primaryAccent),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _delete(p),
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

class _CollectionDialog extends StatefulWidget {
  final UserModel? user;
  final PaymentCollectionModel? existing;
  final Future<void> Function(PaymentCollectionModel) onSave;

  const _CollectionDialog(
      {required this.user, required this.existing, required this.onSave});

  @override
  State<_CollectionDialog> createState() => _CollectionDialogState();
}

class _CollectionDialogState extends State<_CollectionDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _customerCtrl;
  late TextEditingController _amountCtrl;
  late TextEditingController _notesCtrl;
  late TextEditingController _chequeCtrl;
  String _method = 'cash';
  DateTime _date = DateTime.now();
  bool _saving = false;

  static const _methods = [
    ('cash',   'Cash'),
    ('cheque', 'Cheque'),
    ('bKash',  'bKash'),
    ('nagad',  'Nagad'),
    ('bank',   'Bank'),
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _customerCtrl = TextEditingController(text: e?.customerName ?? '');
    _amountCtrl =
        TextEditingController(text: e != null ? e.amount.toString() : '');
    _notesCtrl    = TextEditingController(text: e?.notes ?? '');
    _chequeCtrl   = TextEditingController(text: e?.chequeNumber ?? '');
    _method = e?.paymentMethod ?? 'cash';
    _date   = e?.date ?? DateTime.now();
  }

  @override
  void dispose() {
    _customerCtrl.dispose();
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    _chequeCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final model = PaymentCollectionModel(
      id: widget.existing?.id ??
          'PC-${DateTime.now().millisecondsSinceEpoch}',
      customerName: _customerCtrl.text.trim(),
      amount: double.tryParse(_amountCtrl.text.trim()) ?? 0,
      paymentMethod: _method,
      notes: _notesCtrl.text.trim(),
      chequeNumber: _chequeCtrl.text.trim(),
      date: _date,
      status: widget.existing?.status ?? PaymentCollectionModel.statusPending,
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
                    ? 'New Payment Collection'
                    : 'Edit Collection',
                style: GoogleFonts.hindSiliguri(
                    fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            _label('Customer Name'),
            TextFormField(
              controller: _customerCtrl,
              decoration: const InputDecoration(hintText: 'Customer Name'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            _label('Amount (Taka)'),
            TextFormField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: '0.00'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                if (double.tryParse(v.trim()) == null) return 'Enter a number';
                return null;
              },
            ),
            const SizedBox(height: 12),
            _label('Payment Method'),
            DropdownButtonFormField<String>(
              value: _method,
              items: _methods
                  .map((m) => DropdownMenuItem(
                      value: m.$1,
                      child: Text(m.$2,
                          style: GoogleFonts.hindSiliguri())))
                  .toList(),
              onChanged: (v) => setState(() => _method = v!),
              decoration: const InputDecoration(),
            ),
            if (_method == 'cheque') ...[
              const SizedBox(height: 12),
              _label('Cheque Number'),
              TextFormField(
                controller: _chequeCtrl,
                decoration:
                    const InputDecoration(hintText: 'Enter cheque number'),
              ),
            ],
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
                  Text('${_date.day}/${_date.month}/${_date.year}',
                      style: GoogleFonts.hindSiliguri(fontSize: 14)),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            _label('Notes (optional)'),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration:
                  const InputDecoration(hintText: 'Additional info...'),
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
                      widget.existing == null
                          ? 'Save'
                          : 'Update',
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
