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

  String _appRole(dynamic raw) {
    final role = raw?.toString().trim().toLowerCase() ?? '';
    if (role.contains('super')) return UserModel.roleSuperAdmin;
    if (role == 'admin' || role.contains('administrator')) {
      return UserModel.roleAdmin;
    }
    if (role.contains('leader')) return UserModel.roleTeamLeader;
    if (role.contains('investor')) return UserModel.roleInvestor;
    if (role.contains('customer')) return UserModel.roleCustomer;
    return UserModel.roleTeamMember;
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final identifier = _emailCtrl.text.trim();
    // Trim to guard against invisible spaces added by mobile keyboards
    // (autocomplete often appends a trailing space) — a common cause of
    // "Invalid email or password" even when the typed password looks right.
    final password = _passCtrl.text.trim();

    // 1) Try real ERP login — real-time connection to the ERP database.
    try {
      final erpUser = await ApiService.login(identifier, password);
      final user = UserModel(
        id: erpUser['id']?.toString() ?? '',
        name: erpUser['name']?.toString() ?? identifier,
        email: erpUser['email']?.toString() ?? identifier,
         phone: erpUser['contactNo']?.toString() ??
             erpUser['phone']?.toString() ?? '',
         company: erpUser['company']?.toString() ?? '',
        role: _appRole(erpUser['role']),
        designation: erpUser['designation']?.toString() ?? '',
        myReferralCode: erpUser['employeeCode']?.toString() ?? '',
        branch: erpUser['areaName']?.toString() ??
            erpUser['branchName']?.toString() ?? '',
        areaName: erpUser['areaName']?.toString() ??
            erpUser['branchName']?.toString() ?? '',
        zoneName: erpUser['zoneName']?.toString() ?? '',
        zela: erpUser['zoneName']?.toString() ?? '',
      );
      await LocalStorageService.saveCurrentUser(user);
      if (!mounted) return;
      setState(() => _loading = false);
      Navigator.pushReplacementNamed(context, '/otp');
      return;
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.message,
            style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600)),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not connect to the ERP. Please try again.'),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
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
                      label: 'Employee ID / Email',
                      hint: 'e.g. SR-001 or email@wintech.com',
                      prefixIcon: Icons.badge_outlined,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      enableSuggestions: false,
                      textCapitalization: TextCapitalization.none,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Enter your Employee ID or Email' : null,
                    ),
                    const SizedBox(height: 16),
                    BanglaTextField(
                      controller: _passCtrl,
                      label: 'Password',
                      hint: '••••••••',
                      prefixIcon: Icons.lock_outline_rounded,
                      obscureText: _obscurePass,
                      autocorrect: false,
                      enableSuggestions: false,
                      textCapitalization: TextCapitalization.none,
                      keyboardType: TextInputType.visiblePassword,
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

}
