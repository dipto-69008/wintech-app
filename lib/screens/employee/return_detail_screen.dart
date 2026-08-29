import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';

/// Read-only details view for a sales return invoice.
class ReturnDetailScreen extends StatelessWidget {
  final Map<String, dynamic> returnData;

  const ReturnDetailScreen({
    super.key,
    required this.returnData,
  });

  String _text(String key, [String fallback = '—']) {
    final value = returnData[key]?.toString().trim() ?? '';
    return value.isEmpty ? fallback : value;
  }

  String _date() {
    final raw = returnData['returnDate'] ?? returnData['createdAt'];
    final date = DateTime.tryParse(raw?.toString() ?? '');
    return date == null ? '—' : DateFormat('dd MMM yyyy, hh:mm a').format(date);
  }

  String _money(dynamic value) {
    final amount = value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
    return NumberFormat('#,##0.00', 'en_US').format(amount);
  }

  List<Map<String, dynamic>> _items() {
    final raw = returnData['items'];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    return const [];
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'refunded':
        return AppTheme.success;
      case 'rejected':
        return AppTheme.error;
      case 'replace':
        return Colors.blue;
      default:
        return AppTheme.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = _text('status', 'pending');
    final statusColor = _statusColor(status);
    final items = _items();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Return Details',
          style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppTheme.primaryAccent,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _headerCard(isDark, status, statusColor),
          const SizedBox(height: 12),
          _section(
            isDark,
            title: 'Return Information',
            icon: Icons.receipt_long_rounded,
            child: Column(
              children: [
                _infoRow('Return number', _text('returnNo')),
                _infoRow('Customer', _text('partyName')),
                _infoRow('Invoice number', _text('invoiceNo')),
                _infoRow('Return date', _date()),
                _infoRow('Source', _text('source', 'Mobile')),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _section(
            isDark,
            title: 'Products',
            icon: Icons.inventory_2_rounded,
            child: items.isEmpty
                ? _muted('No product line details available.')
                : Column(
                    children: items.asMap().entries.map((entry) {
                      final item = entry.value;
                      final quantity = item['quantity'];
                      final rate = item['rate'];
                      final total = item['totalAmount'] ??
                          ((quantity is num && rate is num) ? quantity * rate : 0);
                      return Container(
                        width: double.infinity,
                        margin: EdgeInsets.only(
                          bottom: entry.key == items.length - 1 ? 0 : 10,
                        ),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryAccent.withValues(alpha: .07),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['productName']?.toString() ?? 'Product',
                              style: GoogleFonts.hindSiliguri(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            if ((item['packSize'] ?? '').toString().isNotEmpty)
                              Text(
                                'Pack size: ${item['packSize']}',
                                style: GoogleFonts.hindSiliguri(
                                  fontSize: 11,
                                  color: AppTheme.textGrey,
                                ),
                              ),
                            const SizedBox(height: 7),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Qty: ${quantity ?? 0}  ×  Rate: ${_money(rate)}',
                                  style: GoogleFonts.hindSiliguri(fontSize: 12),
                                ),
                                Text(
                                  _money(total),
                                  style: GoogleFonts.hindSiliguri(
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.primaryAccent,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 12),
          _section(
            isDark,
            title: 'Summary',
            icon: Icons.calculate_rounded,
            child: _infoRow('Total amount', _money(returnData['totalAmount'])),
          ),
          const SizedBox(height: 12),
          _section(
            isDark,
            title: 'Reason & Notes',
            icon: Icons.notes_rounded,
            child: Column(
              children: [
                _infoRow('Return reason', _text('reason')),
                _infoRow('Salesperson', _text('srName', _text('createdByName'))),
                _infoRow('Branch', _text('branchName')),
                _infoRow('Notes', _text('notes')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerCard(bool isDark, String status, Color color) {
    final label = status.isEmpty
        ? 'Pending'
        : '${status[0].toUpperCase()}${status.substring(1)}';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: .35)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: color.withValues(alpha: .12),
            child: Icon(Icons.assignment_return_rounded, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sales Return',
                  style: GoogleFonts.hindSiliguri(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _text('returnNo', 'Return invoice'),
                  style: GoogleFonts.hindSiliguri(
                    color: AppTheme.textGrey,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              label,
              style: GoogleFonts.hindSiliguri(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(
    bool isDark, {
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppTheme.primaryAccent),
              const SizedBox(width: 7),
              Text(
                title,
                style: GoogleFonts.hindSiliguri(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: GoogleFonts.hindSiliguri(
                color: AppTheme.textGrey,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.hindSiliguri(
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _muted(String text) => Text(
        text,
        style: GoogleFonts.hindSiliguri(
          color: AppTheme.textGrey,
          fontSize: 12,
        ),
      );
}