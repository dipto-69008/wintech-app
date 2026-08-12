import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../models/target_model.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../services/local_storage_service.dart';

class TargetScreen extends StatefulWidget {
  const TargetScreen({super.key});

  @override
  State<TargetScreen> createState() => _TargetScreenState();
}

class _TargetScreenState extends State<TargetScreen> {
  UserModel? _user;
  List<UserModel> _teamMembers = [];
  List<TargetModel> _targets = [];
  bool _loading = true;
  bool _erpConnected = false;
  double _erpCurrentValue = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = await LocalStorageService.getCurrentUser();
    final members = user?.canManageTeam == true
        ? await LocalStorageService.getTeamMembers()
        : <UserModel>[];
    var targets = await LocalStorageService.getTargets();
    var erp = false;
    var erpCurrent = 0.0;

    // ERP-first: pull live targets assigned in the ERP for this user.
    if (await ApiService.isConnected) {
      try {
        final data = await ApiService.targets();
        final month =
            '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}';
        final remote = data.map((t) {
          return TargetModel(
            id: t['_id']?.toString() ?? t['id']?.toString() ?? '',
            userId: user?.id ?? '',
            userName: user?.name ?? '',
            setById: '',
            setByName: t['setByName']?.toString() ?? 'ERP',
            targetAmount: (t['targetValue'] as num?)?.toDouble() ?? 0,
            commissionPercent:
                (t['commissionPercent'] as num?)?.toDouble() ?? 0,
            month: t['month']?.toString() ?? month,
          );
        }).toList();
        if (data.isNotEmpty) {
          erpCurrent =
              (data.first['currentValue'] as num?)?.toDouble() ?? 0;
        }
        if (remote.isNotEmpty) {
          final remoteIds = remote.map((t) => t.id).toSet();
          targets = [
            ...remote,
            ...targets.where((t) => !remoteIds.contains(t.id)),
          ];
        }
        erp = true;
      } catch (_) {
        // Offline or endpoint unavailable — keep local targets.
      }
    }

