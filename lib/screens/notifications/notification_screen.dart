import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final List<_NotifItem> _notifications = [
    _NotifItem(
      icon: Icons.receipt_long_rounded,
      color: AppTheme.primaryAccent,
      title: 'New Order Received',
      body: 'A new order worth ৳32,500 has been placed by M/s Akhonda Traders.',
      time: '5 minutes ago',
      isRead: false,
    ),
    _NotifItem(
      icon: Icons.payments_rounded,
      color: AppTheme.success,
      title: 'Payment Confirmed',
      body: 'Payment of ৳18,000 from M/s Baly Enterprise has been received successfully.',
      time: '2 hours ago',
      isRead: false,
    ),
    _NotifItem(
      icon: Icons.emoji_events_rounded,
      color: const Color(0xFFF57F17),
      title: 'Monthly Target Achievement',
      body: 'Congratulations! You have achieved 85% of this month\'s target.',
      time: 'Today 9:00 AM',
      isRead: true,
    ),
    _NotifItem(
      icon: Icons.local_shipping_rounded,
      color: const Color(0xFF1565C0),
      title: 'Delivery Completed',
      body: 'Order ORD-2045 for M/s Rahman Fish Feed has been delivered successfully.',
      time: 'Yesterday 4:00 PM',
      isRead: true,
    ),
    _NotifItem(
      icon: Icons.bar_chart_rounded,
      color: const Color(0xFF6A1B9A),
      title: 'Weekly Sales Report',
      body: 'This week: 12 orders completed with total sales of ৳48,500.',
      time: '2 days ago',
      isRead: true,
    ),
  ];

  void _markAllRead() {
    setState(() {
      for (final n in _notifications) {
        n.isRead = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => !n.isRead).length;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // ── Header ──────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
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
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Notifications',
                          style: GoogleFonts.hindSiliguri(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        if (unreadCount > 0)
                          Text(
                            '$unreadCount unread',
                            style: GoogleFonts.hindSiliguri(
                                fontSize: 12, color: Colors.white70),
                          ),
                      ],
                    ),
                  ),
                  if (unreadCount > 0)
                    TextButton(
                      onPressed: _markAllRead,
                      child: Text(
                        'Mark all read',
                        style: GoogleFonts.hindSiliguri(
                          fontSize: 12,
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 8)),

          // ── List ────────────────────────────────────────────────
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) {
                final item = _notifications[i];
                return _NotifTile(
                  item: item,
                  onTap: () => setState(() => item.isRead = true),
                );
              },
              childCount: _notifications.length,
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

class _NotifItem {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final String time;
  bool isRead;

  _NotifItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    required this.time,
    required this.isRead,
  });
}

class _NotifTile extends StatelessWidget {
  final _NotifItem item;
  final VoidCallback onTap;

  const _NotifTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: item.isRead
              ? (isDark ? AppTheme.darkCard : Colors.white)
              : AppTheme.primaryAccent.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: item.isRead
                ? AppTheme.divider
                : AppTheme.primaryAccent.withValues(alpha: 0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(item.icon, color: item.color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: GoogleFonts.hindSiliguri(
                            fontSize: 14,
                            fontWeight: item.isRead
                                ? FontWeight.w500
                                : FontWeight.w700,
                            color: isDark ? AppTheme.darkText : AppTheme.textDark,
                          ),
                        ),
                      ),
                      if (!item.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppTheme.primaryAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.body,
                    style: GoogleFonts.hindSiliguri(
                        fontSize: 12,
                        color: isDark ? AppTheme.darkTextGrey : AppTheme.textGrey,
                        height: 1.4),
                  ),
                  const SizedBox(height: 6),
                  Row(children: [
                    Icon(Icons.access_time_rounded,
                        size: 12,
                        color: isDark
                            ? AppTheme.darkTextGrey
                            : AppTheme.textGrey),
                    const SizedBox(width: 4),
                    Text(
                      item.time,
                      style: GoogleFonts.hindSiliguri(
                        fontSize: 11,
                        color: isDark ? AppTheme.darkTextGrey : AppTheme.textGrey,
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
