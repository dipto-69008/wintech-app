import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'config/theme.dart';
import 'models/user_model.dart';
import 'services/api_service.dart';
import 'services/local_storage_service.dart';
import 'services/offline_queue_service.dart';
import 'services/sync_refresh_service.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/admin/all_employees_screen.dart';
import 'screens/employee/employee_dashboard_screen.dart';
import 'screens/employee/target_achievement_screen.dart';
import 'screens/employee/more_screen.dart';
import 'screens/employee/stock_transfer_screen.dart';
import 'screens/employee/expense_screen.dart';
import 'screens/employee/payment_collection_screen.dart';
import 'screens/employee/return_products_screen.dart';
import 'screens/employee/leave_screen.dart';
import 'screens/employee/survey/survey_screen.dart';
import 'screens/customer/customer_dashboard_screen.dart';
import 'screens/customer/customer_settings_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/employee/order_list_screen.dart';
import 'screens/notifications/notification_screen.dart';

class HomeShell extends StatefulWidget {
  final ValueChanged<bool> onThemeToggle;
  const HomeShell({super.key, required this.onThemeToggle});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _currentIndex = 0;
  UserModel? _user;
  bool _loadingUser = true;
  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUser();
    _startAutoSync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _syncTimer?.cancel();
    super.dispose();
  }

  /// Real-time link: on start, on app-resume, and every 5 seconds —
  /// ping the ERP and push any offline items immediately.
  void _startAutoSync() {
    _runSync();
    _syncTimer =
        Timer.periodic(const Duration(seconds: 5), (_) => _runSync());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _runSync();
  }

  Future<void> _runSync() async {
    try {
      // Fresh reachability check so screens see the real live status.
      final live = await ApiService.ping(force: true);
      if (!live) return;
      final result = await OfflineQueueService.syncAll();
      SyncRefreshService.notify();
      if (result.synced > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '🔄 ${result.synced} offline item(s) synced to ERP',
              style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600)),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } catch (_) {}
  }

  Future<void> _loadUser() async {
    final user = await LocalStorageService.getCurrentUser();
    if (!mounted) return;
    setState(() {
      _user = user;
      _loadingUser = false;
    });
  }

  void _switchTab(int index) {
    setState(() => _currentIndex = index);
    SyncRefreshService.notify(force: true);
  }

  void _openEmployeeTool(String tag) {
    final Widget? screen;
    switch (tag) {
      case 'stock':
        screen = const StockTransferScreen();
        break;
      case 'expense':
        screen = const ExpenseScreen();
        break;
      case 'payment':
        screen = const PaymentCollectionScreen();
        break;
      case 'return':
        screen = const ReturnProductsScreen();
        break;
      case 'leave':
        screen = const LeaveScreen();
        break;
      case 'survey':
        screen = const SurveyScreen();
        break;
      default:
        screen = null;
    }
    if (screen != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen!));
    }
  }

  // ── Admin (3 tabs) ────────────────────────────────────────────────────
  List<Widget> get _adminPages => [
        const AdminDashboardScreen(),
        const AllEmployeesScreen(),
        SettingsScreen(onThemeToggle: widget.onThemeToggle),
      ];

  static const _adminNavItems = [
    _NavDef(Icons.analytics_rounded, 'Reports'),
    _NavDef(Icons.badge_rounded, 'SR List'),
    _NavDef(Icons.settings_rounded, 'Settings'),
  ];

  // ── Employee / SR (5 tabs) ────────────────────────────────────────────
  List<Widget> get _srPages => [
        EmployeeDashboardScreen(
          onGoToOrders: () => _switchTab(1),
          onGoToTargets: () => _switchTab(2),
          onGoToMore: () => _switchTab(3),
          onGoToTool: _openEmployeeTool,
        ),
        const OrderListScreen(),
        const TargetAchievementScreen(),
        const MoreScreen(),
        SettingsScreen(onThemeToggle: widget.onThemeToggle),
      ];

  static const _srNavItems = [
    _NavDef(Icons.dashboard_rounded, 'Dashboard'),
    _NavDef(Icons.receipt_long_rounded, 'Orders'),
    _NavDef(Icons.flag_rounded, 'Target'),
    _NavDef(Icons.grid_view_rounded, 'More'),
    _NavDef(Icons.settings_rounded, 'Settings'),
  ];

  // ── Customer (3 tabs) ─────────────────────────────────────────────────
  List<Widget> get _customerPages => [
        const CustomerDashboardScreen(),
        const NotificationScreen(),
        CustomerSettingsScreen(onThemeToggle: widget.onThemeToggle),
      ];

  static const _customerNavItems = [
    _NavDef(Icons.dashboard_rounded, 'Dashboard'),
    _NavDef(Icons.campaign_rounded, 'Notices'),
    _NavDef(Icons.settings_rounded, 'Settings'),
  ];

  bool get _isAdmin => _user?.isAdmin ?? false;
  bool get _isCustomer => _user?.isCustomer ?? false;

  List<Widget> get _pages =>
      _isAdmin ? _adminPages : (_isCustomer ? _customerPages : _srPages);

  List<_NavDef> get _navItems =>
      _isAdmin ? _adminNavItems : (_isCustomer ? _customerNavItems : _srNavItems);

  @override
  Widget build(BuildContext context) {
    if (_loadingUser) {
      return const Scaffold(
        body: Center(
            child: CircularProgressIndicator(color: AppTheme.primaryAccent)),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBg = isDark ? AppTheme.darkCard : Colors.white;

    // Clamp index if switching between roles
    final safeIndex = _currentIndex.clamp(0, _pages.length - 1);

    return Scaffold(
      body: IndexedStack(index: safeIndex, children: _pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: navBg,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_navItems.length, (i) {
                final item = _navItems[i];
                final sel = safeIndex == i;
                return _NavItem(
                  icon: item.icon,
                  label: item.label,
                  selected: sel,
                  selectedColor: AppTheme.primaryAccent,
                  unselectedColor:
                      isDark ? AppTheme.darkTextGrey : AppTheme.textGrey,
                   onTap: () => _switchTab(i),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavDef {
  final IconData icon;
  final String label;
  const _NavDef(this.icon, this.label);
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final Color selectedColor;
  final Color unselectedColor;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.unselectedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? selectedColor.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 22, color: selected ? selectedColor : unselectedColor),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.hindSiliguri(
                fontSize: 9,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                color: selected ? selectedColor : unselectedColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
