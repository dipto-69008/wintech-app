import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/theme.dart';
import '../../models/leave_model.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../services/local_storage_service.dart';
import '../../services/offline_queue_service.dart';

class LeaveScreen extends StatefulWidget {
  const LeaveScreen({super.key});

  @override
  State<LeaveScreen> createState() => _LeaveScreenState();
}

class _LeaveScreenState extends State<LeaveScreen>
    with SingleTickerProviderStateMixin {
  UserModel? _user;
  List<LeaveModel> _leaves = [];
  bool _loading = true;
  bool _erpConnected = false;
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final user = await LocalStorageService.getCurrentUser();
    final local = await LocalStorageService.getLeaves();
    var all = local;
    var erp = false;

    // ERP-first: fetch live leave applications, merge local-only entries.
    if (await ApiService.isConnected) {
      try {
        final data = await ApiService.leaves();
        final remote = data.map((m) {
          final map = Map<String, dynamic>.from(m);
          map['id'] ??= map['_id']?.toString();
          return LeaveModel.fromMap(map);
        }).toList();
        final remoteIds = remote.map((l) => l.id).toSet();
        all = [
          ...remote,
          ...local.where((l) => !remoteIds.contains(l.id)),
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
      _leaves = (user?.isAdmin ?? false)
          ? all
          : all.where((l) => l.srId == (user?.id ?? '')).toList();
      _loading = false;
    });
  }

  void _openApplySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LeaveApplySheet(
        user: _user,
        onSave: (l) async {
          await LocalStorageService.saveLeave(l);
          var sent = false;
          if (await ApiService.isConnected) {
            try {
              await ApiService.createLeave(l.toMap());
              sent = true;
              // The application now lives in the ERP (with a server id) —
              // drop the local copy so it doesn't show up twice.
              await LocalStorageService.deleteLeave(l.id);
            } catch (_) {}
          }
          if (!sent) {
            await OfflineQueueService.enqueueLeave(l.toMap());
          }
          _snack(sent
              ? '✅ Application submitted to ERP!'
              : '📥 Offline — will sync to ERP when connected');
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

  Future<void> _delete(LeaveModel l) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete?',
            style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w700)),
        content: Text('This leave application will be deleted.',
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
      await LocalStorageService.deleteLeave(l.id);
      _load();
    }
  }

  List<LeaveModel> get _pendingLeaves =>
      _leaves.where((l) => l.status == LeaveModel.statusPending).toList();
  List<LeaveModel> get _historyLeaves =>
      _leaves.where((l) => l.status != LeaveModel.statusPending).toList();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryAccent))
          : NestedScrollView(
              headerSliverBuilder: (_, __) => [
                SliverToBoxAdapter(child: _buildHeader(isDark)),
                SliverToBoxAdapter(child: _buildStats(isDark)),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _TabDelegate(
                    tabBar: TabBar(
                      controller: _tabCtrl,
                      labelStyle: GoogleFonts.hindSiliguri(
                          fontWeight: FontWeight.w700, fontSize: 13),
                      unselectedLabelStyle:
                          GoogleFonts.hindSiliguri(fontSize: 13),
                      labelColor: AppTheme.primaryAccent,
                      unselectedLabelColor: AppTheme.textGrey,
                      indicatorColor: AppTheme.primaryAccent,
                      tabs: const [
                        Tab(text: 'Pending'),
                        Tab(text: 'History'),
                      ],
                    ),
                    bg: isDark ? AppTheme.darkCard : Colors.white,
                  ),
                ),
              ],
              body: TabBarView(
                controller: _tabCtrl,
                children: [
                  _buildList(_pendingLeaves, isDark),
                  _buildList(_historyLeaves, isDark),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openApplySheet,
        backgroundColor: AppTheme.primaryAccent,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('Leave Application',
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
        const Icon(Icons.beach_access_rounded, color: Colors.white, size: 24),
        const SizedBox(width: 10),
        Text('Leave Application',
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
        Text('Total: ${_leaves.length}',
            style: GoogleFonts.hindSiliguri(
                fontSize: 13, color: Colors.white70)),
      ]),
    );
  }

  Widget _buildStats(bool isDark) {
    final approved = _leaves
        .where((l) => l.status == LeaveModel.statusApproved)
        .length;
    final pending = _pendingLeaves.length;
    final cardBg = isDark ? AppTheme.darkCard : Colors.white;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(children: [
        _statCard('Pending', '$pending', AppTheme.warning, cardBg),
        const SizedBox(width: 12),
        _statCard('Approved', '$approved', AppTheme.success, cardBg),
        const SizedBox(width: 12),
        _statCard('Total', '${_leaves.length}', AppTheme.primaryAccent, cardBg),
      ]),
    );
  }

  Widget _statCard(String label, String value, Color color, Color bg) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.2))),
          child: Column(children: [
            Text(value,
                style: GoogleFonts.hindSiliguri(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: color)),
            Text(label,
                style: GoogleFonts.hindSiliguri(
                    fontSize: 11, color: AppTheme.textGrey)),
          ]),
        ),
      );

  Widget _buildList(List<LeaveModel> list, bool isDark) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.beach_access_rounded,
                size: 64,
                color: isDark ? AppTheme.darkTextGrey : AppTheme.divider),
            const SizedBox(height: 14),
            Text('No leave applications',
                style: GoogleFonts.hindSiliguri(
                    fontSize: 15, color: AppTheme.textGrey)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: AppTheme.primaryAccent,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: list.length,
        itemBuilder: (_, i) => _buildTile(list[i], isDark),
      ),
    );
  }

  Widget _buildTile(LeaveModel l, bool isDark) {
    final cardBg = isDark ? AppTheme.darkCard : Colors.white;
    final statusColor = l.status == LeaveModel.statusApproved
        ? AppTheme.success
        : l.status == LeaveModel.statusRejected
            ? AppTheme.error
            : AppTheme.warning;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12)),
          child: Icon(Icons.beach_access_rounded,
              color: statusColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.typeLabel,
                style: GoogleFonts.hindSiliguri(
                    fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(
                '${l.fromDate.day}/${l.fromDate.month}/${l.fromDate.year} — ${l.toDate.day}/${l.toDate.month}/${l.toDate.year}',
                style: GoogleFonts.hindSiliguri(
                    fontSize: 12, color: AppTheme.textGrey)),
            Text('${l.totalDays} days',
                style: GoogleFonts.hindSiliguri(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryAccent)),
            if (l.reason.isNotEmpty)
              Text(l.reason,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.hindSiliguri(
                      fontSize: 11, color: AppTheme.textGrey)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20)),
            child: Text(l.statusLabel,
                style: GoogleFonts.hindSiliguri(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: statusColor)),
          ),
          if (l.status == LeaveModel.statusPending) ...[
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => _delete(l),
              child: const Icon(Icons.delete_outline_rounded,
                  size: 18, color: AppTheme.error),
            ),
          ],
        ]),
      ]),
    );
  }
}

