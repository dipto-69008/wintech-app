import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';

/// Read-only details view for a sent or incoming stock transfer.
class StockTransferDetailScreen extends StatelessWidget {
  final Map<String, dynamic> transfer;

  const StockTransferDetailScreen({
    super.key,
    required this.transfer,
  });

  String _text(String key, [String fallback = '—']) {
    final value = transfer[key]?.toString().trim() ?? '';
    return value.isEmpty ? fallback : value;
  }

  String _date() {
    final raw = transfer['date']?.toString() ?? '';
    final parsed = DateTime.tryParse(raw);
    return parsed == null
        ? '—'
        : DateFormat('dd MMM yyyy, hh:mm a').format(parsed);
  }

  List<Map<String, dynamic>> _items() {
    final raw = transfer['items'];
    if (raw is List) {
      final items = raw
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      if (items.isNotEmpty) return items;
    }

    final productName = _text('productName', '');
    if (productName.isEmpty) return const [];
    return [
      {
        'productName': productName,
        'quantity': transfer['quantity'],
        'quantityUnit': transfer['quantityUnit'] ?? transfer['unit'] ?? 'Pcs',
        'cartonCount': transfer['cartonCount'],
        'bucketCount': transfer['bucketCount'],
        'totalWeight': transfer['totalWeight'],
        'weightUnit': transfer['weightUnit'],
      },
    ];
  }

  String _quantity(Map<String, dynamic> item) {
    final quantity = (item['quantity'] as num?)?.toDouble() ?? 0;
    final carton = item['cartonCount'];
    final bucket = item['bucketCount'];
    final pcs = NumberFormat('#,##0.##', 'en_US').format(quantity);
    if (carton != null) return '$carton Carton = $pcs Pcs';
    if (bucket != null) return '$bucket Bucket = $pcs Pcs';
    return '$pcs Pcs';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = _text('status', 'pending').toLowerCase();
    final queued = transfer['_queued'] == true;
    final items = _items();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Transfer Details',
            style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w700)),
        backgroundColor: AppTheme.primaryAccent,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _headerCard(isDark, status, queued),
          const SizedBox(height: 12),
          _section(
            isDark,
            title: 'Transfer Route',
            icon: Icons.route_rounded,
            child: Column(
              children: [
                _infoRow('From branch', _text('fromBranch')),
                _infoRow('To branch', _text('toBranch')),
                _infoRow('Transfer date', _date()),
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
                      final weight = item['totalWeight']?.toString().trim() ?? '';
                      final weightUnit = item['weightUnit']?.toString() ?? 'g';
                      return Container(
                        width: double.infinity,
                        margin: EdgeInsets.only(
                            bottom: entry.key == items.length - 1 ? 0 : 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryAccent.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item['productName']?.toString() ?? '—',
                                    style: GoogleFonts.hindSiliguri(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14),
                                  ),
                                ),
                                Text(
                                  _quantity(item),
                                  style: GoogleFonts.hindSiliguri(
                                      color: AppTheme.primaryAccent,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12),
                                ),
                              ],
                            ),
                            if (weight.isNotEmpty) ...[
                              const SizedBox(height: 5),
                              Text('Weight: $weight $weightUnit',
                                  style: GoogleFonts.hindSiliguri(
                                      color: AppTheme.textGrey, fontSize: 12)),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 12),
          _section(
            isDark,
            title: 'People & Notes',
            icon: Icons.notes_rounded,
            child: Column(
              children: [
                _infoRow('Transferred by', _text('transferredBy')),
                _infoRow('Received by', _text('receivedBy')),
                if (_text('receiveNote', '').isNotEmpty)
                  _infoRow('Receive note', _text('receiveNote')),
                if (_text('notes', '').isNotEmpty)
                  _infoRow('Notes', _text('notes')),
              ],
            ),
          ),
          if (queued) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cloud_upload_outlined,
                      color: Colors.orange, size: 19),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This transfer is saved offline and will sync when the ERP connection returns.',
                      style: GoogleFonts.hindSiliguri(
                          color: Colors.orange, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _headerCard(bool isDark, String status, bool queued) {
    final color = queued
        ? Colors.orange
        : status == 'received' || status == 'approved'
            ? AppTheme.success
            : status == 'rejected'
                ? AppTheme.error
                : AppTheme.warning;
    final label = queued
        ? 'Pending sync'
        : status == 'received'
            ? 'Received'
            : status == 'approved'
                ? 'Approved'
                : status == 'rejected'
                    ? 'Rejected'
                    : 'Awaiting receipt';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(Icons.swap_horiz_rounded, color: color, size: 25),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Stock Transfer',
                    style: GoogleFonts.hindSiliguri(
                        fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 3),
                Text('ID: ${_text('_id', _text('id'))}',
                    style: GoogleFonts.hindSiliguri(
                        color: AppTheme.textGrey, fontSize: 11)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(label,
                style: GoogleFonts.hindSiliguri(
                    color: color, fontWeight: FontWeight.w700, fontSize: 11)),
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
              Text(title,
                  style: GoogleFonts.hindSiliguri(
                      fontWeight: FontWeight.w700, fontSize: 14)),
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(label,
                style: GoogleFonts.hindSiliguri(
                    color: AppTheme.textGrey, fontSize: 12)),
          ),
          Expanded(
            child: Text(value,
                style: GoogleFonts.hindSiliguri(
                    fontWeight: FontWeight.w600, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _muted(String text) => Text(text,
      style: GoogleFonts.hindSiliguri(color: AppTheme.textGrey, fontSize: 12));
}