    if (!mounted) return;
    setState(() {
      _user = user;
      _teamMembers = members;
      _targets = targets;
      _erpConnected = erp;
      _erpCurrentValue = erpCurrent;
      _loading = false;
    });
  }

  String _currentMonth() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  String _monthLabel(String m) {
    try {
      final parts = m.split('-');
      final dt = DateTime(int.parse(parts[0]), int.parse(parts[1]));
      return DateFormat('MMMM yyyy').format(dt);
    } catch (_) {
      return m;
    }
  }

  TargetModel? _myTarget() {
    final uid = _user?.id ?? '';
    final month = _currentMonth();
    try {
      return _targets.firstWhere(
          (t) => t.userId == uid && t.month == month);
    } catch (_) {
      return null;
    }
  }

  Future<void> _showSetTargetDialog({UserModel? forMember}) async {
    final target = _targets.firstWhere(
      (t) =>
          t.userId == (forMember?.id ?? _user?.id ?? '') &&
          t.month == _currentMonth(),
      orElse: () => TargetModel(
        id: '',
        userId: forMember?.id ?? _user?.id ?? '',
        userName: forMember?.name ?? _user?.name ?? '',
        setById: _user?.id ?? '',
        setByName: _user?.name ?? '',
        targetAmount: 0,
        commissionPercent: 20,
        month: _currentMonth(),
      ),
    );

    final amountCtrl =
        TextEditingController(text: target.targetAmount > 0 ? target.targetAmount.toStringAsFixed(0) : '');
    final commCtrl = TextEditingController(
        text: target.commissionPercent.toStringAsFixed(0));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCard : Colors.white,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: AppTheme.divider,
                        borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 20),
              Text(
                forMember != null
                    ? 'Set Target for ${forMember.name}'
                    : 'Set Target',
                style: GoogleFonts.hindSiliguri(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppTheme.darkText : AppTheme.textDark),
              ),
              const SizedBox(height: 6),
              Text(
                _monthLabel(_currentMonth()),
                style: GoogleFonts.hindSiliguri(
                    fontSize: 13,
                    color: isDark
                        ? AppTheme.darkTextGrey
                        : AppTheme.textGrey),
              ),
              const SizedBox(height: 20),
              Text('Target Amount (৳)',
                  style: GoogleFonts.hindSiliguri(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppTheme.darkText : AppTheme.textDark)),
              const SizedBox(height: 8),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                style: GoogleFonts.hindSiliguri(fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'e.g. 100000',
                  hintStyle: GoogleFonts.hindSiliguri(
                      fontSize: 14, color: AppTheme.textGrey),
                  prefixText: '৳ ',
                  prefixStyle: GoogleFonts.hindSiliguri(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryAccent),
                  filled: true,
                  fillColor: isDark ? AppTheme.darkBg : AppTheme.primaryBg,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppTheme.primaryAccent, width: 2)),
                ),
              ),
              const SizedBox(height: 14),
              Text('Commission Rate (%)',
                  style: GoogleFonts.hindSiliguri(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppTheme.darkText : AppTheme.textDark)),
              const SizedBox(height: 8),
              TextField(
                controller: commCtrl,
                keyboardType: TextInputType.number,
                style: GoogleFonts.hindSiliguri(fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'e.g. 20',
                  hintStyle: GoogleFonts.hindSiliguri(
                      fontSize: 14, color: AppTheme.textGrey),
                  suffixText: '%',
                  suffixStyle: GoogleFonts.hindSiliguri(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryAccent),
                  filled: true,
                  fillColor: isDark ? AppTheme.darkBg : AppTheme.primaryBg,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppTheme.primaryAccent, width: 2)),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'If ${forMember?.name ?? "the officer"} sells ৳${amountCtrl.text.isNotEmpty ? amountCtrl.text : "1,00,000"} this month, they earn ${commCtrl.text}% commission.',
                style: GoogleFonts.hindSiliguri(
                    fontSize: 12,
                    color: isDark ? AppTheme.darkTextGrey : AppTheme.textGrey,
                    height: 1.5),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryAccent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () async {
                    final amt = double.tryParse(amountCtrl.text) ?? 0;
                    final comm = double.tryParse(commCtrl.text) ?? 20;
                    if (amt <= 0) return;
                    final newTarget = TargetModel(
                      id: target.id.isNotEmpty
                          ? target.id
                          : 'TGT-${DateTime.now().millisecondsSinceEpoch}',
                      userId: forMember?.id ?? _user?.id ?? '',
                      userName: forMember?.name ?? _user?.name ?? '',
                      setById: _user?.id ?? '',
                      setByName: _user?.name ?? '',
                      targetAmount: amt,
                      commissionPercent: comm,
                      month: _currentMonth(),
                    );
                    await LocalStorageService.saveTarget(newTarget);
                    if (!mounted) return;
                    Navigator.pop(context);
                    _load();
                  },
                  child: Text('Save',
                      style: GoogleFonts.hindSiliguri(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTaka(double v) {
    if (v >= 100000) return '৳${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '৳${(v / 1000).toStringAsFixed(1)}K';
    return '৳${v.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = _user;
    final myTarget = _myTarget();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Target',
            style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w700)),
        backgroundColor: AppTheme.primaryAccent,
        foregroundColor: Colors.white,
        actions: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
          ),
          if (user?.canManageTeam == true)
            IconButton(
              icon: const Icon(Icons.add_rounded),
              onPressed: () => _showSetTargetDialog(),
              tooltip: 'Set my target',
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryAccent))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── My Target ────────────────────────────────────────
                if (myTarget != null) ...[
                  _sectionTitle('📌 My Target — ${_monthLabel(_currentMonth())}', isDark),
                  const SizedBox(height: 10),
                  _myTargetCard(myTarget, isDark),
                  const SizedBox(height: 24),
                ] else ...[
                  _sectionTitle('📌 My Target — ${_monthLabel(_currentMonth())}', isDark),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkCard : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black
                                .withValues(alpha: isDark ? 0.2 : 0.05),
                            blurRadius: 8)
                      ],
                    ),
                    child: Column(children: [
                      Icon(Icons.flag_outlined,
                          size: 40,
                          color: AppTheme.primaryAccent.withValues(alpha: 0.3)),
                      const SizedBox(height: 10),
                      Text('No target set for this month',
                          style: GoogleFonts.hindSiliguri(
                              fontSize: 14,
                              color: isDark
                                  ? AppTheme.darkTextGrey
                                  : AppTheme.textGrey),
                          textAlign: TextAlign.center),
                      if (user?.canManageTeam == true) ...[
                        const SizedBox(height: 14),
                        TextButton.icon(
                          onPressed: () => _showSetTargetDialog(),
                          icon: const Icon(Icons.add_rounded,
                              color: AppTheme.primaryAccent),
                          label: Text('Set Target',
                              style: GoogleFonts.hindSiliguri(
                                  color: AppTheme.primaryAccent,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ]),
                  ),
                  const SizedBox(height: 24),
                ],

                // ── Team Targets (managers only) ──────────────────────
                if (user?.canManageTeam == true && _teamMembers.isNotEmpty) ...[
                  _sectionTitle('👥 Team Members\' Targets', isDark),
                  const SizedBox(height: 10),
                  ..._teamMembers.map((m) {
                    TargetModel? mt;
                    try {
                      mt = _targets.firstWhere((t) =>
                          t.userId == m.id && t.month == _currentMonth());
                    } catch (_) {}
                    return _teamTargetCard(m, mt, isDark);
                  }),
                ],
              ],
            ),
    );
  }

  Widget _myTargetCard(TargetModel t, bool isDark) {
    // Prefer live ERP progress when connected; fall back to local sales.
    final sold = _erpConnected && _erpCurrentValue > 0
        ? _erpCurrentValue
        : (_user?.totalSales ?? 0);
    final progress = t.targetAmount > 0 ? sold / t.targetAmount : 0.0;
    final earned = sold * (t.commissionPercent / 100);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryAccent, Color(0xFF6A1A20)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: AppTheme.primaryAccent.withValues(alpha: 0.3),
              blurRadius: 14,
              offset: const Offset(0, 6))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.emoji_events_rounded,
                color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Target: ${_formatTaka(t.targetAmount)}',
                  style: GoogleFonts.hindSiliguri(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12)),
              child: Text('${t.commissionPercent.toStringAsFixed(0)}% Commission',
                  style: GoogleFonts.hindSiliguri(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sold',
                        style: GoogleFonts.hindSiliguri(
                            fontSize: 12, color: Colors.white70)),
                    Text(_formatTaka(sold),
                        style: GoogleFonts.hindSiliguri(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                  ]),
            ),
            Container(
                width: 1, height: 40, color: Colors.white.withValues(alpha: 0.2)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Est. Commission',
                        style: GoogleFonts.hindSiliguri(
                            fontSize: 12, color: Colors.white70)),
                    Text(_formatTaka(earned),
                        style: GoogleFonts.hindSiliguri(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                  ]),
            ),
          ]),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${(progress * 100).clamp(0, 100).toStringAsFixed(1)}% complete',
            style: GoogleFonts.hindSiliguri(
                fontSize: 12, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _teamTargetCard(UserModel m, TargetModel? mt, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 6)
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor:
                AppTheme.primaryAccent.withValues(alpha: 0.12),
            child: Text(
              m.name.isNotEmpty ? m.name[0] : '?',
              style: GoogleFonts.hindSiliguri(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryAccent),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.name,
                    style: GoogleFonts.hindSiliguri(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color:
                            isDark ? AppTheme.darkText : AppTheme.textDark)),
                if (mt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Target: ${_formatTaka(mt.targetAmount)} • ${mt.commissionPercent.toStringAsFixed(0)}% Commission',
                    style: GoogleFonts.hindSiliguri(
                        fontSize: 12,
                        color: isDark
                            ? AppTheme.darkTextGrey
                            : AppTheme.textGrey),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (m.totalSales / mt.targetAmount).clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor:
                          AppTheme.primaryAccent.withValues(alpha: 0.1),
                      valueColor: const AlwaysStoppedAnimation(
                          AppTheme.primaryAccent),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 3),
                  Text('No target set',
                      style: GoogleFonts.hindSiliguri(
                          fontSize: 12,
                          color: isDark
                              ? AppTheme.darkTextGrey
                              : AppTheme.textGrey)),
                ],
              ],
            ),
          ),
          IconButton(
            icon: Icon(
                mt != null ? Icons.edit_rounded : Icons.add_circle_rounded,
                color: AppTheme.primaryAccent,
                size: 22),
            onPressed: () => _showSetTargetDialog(forMember: m),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t, bool isDark) => Text(t,
      style: GoogleFonts.hindSiliguri(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: isDark ? AppTheme.darkText : AppTheme.textDark));
}
