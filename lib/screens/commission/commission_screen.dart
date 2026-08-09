import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../models/user_model.dart';
import '../../services/local_storage_service.dart';

class CommissionScreen extends StatefulWidget {
  const CommissionScreen({super.key});

  @override
  State<CommissionScreen> createState() => _CommissionScreenState();
}

class _CommissionScreenState extends State<CommissionScreen> {
  UserModel? _user;
  List<Map<String, dynamic>> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = await LocalStorageService.getCurrentUser();
    final history = await LocalStorageService.getCommissionHistory();
    if (!mounted) return;
    setState(() {
      _user = user;
      _history = history;
      _loading = false;
    });
  }

  String _formatTaka(double v) {
    if (v >= 100000) return '৳${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '৳${(v / 1000).toStringAsFixed(1)}K';
    return '৳${v.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = _user;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Commission Statement',
            style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w700)),
        backgroundColor: AppTheme.primaryAccent,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryAccent))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Summary Card ─────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primaryAccent, Color(0xFF6A1A20)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: AppTheme.primaryAccent.withValues(alpha: 0.28),
                          blurRadius: 14,
                          offset: const Offset(0, 6))
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Commission Summary',
                          style: GoogleFonts.hindSiliguri(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white70)),
                      const SizedBox(height: 14),
                      Row(children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Total Commission',
                                  style: GoogleFonts.hindSiliguri(
                                      fontSize: 12, color: Colors.white70)),
                              const SizedBox(height: 4),
                              Text(_formatTaka(user?.totalCommission ?? 0),
                                  style: GoogleFonts.hindSiliguri(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white)),
                            ],
                          ),
                        ),
                        Container(
                            width: 1,
                            height: 44,
                            color: Colors.white.withValues(alpha: 0.2)),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Pending Commission',
                                  style: GoogleFonts.hindSiliguri(
                                      fontSize: 12, color: Colors.white70)),
                              const SizedBox(height: 4),
                              Text(_formatTaka(user?.pendingCommission ?? 0),
                                  style: GoogleFonts.hindSiliguri(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white)),
                            ],
                          ),
                        ),
                      ]),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(children: [
                          Icon(user?.badgeIcon ?? Icons.emoji_events_rounded,
                              color: Colors.white, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            '${user?.badge ?? "Bronze"} Badge • Commission Rate: ${((user?.commissionRate ?? 0.015) * 100).toStringAsFixed(1)}%',
                            style: GoogleFonts.hindSiliguri(
                                fontSize: 12, color: Colors.white),
                          ),
                        ]),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── History ──────────────────────────────────────────
                Text('📋 Commission History',
                    style: GoogleFonts.hindSiliguri(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppTheme.darkText : AppTheme.textDark)),
                const SizedBox(height: 12),

                if (_history.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkCard : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(children: [
                      Icon(Icons.receipt_long_rounded,
                          size: 44,
                          color: AppTheme.primaryAccent.withValues(alpha: 0.3)),
                      const SizedBox(height: 12),
                      Text('No commission yet',
                          style: GoogleFonts.hindSiliguri(
                              fontSize: 14,
                              color: isDark
                                  ? AppTheme.darkTextGrey
                                  : AppTheme.textGrey)),
                      const SizedBox(height: 6),
                      Text('Commission will appear here after successful sales',
                          style: GoogleFonts.hindSiliguri(
                              fontSize: 12,
                              color: isDark
                                  ? AppTheme.darkTextGrey
                                  : AppTheme.textGrey),
                          textAlign: TextAlign.center),
                    ]),
                  )
                else
                  ..._history.map((h) => _commissionTile(h, isDark)),
              ],
            ),
    );
  }

  Widget _commissionTile(Map<String, dynamic> h, bool isDark) {
    final amount = (h['commission'] as num?)?.toDouble() ?? 0;
    final source = h['source'] as String? ?? '';
    final date = DateTime.tryParse(h['date'] as String? ?? '') ?? DateTime.now();
    final type = h['type'] as String? ?? 'Sales';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 6)
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.attach_money_rounded,
                color: AppTheme.success, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(source,
                    style: GoogleFonts.hindSiliguri(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppTheme.darkText : AppTheme.textDark),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text('$type • ${DateFormat('dd MMM yyyy').format(date)}',
                    style: GoogleFonts.hindSiliguri(
                        fontSize: 12,
                        color: isDark
                            ? AppTheme.darkTextGrey
                            : AppTheme.textGrey)),
              ],
            ),
          ),
          Text(
            '+${_formatTaka(amount)}',
            style: GoogleFonts.hindSiliguri(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppTheme.success),
          ),
        ],
      ),
    );
  }
}
