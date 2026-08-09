import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../models/order_model.dart';
import '../../models/user_model.dart';
import '../../services/local_storage_service.dart';

class SuperAdminDashboard extends StatefulWidget {
  const SuperAdminDashboard({super.key});

  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard>
    with SingleTickerProviderStateMixin {
  List<OrderModel> _allOrders = [];
  List<UserModel> _allEmployees = [];
  bool _loading = true;

  String _dateFilter = 'month'; // today | week | month | all
  String? _zelaFilter;

  late AnimationController _animCtrl;
  late List<Animation<double>> _fadeAnims;

  final _fmt = NumberFormat('#,##0', 'en_US');

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _fadeAnims = List.generate(10, (i) {
      final start = (i * 0.1).clamp(0.0, 1.0);
      final end = (i * 0.1 + 0.45).clamp(0.0, 1.0);
      return Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
          parent: _animCtrl,
          curve: Interval(start, end, curve: Curves.easeOut)));
    });
    _load();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final orders = await LocalStorageService.getOrders();
    final employees = await LocalStorageService.getAllEmployees();
    if (!mounted) return;
    setState(() {
      _allOrders = orders;
      _allEmployees = employees;
      _loading = false;
    });
    _animCtrl.forward(from: 0);
  }

  // ── Filtered orders ──────────────────────────────────────────────────
  List<OrderModel> get _filtered {
    final now = DateTime.now();
    return _allOrders.where((o) {
      if (_dateFilter == 'today') {
        if (o.date.year != now.year ||
            o.date.month != now.month ||
            o.date.day != now.day) return false;
      } else if (_dateFilter == 'week') {
        if (o.date.isBefore(now.subtract(const Duration(days: 7)))) return false;
      } else if (_dateFilter == 'month') {
        if (o.date.year != now.year || o.date.month != now.month) return false;
      }
      if (_zelaFilter != null) {
        final emp = _allEmployees.where((e) => e.id == o.srId).firstOrNull;
        if ((emp?.zela ?? '') != _zelaFilter) return false;
      }
      return true;
    }).toList();
  }

  double get _totalRevenue =>
      _filtered.fold(0.0, (sum, o) => sum + o.total);

  int get _deliveredCount =>
      _filtered.where((o) => o.status == OrderModel.statusDelivered).length;

  int get _todayOrderCount {
    final now = DateTime.now();
    return _allOrders
        .where((o) =>
            o.date.year == now.year &&
            o.date.month == now.month &&
            o.date.day == now.day)
        .length;
  }

  // Last 6 months: {label, count, revenue}
  List<_MonthData> get _monthlyTrend {
    final now = DateTime.now();
    return List.generate(6, (i) {
      final month = DateTime(now.year, now.month - (5 - i), 1);
      final monthOrders = _allOrders.where((o) =>
          o.date.year == month.year && o.date.month == month.month);
      return _MonthData(
        DateFormat('MMM').format(month),
        monthOrders.length,
        monthOrders.fold(0.0, (s, o) => s + o.total),
      );
    });
  }

  // Zela → {emp, orders}
  Map<String, Map<String, int>> get _zelaStats {
    final result = <String, Map<String, int>>{};
    for (final emp in _allEmployees) {
      if (emp.zela.isEmpty) continue;
      result.putIfAbsent(emp.zela, () => {'emp': 0, 'orders': 0});
      result[emp.zela]!['emp'] = (result[emp.zela]!['emp'] ?? 0) + 1;
    }
    for (final o in _filtered) {
      final emp = _allEmployees.where((e) => e.id == o.srId).firstOrNull;
      final zela = emp?.zela ?? '';
      if (zela.isEmpty) continue;
      result.putIfAbsent(zela, () => {'emp': 0, 'orders': 0});
      result[zela]!['orders'] = (result[zela]!['orders'] ?? 0) + 1;
    }
    return result;
  }

  // Officer → order count
  Map<String, int> get _srOrderCounts {
    final m = <String, int>{};
    for (final o in _filtered) {
      if (o.srId.isEmpty) continue;
      m[o.srId] = (m[o.srId] ?? 0) + 1;
    }
    return m;
  }

  Widget _fade(int i, Widget child) => FadeTransition(
      opacity:
          i < _fadeAnims.length ? _fadeAnims[i] : const AlwaysStoppedAnimation(1),
      child: child);

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
                  SliverToBoxAdapter(child: _buildDateFilter(isDark)),
                  SliverToBoxAdapter(child: _buildKpiRow(isDark)),
                  SliverToBoxAdapter(child: _buildMonthlyTrend(isDark)),
                  SliverToBoxAdapter(child: _buildZelaFilter(isDark)),
                  SliverToBoxAdapter(child: _buildZelaStats(isDark)),
                  SliverToBoxAdapter(child: _buildEmployeePerformance(isDark)),
                  SliverToBoxAdapter(child: _buildRecentOrders(isDark)),
                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              ),
            ),
    );
  }

  // ── 1. Header ────────────────────────────────────────────────────────
  Widget _buildHeader(bool isDark) {
    final now = DateTime.now();
    final dateStr = DateFormat('dd MMMM yyyy').format(now);
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryAccent, Color(0xFF6A1A20)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
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
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12)),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(
                'assets/images/wintech.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                    Icons.business_rounded,
                    color: Colors.white,
                    size: 26),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CEO Dashboard',
                      style: GoogleFonts.hindSiliguri(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                  Text(dateStr,
                      style: GoogleFonts.hindSiliguri(
                          fontSize: 12, color: Colors.white70)),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('Super Admin',
                  style: GoogleFonts.hindSiliguri(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            _headerChip(Icons.people_rounded, '${_allEmployees.length} Staff'),
            const SizedBox(width: 8),
            _headerChip(Icons.shopping_bag_rounded,
                '$_todayOrderCount Today\'s Orders'),
            const SizedBox(width: 8),
            _headerChip(Icons.attach_money_rounded,
                '৳${_fmt.format(_totalRevenue.toInt())}'),
          ]),
        ],
      ),
    );
  }

  Widget _headerChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: Colors.white, size: 13),
        const SizedBox(width: 5),
        Text(label,
            style: GoogleFonts.hindSiliguri(
                fontSize: 11,
                color: Colors.white,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }

  // ── 2. Date filter ───────────────────────────────────────────────────
  Widget _buildDateFilter(bool isDark) {
    final filters = [
      ('today', 'Today', Icons.today_rounded),
      ('week', 'This Week', Icons.date_range_rounded),
      ('month', 'This Month', Icons.calendar_month_rounded),
      ('all', 'All Time', Icons.all_inclusive_rounded),
    ];
    return _fade(0, Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: filters.map((f) {
          final selected = _dateFilter == f.$1;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _dateFilter = f.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: EdgeInsets.only(right: f == filters.last ? 0 : 8),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: selected
                      ? AppTheme.primaryAccent
                      : (isDark ? AppTheme.darkCard : Colors.white),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                              color: AppTheme.primaryAccent
                                  .withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3))
                        ]
                      : [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 4)
                        ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(f.$3,
                        size: 16,
                        color: selected
                            ? Colors.white
                            : (isDark
                                ? AppTheme.darkTextGrey
                                : AppTheme.textGrey)),
                    const SizedBox(height: 3),
                    Text(f.$2,
                        style: GoogleFonts.hindSiliguri(
                            fontSize: 10,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: selected
                                ? Colors.white
                                : (isDark
                                    ? AppTheme.darkTextGrey
                                    : AppTheme.textGrey)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    ));
  }

  // ── 3. KPI row ───────────────────────────────────────────────────────
  Widget _buildKpiRow(bool isDark) {
    final kpis = [
      _KpiData('Total Orders', '${_filtered.length}',
          Icons.receipt_long_rounded, AppTheme.primaryAccent),
      _KpiData('Revenue', '৳${_fmt.format(_totalRevenue.toInt())}',
          Icons.account_balance_wallet_rounded, AppTheme.success),
      _KpiData('Delivered', '$_deliveredCount',
          Icons.local_shipping_rounded, const Color(0xFF1565C0)),
      _KpiData('Staff', '${_allEmployees.length}',
          Icons.badge_rounded, const Color(0xFF7B1FA2)),
    ];
    return _fade(1, Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(
        children: kpis.asMap().entries.map((entry) {
          final kpi = entry.value;
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(
                  right: entry.key < kpis.length - 1 ? 10 : 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                      color: kpi.color.withValues(alpha: 0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 3))
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                        color: kpi.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8)),
                    child: Icon(kpi.icon, size: 16, color: kpi.color),
                  ),
                  const SizedBox(height: 8),
                  Text(kpi.value,
                      style: GoogleFonts.hindSiliguri(
                          fontSize: kpi.value.length > 7 ? 13 : 18,
                          fontWeight: FontWeight.w900,
                          color: kpi.color)),
                  Text(kpi.label,
                      style: GoogleFonts.hindSiliguri(
                          fontSize: 10,
                          color: isDark
                              ? AppTheme.darkTextGrey
                              : AppTheme.textGrey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    ));
  }

  // ── 4. Monthly trend ─────────────────────────────────────────────────
  Widget _buildMonthlyTrend(bool isDark) {
    final trend = _monthlyTrend;
    final maxCount = trend.fold(1, (a, b) => a > b.count ? a : b.count);
    final maxRev = trend.fold(1.0, (a, b) => a > b.revenue ? a : b.revenue);
    return _fade(2, Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
              blurRadius: 10)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _sectionLabel('📅 Monthly Order Trend', isDark),
            const Spacer(),
            Row(children: [
              Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                      color: AppTheme.primaryAccent,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 4),
              Text('Orders',
                  style: GoogleFonts.hindSiliguri(
                      fontSize: 10, color: AppTheme.textGrey)),
              const SizedBox(width: 10),
              Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                      color: AppTheme.success,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 4),
              Text('Revenue',
                  style: GoogleFonts.hindSiliguri(
                      fontSize: 10, color: AppTheme.textGrey)),
            ]),
          ]),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: trend.map((m) {
              final countH =
                  maxCount == 0 ? 0.0 : (m.count / maxCount) * 80;
              final revH =
                  maxRev == 0 ? 0.0 : (m.revenue / maxRev) * 80;
              return Expanded(
                child: Column(children: [
                  Text('${m.count}',
                      style: GoogleFonts.hindSiliguri(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryAccent)),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 84,
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        Container(
                          width: 22,
                          height: countH.clamp(4.0, 80.0),
                          decoration: BoxDecoration(
                              color: AppTheme.primaryAccent
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4)),
                        ),
                        Container(
                          width: 12,
                          height: revH.clamp(
                              m.revenue > 0 ? 4.0 : 0.0, 80.0),
                          decoration: BoxDecoration(
                              color: AppTheme.success,
                              borderRadius: BorderRadius.circular(4)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(m.label,
                      style: GoogleFonts.hindSiliguri(
                          fontSize: 9,
                          color: isDark
                              ? AppTheme.darkTextGrey
                              : AppTheme.textGrey)),
                ]),
              );
            }).toList(),
          ),
        ],
      ),
    ));
  }

  // ── 5. Zela filter chips ─────────────────────────────────────────────
  Widget _buildZelaFilter(bool isDark) {
    final zelas = _zelaStats.keys.toList()..sort();
    if (zelas.isEmpty) return const SizedBox.shrink();
    return _fade(3, Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: _sectionLabel('🗺️ District Filter', isDark),
        ),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: zelas.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              if (i == 0) {
                return _zelaChip('All Districts', _zelaFilter == null, isDark,
                    () => setState(() => _zelaFilter = null));
              }
              final z = zelas[i - 1];
              final selected = _zelaFilter == z;
              return _zelaChip(z, selected, isDark,
                  () => setState(() => _zelaFilter = selected ? null : z));
            },
          ),
        ),
      ],
    ));
  }

  Widget _zelaChip(
      String label, bool selected, bool isDark, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primaryAccent
              : (isDark ? AppTheme.darkCard : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color:
                  selected ? AppTheme.primaryAccent : AppTheme.divider),
          boxShadow: selected
              ? [
                  BoxShadow(
                      color: AppTheme.primaryAccent.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2))
                ]
              : [],
        ),
        child: Text(label,
            style: GoogleFonts.hindSiliguri(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected
                    ? Colors.white
                    : (isDark ? AppTheme.darkText : AppTheme.textDark))),
      ),
    );
  }

  // ── 6. Zela stats ────────────────────────────────────────────────────
  Widget _buildZelaStats(bool isDark) {
    final stats = _zelaStats;
    if (stats.isEmpty) return const SizedBox.shrink();
    final sorted = stats.entries.toList()
      ..sort((a, b) =>
          (b.value['orders'] ?? 0).compareTo(a.value['orders'] ?? 0));
    return _fade(4, Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: _sectionLabel('🏙️ District-wise Performance', isDark),
        ),
        SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: sorted.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final entry = sorted[i];
              final emp = entry.value['emp'] ?? 0;
              final orders = entry.value['orders'] ?? 0;
              return Container(
                width: 130,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: AppTheme.primaryAccent.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 3))
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.key,
                        style: GoogleFonts.hindSiliguri(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primaryAccent),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const Spacer(),
                    Row(children: [
                      Icon(Icons.badge_rounded,
                          size: 12,
                          color: isDark
                              ? AppTheme.darkTextGrey
                              : AppTheme.textGrey),
                      const SizedBox(width: 4),
                      Text('$emp staff',
                          style: GoogleFonts.hindSiliguri(
                              fontSize: 11,
                              color: isDark
                                  ? AppTheme.darkTextGrey
                                  : AppTheme.textGrey)),
                    ]),
                    const SizedBox(height: 4),
                    Row(children: [
                      Icon(Icons.receipt_rounded,
                          size: 12, color: const Color(0xFF1565C0)),
                      const SizedBox(width: 4),
                      Text('$orders orders',
                          style: GoogleFonts.hindSiliguri(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1565C0))),
                    ]),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    ));
  }

  // ── 7. Employee performance ──────────────────────────────────────────
  Widget _buildEmployeePerformance(bool isDark) {
    final counts = _srOrderCounts;
    final sorted = _allEmployees
        .where((e) => counts.containsKey(e.id))
        .toList()
      ..sort((a, b) => (counts[b.id] ?? 0).compareTo(counts[a.id] ?? 0));
    if (sorted.isEmpty) return const SizedBox.shrink();
    final maxOrders = counts.values.fold(1, (a, b) => a > b ? a : b);

    return _fade(5, Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
              blurRadius: 10)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('👤 Officer Performance', isDark),
          const SizedBox(height: 14),
          ...sorted.take(8).map((emp) {
            final count = counts[emp.id] ?? 0;
            final pct = maxOrders == 0 ? 0.0 : count / maxOrders;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      emp.name.isNotEmpty ? emp.name.substring(0, 1) : '?',
                      style: GoogleFonts.hindSiliguri(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryAccent),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text(emp.name,
                              style: GoogleFonts.hindSiliguri(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? AppTheme.darkText
                                      : AppTheme.textDark),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        Text('$count',
                            style: GoogleFonts.hindSiliguri(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primaryAccent)),
                      ]),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 6,
                          backgroundColor:
                              AppTheme.primaryAccent.withValues(alpha: 0.1),
                          valueColor: const AlwaysStoppedAnimation(
                              AppTheme.primaryAccent),
                        ),
                      ),
                    ],
                  ),
                ),
              ]),
            );
          }),
        ],
      ),
    ));
  }

  // ── 8. Recent orders ─────────────────────────────────────────────────
  Widget _buildRecentOrders(bool isDark) {
    final orders = _filtered.take(20).toList();
    return _fade(6, Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Row(children: [
            _sectionLabel('📋 Recent Orders', isDark),
            const Spacer(),
            Text('${_filtered.length} total',
                style: GoogleFonts.hindSiliguri(
                    fontSize: 12,
                    color: AppTheme.primaryAccent,
                    fontWeight: FontWeight.w700)),
          ]),
        ),
        if (orders.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(children: [
                Icon(Icons.inbox_rounded,
                    size: 48,
                    color: AppTheme.primaryAccent.withValues(alpha: 0.3)),
                const SizedBox(height: 12),
                Text('No orders',
                    style: GoogleFonts.hindSiliguri(
                        fontSize: 14, color: AppTheme.textGrey)),
              ]),
            ),
          )
        else
          ...orders.map((o) => _buildOrderRow(o, isDark)),
      ],
    ));
  }

  Widget _buildOrderRow(OrderModel order, bool isDark) {
    final statusColor = _orderStatusColor(order.status);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
              blurRadius: 4)
        ],
      ),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              order.customerName.isNotEmpty
                  ? order.customerName.substring(0, 1)
                  : '?',
              style: GoogleFonts.hindSiliguri(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: statusColor),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(order.customerName,
                  style: GoogleFonts.hindSiliguri(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color:
                          isDark ? AppTheme.darkText : AppTheme.textDark)),
              if (order.srName.isNotEmpty)
                Text('Officer: ${order.srName}',
                    style: GoogleFonts.hindSiliguri(
                        fontSize: 10, color: AppTheme.primaryAccent)),
              Text('${order.items.length} items',
                  style: GoogleFonts.hindSiliguri(
                      fontSize: 10,
                      color: isDark
                          ? AppTheme.darkTextGrey
                          : AppTheme.textGrey)),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(order.statusLabel,
                  style: GoogleFonts.hindSiliguri(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: statusColor)),
            ),
            const SizedBox(height: 4),
            Text('৳${_fmt.format(order.total.toInt())}',
                style: GoogleFonts.hindSiliguri(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.success)),
            Text(
              DateFormat('dd/MM').format(order.date),
              style: GoogleFonts.hindSiliguri(
                  fontSize: 10,
                  color: isDark
                      ? AppTheme.darkTextGrey
                      : AppTheme.textGrey),
            ),
          ],
        ),
      ]),
    );
  }

  Color _orderStatusColor(String status) {
    switch (status) {
      case 'delivered':
        return AppTheme.success;
      case 'cancelled':
        return AppTheme.error;
      case 'confirmed':
        return const Color(0xFF1565C0);
      default:
        return const Color(0xFFF57F17);
    }
  }

  Widget _sectionLabel(String text, bool isDark) {
    return Text(text,
        style: GoogleFonts.hindSiliguri(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: isDark ? AppTheme.darkText : AppTheme.textDark));
  }
}

class _KpiData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _KpiData(this.label, this.value, this.icon, this.color);
}

class _MonthData {
  final String label;
  final int count;
  final double revenue;
  const _MonthData(this.label, this.count, this.revenue);
}
