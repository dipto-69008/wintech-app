import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../services/local_storage_service.dart';
import '../../services/offline_queue_service.dart';

class SettingsScreen extends StatefulWidget {
  final ValueChanged<bool> onThemeToggle;
  const SettingsScreen({super.key, required this.onThemeToggle});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  UserModel? _user;
  bool _loading = true;
  bool _isDarkMode = false;
  bool _erpLive = false;
  bool _checkingErp = false;
  int _pendingSync = 0;
  String _erpUrl = '';
  Timer? _syncStatusTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _syncStatusTimer = Timer.periodic(
        const Duration(seconds: 5), (_) => _checkErp());
  }

  @override
  void dispose() {
    _syncStatusTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final user = await LocalStorageService.getCurrentUser();
    final dark = await LocalStorageService.isDarkMode();
    final url = await ApiService.getBaseUrl();
    final pending = await OfflineQueueService.pendingCount;
    if (!mounted) return;
    setState(() {
      _user = user;
      _isDarkMode = dark;
      _erpUrl = url;
      _pendingSync = pending;
      _loading = false;
    });
    _checkErp();
  }

  Future<void> _checkErp() async {
    if (_checkingErp) return;
    setState(() => _checkingErp = true);
    final live = await ApiService.ping(force: true);
    var pending = _pendingSync;
    if (live) {
      // Live link confirmed — push anything waiting immediately.
      try {
        final result = await OfflineQueueService.syncAll();
        pending = result.remaining;
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _erpLive = live;
      _pendingSync = pending;
      _checkingErp = false;
    });
  }

  Future<void> _editErpUrl() async {
    final ctrl = TextEditingController(text: _erpUrl);
    final saved = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('ERP Server URL',
            style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
              hintText: 'https://your-erp-domain.com',
              prefixIcon: Icon(Icons.link_rounded)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: GoogleFonts.hindSiliguri(color: AppTheme.textGrey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryAccent),
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: Text('Save',
                style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (saved != null && saved.isNotEmpty) {
      await ApiService.setBaseUrl(saved);
      setState(() => _erpUrl = saved.replaceAll(RegExp(r'/+$'), ''));
      _checkErp();
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Logout',
            style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to logout?',
            style: GoogleFonts.hindSiliguri()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.hindSiliguri(color: AppTheme.textGrey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryAccent,
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10)),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Yes, Logout',
                style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await LocalStorageService.logout();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
    }
  }


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryAccent))
          : CustomScrollView(
              slivers: [
                // ── Header ────────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      // Gradient banner
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.fromLTRB(
                            20,
                            MediaQuery.of(context).padding.top + 16,
                            20,
                            28),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppTheme.primaryAccent,
                              Color(0xFF6B0E1E),
                            ],
                          ),
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // Decorative circles
                            Positioned(
                              top: -40,
                              right: -10,
                              child: Container(
                                width: 130,
                                height: 130,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.06),
                                ),
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Title row
                                Row(children: [
                                  Text('Profile',
                                      style: GoogleFonts.hindSiliguri(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white)),
                                ]),
                                const SizedBox(height: 20),
                                // Avatar
                                Container(
                                  width: 88,
                                  height: 88,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                    border: Border.all(
                                        color:
                                            Colors.white.withValues(alpha: 0.6),
                                        width: 3),
                                    boxShadow: [
                                      BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.2),
                                          blurRadius: 16,
                                          offset: const Offset(0, 4))
                                    ],
                                  ),
                                  child: ClipOval(
                                    child: Image.asset(
                                      'assets/images/wintech.png',
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        color: Colors.white,
                                        child: Center(
                                          child: Text(
                                            _user?.name.isNotEmpty == true
                                                ? _user!.name[0].toUpperCase()
                                                : 'U',
                                            style: GoogleFonts.hindSiliguri(
                                                fontSize: 34,
                                                fontWeight: FontWeight.w800,
                                                color: AppTheme.primaryAccent),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _user?.name.isNotEmpty == true
                                      ? _user!.name
                                      : 'User',
                                  style: GoogleFonts.hindSiliguri(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _user?.email ?? '',
                                  style: GoogleFonts.hindSiliguri(
                                      fontSize: 13, color: Colors.white70),
                                ),
                                if (_user?.role.isNotEmpty == true) ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                          color:
                                              Colors.white.withValues(alpha: 0.4)),
                                    ),
                                    child: Text(
                                      _user!.role,
                                      style: GoogleFonts.hindSiliguri(
                                          fontSize: 12,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 18),
                                // Edit button
                                GestureDetector(
                                  onTap: () async {
                                    await Navigator.pushNamed(
                                        context, '/edit-profile');
                                    _load();
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 24, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(24),
                                      boxShadow: [
                                        BoxShadow(
                                            color: Colors.black
                                                .withValues(alpha: 0.12),
                                            blurRadius: 8)
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.edit_rounded,
                                            color: AppTheme.primaryAccent,
                                            size: 15),
                                        const SizedBox(width: 8),
                                        Text('Edit Profile',
                                            style: GoogleFonts.hindSiliguri(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: AppTheme.primaryAccent)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Profile Info Cards ──────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionLabel('Profile Info', isDark),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.darkCard : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 8)
                            ],
                          ),
                          child: Column(
                            children: [
                              _infoTile(Icons.person_outline_rounded, 'Name',
                                  _user?.name.isEmpty == false
                                      ? _user!.name
                                      : '—',
                                  isDark),
                              _divider(),
                              _infoTile(Icons.email_outlined, 'Email',
                                  _user?.email.isEmpty == false
                                      ? _user!.email
                                      : '—',
                                  isDark),
                              _divider(),
                              _infoTile(Icons.phone_outlined, 'Mobile',
                                  _user?.phone.isEmpty == false
                                      ? _user!.phone
                                      : '—',
                                  isDark),
                              _divider(),
                              _infoTile(Icons.business_outlined, 'Company',
                                  _user?.company.isEmpty == false
                                      ? _user!.company
                                      : '—',
                                  isDark),
                              _divider(),
                              _infoTile(Icons.badge_outlined, 'Designation',
                                  _user?.designation.isEmpty == false
                                      ? _user!.designation
                                      : '—',
                                  isDark),
                              _divider(),
                              _infoTile(Icons.location_city_rounded, 'District',
                                  _user?.zela.isEmpty == false
                                      ? _user!.zela
                                      : '—',
                                  isDark),
                              _divider(),
                              _infoTile(Icons.pin_drop_rounded, 'Thana / Area',
                                  _user?.thana.isEmpty == false
                                      ? _user!.thana
                                      : '—',
                                  isDark),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── App Settings ──────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionLabel('App Settings', isDark),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.darkCard : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 8)
                            ],
                          ),
                          child: Column(
                            children: [
                              // ERP real-time connection status
                              ListTile(
                                leading: Container(
                                  width: 36, height: 36,
                                  decoration: BoxDecoration(
                                    color: (_erpLive
                                            ? AppTheme.success
                                            : AppTheme.error)
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    _erpLive
                                        ? Icons.cloud_done_rounded
                                        : Icons.cloud_off_rounded,
                                    size: 18,
                                    color: _erpLive
                                        ? AppTheme.success
                                        : AppTheme.error,
                                  ),
                                ),
                                title: Text(
                                  _checkingErp
                                      ? 'Checking ERP connection…'
                                      : (_erpLive
                                          ? 'ERP Connected (Live)'
                                          : 'ERP Offline'),
                                  style: GoogleFonts.hindSiliguri(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? AppTheme.darkText
                                          : AppTheme.textDark),
                                ),
                                subtitle: Text(
                                  _pendingSync > 0
                                      ? '$_pendingSync item(s) waiting to sync'
                                      : (_erpLive
                                          ? 'All data synced in real-time'
                                          : 'Data will sync when reconnected'),
                                  style: GoogleFonts.hindSiliguri(
                                      fontSize: 11,
                                      color: isDark
                                          ? AppTheme.darkTextGrey
                                          : AppTheme.textGrey),
                                ),
                                trailing: _checkingErp
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2))
                                    : IconButton(
                                        icon: const Icon(Icons.refresh_rounded,
                                            size: 20),
                                        tooltip: 'Reconnect & sync now',
                                        onPressed: _checkErp,
                                      ),
                                onTap: _checkErp,
                              ),
                              _divider(),
                              // ERP server URL
                              _settingTile(
                                icon: Icons.dns_rounded,
                                label: 'ERP Server URL',
                                isDark: isDark,
                                trailing: SizedBox(
                                  width: 130,
                                  child: Text(
                                    _erpUrl.replaceFirst(
                                        RegExp(r'^https?://'), ''),
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.right,
                                    style: GoogleFonts.hindSiliguri(
                                        fontSize: 11,
                                        color: isDark
                                            ? AppTheme.darkTextGrey
                                            : AppTheme.textGrey),
                                  ),
                                ),
                                onTap: _editErpUrl,
                              ),
                              _divider(),
                              // Dark/Light mode
                              ListTile(
                                leading: Container(
                                  width: 36, height: 36,
                                  decoration: BoxDecoration(
                                    color: (_isDarkMode
                                            ? Colors.indigo
                                            : AppTheme.primaryAccent)
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    _isDarkMode
                                        ? Icons.dark_mode_rounded
                                        : Icons.light_mode_rounded,
                                    size: 18,
                                    color: _isDarkMode
                                        ? Colors.indigo
                                        : AppTheme.primaryAccent,
                                  ),
                                ),
                                title: Text(
                                  _isDarkMode ? 'Dark Mode On' : 'Light Mode On',
                                  style: GoogleFonts.hindSiliguri(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: isDark
                                          ? AppTheme.darkText
                                          : AppTheme.textDark),
                                ),
                                trailing: Switch(
                                  value: _isDarkMode,
                                  onChanged: (val) async {
                                    await LocalStorageService.setDarkMode(val);
                                    setState(() => _isDarkMode = val);
                                    widget.onThemeToggle(val);
                                  },
                                ),
                              ),
                              if (_user?.isEmployee == true) ...[
                                _divider(),
                                _settingTile(
                                  icon: Icons.grid_view_rounded,
                                  label: 'More Modules (Expense, Leave, Survey...)',
                                  iconColor: AppTheme.primaryAccent,
                                  isDark: isDark,
                                  onTap: () => Navigator.pushNamed(
                                      context, '/more-modules'),
                                ),
                              ],
                              _divider(),
                              _settingTile(
                                icon: Icons.headset_mic_rounded,
                                label: 'Support & Tickets',
                                iconColor: AppTheme.primaryAccent,
                                isDark: isDark,
                                onTap: () =>
                                    Navigator.pushNamed(context, '/support'),
                              ),
                              _divider(),
                              _settingTile(
                                icon: Icons.notifications_outlined,
                                label: 'Notification Settings',
                                isDark: isDark,
                                onTap: () {},
                              ),
                              _divider(),
                              _settingTile(
                                icon: Icons.info_outline_rounded,
                                label: 'App Version',
                                isDark: isDark,
                                trailing: Text(
                                  'v1.0.0',
                                  style: GoogleFonts.hindSiliguri(
                                      fontSize: 13, color: AppTheme.textGrey),
                                ),
                              ),
                              _divider(),
                              _settingTile(
                                icon: Icons.privacy_tip_outlined,
                                label: 'Privacy Policy',
                                isDark: isDark,
                                onTap: () {},
                              ),
                              _divider(),
                              _settingTile(
                                icon: Icons.star_outline_rounded,
                                label: 'Rate the App',
                                iconColor: const Color(0xFFF57F17),
                                isDark: isDark,
                                onTap: () {},
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Logout ────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.error, width: 1.5),
                          foregroundColor: AppTheme.error,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: _logout,
                        icon: const Icon(Icons.logout_rounded, color: AppTheme.error),
                        label: Text('Logout',
                            style: GoogleFonts.hindSiliguri(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.error)),
                      ),
                    ),
                  ),
                ),

                // ── Footer ────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    child: Center(
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.asset(
                              'assets/images/wintech.png',
                              width: 40, height: 40,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                  Icons.business_center_rounded,
                                  color: AppTheme.primaryAccent, size: 30),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '© 2026 Wintech Agro\nAll rights reserved.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.hindSiliguri(
                                fontSize: 12,
                                color: isDark
                                    ? AppTheme.darkTextGrey
                                    : AppTheme.textGrey),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value, bool isDark,
      {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
                color: AppTheme.primaryAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: AppTheme.primaryAccent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.hindSiliguri(
                        fontSize: 11,
                        color: isDark ? AppTheme.darkTextGrey : AppTheme.textGrey)),
                const SizedBox(height: 2),
                Text(value,
                    style: GoogleFonts.hindSiliguri(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: valueColor ??
                            (isDark ? AppTheme.darkText : AppTheme.textDark))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => const Divider(height: 1, indent: 66);

  Widget _sectionLabel(String text, bool isDark) {
    return Row(
      children: [
        Container(
          width: 4, height: 18,
          decoration: BoxDecoration(
              color: AppTheme.primaryAccent,
              borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 8),
        Text(text,
            style: GoogleFonts.hindSiliguri(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark ? AppTheme.darkText : AppTheme.textDark)),
      ],
    );
  }

  Widget _settingTile({
    required IconData icon,
    required String label,
    required bool isDark,
    Widget? trailing,
    VoidCallback? onTap,
    Color? iconColor,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: (iconColor ?? AppTheme.primaryAccent).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: iconColor ?? AppTheme.primaryAccent),
      ),
      title: Text(label,
          style: GoogleFonts.hindSiliguri(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark ? AppTheme.darkText : AppTheme.textDark)),
      trailing: trailing ??
          (onTap != null
              ? Icon(Icons.chevron_right_rounded,
                  color: isDark ? AppTheme.darkTextGrey : AppTheme.textGrey,
                  size: 20)
              : null),
    );
  }
}
