import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../models/user_model.dart';
import '../../services/local_storage_service.dart';

class DigitalIdCardScreen extends StatefulWidget {
  const DigitalIdCardScreen({super.key});

  @override
  State<DigitalIdCardScreen> createState() => _DigitalIdCardScreenState();
}

class _DigitalIdCardScreenState extends State<DigitalIdCardScreen>
    with SingleTickerProviderStateMixin {
  UserModel? _user;
  bool _loading = true;
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _fade = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _slide = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final user = await LocalStorageService.getCurrentUser();
    if (!mounted) return;
    setState(() {
      _user = user;
      _loading = false;
    });
    _ctrl.forward();
  }

  void _copyId() {
    HapticFeedback.lightImpact();
    Clipboard.setData(ClipboardData(text: _user?.id ?? ''));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('ID copied!',
          style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600)),
      backgroundColor: AppTheme.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 2),
    ));
  }

  void _share() {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Sharing card...',
          style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600)),
      backgroundColor: AppTheme.primaryAccent,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF111111) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: AppTheme.primaryAccent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        ),
        title: Text('Digital ID Card',
            style: GoogleFonts.hindSiliguri(
                fontWeight: FontWeight.w700, color: Colors.white)),
        actions: [
          IconButton(
            onPressed: _share,
            icon: const Icon(Icons.share_rounded, color: Colors.white),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryAccent))
          : FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildCard(isDark),
                      const SizedBox(height: 20),
                      _buildStats(isDark),
                      const SizedBox(height: 20),
                      _buildActions(isDark),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildCard(bool isDark) {
    final user = _user;
    if (user == null) return const SizedBox();
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryAccent,
            const Color(0xFF6A1A20),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: AppTheme.primaryAccent.withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, 8))
        ],
      ),
      child: Stack(
        children: [
          // Background pattern
          Positioned(
            right: -20, top: -20,
            child: Container(
              width: 140, height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Positioned(
            right: 20, bottom: -30,
            child: Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        'assets/images/wintech.png',
                        width: 36, height: 36,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 36, height: 36,
                          color: Colors.white,
                          child: const Icon(Icons.business_center_rounded,
                              size: 20, color: AppTheme.primaryAccent),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Wintech Agro',
                            style: GoogleFonts.hindSiliguri(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                        Text('Sales Partner Card',
                            style: GoogleFonts.hindSiliguri(
                                fontSize: 10, color: Colors.white60)),
                      ],
                    ),
                    const Spacer(),
                    // Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: user.badgeColor,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                              color: user.badgeColor.withValues(alpha: 0.4),
                              blurRadius: 8)
                        ],
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(user.badgeIcon, color: Colors.white, size: 12),
                        const SizedBox(width: 4),
                        Text(user.badge,
                            style: GoogleFonts.hindSiliguri(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                      ]),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                // Avatar + name
                Row(
                  children: [
                    Container(
                      width: 64, height: 64,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 2),
                      ),
                      child: Center(
                        child: Text(
                          user.name.isNotEmpty
                              ? user.name[0].toUpperCase()
                              : 'U',
                          style: GoogleFonts.hindSiliguri(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primaryAccent),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.name,
                              style: GoogleFonts.hindSiliguri(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white)),
                          const SizedBox(height: 3),
                          Text(user.role,
                              style: GoogleFonts.hindSiliguri(
                                  fontSize: 13, color: Colors.white70)),
                          if (user.designation.isNotEmpty)
                            Text(user.designation,
                                style: GoogleFonts.hindSiliguri(
                                    fontSize: 12, color: Colors.white60)),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                Container(height: 1, color: Colors.white.withValues(alpha: 0.15)),
                const SizedBox(height: 16),

                // Info rows
                if (user.phone.isNotEmpty)
                  _cardRow(Icons.phone_rounded, user.phone),
                if (user.phone.isNotEmpty) const SizedBox(height: 8),
                _cardRow(Icons.email_rounded, user.email),
                const SizedBox(height: 8),
                if (user.zela.isNotEmpty || user.thana.isNotEmpty)
                  _cardRow(Icons.location_on_rounded,
                    [user.thana, user.zela]
                        .where((s) => s.isNotEmpty)
                        .join(', ')),
                if (user.zela.isNotEmpty || user.thana.isNotEmpty)
                  const SizedBox(height: 8),
                if (user.teamName.isNotEmpty)
                  _cardRow(Icons.group_rounded, 'Team: ${user.teamName}'),

                const SizedBox(height: 16),
                // ID row with copy
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(children: [
                    const Icon(Icons.badge_rounded,
                        color: Colors.white70, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('ID: ${user.id}',
                          style: GoogleFonts.hindSiliguri(
                              fontSize: 12, color: Colors.white70),
                          overflow: TextOverflow.ellipsis),
                    ),
                    GestureDetector(
                      onTap: _copyId,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.copy_rounded,
                              color: Colors.white, size: 12),
                          const SizedBox(width: 4),
                          Text('Copy',
                              style: GoogleFonts.hindSiliguri(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white)),
                        ]),
                      ),
                    ),
                  ]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardRow(IconData icon, String text) {
    return Row(children: [
      Icon(icon, color: Colors.white60, size: 15),
      const SizedBox(width: 8),
      Expanded(
        child: Text(text,
            style: GoogleFonts.hindSiliguri(
                fontSize: 13, color: Colors.white.withValues(alpha: 0.85))),
      ),
    ]);
  }

  Widget _buildStats(bool isDark) {
    final user = _user;
    if (user == null) return const SizedBox();
    final cardBg = isDark ? AppTheme.darkCard : Colors.white;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
              blurRadius: 8)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Performance',
              style: GoogleFonts.hindSiliguri(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppTheme.darkText : AppTheme.textDark)),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _statTile('Total Sales',
                _formatTaka(user.totalSales),
                Icons.trending_up_rounded, AppTheme.success, isDark)),
            const SizedBox(width: 10),
            Expanded(child: _statTile('Commission Rate',
                '${(user.commissionRate * 100).toStringAsFixed(1)}%',
                Icons.percent_rounded, AppTheme.primaryAccent, isDark)),
          ]),
          const SizedBox(height: 10),
          // Badge progress
          Row(children: [
            Icon(user.badgeIcon, color: user.badgeColor, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(user.badge,
                        style: GoogleFonts.hindSiliguri(
                            fontSize: 13, fontWeight: FontWeight.w700,
                            color: user.badgeColor)),
                    const Spacer(),
                    if (user.totalSales < 5000000)
                      Text('Next: ${user.nextBadgeName}',
                          style: GoogleFonts.hindSiliguri(
                              fontSize: 11,
                              color: isDark ? AppTheme.darkTextGrey : AppTheme.textGrey)),
                  ]),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: user.badgeProgress,
                      minHeight: 7,
                      backgroundColor: user.badgeColor.withValues(alpha: 0.15),
                      valueColor: AlwaysStoppedAnimation(user.badgeColor),
                    ),
                  ),
                ],
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _statTile(String label, String value, IconData icon, Color color,
      bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 6),
        Text(value,
            style: GoogleFonts.hindSiliguri(
                fontSize: 16, fontWeight: FontWeight.w800, color: color)),
        Text(label,
            style: GoogleFonts.hindSiliguri(
                fontSize: 11,
                color: isDark ? AppTheme.darkTextGrey : AppTheme.textGrey)),
      ]),
    );
  }

  Widget _buildActions(bool isDark) {
    return Row(children: [
      Expanded(
        child: _actionBtn(
          icon: Icons.share_rounded,
          label: 'Share Card',
          color: AppTheme.primaryAccent,
          onTap: _share,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: _actionBtn(
          icon: Icons.download_rounded,
          label: 'Download',
          color: AppTheme.success,
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Coming soon...',
                style: GoogleFonts.hindSiliguri()),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          )),
        ),
      ),
    ]);
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 3))
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(height: 6),
          Text(label,
              style: GoogleFonts.hindSiliguri(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
        ]),
      ),
    );
  }

  String _formatTaka(double v) {
    if (v >= 10000000) return '৳${(v / 10000000).toStringAsFixed(1)} Crore';
    if (v >= 100000) return '৳${(v / 100000).toStringAsFixed(1)} Lakh';
    if (v >= 1000) return '৳${(v / 1000).toStringAsFixed(1)}K';
    return '৳${v.toStringAsFixed(0)}';
  }
}
