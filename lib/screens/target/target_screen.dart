import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../models/target_model.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../services/local_storage_service.dart';

/// Target Module — Admin-only yearly target setting.
/// Officers can only VIEW their assigned targets; they cannot create or edit.
/// Targets are set for all months Jan–Dec at once. Current month auto-activates.
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
    // ONLY Admin / Super Admin may configure targets — not Team Leaders/officers
    final isAdmin = user?.isAdmin == true;
    final members = isAdmin
        ? await LocalStorageService.getTeamMembers()
        : <UserModel>[];
    var targets = await LocalStorageService.getTargets();
    var erp = false;
    var erpCurrent = 0.0;

    if (await ApiService.isConnected) {
      try {
        // Fetch the full year so the Jan–Dec plan shows pre-set months;
        // the current month's target activates automatically.
        final data =
            await ApiService.targets(year: DateTime.now().year.toString());
        final month = _currentMonth();
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
          erpCurrent = (data.first['currentValue'] as num?)?.toDouble() ?? 0;
        }
        if (remote.isNotEmpty) {
          final remoteIds = remote.map((t) => t.id).toSet();
          targets = [
            ...remote,
            ...targets.where((t) => !remoteIds.contains(t.id)),
          ];
        }
        erp = true;
      } catch (_) {}
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

  /// Admin-only — Team Leaders and officers can only view their targets.
  bool get _isAdmin => _user?.isAdmin == true;

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
      return _targets.firstWhere((t) => t.userId == uid && t.month == month);
    } catch (_) {
      return null;
    }
  }

  /// Admin-only: set yearly targets for a member for all months Jan–Dec.
  Future<void> _showYearlyTargetDialog({required UserModel forMember}) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final year = now.year;

    // Build controllers for each month (1..12)
    final months = List.generate(12, (i) => i + 1);
    final amountCtrls = <int, TextEditingController>{};
    final commCtrls = <int, TextEditingController>{};

    for (final m in months) {
      final monthKey = '$year-${m.toString().padLeft(2, '0')}';
      TargetModel? existing;
      try {
        existing = _targets
            .firstWhere((t) => t.userId == forMember.id && t.month == monthKey);
      } catch (_) {}
      amountCtrls[m] = TextEditingController(
          text: existing != null && existing.targetAmount > 0
              ? existing.targetAmount.toStringAsFixed(0)
              : '');
      commCtrls[m] = TextEditingController(
          text: existing != null
              ? existing.commissionPercent.toStringAsFixed(0)
              : '20');
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (ctx, sc) => Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCard : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(children: [
            Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 16),
                decoration: BoxDecoration(
                    color: AppTheme.divider,
                    borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Set Yearly Target',
                            style: GoogleFonts.hindSiliguri(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? AppTheme.darkText
                                    : AppTheme.textDark)),
                        Text('For: ${forMember.name}  •  $year',
                            style: GoogleFonts.hindSiliguri(
                                fontSize: 12,
                                color: isDark
                                    ? AppTheme.darkTextGrey
                                    : AppTheme.textGrey)),
                      ]),
                ),
              ]),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryAccent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Targets set here apply automatically each month. '
                  'When a month begins its pre-set target becomes active. '
                  'Officers cannot see or edit this form.',
                  style: GoogleFonts.hindSiliguri(
                      fontSize: 11.5,
                      color: AppTheme.primaryAccent,
                      height: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                controller: sc,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  ...months.map((m) {
                    final monthKey =
                        '$year-${m.toString().padLeft(2, '0')}';
                    final label =
                        DateFormat('MMMM').format(DateTime(year, m));
                    final isCurrent = m == now.month;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? AppTheme.primaryAccent.withValues(alpha: 0.06)
                            : (isDark
                                ? AppTheme.darkBg
                                : AppTheme.primaryBg),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: isCurrent
                                ? AppTheme.primaryAccent.withValues(alpha: 0.4)
                                : AppTheme.divider),
                      ),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Text(label,
                                  style: GoogleFonts.hindSiliguri(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: isCurrent
                                          ? AppTheme.primaryAccent
                                          : (isDark
                                              ? AppTheme.darkText
                                              : AppTheme.textDark))),
                              if (isCurrent) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                      color: AppTheme.primaryAccent,
                                      borderRadius:
                                          BorderRadius.circular(8)),
                                  child: Text('Current',
                                      style: GoogleFonts.hindSiliguri(
                                          fontSize: 10,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700)),
                                ),
                              ],
                            ]),
                            const SizedBox(height: 8),
                            Row(children: [
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  controller: amountCtrls[m],
                                  keyboardType: TextInputType.number,
                                  style:
                                      GoogleFonts.hindSiliguri(fontSize: 13),
                                  decoration: InputDecoration(
                                    labelText: 'Amount (৳)',
                                    labelStyle: GoogleFonts.hindSiliguri(
                                        fontSize: 11,
                                        color: AppTheme.textGrey),
                                    prefixText: '৳ ',
                                    border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                    contentPadding: const EdgeInsets.all(10),
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: commCtrls[m],
                                  keyboardType: TextInputType.number,
                                  style:
                                      GoogleFonts.hindSiliguri(fontSize: 13),
                                  decoration: InputDecoration(
                                    labelText: 'Comm %',
                                    labelStyle: GoogleFonts.hindSiliguri(
                                        fontSize: 11,
                                        color: AppTheme.textGrey),
                                    suffixText: '%',
                                    border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                    contentPadding: const EdgeInsets.all(10),
                                    isDense: true,
                                  ),
                                ),
                              ),
                            ]),
                          ]),
                    );
                  }),
                  const SizedBox(height: 16),
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
                        // Build month payload for ERP (admin-only endpoint)
                        final erpMonths = <Map<String, dynamic>>[];
                        for (final m in months) {
                          final amt =
                              double.tryParse(amountCtrls[m]!.text) ?? 0;
                          if (amt <= 0) continue;
                          final comm =
                              double.tryParse(commCtrls[m]!.text) ?? 20;
                          erpMonths.add({
                            'month': m,
                            'targetAmount': amt,
                            'commissionPercent': comm,
                          });
                        }
                        if (erpMonths.isEmpty) {
                          Navigator.pop(ctx);
                          return;
                        }

                        // 1) Persist to ERP when connected
                        String? erpError;
                        var savedToErp = false;
                        if (await ApiService.isConnected) {
                          try {
                            await ApiService.setYearlyTargets(
                              assignedTo: forMember.name,
                              year: year,
                              months: erpMonths,
                            );
                            savedToErp = true;
                          } on ApiException catch (e) {
                            erpError = e.message; // e.g. 403 non-admin
                          } catch (_) {}
                        }

                        if (erpError != null) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                                content: Text(erpError,
                                    style: GoogleFonts.hindSiliguri()),
                                backgroundColor: AppTheme.error));
                          }
                          return;
                        }

                        // 2) Local copy for offline viewing
                        for (final em in erpMonths) {
                          final m = em['month'] as int;
                          final monthKey =
                              '$year-${m.toString().padLeft(2, '0')}';
                          TargetModel? existing;
                          try {
                            existing = _targets.firstWhere((t) =>
                                t.userId == forMember.id &&
                                t.month == monthKey);
                          } catch (_) {}
                          final newTarget = TargetModel(
                            id: existing?.id.isNotEmpty == true
                                ? existing!.id
                                : 'TGT-${forMember.id}-$monthKey',
                            userId: forMember.id,
                            userName: forMember.name,
                            setById: _user?.id ?? '',
                            setByName: _user?.name ?? '',
                            targetAmount: em['targetAmount'] as double,
                            commissionPercent:
                                em['commissionPercent'] as double,
                            month: monthKey,
                          );
                          await LocalStorageService.saveTarget(newTarget);
                        }
                        if (!mounted) return;
                        Navigator.pop(context);
                        if (savedToErp && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('✅ Yearly targets saved to ERP',
                                  style: GoogleFonts.hindSiliguri()),
                              backgroundColor: AppTheme.success));
                        }
                        _load();
                      },
                      child: Text('Save Yearly Targets',
                          style: GoogleFonts.hindSiliguri(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ]),
        ),
      ),
    );

    for (final c in amountCtrls.values) { c.dispose(); }
    for (final c in commCtrls.values) { c.dispose(); }
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
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryAccent))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── My Target ─────────────────────────────────────────
                _sectionTitle(
                    '📌 My Target — ${_monthLabel(_currentMonth())}', isDark),
                const SizedBox(height: 10),
                if (myTarget != null)
                  _myTargetCard(myTarget, isDark)
                else
                  _noTargetCard(isDark),
                const SizedBox(height: 24),

                // ── All Months at a Glance (read-only) ────────────────
                _sectionTitle('📅 ${DateTime.now().year} Year Plan', isDark),
                const SizedBox(height: 10),
                _yearPlanCard(isDark),
                const SizedBox(height: 24),

                // ── Team Targets (admin only) ──────────────────────────
                if (_isAdmin && _teamMembers.isNotEmpty) ...[
                  _sectionTitle('👥 Team Members\' Targets', isDark),
                  const SizedBox(height: 10),
                  ..._teamMembers.map((m) {
                    TargetModel? mt;
                    try {
                      mt = _targets.firstWhere(
                          (t) => t.userId == m.id && t.month == _currentMonth());
                    } catch (_) {}
                    return _teamTargetCard(m, mt, isDark);
                  }),
                ],
              ],
            ),
    );
  }

  Widget _noTargetCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
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
                color: isDark ? AppTheme.darkTextGrey : AppTheme.textGrey),
            textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text('Your admin will assign a target.',
            style: GoogleFonts.hindSiliguri(
                fontSize: 12,
                color: isDark ? AppTheme.darkTextGrey : AppTheme.textGrey),
            textAlign: TextAlign.center),
      ]),
    );
  }

  /// Yearly plan: shows all 12 months targets for the logged-in user (read-only)
  Widget _yearPlanCard(bool isDark) {
    final now = DateTime.now();
    final year = now.year;
    final uid = _user?.id ?? '';
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 8)
        ],
      ),
      child: Column(
        children: List.generate(12, (i) {
          final m = i + 1;
          final monthKey = '$year-${m.toString().padLeft(2, '0')}';
          final label = DateFormat('MMM').format(DateTime(year, m));
          final isCurrent = m == now.month;
          final isPast = m < now.month;
          TargetModel? t;
          try {
            t = _targets.firstWhere(
                (x) => x.userId == uid && x.month == monthKey);
          } catch (_) {}
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              color: isCurrent
                  ? AppTheme.primaryAccent.withValues(alpha: 0.07)
                  : Colors.transparent,
              border: Border(
                  bottom: i < 11
                      ? BorderSide(color: AppTheme.divider, width: 0.8)
                      : BorderSide.none),
            ),
            child: Row(children: [
              SizedBox(
                width: 32,
                child: Text(label,
                    style: GoogleFonts.hindSiliguri(
                        fontSize: 12,
                        fontWeight: isCurrent
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isCurrent
                            ? AppTheme.primaryAccent
                            : isPast
                                ? AppTheme.textGrey
                                : (isDark
                                    ? AppTheme.darkText
                                    : AppTheme.textDark))),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: t != null
                    ? Row(children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: isCurrent && t.targetAmount > 0
                                  ? (_erpCurrentValue / t.targetAmount)
                                      .clamp(0.0, 1.0)
                                  : 0.0,
                              minHeight: 6,
                              backgroundColor:
                                  AppTheme.primaryAccent.withValues(alpha: 0.1),
                              valueColor: AlwaysStoppedAnimation(
                                  isCurrent
                                      ? AppTheme.primaryAccent
                                      : AppTheme.primaryAccent
                                          .withValues(alpha: 0.4)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(_formatTaka(t.targetAmount),
                            style: GoogleFonts.hindSiliguri(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isCurrent
                                    ? AppTheme.primaryAccent
                                    : (isDark
                                        ? AppTheme.darkTextGrey
                                        : AppTheme.textGrey))),
                      ])
                    : Text('—',
                        style: GoogleFonts.hindSiliguri(
                            fontSize: 12, color: AppTheme.textGrey)),
              ),
            ]),
          );
        }),
      ),
    );
  }

  Widget _myTargetCard(TargetModel t, bool isDark) {
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Target: ${_formatTaka(t.targetAmount)}',
                style: GoogleFonts.hindSiliguri(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12)),
            child: Text(
                '${t.commissionPercent.toStringAsFixed(0)}% Commission',
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
              width: 1,
              height: 40,
              color: Colors.white.withValues(alpha: 0.2)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sales Incentive',
                      style: GoogleFonts.hindSiliguri(
                          fontSize: 12, color: Colors.white70)),
                  Text(_formatTaka(earned),
                      style: GoogleFonts.hindSiliguri(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                  // Spell out how the figure is reached so the officer can
                  // check it against their own sales.
                  Text(
                      '${t.commissionPercent.toStringAsFixed(t.commissionPercent % 1 == 0 ? 0 : 2)}% of ${_formatTaka(sold)}',
                      style: GoogleFonts.hindSiliguri(
                          fontSize: 10, color: Colors.white70)),
                ]),
          ),
        ]),
        const SizedBox(height: 12),
        // Incentive at full target — what the officer is working towards.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            const Icon(Icons.savings_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                  'Incentive on full target: '
                  '${_formatTaka(t.targetAmount * (t.commissionPercent / 100))}',
                  style: GoogleFonts.hindSiliguri(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ),
            if (t.targetAmount > sold)
              Text('${_formatTaka(t.targetAmount - sold)} to go',
                  style: GoogleFonts.hindSiliguri(
                      fontSize: 11, color: Colors.white70)),
          ]),
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 10,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${(progress * 100).clamp(0, 100).toStringAsFixed(1)}% complete',
          style: GoogleFonts.hindSiliguri(fontSize: 12, color: Colors.white70),
        ),
      ]),
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
      child: Row(children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: AppTheme.primaryAccent.withValues(alpha: 0.12),
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
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(m.name,
                style: GoogleFonts.hindSiliguri(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppTheme.darkText : AppTheme.textDark)),
            if (mt != null) ...[
              const SizedBox(height: 4),
              Text(
                'Target: ${_formatTaka(mt.targetAmount)} • ${mt.commissionPercent.toStringAsFixed(0)}% Commission',
                style: GoogleFonts.hindSiliguri(
                    fontSize: 12,
                    color: isDark ? AppTheme.darkTextGrey : AppTheme.textGrey),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: mt.targetAmount > 0
                      ? (m.totalSales / mt.targetAmount).clamp(0.0, 1.0)
                      : 0,
                  minHeight: 6,
                  backgroundColor:
                      AppTheme.primaryAccent.withValues(alpha: 0.1),
                  valueColor:
                      const AlwaysStoppedAnimation(AppTheme.primaryAccent),
                ),
              ),
            ] else ...[
              const SizedBox(height: 3),
              Text('No target set',
                  style: GoogleFonts.hindSiliguri(
                      fontSize: 12,
                      color:
                          isDark ? AppTheme.darkTextGrey : AppTheme.textGrey)),
            ],
          ]),
        ),
        // Admin-only: set yearly target button
        if (_isAdmin)
          IconButton(
            icon: Icon(
                mt != null ? Icons.edit_calendar_rounded : Icons.add_circle_rounded,
                color: AppTheme.primaryAccent,
                size: 22),
            tooltip: 'Set yearly target',
            onPressed: () => _showYearlyTargetDialog(forMember: m),
          ),
      ]),
    );
  }

  Widget _sectionTitle(String t, bool isDark) => Text(t,
      style: GoogleFonts.hindSiliguri(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: isDark ? AppTheme.darkText : AppTheme.textDark));
}
