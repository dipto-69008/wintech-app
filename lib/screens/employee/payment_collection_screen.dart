import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../models/payment_collection_model.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../services/local_storage_service.dart';
import '../../services/offline_queue_service.dart';

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
  bool _erpConnected = false;
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
    final local = await LocalStorageService.getPaymentCollections();
    var all = local;
    var erp = false;

    // ERP-first: fetch live collections, merge local-only entries.
    if (await ApiService.isConnected) {
      try {
        final data = await ApiService.paymentCollections();
        final remote = data.map((m) {
          final map = Map<String, dynamic>.from(m);
          map['id'] ??= map['_id']?.toString();
          return PaymentCollectionModel.fromMap(map);
        }).toList();
        final remoteIds = remote.map((p) => p.id).toSet();
        all = [
          ...remote,
          ...local.where((p) => !remoteIds.contains(p.id)),
        ];
        erp = true;
      } catch (_) {
        // Offline or endpoint unavailable — keep local data.
      }
    }

    if (!mounted) return;
    setState(() {
      _user = user;
      _erpConnected = erp;
      // Live mobile records are already scoped to the signed-in officer.
      // Local and ERP IDs can differ, so only filter offline-only entries.
      _payments = erp || (user?.isAdmin ?? false)
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
          // Only push brand-new collections to the ERP (edits stay local).
          if (edit == null) {
            var sent = false;
            var submission = p;
            if (p.proofImage.isNotEmpty && !p.proofImage.startsWith('http')) {
              try {
                submission = p.copyWith(
                    proofImage: await ApiService.uploadPhoto(p.proofImage,
                        folder: 'collections'));
              } catch (_) {
                // Keep the local image only in the offline queue. It must
                // never be posted to the ERP as a device-specific file path.
              }
            }
            if (await ApiService.isConnected) {
              try {
                final imageReady = submission.proofImage.isEmpty ||
                    submission.proofImage.startsWith('https://');
                if (imageReady) {
                  await ApiService.createPaymentCollection(submission.toMap());
                  sent = true;
                  // The collection now lives in the ERP (with a server id) —
                  // drop the local copy so it doesn't show up twice.
                  await LocalStorageService.deletePaymentCollection(p.id);
                }
              } catch (_) {}
            }
            if (!sent) {
              await OfflineQueueService.enqueuePaymentCollection(submission.toMap());
            }
            _snack(sent
                ? '✅ Collection submitted to ERP!'
                : '📥 Offline — will sync to ERP when connected');
          }
          await _load();
        },
      ),
    );
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600)),
      backgroundColor: AppTheme.success,
      behavior: SnackBarBehavior.floating,
    ));
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(
                _erpConnected
                    ? Icons.cloud_done_rounded
                    : Icons.wifi_off_rounded,
                size: 13,
                color: Colors.white),
            const SizedBox(width: 4),
            Text(_erpConnected ? 'ERP Connected' : 'Offline',
                style: GoogleFonts.hindSiliguri(
                    fontSize: 11, color: Colors.white)),
          ]),
        ),
        const SizedBox(width: 8),
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

    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => PaymentCollectionDetailScreen(payment: p))),
      borderRadius: BorderRadius.circular(14),
      child: Container(
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
            if (p.invoiceNo.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text('Invoice: ${p.invoiceNo}',
                  style: GoogleFonts.hindSiliguri(
                      fontSize: 11, color: AppTheme.primaryAccent)),
            ],
            if (p.commissionAmount > 0) ...[
              const SizedBox(height: 2),
              Text('Cash commission: ৳ ${_fmt.format(p.commissionAmount)}',
                  style: GoogleFonts.hindSiliguri(
                      fontSize: 11, color: AppTheme.warning)),
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
      ),
    );
  }
}

