import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
              ? '✅ আবেদন ERP-তে জমা হয়েছে!'
              : '📥 অফলাইন — sync হলে ERP-তে যাবে');
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
            Text(_erpConnected ? 'ERP সংযুক্ত' : 'অফলাইন',
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
  final _reasonCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _reasonCtrl.dispose();
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
        if (_to.isBefore(_from)) _to = _from;
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
    if (d != null) setState(() => _to = d);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final l = LeaveModel(
      id: 'LV-${DateTime.now().millisecondsSinceEpoch}',
      leaveType: _type,
      fromDate: _from,
      toDate: _to,
      reason: _reasonCtrl.text.trim(),
      status: LeaveModel.statusPending,
      srId: widget.user?.id ?? '',
      srName: widget.user?.name ?? '',
      appliedAt: DateTime.now(),
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

