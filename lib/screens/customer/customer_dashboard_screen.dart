import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../models/order_model.dart';
import '../../models/user_model.dart';
import '../../services/local_storage_service.dart';
import '../../services/sync_refresh_service.dart';

class CustomerDashboardScreen extends StatefulWidget {
  const CustomerDashboardScreen({super.key});

  @override
  State<CustomerDashboardScreen> createState() =>
      _CustomerDashboardScreenState();
}

class _CustomerDashboardScreenState extends State<CustomerDashboardScreen> {
  UserModel? _user;
  List<OrderModel> _orders = [];
  bool _loading = true;

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
    final user = await LocalStorageService.getCurrentUser();
    final orders = await LocalStorageService.getOrders();
    if (!mounted) return;
    setState(() {
      _user = user;
      // Customer sees only their orders
      _orders = orders
          .where((o) => o.customerId == (user?.id ?? ''))
          .toList();
      _loading = false;
    });
  }

  List<OrderModel> get _thisMonthOrders {
    final now = DateTime.now();
    return _orders.where((o) =>
        o.date.year == now.year &&
        o.date.month == now.month &&
        o.status != OrderModel.statusCancelled).toList();
  }

  double get _thisMonthTotal =>
      _thisMonthOrders.fold(0.0, (s, o) => s + o.total);

  double get _creditLimit => _user?.creditLimit ?? 500000;
  double get _creditUsed => _user?.creditUsed ?? 0;
  double get _creditAvailable => (_creditLimit - _creditUsed).clamp(0, double.infinity);
  double get _creditPercent =>
      _creditLimit > 0 ? (_creditUsed / _creditLimit).clamp(0.0, 1.0) : 0;

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
                  SliverToBoxAdapter(child: _buildCreditCard(isDark)),
                  SliverToBoxAdapter(child: _buildMonthStats(isDark)),
                  SliverToBoxAdapter(child: _buildSectionTitle('This Month Purchases', isDark)),
                  if (_thisMonthOrders.isEmpty)
                    SliverToBoxAdapter(child: _buildEmpty(isDark))
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) =>
                            _buildOrderTile(_thisMonthOrders[i], isDark),
                        childCount: _thisMonthOrders.length,
                      ),
                    ),
                  if (_orders.isNotEmpty &&
                      _orders.length > _thisMonthOrders.length) ...[
                    SliverToBoxAdapter(
                        child: _buildSectionTitle('Previous Orders', isDark)),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) {
                          final prev = _orders
                              .where((o) => !_thisMonthOrders.contains(o))
                              .toList();
                          return _buildOrderTile(prev[i], isDark);
                        },
                        childCount: _orders
                            .where((o) => !_thisMonthOrders.contains(o))
                            .length,
                      ),
                    ),
                  ],
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
          child: const Icon(Icons.storefront_rounded,
              color: Colors.white, size: 26),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$greet, ${_user?.name ?? 'Customer'}! 👋',
                  style: GoogleFonts.hindSiliguri(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6)),
                child: Text('Wintech Agro — Customer Portal',
                    style: GoogleFonts.hindSiliguri(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.w600)),
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

  Widget _buildCreditCard(bool isDark) {
    final creditColor = _creditPercent >= 0.9
        ? AppTheme.error
        : _creditPercent >= 0.75
            ? AppTheme.warning
            : AppTheme.success;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Container(
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
            Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.account_balance_wallet_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Credit Limit',
                        style: GoogleFonts.hindSiliguri(
                            fontSize: 12, color: Colors.white70)),
                    Text('৳ ${_fmt.format(_creditLimit)}',
                        style: GoogleFonts.hindSiliguri(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(
                    '${(_creditPercent * 100).toStringAsFixed(0)}% Used',
                    style: GoogleFonts.hindSiliguri(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.w600)),
              ),
            ]),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _creditPercent,
                minHeight: 10,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation(
                    _creditPercent >= 0.9 ? Colors.red[200]! : Colors.white),
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              _creditChip(Icons.check_circle_rounded,
                  'Available: ৳${_fmt.format(_creditAvailable)}'),
              const SizedBox(width: 10),
              _creditChip(Icons.payment_rounded,
                  'Used: ৳${_fmt.format(_creditUsed)}'),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _creditChip(IconData icon, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: Colors.white, size: 13),
          const SizedBox(width: 5),
          Flexible(
            child: Text(label,
                style: GoogleFonts.hindSiliguri(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
          ),
        ]),
      ),
    );
  }

  Widget _buildMonthStats(bool isDark) {
    final cardBg = isDark ? AppTheme.darkCard : Colors.white;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(children: [
        Expanded(
            child: _statCard(cardBg, 'Orders This Month',
                '${_thisMonthOrders.length}', Icons.receipt_long_rounded,
                AppTheme.primaryAccent, isDark)),
        const SizedBox(width: 10),
        Expanded(
            child: _statCard(cardBg, 'Purchases This Month',
                '৳${_fmt.format(_thisMonthTotal)}', Icons.shopping_cart_rounded,
                AppTheme.success, isDark)),
        const SizedBox(width: 10),
        Expanded(
            child: _statCard(cardBg, 'Total Orders',
                '${_orders.length}', Icons.history_rounded,
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
                  color:
                      isDark ? AppTheme.darkTextGrey : AppTheme.textGrey)),
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

  Widget _buildEmpty(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(children: [
          Icon(Icons.shopping_cart_outlined,
              size: 60,
              color: isDark ? AppTheme.darkTextGrey : AppTheme.divider),
          const SizedBox(height: 12),
          Text('No purchases this month',
              style: GoogleFonts.hindSiliguri(
                  fontSize: 14, color: AppTheme.textGrey)),
        ]),
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
        border: Border.all(
            color: statusColor.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
              blurRadius: 4)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
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
                  Text('Order #${order.id.split('-').last}',
                      style: GoogleFonts.hindSiliguri(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                  Text(
                      '${order.date.day}/${order.date.month}/${order.date.year} · ${order.items.length} Items',
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
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryAccent)),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
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
          if (order.items.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            ...order.items.take(3).map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(children: [
                    const Icon(Icons.inventory_2_rounded,
                        size: 14, color: AppTheme.textGrey),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                          '${item.productName} × ${item.quantity} ${item.unit}',
                          style: GoogleFonts.hindSiliguri(
                              fontSize: 12, color: AppTheme.textGrey)),
                    ),
                    Text('৳${_fmt.format(item.total)}',
                        style: GoogleFonts.hindSiliguri(
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ]),
                )),
            if (order.items.length > 3)
              Text('+${order.items.length - 3} more items',
                  style: GoogleFonts.hindSiliguri(
                      fontSize: 11, color: AppTheme.textGrey)),
          ],
        ],
      ),
    );
  }
}
