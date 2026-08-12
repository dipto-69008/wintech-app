import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';

class CustomerNotificationScreen extends StatelessWidget {
  const CustomerNotificationScreen({super.key});

  static final List<Map<String, dynamic>> _announcements = [
    {
      'title': 'ঈদ বিশেষ ছাড়',
      'body': 'আসন্ন ঈদ উপলক্ষে সকল পেমেন্টে ১০% ছাড় পাচ্ছেন। অফার সীমিত সময়ের জন্য।',
      'date': '১ জুলাই ২০২৬',
      'icon': Icons.celebration_rounded,
      'color': Color(0xFFF57F17),
      'type': 'অফার',
    },
    {
      'title': 'মাসিক পেমেন্ট রিমাইন্ডার',
      'body': 'জুলাই মাসের পেমেন্ট এখনও করা হয়নি। অনুগ্রহ করে ১০ জুলাইয়ের মধ্যে পরিশোধ করুন।',
      'date': '১ জুলাই ২০২৬',
      'icon': Icons.payment_rounded,
      'color': Color(0xFF1B9DD9),
      'type': 'পেমেন্ট',
    },
    {
      'title': 'নতুন প্রজেক্ট আপডেট',
      'body': 'সেক্টর-৭ এর নির্মাণ কাজ ৭৫% সম্পন্ন হয়েছে। ২০২৬ সালের ডিসেম্বরে হস্তান্তর হবে।',
      'date': '২৮ জুন ২০২৬',
      'icon': Icons.construction_rounded,
      'color': Color(0xFF1565C0),
      'type': 'আপডেট',
    },
    {
      'title': 'নথি জমা দেওয়ার অনুরোধ',
      'body': 'আপনার NID ও ছবি আপডেট করার জন্য অনুগ্রহ করে অফিসে যোগাযোগ করুন।',
      'date': '২৫ জুন ২০২৬',
      'icon': Icons.folder_rounded,
      'color': Color(0xFF6A1B9A),
      'type': 'নথি',
    },
    {
      'title': 'পেমেন্ট সফল হয়েছে',
      'body': 'জুন ২০২৬ এর জন্য ৳১২,০০০ পেমেন্ট সফলভাবে গ্রহণ করা হয়েছে।',
      'date': '৪ জুন ২০২৬',
      'icon': Icons.check_circle_rounded,
      'color': Color(0xFF2E7D32),
      'type': 'সফল',
    },
    {
      'title': 'সম্পত্তি পরিদর্শন',
      'body': 'আগামী শুক্রবার বিকেল ৩টায় সাইট ভিজিট আয়োজন করা হয়েছে। অংশ নিতে সম্মতি জানান।',
      'date': '২০ মে ২০২৬',
      'icon': Icons.location_on_rounded,
      'color': AppTheme.secondaryAccent,
      'type': 'ইভেন্ট',
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
                        Text('নোটিফিকেশন ও ঘোষণা',
                            style: GoogleFonts.hindSiliguri(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                        Text('সর্বশেষ আপডেট ও অফার',
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
                    child: Text('${_announcements.length} টি',
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