// ── Leave Apply Sheet ─────────────────────────────────────────────────────

class _LeaveApplySheet extends StatefulWidget {
  final UserModel? user;
  final Future<void> Function(LeaveModel) onSave;
  const _LeaveApplySheet({required this.user, required this.onSave});

  @override
  State<_LeaveApplySheet> createState() => _LeaveApplySheetState();
}

class _LeaveApplySheetState extends State<_LeaveApplySheet> {
  final _formKey = GlobalKey<FormState>();
  String _type = LeaveModel.typeCasual;
  DateTime _from = DateTime.now();
  DateTime _to   = DateTime.now();
  DateTime? _joining;
  final _reasonCtrl = TextEditingController();
  final _encashDaysCtrl = TextEditingController();
  List<String> _attachments = [];
  bool _pickingPhoto = false;
  bool _saving = false;

  bool get _isEncashment => _type == LeaveModel.typeEncashment;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    _encashDaysCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFrom() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _from,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) {
      setState(() {
        _from = d;
        // One-day leave by default: keep both dates equal until the user
        // explicitly picks a later end date.
        if (_to.isBefore(_from)) _to = _from;
        if (_joining != null && !_joining!.isAfter(_to)) _joining = null;
      });
    }
  }

  Future<void> _pickTo() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _to.isBefore(_from) ? _from : _to,
      firstDate: _from,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) {
      setState(() {
        _to = d;
        if (_joining != null && !_joining!.isAfter(_to)) _joining = null;
      });
    }
  }

  Future<void> _pickJoining() async {
    final min = _to.add(const Duration(days: 1));
    final d = await showDatePicker(
      context: context,
      initialDate: _joining != null && _joining!.isAfter(_to) ? _joining! : min,
      firstDate: min,
      lastDate: _to.add(const Duration(days: 400)),
    );
    if (d != null) setState(() => _joining = d);
  }

  Future<void> _captureAttachment() async {
    if (_pickingPhoto) return;
    setState(() => _pickingPhoto = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 75,
        maxWidth: 1280,
      );
      if (picked != null && mounted) {
        setState(() => _attachments = [..._attachments, picked.path]);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Camera unavailable',
              style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600)),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _pickingPhoto = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_type == LeaveModel.typeMedical && _attachments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Medical leave requires a supporting document photo',
            style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600)),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    final encashDays = int.tryParse(_encashDaysCtrl.text.trim()) ?? 0;
    if (_isEncashment && encashDays <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Enter the number of days to encash',
            style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600)),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    setState(() => _saving = true);
    // Upload attachments to the ERP first so the payload carries URLs.
    var attachmentUrls = _attachments;
    if (_attachments.isNotEmpty) {
      try {
        attachmentUrls =
            await ApiService.uploadPhotos(_attachments, folder: 'leaves');
      } catch (_) {
        // Offline — keep local paths; queue sync will retry later.
      }
    }
    final l = LeaveModel(
      id: 'LV-${DateTime.now().millisecondsSinceEpoch}',
      leaveType: _type,
      fromDate: _from,
      toDate: _isEncashment ? _from : _to,
      reason: _reasonCtrl.text.trim(),
      status: LeaveModel.statusPending,
      srId: widget.user?.id ?? '',
      srName: widget.user?.name ?? '',
      appliedAt: DateTime.now(),
      attachments: attachmentUrls,
      joiningDate: _isEncashment
          ? null
          : (_joining ?? _to.add(const Duration(days: 1))),
      isEncashment: _isEncashment,
      encashmentDays: _isEncashment ? encashDays : 0,
    );
    await widget.onSave(l);
    if (mounted) Navigator.pop(context);
  }

  int get _days => _to.difference(_from).inDays + 1;

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
            Text('Apply for Leave',
                style: GoogleFonts.hindSiliguri(
                    fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            _label('Leave Type'),
            DropdownButtonFormField<String>(
              value: _type,
              items: LeaveModel.leaveTypes.map((t) {
                final l = LeaveModel(
                  id: '',
                  leaveType: t,
                  fromDate: DateTime.now(),
                  toDate: DateTime.now(),
                  srId: '',
                  srName: '',
                  appliedAt: DateTime.now(),
                );
                return DropdownMenuItem(
                    value: t,
                    child: Text(l.typeLabel,
                        style: GoogleFonts.hindSiliguri()));
              }).toList(),
              onChanged: (v) => setState(() => _type = v!),
              decoration: const InputDecoration(),
            ),
            const SizedBox(height: 12),
            if (_isEncashment) ...[
              _label('Days to Encash'),
              TextFormField(
                controller: _encashDaysCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    hintText: 'Number of earned-leave days to encash'),
                validator: (v) {
                  if (!_isEncashment) return null;
                  final n = int.tryParse((v ?? '').trim()) ?? 0;
                  return n <= 0 ? 'Enter a positive number of days' : null;
                },
              ),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                    color: AppTheme.primaryAccent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 14, color: AppTheme.primaryAccent),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                        'Encashment amount is calculated from your salary by HR after approval.',
                        style: GoogleFonts.hindSiliguri(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryAccent)),
                  ),
                ]),
              ),
            ] else ...[
              Row(children: [
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Start Date'),
                        GestureDetector(
                          onTap: _pickFrom,
                          child: _dateField(
                              '${_from.day}/${_from.month}/${_from.year}',
                              isDark),
                        ),
                      ]),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('End Date'),
                        GestureDetector(
                          onTap: _pickTo,
                          child: _dateField(
                              '${_to.day}/${_to.month}/${_to.year}',
                              isDark),
                        ),
                      ]),
                ),
              ]),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                    color:
                        AppTheme.primaryAccent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 14, color: AppTheme.primaryAccent),
                  const SizedBox(width: 6),
                  Text('Total $_days days of leave',
                      style: GoogleFonts.hindSiliguri(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryAccent)),
                ]),
              ),
              const SizedBox(height: 12),
              _label('Joining Date (after leave)'),
              GestureDetector(
                onTap: _pickJoining,
                child: _dateField(
                    _joining == null
                        ? 'Auto: day after end date'
                        : '${_joining!.day}/${_joining!.month}/${_joining!.year}',
                    isDark),
              ),
            ],
            const SizedBox(height: 12),
            _label(_type == LeaveModel.typeMedical
                ? 'Supporting Document (Required)'
                : 'Supporting Document (Optional)'),
            _attachmentPicker(),
            const SizedBox(height: 12),
            _label('Reason'),
            TextFormField(
              controller: _reasonCtrl,
              maxLines: 3,
              decoration:
                  const InputDecoration(hintText: 'Enter leave reason...'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
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
                  : Text('Submit Application',
                      style: GoogleFonts.hindSiliguri(
                          fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _dateField(String text, bool isDark) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard2 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.divider, width: 1.5),
        ),
        child: Row(children: [
          const Icon(Icons.calendar_today_rounded,
              size: 14, color: AppTheme.primaryAccent),
          const SizedBox(width: 6),
          Text(text, style: GoogleFonts.hindSiliguri(fontSize: 13)),
        ]),
      );

  Widget _attachmentPicker() {
    Widget thumb(String path) => Stack(children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.divider),
            ),
            clipBehavior: Clip.antiAlias,
            child: path.startsWith('http')
                ? Image.network(path,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                        Icons.broken_image_outlined,
                        size: 22, color: AppTheme.textGrey))
                : Image.file(File(path),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                        Icons.broken_image_outlined,
                        size: 22, color: AppTheme.textGrey)),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: GestureDetector(
              onTap: () =>
                  setState(() => _attachments.remove(path)),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                    color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.close_rounded,
                    size: 12, color: Colors.white),
              ),
            ),
          ),
        ]);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (_attachments.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _attachments.map(thumb).toList()),
        ),
      OutlinedButton.icon(
        onPressed:
            (_pickingPhoto || _attachments.length >= 5) ? null : _captureAttachment,
        icon: _pickingPhoto
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.photo_camera_rounded, size: 17),
        label: Text(
            _attachments.isEmpty ? 'Take Photo' : 'Add Photo (${_attachments.length}/5)',
            style: GoogleFonts.hindSiliguri(fontSize: 12)),
      ),
    ]);
  }

  Widget _label(String t) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(t,
          style: GoogleFonts.hindSiliguri(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textGrey)));
}

// ── Sticky TabBar Delegate ────────────────────────────────────────────────
class _TabDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color bg;
  const _TabDelegate({required this.tabBar, required this.bg});

  @override
  double get minExtent => tabBar.preferredSize.height + 1;
  @override
  double get maxExtent => tabBar.preferredSize.height + 1;

  @override
  Widget build(
          BuildContext context, double shrinkOffset, bool overlapsContent) =>
      Container(color: bg, child: tabBar);

  @override
  bool shouldRebuild(_TabDelegate old) => old.tabBar != tabBar || old.bg != bg;
}

