import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../models/order_model.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../services/local_storage_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  UserModel? _user;
  List<OrderModel> _orders = [];
  List<UserModel> _employees = [];
  bool _loading = true;

  // Live ERP figures
  bool _erpConnected = false;
  double _erpMonthSales = 0;
  int _erpMonthOrders = 0;
  double _erpTodaySales = 0;
  int _erpTodayOrders = 0;

  final _fmt = NumberFormat('#,##0', 'en_US');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final user = await LocalStorageService.getCurrentUser();

    // Pull live dashboard stats from ERP when connected
    if (await ApiService.isConnected) {
      try {
        final dash = await ApiService.dashboard();
        final today = dash['today'] as Map<String, dynamic>? ?? {};
        final thisMonth = dash['thisMonth'] as Map<String, dynamic>? ?? {};
        if (mounted) {
          _erpConnected = true;
          _erpTodaySales = (today['salesAmount'] as num?)?.toDouble() ?? 0;
          _erpTodayOrders = (today['orders'] as num?)?.toInt() ?? 0;
          _erpMonthSales = (thisMonth['salesAmount'] as num?)?.toDouble() ?? 0;
          _erpMonthOrders = (thisMonth['orders'] as num?)?.toInt() ?? 0;
        }
      } catch (_) {
        // ERP unreachable — use local data
      }
    }

    final orders = await LocalStorageService.getOrders();
    final employees = await LocalStorageService.getAllEmployees();
    if (!mounted) return;
    setState(() {
      _user = user;
      _orders = orders;
      _employees = employees;
      _loading = false;
    });
  }

  List<OrderModel> get _thisMonthOrders {
    final now = DateTime.now();
    return _orders
        .where((o) =>
            o.date.year == now.year &&
            o.date.month == now.month &&
            o.status != OrderModel.statusCancelled)
        .toList();
  }

  double get _thisMonthRevenue =>
      _erpConnected ? _erpMonthSales : _thisMonthOrders.fold(0.0, (s, o) => s + o.total);

  int get _thisMonthOrderCount =>
      _erpConnected ? _erpMonthOrders : _thisMonthOrders.length;

  double get _totalOutstanding {
    return _employees
        .where((e) => e.isCustomer)
        .fold(0.0, (s, c) => s + c.creditUsed);
  }

  Map<String, _SRStats> get _srStats {
    final map = <String, _SRStats>{};
    for (final o in _thisMonthOrders) {
      map.putIfAbsent(o.srId, () => _SRStats(name: o.srName));
      map[o.srId]!.revenue += o.total;
      map[o.srId]!.orders++;
    }
    return map;
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
                  SliverToBoxAdapter(child: _buildSummaryRow(isDark)),
                  SliverToBoxAdapter(child: _buildSectionTitle('এস.আর. পারফরম্যান্স', isDark)),
                  SliverToBoxAdapter(child: _buildSRPerformance(isDark)),
                  SliverToBoxAdapter(child: _buildSectionTitle('সাম্প্রতিক অর্ডার', isDark)),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => _buildOrderTile(_orders[i], isDark),
                      childCount: _orders.take(20).length,
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader(bool isDark) {
    final hour = DateTime.now().hour;
    final greet = hour < 12 ? 'সুপ্রভাত' : hour < 17 ? 'শুভ অপরাহ্ন' : 'শুভ সন্ধ্যা';
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
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.admin_panel_settings_rounded,
                color: Colors.white, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$greet, ${_user?.name ?? 'অ্যাডমিন'}! 👋',
                    style: GoogleFonts.hindSiliguri(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
                Row(children: [
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('Wintech Agro — অ্যাডমিন',
                          style: GoogleFonts.hindSiliguri(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.w600)),
                      if (_erpConnected) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.cloud_done_rounded,
                            size: 11, color: Colors.white70),
                      ],
                    ]),
                  ),
                ]),
              ],
            ),
          ),
          GestureDetector(
            onTap: _load,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.refresh_rounded,
                  color: Colors.white, size: 24),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(bool isDark) {
    final stats = _srStats;
    final cardBg = isDark ? AppTheme.darkCard : Colors.white;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        children: [
          // Big revenue card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primaryAccent, Color(0xFFB03040)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                    color: AppTheme.primaryAccent.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 6))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('এই মাসের মোট বিক্রয়',
                    style: GoogleFonts.hindSiliguri(
                        fontSize: 13, color: Colors.white70)),
                const SizedBox(height: 6),
                Text('৳ ${_fmt.format(_thisMonthRevenue)}',
                    style: GoogleFonts.hindSiliguri(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
                const SizedBox(height: 16),
                Row(children: [
                  _headerChip(Icons.receipt_long_rounded,
                      '$_thisMonthOrderCount অর্ডার'),
                  const SizedBox(width: 10),
                  _headerChip(Icons.people_rounded,
                      '${stats.length} এস.আর.'),
                  const SizedBox(width: 10),
                  _headerChip(Icons.account_balance_wallet_rounded,
                      '৳ ${_fmt.format(_totalOutstanding)} বকেয়া'),
                ]),
                if (_erpConnected) ...[
                  const SizedBox(height: 10),
                  Row(children: [
                    const Icon(Icons.cloud_done_rounded,
                        size: 12, color: Colors.white54),
                    const SizedBox(width: 4),
                    Text('ERP live — আজ: ৳${_fmt.format(_erpTodaySales)} (${_erpTodayOrders} অর্ডার)',
                        style: GoogleFonts.hindSiliguri(
                            fontSize: 11, color: Colors.white54)),
                  ]),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          // 3 stat cards
          Row(children: [
            Expanded(
                child: _statCard(
                    cardBg, 'মোট অর্ডার', '${_erpConnected ? _erpMonthOrders : _orders.length}',
                    Icons.receipt_rounded, AppTheme.primaryAccent, isDark)),
            const SizedBox(width: 10),
            Expanded(
                child: _statCard(
                    cardBg, 'এস.আর. সংখ্যা', '${_employees.where((e) => e.isEmployee).length}',
                    Icons.badge_rounded, const Color(0xFF1565C0), isDark)),
            const SizedBox(width: 10),
            Expanded(
                child: _statCard(
                    cardBg, 'কাস্টমার', '${_employees.where((e) => e.isCustomer).length}',
                    Icons.storefront_rounded, AppTheme.success, isDark)),
          ]),
        ],
      ),
    );
  }

  Widget _headerChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20)),
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
            width: 32,
            height: 32,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 8),
          Text(value,
              style: GoogleFonts.hindSiliguri(
                  fontSize: 18, fontWeight: FontWeight.w800, color: color)),
          Text(label,
              style: GoogleFonts.hindSiliguri(
                  fontSize: 10,
                  color: isDark ? AppTheme.darkTextGrey : AppTheme.textGrey)),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Row(children: [
        Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
                color: AppTheme.primaryAccent,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(title,
            style: GoogleFonts.hindSiliguri(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark ? AppTheme.darkText : AppTheme.textDark)),
      ]),
    );
  }

  Widget _buildSRPerformance(bool isDark) {
    final stats = _srStats;
    final cardBg = isDark ? AppTheme.darkCard : Colors.white;
    if (stats.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
              color: cardBg, borderRadius: BorderRadius.circular(14)),
          child: Center(
            child: Text('এই মাসে কোনো অর্ডার নেই',
                style: GoogleFonts.hindSiliguri(
                    fontSize: 13, color: AppTheme.textGrey)),
          ),
        ),
      );
    }
    final sortedEntries = stats.entries.toList()
      ..sort((a, b) => b.value.revenue.compareTo(a.value.revenue));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
            color: cardBg, borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: sortedEntries.asMap().entries.map((entry) {
            final i = entry.key;
            final e = entry.value;
            final isLast = i == sortedEntries.length - 1;
            return Column(children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                        color: AppTheme.primaryAccent
                            .withValues(alpha: 0.1),
                        shape: BoxShape.circle),
                    child: Center(
                      child: Text('${i + 1}',
                          style: GoogleFonts.hindSiliguri(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primaryAccent)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.value.name,
                            style: GoogleFonts.hindSiliguri(
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                        Text('${e.value.orders} টি অর্ডার',
                            style: GoogleFonts.hindSiliguri(
                                fontSize: 12,
                                color: AppTheme.textGrey)),
                      ],
                    ),
                  ),
                  Text('৳ ${_fmt.format(e.value.revenue)}',
                      style: GoogleFonts.hindSiliguri(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryAccent)),
                ]),
              ),
              if (!isLast) const Divider(height: 1),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildOrderTile(OrderModel order, bool isDark) {
    final cardBg = isDark ? AppTheme.darkCard : Colors.white;
    final statusColor = order.status == 'delivered'
        ? AppTheme.success
        : order.status == 'cancelled'
            ? AppTheme.error
            : order.status == 'confirmed'
                ? const Color(0xFF1565C0)
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
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12)),
          child: Icon(Icons.receipt_long_rounded,
              color: statusColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(order.customerName,
                  style: GoogleFonts.hindSiliguri(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              Text(
                  'SR: ${order.srName} · ${order.items.length} আইটেম',
                  style: GoogleFonts.hindSiliguri(
                      fontSize: 12, color: AppTheme.textGrey)),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('৳ ${_fmt.format(order.total)}',
                style: GoogleFonts.hindSiliguri(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryAccent)),
            const SizedBox(height: 3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20)),
              child: Text(order.statusLabel,
                  style: GoogleFonts.hindSiliguri(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: statusColor)),
            ),
          ],
        ),
      ]),
    );
  }
}

class _SRStats {
  final String name;
  double revenue;
  int orders;
  _SRStats({required this.name, this.revenue = 0, this.orders = 0});
}
