import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../models/order_model.dart';
import '../../models/user_model.dart';
import '../../services/local_storage_service.dart';

class TargetAchievementScreen extends StatefulWidget {
  const TargetAchievementScreen({super.key});

  @override
  State<TargetAchievementScreen> createState() =>
      _TargetAchievementScreenState();
}

class _TargetAchievementScreenState extends State<TargetAchievementScreen> {
  UserModel? _user;
  List<OrderModel> _myOrders = [];
  bool _loading = true;
  bool _editingTarget = false;
  final _targetCtrl = TextEditingController();

  final _fmt = NumberFormat('#,##0', 'en_US');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final user = await LocalStorageService.getCurrentUser();
    final orders = await LocalStorageService.getOrders();
    if (!mounted) return;
    final myOrders = orders
        .where((o) => o.srId == (user?.id ?? ''))
        .toList();
    setState(() {
      _user = user;
      _myOrders = myOrders;
      _loading = false;
      if (user != null) {
        _targetCtrl.text = user.targetAmount > 0
            ? user.targetAmount.toStringAsFixed(0)
            : '';
      }
    });
  }

  List<OrderModel> get _monthOrders {
    final now = DateTime.now();
    return _myOrders
        .where((o) =>
            o.date.year == now.year &&
            o.date.month == now.month &&
            o.status != OrderModel.statusCancelled)
        .toList();
  }

  double get _monthRevenue =>
      _monthOrders.fold(0.0, (s, o) => s + o.total);
  double get _target => _user?.targetAmount ?? 0;
  double get _progress =>
      _target > 0 ? (_monthRevenue / _target).clamp(0.0, 1.0) : 0;
  double get _remaining => (_target - _monthRevenue).clamp(0, double.infinity);

  Future<void> _saveTarget() async {
    final val = double.tryParse(_targetCtrl.text.replaceAll(',', ''));
    if (val == null || val <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('সঠিক টার্গেট পরিমাণ দিন',
            style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600)),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
      return;
    }
    final updated = _user!.copyWith(targetAmount: val);
    await LocalStorageService.saveCurrentUser(updated);
    if (!mounted) return;
    setState(() {
      _user = updated;
      _editingTarget = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('✅ টার্গেট আপডেট হয়েছে!',
          style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600)),
      backgroundColor: AppTheme.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  String get _achievementBadge {
    if (_progress >= 1.0) return '🏆 টার্গেট অর্জিত!';
    if (_progress >= 0.75) return '🔥 দারুণ চলছে!';
    if (_progress >= 0.5) return '💪 অর্ধেক পার!';
    if (_progress >= 0.25) return '🚀 এগিয়ে চলুন!';
    return '🎯 শুরু হোক!';
  }

  Color get _progressColor {
    if (_progress >= 1.0) return AppTheme.success;
    if (_progress >= 0.75) return const Color(0xFF1565C0);
    if (_progress >= 0.5) return AppTheme.warning;
    return AppTheme.primaryAccent;
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
                  SliverToBoxAdapter(child: _buildTargetCard(isDark)),
                  SliverToBoxAdapter(child: _buildStatsRow(isDark)),
                  SliverToBoxAdapter(child: _buildTargetEditor(isDark)),
                  SliverToBoxAdapter(child: _buildMonthlyHistory(isDark)),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
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
          20, MediaQuery.of(context).padding.top + 14, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.flag_rounded, color: Colors.white, size: 24),
            const SizedBox(width: 10),
            Text('টার্গেট ও অর্জন',
                style: GoogleFonts.hindSiliguri(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ]),
          const SizedBox(height: 6),
          Text('ORIENT ERP — Sales Achievement',
              style: GoogleFonts.hindSiliguri(
                  fontSize: 13, color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildTargetCard(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_progressColor, _progressColor.withValues(alpha: 0.75)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: _progressColor.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 6))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_achievementBadge,
                style: GoogleFonts.hindSiliguri(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
            const SizedBox(height: 4),
            Text(
                _target > 0
                    ? 'এই মাসের টার্গেট: ৳ ${_fmt.format(_target)}'
                    : 'টার্গেট এখনো সেট করা হয়নি',
                style: GoogleFonts.hindSiliguri(
                    fontSize: 13, color: Colors.white70)),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _progress,
                minHeight: 14,
                backgroundColor: Colors.white.withValues(alpha: 0.25),
                valueColor: const AlwaysStoppedAnimation(Colors.white),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('৳ ${_fmt.format(_monthRevenue)} অর্জিত',
                    style: GoogleFonts.hindSiliguri(
                        fontSize: 13, color: Colors.white)),
                Text('${(_progress * 100).toStringAsFixed(1)}%',
                    style: GoogleFonts.hindSiliguri(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(bool isDark) {
    final cardBg = isDark ? AppTheme.darkCard : Colors.white;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(children: [
        Expanded(child: _statCard(cardBg, 'মাসের অর্ডার',
            '${_monthOrders.length}', Icons.receipt_long_rounded,
            AppTheme.primaryAccent, isDark)),
        const SizedBox(width: 10),
        Expanded(child: _statCard(cardBg, 'অর্জিত',
            '৳${_fmt.format(_monthRevenue)}', Icons.payments_rounded,
            AppTheme.success, isDark)),
        const SizedBox(width: 10),
        Expanded(child: _statCard(cardBg, 'বাকি',
            _target > 0 ? '৳${_fmt.format(_remaining)}' : 'N/A',
            Icons.schedule_rounded, AppTheme.warning, isDark)),
      ]),
    );
  }

  Widget _statCard(Color bg, String label, String value, IconData icon,
      Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 16, color: color)),
          const SizedBox(height: 8),
          Text(value,
              style: GoogleFonts.hindSiliguri(
                  fontSize: 13, fontWeight: FontWeight.w800, color: color)),
          Text(label,
              style: GoogleFonts.hindSiliguri(
                  fontSize: 10,
                  color: isDark ? AppTheme.darkTextGrey : AppTheme.textGrey)),
        ],
      ),
    );
  }

  Widget _buildTargetEditor(bool isDark) {
    final cardBg = isDark ? AppTheme.darkCard : Colors.white;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: AppTheme.primaryAccent.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.edit_rounded,
                  color: AppTheme.primaryAccent, size: 18),
              const SizedBox(width: 8),
              Text('মাসিক টার্গেট সেট করুন',
                  style: GoogleFonts.hindSiliguri(
                      fontSize: 14, fontWeight: FontWeight.w700)),
              const Spacer(),
              if (!_editingTarget)
                TextButton(
                  onPressed: () =>
                      setState(() => _editingTarget = true),
                  child: Text('পরিবর্তন',
                      style: GoogleFonts.hindSiliguri(
                          fontSize: 13,
                          color: AppTheme.primaryAccent,
                          fontWeight: FontWeight.w600)),
                ),
            ]),
            if (_editingTarget) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _targetCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly
                ],
                style: GoogleFonts.hindSiliguri(fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'টার্গেট পরিমাণ (৳)',
                  labelStyle: GoogleFonts.hindSiliguri(fontSize: 13),
                  prefixText: '৳ ',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        setState(() => _editingTarget = false),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.primaryAccent),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text('বাতিল',
                        style: GoogleFonts.hindSiliguri(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryAccent)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saveTarget,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryAccent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text('সংরক্ষণ',
                        style: GoogleFonts.hindSiliguri(
                            fontWeight: FontWeight.w600,
                            color: Colors.white)),
                  ),
                ),
              ]),
            ] else ...[
              const SizedBox(height: 8),
              Text(
                  _target > 0
                      ? 'বর্তমান টার্গেট: ৳ ${_fmt.format(_target)}'
                      : 'টার্গেট সেট করুন',
                  style: GoogleFonts.hindSiliguri(
                      fontSize: 13,
                      color: _target > 0
                          ? AppTheme.primaryAccent
                          : AppTheme.textGrey)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyHistory(bool isDark) {
    final cardBg = isDark ? AppTheme.darkCard : Colors.white;
    final now = DateTime.now();
    // last 3 months stats (demo)
    final months = [
      {'label': _monthName(now.month - 2 < 1 ? now.month - 2 + 12 : now.month - 2), 'sales': 380000.0, 'target': 500000.0},
      {'label': _monthName(now.month - 1 < 1 ? now.month - 1 + 12 : now.month - 1), 'sales': 620000.0, 'target': 600000.0},
      {'label': _monthName(now.month), 'sales': _monthRevenue, 'target': _target > 0 ? _target : 500000.0},
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 4, height: 18,
                decoration: BoxDecoration(
                    color: AppTheme.primaryAccent,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 8),
            Text('মাসিক পারফরম্যান্স',
                style: GoogleFonts.hindSiliguri(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppTheme.darkText : AppTheme.textDark)),
          ]),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
                color: cardBg, borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: months.asMap().entries.map((entry) {
                final i = entry.key;
                final m = entry.value;
                final sales = m['sales'] as double;
                final target = m['target'] as double;
                final pct = target > 0 ? (sales / target).clamp(0.0, 1.0) : 0.0;
                final achieved = pct >= 1.0;
                final isLast = i == months.length - 1;
                return Column(children: [
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text(m['label'] as String,
                              style: GoogleFonts.hindSiliguri(
                                  fontSize: 14, fontWeight: FontWeight.w600)),
                          const Spacer(),
                          if (achieved)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                  color: AppTheme.success.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20)),
                              child: Text('✅ অর্জিত',
                                  style: GoogleFonts.hindSiliguri(
                                      fontSize: 11,
                                      color: AppTheme.success,
                                      fontWeight: FontWeight.w600)),
                            ),
                          Text(
                              '৳${_fmt.format(sales)} / ৳${_fmt.format(target)}',
                              style: GoogleFonts.hindSiliguri(
                                  fontSize: 12, color: AppTheme.textGrey)),
                        ]),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: pct,
                            minHeight: 8,
                            backgroundColor: AppTheme.primaryAccent
                                .withValues(alpha: 0.1),
                            valueColor: AlwaysStoppedAnimation(
                                achieved ? AppTheme.success : AppTheme.primaryAccent),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isLast) const Divider(height: 1),
                ]);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  String _monthName(int m) {
    const names = [
      '', 'জানুয়ারি', 'ফেব্রুয়ারি', 'মার্চ', 'এপ্রিল', 'মে', 'জুন',
      'জুলাই', 'আগস্ট', 'সেপ্টেম্বর', 'অক্টোবর', 'নভেম্বর', 'ডিসেম্বর'
    ];
    return names[m.clamp(1, 12)];
  }

  @override
  void dispose() {
    _targetCtrl.dispose();
    super.dispose();
  }
}