class PaymentCollectionDetailScreen extends StatelessWidget {
  final PaymentCollectionModel payment;
  const PaymentCollectionDetailScreen({super.key, required this.payment});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = payment.status == PaymentCollectionModel.statusConfirmed
        ? AppTheme.success
        : payment.status == PaymentCollectionModel.statusRejected
            ? AppTheme.error
            : AppTheme.warning;
    return Scaffold(
      appBar: AppBar(
        title: Text('Collection Details',
            style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w700)),
        backgroundColor: AppTheme.primaryAccent,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primaryAccent.withValues(alpha: .2)),
            ),
            child: Column(children: [
              const Icon(Icons.payments_rounded,
                  color: AppTheme.primaryAccent, size: 42),
              const SizedBox(height: 8),
              Text('৳ ${NumberFormat('#,##0', 'en_US').format(payment.amount)}',
                  style: GoogleFonts.hindSiliguri(
                      fontSize: 27, fontWeight: FontWeight.w800,
                      color: AppTheme.primaryAccent)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(payment.statusLabel,
                    style: GoogleFonts.hindSiliguri(
                        color: statusColor, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          _detailCard(context, [
            _detail('Customer', payment.customerName),
            _detail('Payment Method', payment.methodLabel),
            _detail('Collection Date',
                DateFormat('dd MMM yyyy, hh:mm a').format(payment.date)),
            if (payment.chequeNumber.isNotEmpty)
              _detail('Cheque Number', payment.chequeNumber),
            _detail('Ledger', payment.invoiceNo.isNotEmpty
                ? 'Invoice ${payment.invoiceNo}'
                : 'Party Ledger'),
            if (payment.commissionAmount > 0)
              _detail('Cash Commission',
                  '৳ ${NumberFormat('#,##0.00', 'en_US').format(payment.commissionAmount)} (${payment.commissionPct}%)'),
            if (payment.srName.isNotEmpty) _detail('Collected By', payment.srName),
            if (payment.notes.isNotEmpty) _detail('Notes', payment.notes),
          ]),
          if (payment.proofImage.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('Payment Proof',
                style: GoogleFonts.hindSiliguri(
                    fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(payment.proofImage,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Padding(
                      padding: EdgeInsets.all(18),
                      child: Text('Proof image unavailable'))),
            ),
          ],
        ],
      ),
    );
  }

  Widget _detailCard(BuildContext context, List<Widget> children) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppTheme.darkCard
                : Colors.white,
            borderRadius: BorderRadius.circular(14)),
        child: Column(children: children),
      );

  Widget _detail(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 125,
              child: Text(label,
                  style: GoogleFonts.hindSiliguri(
                      color: AppTheme.textGrey, fontSize: 12))),
          Expanded(
              child: Text(value,
                  style: GoogleFonts.hindSiliguri(
                      fontSize: 13, fontWeight: FontWeight.w600))),
        ]),
      );
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
  late TextEditingController _invoiceCtrl;
  late TextEditingController _commissionPctCtrl;
  String _method = 'cash';
  DateTime _date = _dhakaNow();
  String _proofImage = '';
  bool _pickingImage = false;
  double _customerDue = 0;
  bool _saving = false;
  bool _commissionRequested = false;

  // Searchable ERP customer selection
  List<Map<String, dynamic>> _erpParties = [];
  String _customerId = '';

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
    _invoiceCtrl  = TextEditingController(text: e?.invoiceNo ?? '');
    _commissionPctCtrl = TextEditingController(
        text: e != null && e.commissionPct > 0 ? e.commissionPct.toString() : '3');
    _commissionRequested = e?.commissionRequested ?? false;
    _method = e?.paymentMethod ?? 'cash';
    _date   = e?.date ?? _dhakaNow();
    _customerId = e?.customerId ?? '';
    _proofImage = e?.proofImage ?? '';
    _loadParties();
  }

  Future<void> _loadParties() async {
    try {
      if (await ApiService.isConnected) {
        final data = await ApiService.parties();
        if (mounted) setState(() => _erpParties = data);
      }
    } catch (_) {
      // Offline — an existing selected party can still be submitted from cache.
    }
  }

  void _openCustomerPicker() {
    if (_erpParties.isEmpty) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CustomerPickerSheet(
        parties: _erpParties,
        onSelect: (p) {
          setState(() {
            _customerCtrl.text = (p['name'] ?? '').toString();
            _customerId = (p['_id'] ?? '').toString();
            _customerDue = _number(p['currentDue']) + _number(p['previousDue']);
          });
        },
      ),
    );
  }

  @override
  void dispose() {
    _customerCtrl.dispose();
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    _chequeCtrl.dispose();
    _invoiceCtrl.dispose();
    _commissionPctCtrl.dispose();
    super.dispose();
  }

  static DateTime _dhakaNow() =>
      DateTime.now().toUtc().add(const Duration(hours: 6));

  static double _number(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

  Future<void> _pickProofImage() async {
    if (_pickingImage) return;
    setState(() => _pickingImage = true);
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 75,
        maxWidth: 1280,
      );
      if (image != null && mounted) setState(() => _proofImage = image.path);
    } finally {
      if (mounted) setState(() => _pickingImage = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    // The collection timestamp is always captured at submit time in Dhaka.
    _date = _dhakaNow();
    setState(() => _saving = true);
    final model = PaymentCollectionModel(
      id: widget.existing?.id ??
          'PC-${DateTime.now().millisecondsSinceEpoch}',
      customerName: _customerCtrl.text.trim(),
      customerId: _customerId,
      amount: double.tryParse(_amountCtrl.text.trim()) ?? 0,
      paymentMethod: _method,
      notes: _notesCtrl.text.trim(),
      chequeNumber: _chequeCtrl.text.trim(),
      proofImage: _proofImage,
      invoiceNo: _invoiceCtrl.text.trim(),
      commissionRequested: _commissionRequested && _invoiceCtrl.text.trim().isNotEmpty,
      commissionPct: double.tryParse(_commissionPctCtrl.text.trim()) ?? 0,
      commissionAmount: widget.existing?.commissionAmount ?? 0,
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
            _label('Party'),
            TextFormField(
              controller: _customerCtrl,
              readOnly: true,
              onTap: _erpParties.isNotEmpty ? _openCustomerPicker : null,
              decoration: InputDecoration(
                hintText: _erpParties.isNotEmpty
                    ? 'Tap to select ERP party'
                    : 'Connect to ERP to load parties',
                suffixIcon: _erpParties.isNotEmpty
                    ? const Icon(Icons.search_rounded,
                        color: AppTheme.primaryAccent)
                    : null,
              ),
              validator: (_) =>
                  _customerId.isEmpty ? 'Please select a party' : null,
            ),
            const SizedBox(height: 12),
            if (_customerId.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Party due: ৳ ${NumberFormat('#,##0.00', 'en_US').format(_customerDue)}',
                  style: GoogleFonts.hindSiliguri(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textDark,
                  ),
                ),
              ),
            if (_customerId.isNotEmpty) const SizedBox(height: 12),
            _label('Invoice Number (optional)'),
            TextFormField(
              controller: _invoiceCtrl,
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) => setState(() {
                if (_invoiceCtrl.text.trim().isEmpty) _commissionRequested = false;
              }),
              decoration: const InputDecoration(
                hintText: 'Leave blank for party ledger payment',
                prefixIcon: Icon(Icons.receipt_long_rounded),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'With invoice: payment reduces that invoice due. Without invoice: payment reduces the party ledger due.',
              style: GoogleFonts.hindSiliguri(
                fontSize: 11,
                color: AppTheme.textGrey,
              ),
            ),
            if (_invoiceCtrl.text.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryAccent.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppTheme.primaryAccent.withValues(alpha: 0.18)),
                ),
                child: Column(
                  children: [
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: _commissionRequested,
                      onChanged: (value) =>
                          setState(() => _commissionRequested = value ?? false),
                      title: Text('Apply Cash Commission to this invoice',
                          style: GoogleFonts.hindSiliguri(
                              fontSize: 13, fontWeight: FontWeight.w700)),
                      subtitle: Text(
                          'Only available when this payment settles the invoice.',
                          style: GoogleFonts.hindSiliguri(fontSize: 11)),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    if (_commissionRequested)
                      TextFormField(
                        controller: _commissionPctCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Cash Commission %',
                          hintText: '3',
                          suffixText: '%',
                        ),
                        validator: (value) {
                          if (!_commissionRequested) return null;
                          final pct = double.tryParse(value?.trim() ?? '');
                          if (pct == null || pct <= 0 || pct > 100) {
                            return 'Enter a percentage between 0 and 100';
                          }
                          return null;
                        },
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            _label('Amount (Taka)'),
            TextFormField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: '0.00'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                final amount = double.tryParse(v.trim());
                if (amount == null) return 'Enter a number';
                if (amount <= 0) return 'Enter an amount greater than zero';
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
            _label('Collection Date & Time (Asia/Dhaka)'),
            Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkCard2 : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.divider, width: 1.5),
                ),
                child: Row(children: [
                  const Icon(Icons.access_time_rounded,
                      size: 16, color: AppTheme.primaryAccent),
                  const SizedBox(width: 8),
                  Text(DateFormat('dd MMM yyyy · hh:mm a').format(_date),
                      style: GoogleFonts.hindSiliguri(fontSize: 14)),
                ]),
              ),
            const SizedBox(height: 12),
            _label('Payment Collection Image (optional)'),
            Row(children: [
              OutlinedButton.icon(
                onPressed: _pickingImage ? null : _pickProofImage,
                icon: _pickingImage
                    ? const SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.photo_camera_rounded, size: 17),
                label: Text(_proofImage.isEmpty ? 'Take a Photo' : 'Retake Photo',
                    style: GoogleFonts.hindSiliguri(fontSize: 12)),
              ),
              if (_proofImage.isNotEmpty) ...[
                const SizedBox(width: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _proofImage.startsWith('http')
                      ? Image.network(_proofImage, width: 42, height: 42,
                          fit: BoxFit.cover)
                      : Image.file(File(_proofImage), width: 42, height: 42,
                          fit: BoxFit.cover),
                ),
                IconButton(
                    tooltip: 'Remove image',
                    onPressed: () => setState(() => _proofImage = ''),
                    icon: const Icon(Icons.close_rounded, size: 18)),
              ],
            ]),
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

