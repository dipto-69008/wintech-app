import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../services/local_storage_service.dart';
import '../../widgets/custom_text_field.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscurePass = true;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final email = _emailCtrl.text.trim().toLowerCase();
    final password = _passCtrl.text;

    // 1) Try real ERP login — real-time connection to the ERP database.
    try {
      final erpUser = await ApiService.login(email, password);
      final user = UserModel(
        id: erpUser['id']?.toString() ?? '',
        name: erpUser['name']?.toString() ?? email.split('@').first,
        email: email,
        role: UserModel.roleTeamMember, // SR / employee
        myReferralCode: erpUser['employeeCode']?.toString() ?? '',
        branch: erpUser['branchName']?.toString() ?? '',
        zela: erpUser['areaName']?.toString() ?? '',
      );
      await LocalStorageService.saveCurrentUser(user);
      if (!mounted) return;
      setState(() => _loading = false);
      Navigator.pushReplacementNamed(context, '/otp');
      return;
    } on ApiException catch (e) {
      // Wrong credentials on ERP — fall through to demo accounts only if it's a demo email
      if (!LocalStorageService.isDemoAccount(email)) {
        if (!mounted) return;
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.message,
              style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600)),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ));
        return;
      }
    } catch (_) {
      // Network/server unreachable — offline mode, demo accounts still work
    }

    // 2) Demo/offline fallback
    final demoUser = LocalStorageService.getDemoUser(email);
    if (demoUser != null) {
      await LocalStorageService.saveCurrentUser(demoUser);
    } else {
      await LocalStorageService.saveUserProfile(
        name: email.split('@').first,
        email: email,
      );
    }

    if (!mounted) return;
    setState(() => _loading = false);
    Navigator.pushReplacementNamed(context, '/otp');
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 40),
              // Logo
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                        color: AppTheme.primaryAccent.withValues(alpha: 0.3),
                        blurRadius: 20)
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  'assets/images/wintech.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Center(
                    child: Text(
                      'WA',
                      style: GoogleFonts.hindSiliguri(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primaryAccent),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Wintech Agro',
                  style: GoogleFonts.hindSiliguri(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.primaryAccent,
                      letterSpacing: 2)),
              const SizedBox(height: 4),
              Text('Sign in to your account',
                  style: GoogleFonts.hindSiliguri(
                      fontSize: 14, color: AppTheme.textGrey)),
              const SizedBox(height: 32),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    BanglaTextField(
                      controller: _emailCtrl,
                      label: 'Email',
                      hint: 'example@gmail.com',
                      prefixIcon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Enter email' : null,
                    ),
                    const SizedBox(height: 16),
                    BanglaTextField(
                      controller: _passCtrl,
                      label: 'Password',
                      hint: '••••••••',
                      prefixIcon: Icons.lock_outline_rounded,
                      obscureText: _obscurePass,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePass
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppTheme.textGrey,
                          size: 20,
                        ),
                        onPressed: () =>
                            setState(() => _obscurePass = !_obscurePass),
                      ),
                      validator: (v) =>
                          (v == null || v.length < 4) ? 'Enter password' : null,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _login,
                        child: _loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation(
                                        Colors.white)),
                              )
                            : Text('Login',
                                style: GoogleFonts.hindSiliguri(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Demo credentials
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryAccent.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppTheme.primaryAccent
                                .withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Icon(Icons.info_outline_rounded,
                                size: 16, color: AppTheme.primaryAccent),
                            const SizedBox(width: 6),
                            Text('Demo Accounts — Wintech Agro',
                                style: GoogleFonts.hindSiliguri(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primaryAccent)),
                          ]),
                          const SizedBox(height: 8),
                          _demoRow('Admin', 'admin@gmail.com'),
                          _demoRow('SR / Employee', 'sr@wintech.com'),
                          _demoRow('Customer', 'customer@gmail.com'),
                          const SizedBox(height: 4),
                          Text('Password: anything | OTP: 123456',
                              style: GoogleFonts.hindSiliguri(
                                  fontSize: 11,
                                  color: AppTheme.textGrey,
                                  fontStyle: FontStyle.italic)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _demoRow(String role, String email) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: GestureDetector(
        onTap: () => setState(() => _emailCtrl.text = email),
        child: Row(
          children: [
            Text('• $role: ',
                style: GoogleFonts.hindSiliguri(
                    fontSize: 12, color: AppTheme.textGrey)),
            Text(email,
                style: GoogleFonts.hindSiliguri(
                    fontSize: 12,
                    color: AppTheme.primaryAccent,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
