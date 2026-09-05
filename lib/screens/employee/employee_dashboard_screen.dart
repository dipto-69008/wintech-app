import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../models/order_model.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../services/local_storage_service.dart';
import '../../services/sync_refresh_service.dart';

class EmployeeDashboardScreen extends StatefulWidget {
  final VoidCallback? onGoToOrders;
  final VoidCallback? onGoToTargets;
  final VoidCallback? onGoToMore;
  final ValueChanged<String>? onGoToTool;
  const EmployeeDashboardScreen(
      {super.key,
      this.onGoToOrders,
      this.onGoToTargets,
      this.onGoToMore,
      this.onGoToTool});

  @override
  State<EmployeeDashboardScreen> createState() =>
      _EmployeeDashboardScreenState();
}

class _EmployeeDashboardScreenState extends State<EmployeeDashboardScreen> {
  UserModel? _user;
  List<OrderModel> _orders = [];
  bool _loading = true;

  // Live ERP figures
  bool _erpConnected = false;
  double _erpTodaySales = 0;
  double _erpMonthSales = 0;
  int _erpTodayOrders = 0;
  int _erpMonthOrders = 0;
  double _erpTargetValue = 0;
  double _erpCurrentValue = 0;
  double _erpIncentiveEarned = 0;
  double _erpCommissionPercent = 0;
  double _erpCollectionAmount = 0;
  double _erpCollectionPercent = 0;

  final _fmt = NumberFormat('#,##0', 'en_US');
  @override
  void initState() {
    super.initState();
    SyncRefreshService.revision.addListener(_refreshFromSync);
    _load();
  }

  void _refreshFromSync() {
    if (mounted) _load(silent: true);
  }

  @override
  void dispose() {
    SyncRefreshService.revision.removeListener(_refreshFromSync);
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    final user = await LocalStorageService.getCurrentUser();
    List<OrderModel>? liveOrders;

    // Pull live dashboard stats from ERP when connected
    if (await ApiService.isConnected) {
      try {
        final dash = await ApiService.dashboard();
        final erpOrders =
            await ApiService.orders(mineOnly: !(user?.isAdmin ?? false));
        final today = dash['today'] as Map<String, dynamic>? ?? {};
        final thisMonth = dash['thisMonth'] as Map<String, dynamic>? ?? {};
        final targets = (dash['targets'] as List? ?? []);
        liveOrders =
            erpOrders.map((order) => _erpToOrderModel(order, user)).toList();
        if (mounted) {
          _user = user;
          _erpConnected = true;
          _erpTodaySales = (today['salesAmount'] as num?)?.toDouble() ?? 0;
          _erpTodayOrders = (today['orders'] as num?)?.toInt() ?? 0;
          _erpMonthSales = (thisMonth['salesAmount'] as num?)?.toDouble() ?? 0;
          _erpMonthOrders = (thisMonth['orders'] as num?)?.toInt() ?? 0;
          _erpIncentiveEarned =
              (thisMonth['incentiveEarned'] as num?)?.toDouble() ?? 0;
          _erpCommissionPercent =
              (thisMonth['commissionPercent'] as num?)?.toDouble() ?? 0;
          _erpCollectionAmount =
              (thisMonth['collectionAmount'] as num?)?.toDouble() ?? 0;
          _erpCollectionPercent =
              (thisMonth['collectionPercent'] as num?)?.toDouble() ?? 0;
          if (targets.isNotEmpty) {
            final t = targets.first as Map<String, dynamic>;
            _erpTargetValue = (t['targetValue'] as num?)?.toDouble() ?? 0;
            _erpCurrentValue = (t['currentValue'] as num?)?.toDouble() ?? 0;
          }
        }
      } catch (_) {
        // ERP unreachable right now — show as offline until it responds.
        _erpConnected = false;
      }
    } else {
      _erpConnected = false;
    }

    // Use the same live ERP order source as Order List. Only use local data
    // when the ERP is unavailable, so ERP-deleted orders disappear here too.
    final orders = liveOrders ?? await LocalStorageService.getOrders();
    if (!mounted) return;
    setState(() {
      _user = user;
      _orders = liveOrders ??
          orders.where((o) => o.srId == (user?.id ?? '')).toList();
      _loading = false;
    });
  }

