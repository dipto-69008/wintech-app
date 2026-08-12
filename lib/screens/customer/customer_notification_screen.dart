import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';

class CustomerNotificationScreen extends StatelessWidget {
  const CustomerNotificationScreen({super.key});

  static final List<Map<String, dynamic>> _announcements = [
    {
      'title': 'Eid Special Discount',
      'body': 'Get 10% off on all payments this Eid season. Limited-time offer — act fast!',
      'date': '1 July 2026',
      'icon': Icons.celebration_rounded,
      'color': Color(0xFFF57F17),
      'type': 'Offer',
    },
    {
      'title': 'Monthly Payment Reminder',
      'body': 'July payment is still outstanding. Please settle before 10 July to avoid any delay.',
      'date': '1 July 2026',
      'icon': Icons.payment_rounded,
      'color': Color(0xFF1B9DD9),
      'type': 'Payment',
    },
    {
      'title': 'New Product Update',
      'body': 'Aqua Safe Plus 5 Kg (৳680) and Win C 500gm (৳780) are now available. Contact your SR to order.',
      'date': '28 June 2026',
      'icon': Icons.construction_rounded,
      'color': Color(0xFF1565C0),
      'type': 'Update',
    },
    {
      'title': 'Document Submission Request',
      'body': 'Please visit the office to update your NID and photograph for our records.',
      'date': '25 June 2026',
      'icon': Icons.folder_rounded,
      'color': Color(0xFF6A1B9A),
      'type': 'Document',
    },
    {
      'title': 'Payment Successful',
      'body': 'Your payment of ৳12,000 for June 2026 has been received successfully.',
      'date': '4 June 2026',
      'icon': Icons.check_circle_rounded,
      'color': Color(0xFF2E7D32),
      'type': 'Success',
    },
    {
      'title': 'Field Visit Scheduled',
      'body': 'A site visit has been arranged for this Friday at 3:00 PM. Please confirm your attendance.',
      'date': '20 May 2026',
      'icon': Icons.location_on_rounded,
      'color': AppTheme.secondaryAccent,
      'type': 'Event',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // Header
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
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.campaign_rounded,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Notifications & Announcements',
                            style: GoogleFonts.hindSiliguri(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                        Text('Latest updates & offers',
                            style: GoogleFonts.hindSiliguri(
                                fontSize: 12, color: Colors.white70)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text('${_announcements.length} items',
                        style: GoogleFonts.hindSiliguri(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 12)),

          SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => _buildCard(_announcements[i], context),
              childCount: _announcements.length,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> item, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = item['color'] as Color;
    final cardBg = isDark ? AppTheme.darkCard : Colors.white;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
              blurRadius: 6)
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(item['icon'] as IconData, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(item['title'] as String,
                          style: GoogleFonts.hindSiliguri(
                              fontSize: 14, fontWeight: FontWeight.w700)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(item['type'] as String,
                          style: GoogleFonts.hindSiliguri(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: color)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(item['body'] as String,
                    style: GoogleFonts.hindSiliguri(
                        fontSize: 13,
                        color: isDark ? AppTheme.darkTextGrey : AppTheme.textGrey,
                        height: 1.4)),
                const SizedBox(height: 8),
                Row(children: [
                  Icon(Icons.schedule_rounded,
                      size: 12,
                      color: isDark ? AppTheme.darkTextGrey : AppTheme.textGrey),
                  const SizedBox(width: 4),
                  Text(item['date'] as String,
                      style: GoogleFonts.hindSiliguri(
                          fontSize: 11,
                          color: isDark ? AppTheme.darkTextGrey : AppTheme.textGrey)),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
