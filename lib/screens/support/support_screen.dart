import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../services/local_storage_service.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  List<Map<String, dynamic>> _tickets = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final tickets = await LocalStorageService.getSupportTickets();
    if (!mounted) return;
    setState(() {
      _tickets = tickets;
      _loading = false;
    });
  }

  void _showCreateTicket() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final problemCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.all(24),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                          color: AppTheme.divider,
                          borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  Text('New Support Ticket',
                      style: GoogleFonts.hindSiliguri(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryAccent)),
                  const SizedBox(height: 4),
                  Text('Describe your issue — we will help you',
                      style: GoogleFonts.hindSiliguri(
                          fontSize: 13, color: AppTheme.textGrey)),
                  const SizedBox(height: 20),
                  _formField(nameCtrl, 'Your Name *', 'Full name',
                      Icons.person_outline_rounded,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Enter name' : null),
                  const SizedBox(height: 12),
                  _formField(emailCtrl, 'Email *', 'example@email.com',
                      Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) => (v == null || !v.contains('@'))
                          ? 'Enter a valid email'
                          : null),
                  const SizedBox(height: 12),
                  _formField(problemCtrl, 'Problem Description *',
                      'Describe your issue in detail...',
                      Icons.bug_report_outlined,
                      maxLines: 5,
                      validator: (v) => (v == null || v.trim().length < 10)
                          ? 'Enter at least 10 characters'
                          : null),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        await LocalStorageService.createSupportTicket(
                          name: nameCtrl.text.trim(),
                          email: emailCtrl.text.trim(),
                          problem: problemCtrl.text.trim(),
                        );
                        if (!mounted) return;
                        Navigator.pop(context);
                        _load();
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Ticket created! We will contact you shortly.',
                              style: GoogleFonts.hindSiliguri()),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: AppTheme.success,
                        ));
                      },
                      icon: const Icon(Icons.send_rounded, color: Colors.white),
                      label: Text('Submit Ticket',
                          style: GoogleFonts.hindSiliguri(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _formField(
    TextEditingController ctrl,
    String label,
    String hint,
    IconData icon, {
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.hindSiliguri(
                fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          style: GoogleFonts.hindSiliguri(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.hindSiliguri(
                fontSize: 13, color: AppTheme.textGrey),
            prefixIcon: Icon(icon, color: AppTheme.primaryAccent, size: 20),
            filled: true,
            fillColor: AppTheme.primaryBg,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.divider)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.divider)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppTheme.primaryAccent, width: 2)),
            errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppTheme.error, width: 1.5)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryBg,
      appBar: AppBar(
        title: Text('Support & Tickets',
            style:
                GoogleFonts.hindSiliguri(fontWeight: FontWeight.w700)),
        backgroundColor: AppTheme.primaryAccent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryAccent))
          : Column(
              children: [
                // Info banner
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [
                      AppTheme.primaryAccent,
                      Color(0xFFB03040),
                    ]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(children: [
                    const Icon(Icons.headset_mic_rounded,
                        color: Colors.white, size: 36),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('We are here to help',
                              style: GoogleFonts.hindSiliguri(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                          Text('Open a ticket and we will resolve it as soon as possible',
                              style: GoogleFonts.hindSiliguri(
                                  fontSize: 12, color: Colors.white70)),
                        ],
                      ),
                    ),
                  ]),
                ),

                // Tickets header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(children: [
                    Expanded(
                      child: Text('My Tickets (${_tickets.length})',
                          style: GoogleFonts.hindSiliguri(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                  ]),
                ),
                const SizedBox(height: 8),

                Expanded(
                  child: _tickets.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.inbox_rounded,
                                  size: 64,
                                  color: AppTheme.primaryAccent
                                      .withValues(alpha: 0.3)),
                              const SizedBox(height: 12),
                              Text('No tickets yet',
                                  style: GoogleFonts.hindSiliguri(
                                      fontSize: 15, color: AppTheme.textGrey)),
                              const SizedBox(height: 6),
                              Text('Use the button below to report an issue',
                                  style: GoogleFonts.hindSiliguri(
                                      fontSize: 13, color: AppTheme.textGrey)),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          color: AppTheme.primaryAccent,
                          onRefresh: _load,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _tickets.length,
                            itemBuilder: (_, i) =>
                                _buildTicketCard(_tickets[i]),
                          ),
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateTicket,
        backgroundColor: AppTheme.primaryAccent,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('New Ticket',
            style: GoogleFonts.hindSiliguri(
                color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildTicketCard(Map<String, dynamic> ticket) {
    final status = ticket['status'] as String? ?? 'Pending';
    final createdAt = ticket['createdAt'] != null
        ? DateTime.tryParse(ticket['createdAt'].toString())
        : null;
    final dateStr = createdAt != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(createdAt)
        : '';

    Color statusColor;
    switch (status) {
      case 'Resolved':
      case 'resolved':
        statusColor = AppTheme.success;
        break;
      case 'In Progress':
      case 'in_progress':
        statusColor = AppTheme.warning;
        break;
      default:
        statusColor = AppTheme.textGrey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: AppTheme.primaryAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.confirmation_number_rounded,
                  color: AppTheme.primaryAccent, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ticket['name']?.toString() ?? '',
                      style: GoogleFonts.hindSiliguri(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                  Text(ticket['email']?.toString() ?? '',
                      style: GoogleFonts.hindSiliguri(
                          fontSize: 12, color: AppTheme.textGrey)),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(status,
                  style: GoogleFonts.hindSiliguri(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: statusColor)),
            ),
          ]),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(ticket['problem']?.toString() ?? '',
                style: GoogleFonts.hindSiliguri(
                    fontSize: 13, height: 1.5),
                maxLines: 3,
                overflow: TextOverflow.ellipsis),
          ),
          if (dateStr.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.schedule_rounded,
                  size: 12, color: AppTheme.textGrey),
              const SizedBox(width: 4),
              Text(dateStr,
                  style: GoogleFonts.hindSiliguri(
                      fontSize: 11, color: AppTheme.textGrey)),
            ]),
          ],
        ],
      ),
    );
  }
}
