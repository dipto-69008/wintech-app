import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../models/order_model.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../services/local_storage_service.dart';
import 'order_detail_screen.dart';

class OrderListScreen extends StatefulWidget {
  const OrderListScreen({super.key});

  @override
  State<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends State<OrderListScreen> {
  UserModel? _user;
  List<OrderModel> _orders = [];
  bool _loading = true;
  String _filter = 'all'; // all | today | month

  final _fmt = NumberFormat('#,##0', 'en_US');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final user = await LocalStorageService.getCurrentUser();

    // 1) Try live ERP orders first (real-time from ERP database).
    if (await ApiService.isConnected) {
      try {
        final erpOrders =
            await ApiService.orders(mineOnly: !(user?.isAdmin ?? false));
        if (!mounted) return;
        setState(() {
          _user = user;
          _orders = erpOrders.map(_erpToOrderModel).toList();
          _loading = false;
        });
        return;
      } catch (_) {
        // ERP unreachable — fall back to local orders below
      }
    }

    // 2) Offline / demo fallback
    final orders = await LocalStorageService.getOrders();
    if (!mounted) return;
    setState(() {
      _user = user;
      // Show all orders if admin, else only this SR's orders
      _orders = (user?.isAdmin ?? false)
          ? orders
          : orders.where((o) => o.srId == (user?.id ?? '')).toList();
      _loading = false;
    });
  }

  /// Map an ERP SaleMaster (+items) document to the local OrderModel.
  OrderModel _erpToOrderModel(Map<String, dynamic> m) {
    final items = (m['items'] as List? ?? [])
        .map((d) {
          final productName = d['productName']?.toString() ?? '';
          final packSize = d['packSize']?.toString() ?? '';
          final displayName = packSize.isNotEmpty &&
                  !productName.toLowerCase().endsWith(packSize.toLowerCase())
              ? '$productName $packSize'
              : productName;
          return OrderItem(
              productName: displayName,
              quantity: (d['quantity'] as num?)?.toDouble() ?? 0,
              unit: 'Pcs',
              unitPrice: (d['rate'] as num?)?.toDouble() ?? 0,
              isBonus: d['isBonus'] == true,
            );
        })
        .toList();
    // ERP status 'a' (active) → confirmed
    final erpStatus = m['status']?.toString() ?? 'a';
    final status = erpStatus == 'a'
        ? OrderModel.statusConfirmed
        : (erpStatus == 'cancelled'
            ? OrderModel.statusCancelled
            : erpStatus);
    return OrderModel(
      id: m['invoiceNo']?.toString() ?? m['_id']?.toString() ?? '',
      srId: _user?.id ?? '',
      srName: m['addBy']?.toString() ?? '',
      customerId: m['partyId']?.toString() ?? '',
      customerName: m['partyName']?.toString() ?? '',
      items: items,
      total: (m['totalAmount'] as num?)?.toDouble() ?? 0,
      date: DateTime.tryParse(m['saleDate']?.toString() ?? '') ?? DateTime.now(),
      status: status,
      notes: m['description']?.toString() ?? '',
      probablePaymentDate:
          DateTime.tryParse(m['probablePaymentDate']?.toString() ?? ''),
      paidAmount: (m['paidAmount'] as num?)?.toDouble() ?? 0,
      paymentType: m['paymentType']?.toString() ?? 'Cash',
      commissionPct: (m['commissionPct'] as num?)?.toDouble() ?? 0,
    );
  }

  List<OrderModel> get _filtered {
    final now = DateTime.now();
    return _orders.where((o) {
      if (_filter == 'today') {
        return o.date.year == now.year &&
            o.date.month == now.month &&
            o.date.day == now.day;
      } else if (_filter == 'month') {
        return o.date.year == now.year && o.date.month == now.month;
      }
      return true;
    }).toList();
  }

  double get _filteredTotal =>
      _filtered.where((o) => o.status != OrderModel.statusCancelled)
          .fold(0.0, (s, o) => s + o.total);

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
                        (ctx, i) => _buildOrderTile(_filtered[i], isDark),
                        childCount: _filtered.length,
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            Navigator.pushNamed(context, '/pos-order').then((_) => _load()),
        backgroundColor: AppTheme.primaryAccent,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('New Order',
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
        const Icon(Icons.receipt_long_rounded,
            color: Colors.white, size: 24),
        const SizedBox(width: 10),
        Text('Order List',
            style: GoogleFonts.hindSiliguri(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white)),
        const Spacer(),
        Text('Total: ${_orders.length}',
            style: GoogleFonts.hindSiliguri(
                fontSize: 13, color: Colors.white70)),
      ]),
    );
  }

  Widget _buildFilters(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(children: [
        _filterChip('all', 'All', isDark),
        const SizedBox(width: 8),
        _filterChip('today', 'Today', isDark),
        const SizedBox(width: 8),
        _filterChip('month', 'This Month', isDark),
      ]),
    );
  }

  Widget _filterChip(String val, String label, bool isDark) {
    final selected = _filter == val;
    return GestureDetector(
      onTap: () => setState(() => _filter = val),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primaryAccent
              : (isDark ? AppTheme.darkCard : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected
                  ? AppTheme.primaryAccent
                  : AppTheme.divider),
        ),
        child: Text(label,
            style: GoogleFonts.hindSiliguri(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected
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
          border: Border.all(
              color: AppTheme.primaryAccent.withValues(alpha: 0.2)),
        ),
        child: Row(children: [
          const Icon(Icons.payments_rounded,
              color: AppTheme.primaryAccent, size: 18),
          const SizedBox(width: 8),
          Text('${_filtered.length} order(s) · ',
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
          Icon(Icons.receipt_long_rounded,
              size: 64,
              color: isDark ? AppTheme.darkTextGrey : AppTheme.divider),
          const SizedBox(height: 14),
          Text('No orders found',
              style: GoogleFonts.hindSiliguri(
                  fontSize: 15, color: AppTheme.textGrey)),
          const SizedBox(height: 6),
          Text('Tap + to place a new order',
              style: GoogleFonts.hindSiliguri(
                  fontSize: 12, color: AppTheme.textGrey)),
        ]),
      ),
    );
  }

  Widget _buildOrderTile(OrderModel order, bool isDark) {
    final cardBg = isDark ? AppTheme.darkCard : Colors.white;
    final productCount = order.items.where((item) => !item.isBonus).length;
    final bonusCount = order.items.where((item) => item.isBonus).length;
    final itemLabel = '$productCount item(s)'
        '${bonusCount > 0 ? ' + $bonusCount bonus' : ''}';
    final statusColor = order.status == 'delivered'
        ? AppTheme.success
        : order.status == 'cancelled'
            ? AppTheme.error
            : order.status == 'confirmed'
                ? const Color(0xFF1565C0)
                : AppTheme.warning;

    return GestureDetector(
      onTap: () async {
        final updated = await Navigator.pushNamed(
          context,
          '/order-detail',
          arguments: order,
        );
        if (updated is OrderModel) {
          setState(() {
            final idx = _orders.indexWhere((o) => o.id == updated.id);
            if (idx != -1) _orders[idx] = updated;
          });
        }
      },
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
                  '${order.date.day}/${order.date.month}/${order.date.year} · $itemLabel',
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
    ),   // closes Container
    );   // closes GestureDetector
  }
}