  /// Map a live ERP SaleMaster (+items) document to the dashboard model.
  OrderModel _erpToOrderModel(
      Map<String, dynamic> m, UserModel? currentUser) {
    final items = (m['items'] as List? ?? [])
        .map((d) {
          final item = Map<String, dynamic>.from(d as Map);
          final productName = item['productName']?.toString() ?? '';
          final packSize = item['packSize']?.toString() ?? '';
          final displayName = packSize.isNotEmpty &&
                  !productName.toLowerCase().endsWith(packSize.toLowerCase())
              ? '$productName $packSize'
              : productName;
          final rate = (item['rate'] as num?)?.toDouble() ?? 0;
          return OrderItem(
            productName: displayName,
            quantity: (item['quantity'] as num?)?.toDouble() ?? 0,
            unit: 'Pcs',
            unitPrice: rate,
            isBonus: item['isBonus'] == true ||
                (rate == 0 &&
                    productName.toLowerCase().contains('(bonus)')),
          );
        })
        .toList();
    final erpStatus = m['status']?.toString() ?? 'a';
    final status = erpStatus == 'a'
        ? OrderModel.statusConfirmed
        : (erpStatus == 'cancelled'
            ? OrderModel.statusCancelled
            : erpStatus);
    return OrderModel(
      id: m['invoiceNo']?.toString() ?? m['_id']?.toString() ?? '',
      srId: currentUser?.id ?? '',
      srName: m['addBy']?.toString() ?? '',
      customerId: m['partyId']?.toString() ?? '',
      customerName: m['partyName']?.toString() ?? '',
      items: items,
      total: (m['totalAmount'] as num?)?.toDouble() ?? 0,
      date: DateTime.tryParse(m['saleDate']?.toString() ?? '') ??
          DateTime.now(),
      status: status,
      notes: m['description']?.toString() ?? '',
      probablePaymentDate:
          DateTime.tryParse(m['probablePaymentDate']?.toString() ?? ''),
      paidAmount: (m['paidAmount'] as num?)?.toDouble() ?? 0,
      mobileCollectedAmount:
          (m['mobileCollectedAmount'] as num?)?.toDouble() ?? 0,
      paymentType: m['paymentType']?.toString() ?? 'Cash',
      commissionPct: (m['commissionPct'] as num?)?.toDouble() ?? 0,
    );
  }

  List<OrderModel> get _todayOrders {
    final now = DateTime.now();
    return _orders
        .where((o) =>
            o.date.year == now.year &&
            o.date.month == now.month &&
            o.date.day == now.day &&
            o.status != OrderModel.statusCancelled)
        .toList();
  }

  List<OrderModel> get _monthOrders {
    final now = DateTime.now();
    return _orders
        .where((o) =>
            o.date.year == now.year &&
            o.date.month == now.month &&
            o.status != OrderModel.statusCancelled)
        .toList();
  }

