import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../models/user_model.dart';
import '../../services/local_storage_service.dart';

class CustomerSettingsScreen extends StatefulWidget {
  final ValueChanged<bool> onThemeToggle;
  const CustomerSettingsScreen({super.key, required this.onThemeToggle});

  @override
  State<CustomerSettingsScreen> createState() => _CustomerSettingsScreenState();
}

class _CustomerSettingsScreenState extends State<CustomerSettingsScreen> {
  UserModel? _user;
  bool _loading = true;
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = await LocalStorageService.getCurrentUser();
    final dark = await LocalStorageService.isDarkMode();
    if (!mounted) return;
    setState(() {
      _user = user;
      _isDarkMode = dark;
      _loading = false;
    });
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Logout',
            style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to log out?',
            style: GoogleFonts.hindSiliguri(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('No',
                style: GoogleFonts.hindSiliguri(color: AppTheme.textGrey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryAccent),
            child: Text('Yes, Logout',
                style: GoogleFonts.hindSiliguri(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await LocalStorageService.logout();
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppTheme.darkCard : Colors.white;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryAccent))
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildHeader(isDark)),
                SliverToBoxAdapter(child: _buildProfileCard(cardBg, isDark)),
                SliverToBoxAdapter(child: _buildSection(cardBg, isDark)),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
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
      child: Row(children: [
        const Icon(Icons.settings_rounded, color: Colors.white, size: 24),
        const SizedBox(width: 10),
        Text('Settings',
            style: GoogleFonts.hindSiliguri(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white)),
      ]),
    );
  }

  Widget _buildProfileCard(Color bg, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                blurRadius: 8)
          ],
        ),
        child: Row(children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
                color: AppTheme.primaryAccent.withValues(alpha: 0.1),
                shape: BoxShape.circle),
            child: const Icon(Icons.storefront_rounded,
                color: AppTheme.primaryAccent, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_user?.name ?? 'Customer',
                    style: GoogleFonts.hindSiliguri(
                        fontSize: 16, fontWeight: FontWeight.w700)),
                Text(_user?.email ?? '',
                    style: GoogleFonts.hindSiliguri(
                        fontSize: 13, color: AppTheme.textGrey)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                      color: AppTheme.primaryAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text('Customer Portal',
                      style: GoogleFonts.hindSiliguri(
                          fontSize: 11,
                          color: AppTheme.primaryAccent,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildSection(Color bg, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                blurRadius: 8)
          ],
        ),
        child: Column(children: [
          _tile(
            Icons.dark_mode_rounded,
            'Dark Mode',
            trailing: Switch(
              value: _isDarkMode,
              onChanged: (val) async {
                setState(() => _isDarkMode = val);
                await LocalStorageService.setDarkMode(val);
                widget.onThemeToggle(val);
              },
              activeColor: AppTheme.primaryAccent,
            ),
          ),
          const Divider(height: 1),
          _tile(Icons.notifications_outlined, 'Notifications',
              onTap: () =>
                  Navigator.pushNamed(context, '/notifications')),
          const Divider(height: 1),
          _tile(Icons.support_agent_rounded, 'Support',
              onTap: () => Navigator.pushNamed(context, '/support')),
          const Divider(height: 1),
          _tile(Icons.logout_rounded, 'Logout',
              color: AppTheme.error, onTap: _logout),
        ]),
      ),
    );
  }

  Widget _tile(IconData icon, String label,
      {VoidCallback? onTap, Color? color, Widget? trailing}) {
    final c = color ?? AppTheme.primaryAccent;
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
            color: c.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: c, size: 18),
      ),
      title: Text(label,
          style: GoogleFonts.hindSiliguri(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: color)),
      trailing: trailing ??
          const Icon(Icons.arrow_forward_ios_rounded,
              size: 14, color: AppTheme.textGrey),
      onTap: onTap,
    );
  }
}
