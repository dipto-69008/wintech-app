import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/theme.dart';
import '../../models/leave_model.dart';

class LeaveDetailsScreen extends StatelessWidget {
  final LeaveModel leave;

  const LeaveDetailsScreen({super.key, required this.leave});

  Color _statusColor() {
    switch (leave.status) {
      case LeaveModel.statusApproved:
        return AppTheme.success;
      case LeaveModel.statusRejected:
        return AppTheme.error;
      default:
        return AppTheme.warning;
    }
  }

  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/${value.year}';

  String _dateTime(DateTime value) =>
      '${_date(value)} · ${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppTheme.darkCard : Colors.white;
    final statusColor = _statusColor();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Leave Details',
            style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _summaryCard(statusColor),
          const SizedBox(height: 14),
          _sectionCard(
            cardColor,
            title: 'Leave Information',
            icon: Icons.event_note_rounded,
            children: [
              _infoRow('Leave type', leave.typeLabel, Icons.category_outlined),
              _infoRow('From date', _date(leave.fromDate), Icons.event_rounded),
              _infoRow('To date', _date(leave.toDate), Icons.event_available_rounded),
              _infoRow('Total days', '${leave.totalDays} days',
                  Icons.calendar_month_rounded),
              _infoRow('Applied on', _dateTime(leave.appliedAt),
                  Icons.schedule_rounded),
              if (leave.joiningDate != null)
                _infoRow('Joining date', _date(leave.joiningDate!),
                    Icons.login_rounded),
            ],
          ),
          if (leave.isEncashment) ...[
            const SizedBox(height: 14),
            _sectionCard(
              cardColor,
              title: 'Encashment Information',
              icon: Icons.payments_outlined,
              children: [
                _infoRow('Request type', 'Leave Encashment',
                    Icons.account_balance_wallet_outlined),
                _infoRow('Encashment days', '${leave.encashmentDays} days',
                    Icons.date_range_rounded),
              ],
            ),
          ],
          if (leave.reason.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            _textCard(cardColor, 'Reason', leave.reason, Icons.notes_rounded),
          ],
          if (leave.adminNote.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            _textCard(
              cardColor,
              leave.status == LeaveModel.statusRejected
                  ? 'HR Rejection Note'
                  : 'HR Note',
              leave.adminNote,
              Icons.info_outline_rounded,
              accent: leave.status == LeaveModel.statusRejected
                  ? AppTheme.error
                  : AppTheme.primaryAccent,
            ),
          ],
          const SizedBox(height: 14),
          _attachmentsCard(context, cardColor),
        ],
      ),
    );
  }

  Widget _summaryCard(Color statusColor) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryAccent,
              AppTheme.primaryAccent.withValues(alpha: 0.78),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: AppTheme.primaryAccent.withValues(alpha: 0.22),
                blurRadius: 12,
                offset: const Offset(0, 5))
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(Icons.beach_access_rounded,
                  color: Colors.white, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(leave.typeLabel,
                      style: GoogleFonts.hindSiliguri(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text('${leave.totalDays} calendar day${leave.totalDays == 1 ? '' : 's'}',
                      style: GoogleFonts.hindSiliguri(
                          color: Colors.white.withValues(alpha: 0.82),
                          fontSize: 13)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(leave.statusLabel,
                  style: GoogleFonts.hindSiliguri(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );

  Widget _sectionCard(
    Color cardColor, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) =>
      Container(
        padding: const EdgeInsets.fromLTRB(16, 15, 16, 8),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: AppTheme.divider.withValues(alpha: 0.7)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: AppTheme.primaryAccent),
                const SizedBox(width: 8),
                Text(title,
                    style: GoogleFonts.hindSiliguri(
                        fontSize: 15, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      );

  Widget _infoRow(String label, String value, IconData icon) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 17, color: AppTheme.textGrey),
            const SizedBox(width: 10),
            SizedBox(
              width: 105,
              child: Text(label,
                  style: GoogleFonts.hindSiliguri(
                      fontSize: 12, color: AppTheme.textGrey)),
            ),
            Expanded(
              child: Text(value,
                  textAlign: TextAlign.right,
                  style: GoogleFonts.hindSiliguri(
                      fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );

  Widget _textCard(Color cardColor, String title, String text, IconData icon,
          {Color accent = AppTheme.primaryAccent}) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: accent.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: accent),
                const SizedBox(width: 8),
                Text(title,
                    style: GoogleFonts.hindSiliguri(
                        fontSize: 15, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 10),
            Text(text,
                style: GoogleFonts.hindSiliguri(
                    fontSize: 13, color: AppTheme.textGrey, height: 1.45)),
          ],
        ),
      );

  Widget _attachmentsCard(BuildContext context, Color cardColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppTheme.divider.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.photo_library_outlined,
                  size: 18, color: AppTheme.primaryAccent),
              const SizedBox(width: 8),
              Text('Supporting Photos',
                  style: GoogleFonts.hindSiliguri(
                      fontSize: 15, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          if (leave.attachments.isEmpty)
            Text('No supporting photo attached.',
                style: GoogleFonts.hindSiliguri(
                    fontSize: 13, color: AppTheme.textGrey))
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: leave.attachments.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.2,
              ),
              itemBuilder: (_, index) {
                final path = leave.attachments[index];
                return GestureDetector(
                  onTap: () => _openPhoto(context, path),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: _image(path, fit: BoxFit.cover),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _image(String path, {BoxFit fit = BoxFit.contain}) {
    final isRemote = path.startsWith('http://') || path.startsWith('https://');
    return isRemote
        ? Image.network(path,
            fit: fit,
            errorBuilder: (_, __, ___) => _imageError())
        : Image.file(File(path),
            fit: fit,
            errorBuilder: (_, __, ___) => _imageError());
  }

  Widget _imageError() => Container(
        color: AppTheme.primaryBg,
        alignment: Alignment.center,
        child: const Icon(Icons.broken_image_outlined,
            size: 30, color: AppTheme.textGrey),
      );

  void _openPhoto(BuildContext context, String path) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text('Supporting Photo',
                style: GoogleFonts.hindSiliguri(color: Colors.white)),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 4,
              child: _image(path),
            ),
          ),
        ),
      ),
    );
  }
}