  double get _todayRevenue =>
      _erpConnected ? _erpTodaySales : _todayOrders.fold(0.0, (s, o) => s + o.total);
  double get _monthRevenue =>
      _erpConnected ? _erpMonthSales : _monthOrders.fold(0.0, (s, o) => s + o.total);
  int get _todayOrderCount =>
      _erpConnected ? _erpTodayOrders : _todayOrders.length;
  int get _monthOrderCount =>
      _erpConnected ? _erpMonthOrders : _monthOrders.length;
  double get _targetValue =>
      _erpConnected ? _erpTargetValue : 0;
  double get _achievedValue =>
      _erpConnected && _erpCurrentValue > 0 ? _erpCurrentValue : _monthRevenue;

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
                  SliverToBoxAdapter(child: _buildTodayStats(isDark)),
                  SliverToBoxAdapter(child: _buildQuickActions(isDark)),
                   SliverToBoxAdapter(child: _buildMoreToolsCard(isDark)),
                  SliverToBoxAdapter(child: _buildSectionTitle('Recent Orders', isDark)),
                  if (_orders.isEmpty)
                    SliverToBoxAdapter(child: _buildEmpty(isDark))
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => _buildOrderTile(_orders[i], isDark),
                        childCount: _orders.take(10).length,
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
    final greet = hour < 12
        ? 'Good Morning'
        : hour < 17
            ? 'Good Afternoon'
            : 'Good Evening';
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
      child: Row(children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.person_rounded,
              color: Colors.white, size: 26),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$greet, ${_user?.name ?? 'SR'}! 👋',
                  style: GoogleFonts.hindSiliguri(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
               Container(
                 margin: const EdgeInsets.only(top: 4),
                 padding: const EdgeInsets.symmetric(
                     horizontal: 10, vertical: 4),
                 decoration: BoxDecoration(
                     color: Colors.white.withValues(alpha: 0.2),
                     borderRadius: BorderRadius.circular(6)),
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Text(
                         _user?.designation.isNotEmpty == true
                             ? _user!.designation
                             : 'Sales Representative',
                         style: GoogleFonts.hindSiliguri(
                             fontSize: 11,
                             color: Colors.white,
                             fontWeight: FontWeight.w700)),
                     if (_user?.branch.isNotEmpty == true)
                       Text('Zone: ${_user!.zoneName.isNotEmpty ? _user!.zoneName : '—'}  •  Area: ${_user!.areaName.isNotEmpty ? _user!.areaName : _user!.branch}',
                           style: GoogleFonts.hindSiliguri(
                               fontSize: 10,
                               color: Colors.white.withValues(alpha: 0.9),
                               fontWeight: FontWeight.w500)),
                   ],
                 ),
               ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/notifications'),
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12)),
            child: Stack(children: [
              const Center(
                  child: Icon(Icons.notifications_none_rounded,
                      color: Colors.white, size: 26)),
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                        color: Color(0xFFF57F17),
                        shape: BoxShape.circle)),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildTargetCard(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(18),
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
            Row(children: [
              const Icon(Icons.flag_rounded, color: Colors.white70, size: 18),
              const SizedBox(width: 8),
               Text('Achieved Incentive',
                  style: GoogleFonts.hindSiliguri(
                      fontSize: 13, color: Colors.white70)),
              const Spacer(),
               Text('৳${_fmt.format(_erpIncentiveEarned)}',
                  style: GoogleFonts.hindSiliguri(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
            ]),
             const SizedBox(height: 12),
               Text(_erpConnected
                   ? (_targetValue > 0
                         ? 'Target: ৳${_fmt.format(_targetValue)}  •  Collection: ৳${_fmt.format(_erpCollectionAmount)} (${_erpCollectionPercent.toStringAsFixed(1)}%)  •  Commission: ${_erpCommissionPercent.toStringAsFixed(1)}%'
                       : 'Not set target yet')
                   : 'Not set target yet',
                 style: GoogleFonts.hindSiliguri(
                     fontSize: 12, color: Colors.white70)),
             if (_targetValue > 0) ...[
               const SizedBox(height: 12),
               ClipRRect(
                 borderRadius: BorderRadius.circular(8),
                 child: LinearProgressIndicator(
                   value: (_achievedValue / _targetValue).clamp(0.0, 1.0),
                   minHeight: 11,
                   backgroundColor: Colors.white.withValues(alpha: 0.25),
                   valueColor: const AlwaysStoppedAnimation(Colors.white),
                 ),
               ),
               const SizedBox(height: 8),
               Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                   Text('৳${_fmt.format(_achievedValue)} achieved',
                       style: GoogleFonts.hindSiliguri(
                           fontSize: 12, color: Colors.white)),
                   Text('${((_achievedValue / _targetValue).clamp(0.0, 1.0) * 100).toStringAsFixed(1)}%',
                       style: GoogleFonts.hindSiliguri(
                           fontSize: 16, fontWeight: FontWeight.w800,
                           color: Colors.white)),
                 ],
               ),
             ],
            if (_erpConnected) ...[
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.cloud_done_rounded,
                    color: Colors.white54, size: 13),
                const SizedBox(width: 4),
                Text('ERP live data',
                    style: GoogleFonts.hindSiliguri(
                        fontSize: 11, color: Colors.white54)),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _targetChip(IconData icon, String label) {
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

  Widget _buildTodayStats(bool isDark) {
    final cardBg = isDark ? AppTheme.darkCard : Colors.white;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(children: [
        Expanded(
            child: _statCard(cardBg, "Today's Orders",
                '$_todayOrderCount', Icons.receipt_long_rounded,
                AppTheme.primaryAccent, isDark)),
        const SizedBox(width: 10),
        Expanded(
            child: _statCard(cardBg, "Today's Sales",
                '৳${_fmt.format(_todayRevenue)}',
                Icons.payments_rounded, AppTheme.success, isDark)),
        const SizedBox(width: 10),
        Expanded(
            child: _statCard(cardBg, 'Monthly Total',
                '৳${_fmt.format(_monthRevenue)}',
                Icons.bar_chart_rounded,
                const Color(0xFF1565C0), isDark)),
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
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: color)),
          Text(label,
              style: GoogleFonts.hindSiliguri(
                  fontSize: 10,
                  color: isDark ? AppTheme.darkTextGrey : AppTheme.textGrey)),
        ],
      ),
    );
  }

  Widget _buildQuickActions(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(children: [
        Expanded(
          child: GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/pos-order')
                .then((_) => _load()),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryAccent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.point_of_sale_rounded,
                    color: Colors.white, size: 22),
                const SizedBox(width: 8),
                Text('New Order (POS)',
                    style: GoogleFonts.hindSiliguri(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ]),
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: widget.onGoToTargets,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AppTheme.primaryAccent.withValues(alpha: 0.3)),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.flag_rounded,
                  color: AppTheme.primaryAccent, size: 24),
              const SizedBox(height: 4),
              Text('Target',
                  style: GoogleFonts.hindSiliguri(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryAccent)),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildMoreToolsCard(bool isDark) {
    final cardBg = isDark ? AppTheme.darkCard : Colors.white;
    const tools = [
      (Icons.swap_horiz_rounded, 'Transfer', 'stock'),
      (Icons.receipt_rounded, 'Expense', 'expense'),
      (Icons.payments_rounded, 'Payment', 'payment'),
      (Icons.assignment_return_rounded, 'Return', 'return'),
      (Icons.beach_access_rounded, 'Leave', 'leave'),
      (Icons.assignment_rounded, 'Field Visit Report', 'survey'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: AppTheme.primaryAccent.withValues(alpha: 0.18)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.grid_view_rounded,
                  color: AppTheme.primaryAccent, size: 20),
              const SizedBox(width: 8),
              Text('More Tools',
                  style: GoogleFonts.hindSiliguri(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppTheme.darkText : AppTheme.textDark)),
              const Spacer(),
              const Icon(Icons.arrow_forward_ios_rounded,
                  color: AppTheme.textGrey, size: 15),
            ]),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final tileWidth = (constraints.maxWidth - 10) / 2;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: tools.map((tool) => SizedBox(
                    width: tileWidth,
                    height: 68,
                    child: Material(
                      color: AppTheme.primaryAccent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                         onTap: widget.onGoToTool == null
                             ? widget.onGoToMore
                             : () => widget.onGoToTool!(tool.$3),
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          child: Row(children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryAccent
                                    .withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(tool.$1,
                                  size: 24, color: AppTheme.primaryAccent),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(tool.$2,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.hindSiliguri(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? AppTheme.darkText
                                          : AppTheme.textDark)),
                            ),
                          ]),
                        ),
                      ),
                    ),
                  )).toList(),
                );
              },
            ),
          ]),
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
        const Spacer(),
        if (_erpConnected)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.cloud_done_rounded,
                  size: 11, color: AppTheme.success),
              const SizedBox(width: 3),
              Text('ERP live',
                  style: GoogleFonts.hindSiliguri(
                      fontSize: 10,
                      color: AppTheme.success,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
      ]),
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(children: [
          Icon(Icons.receipt_long_rounded,
              size: 60,
              color: isDark ? AppTheme.darkTextGrey : AppTheme.divider),
          const SizedBox(height: 12),
          Text('No orders yet',
              style: GoogleFonts.hindSiliguri(
                  fontSize: 14, color: AppTheme.textGrey)),
          const SizedBox(height: 8),
          Text('Add a new order from POS',
              style: GoogleFonts.hindSiliguri(
                  fontSize: 12, color: AppTheme.textGrey)),
        ]),
      ),
    );
  }

  Widget _buildOrderTile(OrderModel order, bool isDark) {
    final cardBg = isDark ? AppTheme.darkCard : Colors.white;
    String quantityLabel(double quantity) => quantity == quantity.roundToDouble()
        ? quantity.toInt().toString()
        : quantity.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
    final itemCount = quantityLabel(order.itemQuantity);
    final bonusCount = quantityLabel(order.bonusQuantity);
    final itemLabel = '$itemCount item(s)'
        '${order.bonusQuantity > 0 ? ' + $bonusCount bonus' : ''}';
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
          child: Icon(Icons.store_rounded, color: statusColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(order.customerName,
                  style: GoogleFonts.hindSiliguri(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              Text(itemLabel,
                  style: GoogleFonts.hindSiliguri(
                      fontSize: 12, color: AppTheme.textGrey)),
               if (order.mobileCollectedAmount > 0)
                 Text(
                   'Collected: ৳ ${_fmt.format(order.mobileCollectedAmount)}',
                   style: GoogleFonts.hindSiliguri(
                       fontSize: 11,
                       fontWeight: FontWeight.w700,
                       color: AppTheme.success),
                 ),
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
