import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../models/user_model.dart';
import '../../services/local_storage_service.dart';
import 'stock_transfer_screen.dart';
import 'expense_screen.dart';
import 'payment_collection_screen.dart';
import 'return_products_screen.dart';
import 'leave_screen.dart';
import '../survey/survey_screen.dart';

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  UserModel? _user;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await LocalStorageService.getCurrentUser();
    if (!mounted) return;
    setState(() => _user = user);
  }

  static const _modules = [
    _ModuleDef(
      title: 'Stock Transfer',
      subtitle: 'Transfer products between warehouses',
      icon: Icons.swap_horiz_rounded,
      color: AppTheme.primaryAccent,
      tag: 'stock',
    ),
    _ModuleDef(
      title: 'Expense / TA-DA',
      subtitle: 'TA bill, DA, motorcycle log, out station',
      icon: Icons.receipt_rounded,
      color: Color(0xFF6A1B9A),
      tag: 'expense',
    ),
    _ModuleDef(
      title: 'Payment Collection',
      subtitle: 'Collect payments from customers',
      icon: Icons.payments_rounded,
      color: Color(0xFF2E7D32),
      tag: 'payment',
    ),
    _ModuleDef(
      title: 'Return Products',
      subtitle: 'Create ERP sales return invoices',
      icon: Icons.assignment_return_rounded,
      color: Color(0xFFB45309),
      tag: 'return',
    ),
    _ModuleDef(
      title: 'Leave Application',
      subtitle: 'Casual, medical, annual leave',
      icon: Icons.beach_access_rounded,
      color: Color(0xFFE65100),
      tag: 'leave',
    ),
    _ModuleDef(
      title: 'Survey',
      subtitle: 'Create field-level surveys',
      icon: Icons.assignment_rounded,
      color: Color(0xFF1565C0),
      tag: 'survey',
    ),
  ];

  void _navigate(String tag) {
    Widget screen;
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
        return;
    }
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(isDark)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => _buildCard(_modules[i], isDark),
                childCount: _modules.length,
              ),
            ),
          ),
        ],
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.grid_view_rounded, color: Colors.white, size: 22),
          const SizedBox(width: 10),
          Text('More Modules',
              style: GoogleFonts.hindSiliguri(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
        ]),
        const SizedBox(height: 6),
        Text('All features in one place',
            style: GoogleFonts.hindSiliguri(
                fontSize: 13, color: Colors.white70)),
        if (_user != null) ...[
          const SizedBox(height: 10),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.person_rounded,
                  size: 14, color: Colors.white70),
              const SizedBox(width: 6),
              Text(_user!.name,
                  style: GoogleFonts.hindSiliguri(
                      fontSize: 12, color: Colors.white70)),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _buildCard(_ModuleDef mod, bool isDark) {
    final cardBg = isDark ? AppTheme.darkCard : Colors.white;
    return GestureDetector(
      onTap: () => _navigate(mod.tag),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.05),
                blurRadius: 6)
          ],
        ),
        child: Row(children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: mod.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(mod.icon, color: mod.color, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(mod.title,
                      style: GoogleFonts.hindSiliguri(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppTheme.darkText : AppTheme.textDark)),
                  const SizedBox(height: 3),
                  Text(mod.subtitle,
                      style: GoogleFonts.hindSiliguri(
                          fontSize: 12,
                          color: isDark
                              ? AppTheme.darkTextGrey
                              : AppTheme.textGrey)),
                ]),
          ),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: mod.color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.chevron_right_rounded,
                color: mod.color, size: 20),
          ),
        ]),
      ),
    );
  }
}

class _ModuleDef {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String tag;
  const _ModuleDef(
      {required this.title,
      required this.subtitle,
      required this.icon,
      required this.color,
      required this.tag});
}
