import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../services/local_storage_service.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen>
    with SingleTickerProviderStateMixin {
  final List<TextEditingController> _ctls =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _nodes = List.generate(6, (_) => FocusNode());
  bool _loading = false;
  bool _hasError = false;

  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  static const String _correctCode = '123456';

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    for (final c in _ctls) c.dispose();
    for (final n in _nodes) n.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }

  String get _enteredCode => _ctls.map((c) => c.text).join();

  Future<void> _verify() async {
    if (_enteredCode.length < 6) {
      _triggerError();
      return;
    }
    if (_enteredCode != _correctCode &&
        !RegExp(r'^\d{6}$').hasMatch(_enteredCode)) {
      _triggerError();
      return;
    }
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 700));
    await LocalStorageService.setLoggedIn(true);
    final user = await LocalStorageService.getCurrentUser();
    if (!mounted) return;
    setState(() => _loading = false);
    if (user != null && user.isPendingOnboarding) {
      Navigator.pushReplacementNamed(context, '/employee-type');
    } else {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  void _triggerError() {
    setState(() => _hasError = true);
    _shakeCtrl.forward(from: 0).then((_) {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) setState(() => _hasError = false);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryAccent,
      body: Column(
        children: [
          // ── Top header ─────────────────────────────────────────────
          Expanded(
            flex: 2,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.arrow_back_rounded,
                            color: Colors.white, size: 20),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(Icons.shield_rounded,
                          color: Colors.white, size: 32),
                    ),
                    const SizedBox(height: 16),
                    Text('Verification Code',
                        style: GoogleFonts.hindSiliguri(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                    const SizedBox(height: 6),
                    Text('Enter your 6-digit code',
                        style: GoogleFonts.hindSiliguri(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.75))),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
          ),

          // ── White card ─────────────────────────────────────────────
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              padding: const EdgeInsets.fromLTRB(28, 36, 28, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Enter code',
                      style: GoogleFonts.hindSiliguri(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textGrey)),
                  const SizedBox(height: 20),

                  // OTP boxes
                  AnimatedBuilder(
                    animation: _shakeAnim,
                    builder: (_, child) => Transform.translate(
                      offset: Offset(
                          10 *
                              (0.5 - _shakeAnim.value).abs() *
                              (_shakeAnim.value > 0.5 ? 1 : -1),
                          0),
                      child: child,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(
                          6,
                          (i) => _OtpBox(
                                controller: _ctls[i],
                                focusNode: _nodes[i],
                                hasError: _hasError,
                                onChanged: (val) {
                                  setState(() {});
                                  if (val.isNotEmpty && i < 5) {
                                    _nodes[i + 1].requestFocus();
                                  } else if (val.isEmpty && i > 0) {
                                    _nodes[i - 1].requestFocus();
                                  }
                                  if (i == 5 && val.isNotEmpty) _verify();
                                },
                              )),
                    ),
                  ),

                  if (_hasError) ...[
                    const SizedBox(height: 12),
                    Text('Incorrect code, please try again',
                        style: GoogleFonts.hindSiliguri(
                            fontSize: 13,
                            color: AppTheme.error,
                            fontWeight: FontWeight.w500)),
                  ],

                  const Spacer(),

                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _verify,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryAccent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor:
                                      AlwaysStoppedAnimation(Colors.white)),
                            )
                          : Text('Verify',
                              style: GoogleFonts.hindSiliguri(
                                  fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final bool hasError;

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.hasError,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: 48,
      height: 58,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textAlign: TextAlign.center,
        maxLength: 1,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: GoogleFonts.hindSiliguri(
            fontSize: 24, fontWeight: FontWeight.w800,
            color: isDark ? AppTheme.darkText : AppTheme.textDark),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: hasError
              ? AppTheme.error.withValues(alpha: 0.07)
              : (isDark
                  ? AppTheme.darkCard
                  : AppTheme.primaryAccent.withValues(alpha: 0.06)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
                color: hasError
                    ? AppTheme.error.withValues(alpha: 0.5)
                    : AppTheme.divider,
                width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
                color: hasError
                    ? AppTheme.error.withValues(alpha: 0.5)
                    : AppTheme.divider,
                width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
                color: hasError ? AppTheme.error : AppTheme.primaryAccent,
                width: 2.5),
          ),
        ),
        onChanged: onChanged,
      ),
    );
  }
}