// ── Searchable ERP Customer Picker ────────────────────────────────────────

class _CustomerPickerSheet extends StatefulWidget {
  final List<Map<String, dynamic>> parties;
  final void Function(Map<String, dynamic>) onSelect;
  const _CustomerPickerSheet({required this.parties, required this.onSelect});

  @override
  State<_CustomerPickerSheet> createState() => _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends State<_CustomerPickerSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  static double _number(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filtered {
    if (_query.trim().isEmpty) return widget.parties;
    final q = _query.toLowerCase();
    return widget.parties.where((p) {
      final name = (p['name'] ?? '').toString().toLowerCase();
      final code = (p['code'] ?? '').toString().toLowerCase();
      final mobile = (p['mobile'] ?? '').toString().toLowerCase();
      final area = (p['area'] ?? '').toString().toLowerCase();
      return name.contains(q) ||
          code.contains(q) ||
          mobile.contains(q) ||
          area.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.darkCard : Colors.white;
    final results = _filtered;
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(children: [
        Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: AppTheme.divider,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 14),
        Text('Select Party',
            style: GoogleFonts.hindSiliguri(
                fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        TextField(
          controller: _searchCtrl,
          autofocus: true,
          onChanged: (v) => setState(() => _query = v),
          decoration: const InputDecoration(
            hintText: 'Search by name, code, mobile or area...',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: results.isEmpty
              ? Center(
                   child: Text('No party found',
                      style: GoogleFonts.hindSiliguri(
                          color: AppTheme.textGrey)))
              : ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (_, i) {
                    final p = results[i];
                    final sub = [
                      (p['code'] ?? '').toString(),
                      (p['mobile'] ?? '').toString(),
                      (p['area'] ?? '').toString(),
                    ].where((s) => s.isNotEmpty).join(' • ');
                      final due = _number(p['currentDue']) + _number(p['previousDue']);
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.storefront_rounded,
                          color: AppTheme.primaryAccent, size: 20),
                      title: Text((p['name'] ?? '').toString(),
                          style: GoogleFonts.hindSiliguri(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                      subtitle: Text(
                          [
                            if (sub.isNotEmpty) sub,
                            'Due: ৳ ${NumberFormat('#,##0.00', 'en_US').format(due)}',
                          ].join(' • '),
                              style: GoogleFonts.hindSiliguri(fontSize: 11)),
                      onTap: () {
                        widget.onSelect(p);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
        ),
      ]),
    );
  }
}
