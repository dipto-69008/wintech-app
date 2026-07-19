import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../models/user_model.dart';
import '../../services/local_storage_service.dart';

class WithdrawalScreen extends StatefulWidget {
  const WithdrawalScreen({super.key});

  @override
  State<WithdrawalScreen> createState() => _WithdrawalScreenState();
}

class _WithdrawalScreenState extends State<WithdrawalScreen> {
  final _bkashCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  UserModel? _user;
  List<Map<String, dynamic>> _history = [];
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _bkashCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final user = await LocalStorageService.getCurrentUser();
    final history = await LocalStorageService.getWithdrawalHistory();
    if (!mounted) return;
    setState(() {
      _user = user;
      _history = history;
      _bkashCtrl.text = user?.phone ?? '';
      _loading = false;
    });
  }

  String _formatTaka(double v) {
    if (v >= 100000) return '৳${(v / 100000).toStringAsFixed(1)} লক্ষ';
    if (v >= 1000) return '৳${(v / 1000).toStringAsFixed(1)}K';
    return '৳${v.toStringAsFixed(0)}';
  }

  Future<void> _submit() async {
    final bkash = _bkashCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    final pending = _user?.pendingCommission ?? 0;

    if (bkash.length < 11) {
      _snack('সঠিক বিকাশ নম্বর দিন');
      return;
    }
    if (amount <= 0) {
      _snack('উইথড্র পরিমাণ দিন');
      return;
    }
    if (amount > pending) {
      _snack('পর্যাপ্ত ব্যালেন্স নেই');
      return;
    }

    setState(() => _submitting = true);
    await LocalStorageService.requestWithdrawal(
        bkashNumber: bkash, amount: amount);
    await _load();
    if (!mounted) return;
    setState(() => _submitting = false);
    _amountCtrl.clear();
    _showSuccess();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.hindSiliguri()),
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppTheme.error,
    ));
  }

  void _showSuccess() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 10),
          const Icon(Icons.check_circle_rounded,
              color: AppTheme.success, size: 56),
          const SizedBox(height: 14),
          Text('অনুরোধ সফল হয়েছে!',
              style: GoogleFonts.hindSiliguri(
                  fontSize: 17, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text('আপনার উইথড্র অনুরোধ পাঠানো হয়েছে। শীঘ্রই বিকাশে পাঠানো হবে।',
              style: GoogleFonts.hindSiliguri(
                  fontSize: 13, color: AppTheme.textGrey, height: 1.5),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryAccent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('ঠিক আছে',
                  style: GoogleFonts.hindSiliguri(
                      fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
        ]),
      ),
    );
  }

  Color _statusColor(String s) {
    if (s == 'সম্পন্ন') return AppTheme.success;
    if (s == 'বাতিল') return AppTheme.error;
    return AppTheme.warning;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pending = _user?.pendingCommission ?? 0;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('উইথড্র',
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
                // ── Balance Card ─────────────────────────────────────
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
                      Row(children: [
                        const Icon(Icons.account_balance_wallet_rounded,
                            color: Colors.white70, size: 18),
                        const SizedBox(width: 8),
                        Text('উইথড্রযোগ্য ব্যালেন্স',
                            style: GoogleFonts.hindSiliguri(
                                fontSize: 13, color: Colors.white70)),
                      ]),
                      const SizedBox(height: 8),
                      Text(
                        _formatTaka(pending),
                        style: GoogleFonts.hindSiliguri(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'মোট অর্জিত: ${_formatTaka(_user?.totalCommission ?? 0)}',
                        style: GoogleFonts.hindSiliguri(
                            fontSize: 12, color: Colors.white60),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Form ─────────────────────────────────────────────
                Text('💸 উইথড্র অনুরোধ',
                    style: GoogleFonts.hindSiliguri(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppTheme.darkText : AppTheme.textDark)),
                const SizedBox(height: 14),

                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkCard : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black
                              .withValues(alpha: isDark ? 0.2 : 0.05),
                          blurRadius: 8)
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // bKash number
                      _fieldLabel('বিকাশ নম্বর'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _bkashCtrl,
                        keyboardType: TextInputType.phone,
                        style: GoogleFonts.hindSiliguri(fontSize: 15),
                        decoration: _deco(
                          hint: '01XXXXXXXXX',
                          icon: Icons.phone_android_rounded,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Amount
                      _fieldLabel('পরিমাণ (৳)'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _amountCtrl,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.hindSiliguri(fontSize: 15),
                        decoration: _deco(
                          hint: 'সর্বোচ্চ ${_formatTaka(pending)}',
                          icon: Icons.currency_exchange_rounded,
                          isDark: isDark,
                          prefix: '৳ ',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(children: [
                        const Icon(Icons.info_outline_rounded,
                            size: 14, color: AppTheme.secondaryAccent),
                        const SizedBox(width: 6),
                        Text('সর্বনিম্ন উইথড্র: ৳৫০০',
                            style: GoogleFonts.hindSiliguri(
                                fontSize: 12,
                                color: isDark
                                    ? AppTheme.darkTextGrey
                                    : AppTheme.textGrey)),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => _amountCtrl.text =
                              pending.toStringAsFixed(0),
                          child: Text('সর্বোচ্চ',
                              style: GoogleFonts.hindSiliguri(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primaryAccent)),
                        ),
                      ]),
                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: _submitting ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryAccent,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: _submitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation(
                                          Colors.white)))
                              : const Icon(Icons.send_rounded,
                                  color: Colors.white),
                          label: Text('উইথড্র করুন',
                              style: GoogleFonts.hindSiliguri(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── History ──────────────────────────────────────────
                Text('📜 উইথড্র ইতিহাস',
                    style: GoogleFonts.hindSiliguri(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppTheme.darkText : AppTheme.textDark)),
                const SizedBox(height: 12),

                if (_history.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkCard : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(children: [
                      Icon(Icons.history_rounded,
                          size: 40,
                          color: AppTheme.primaryAccent.withValues(alpha: 0.3)),
                      const SizedBox(height: 10),
                      Text('কোনো উইথড্র ইতিহাস নেই',
                          style: GoogleFonts.hindSiliguri(
                              fontSize: 13,
                              color: isDark
                                  ? AppTheme.darkTextGrey
                                  : AppTheme.textGrey)),
                    ]),
                  )
                else
                  ..._history.map((w) {
                    final amount =
                        (w['amount'] as num?)?.toDouble() ?? 0;
                    final bkash = w['bkashNumber'] as String? ?? '';
                    final status = w['status'] as String? ?? 'অপেক্ষমাণ';
                    final date =
                        DateTime.tryParse(w['date'] as String? ?? '') ??
                            DateTime.now();
                    final sc = _statusColor(status);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkCard : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black
                                  .withValues(alpha: isDark ? 0.2 : 0.04),
                              blurRadius: 6)
                        ],
                      ),
                      child: Row(children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: sc.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.mobile_friendly_rounded,
                              color: sc, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('বিকাশ: $bkash',
                                  style: GoogleFonts.hindSiliguri(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? AppTheme.darkText
                                          : AppTheme.textDark)),
                              Text(
                                '${date.day}/${date.month}/${date.year}',
                                style: GoogleFonts.hindSiliguri(
                                    fontSize: 12,
                                    color: isDark
                                        ? AppTheme.darkTextGrey
                                        : AppTheme.textGrey),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(_formatTaka(amount),
                                style: GoogleFonts.hindSiliguri(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.primaryAccent)),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: sc.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(status,
                                  style: GoogleFonts.hindSiliguri(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: sc)),
                            ),
                          ],
                        ),
                      ]),
                    );
                  }),

                const SizedBox(height: 40),
              ],
            ),
    );
  }

  Widget _fieldLabel(String t) => Text(t,
      style: GoogleFonts.hindSiliguri(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.darkText
              : AppTheme.textDark));

  InputDecoration _deco({
    required String hint,
    required IconData icon,
    required bool isDark,
    String? prefix,
  }) =>
      InputDecoration(
        hintText: hint,
        hintStyle:
            GoogleFonts.hindSiliguri(fontSize: 14, color: AppTheme.textGrey),
        prefixIcon: Icon(icon, color: AppTheme.primaryAccent, size: 20),
        prefixText: prefix,
        prefixStyle: GoogleFonts.hindSiliguri(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppTheme.primaryAccent),
        filled: true,
        fillColor: isDark ? AppTheme.darkBg : AppTheme.primaryBg,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: AppTheme.primaryAccent, width: 2)),
      );
}
