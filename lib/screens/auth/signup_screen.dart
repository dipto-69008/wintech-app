import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../models/user_model.dart';
import '../../services/local_storage_service.dart';
import '../../widgets/custom_text_field.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _referredByCtrl = TextEditingController();
  bool _loading = false;
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  String _selectedZela = UserModel.zelaList.first;

  String _generateReferralCode(String name) {
    final prefix = name.isNotEmpty
        ? name.substring(0, name.length > 3 ? 3 : name.length).toUpperCase()
        : 'USR';
    final num = DateTime.now().millisecondsSinceEpoch % 10000;
    return '$prefix$num';
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 800));
    final user = UserModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim().toLowerCase(),
      phone: _phoneCtrl.text.trim(),
      company: _companyCtrl.text.trim(),
      role: UserModel.roleTeamMember,
      zela: _selectedZela,
      myReferralCode: _generateReferralCode(_nameCtrl.text.trim()),
      referredByCode: _referredByCtrl.text.trim(),
      investorType: '',
    );
    await LocalStorageService.saveCurrentUser(user);
    if (!mounted) return;
    setState(() => _loading = false);
    Navigator.pushReplacementNamed(context, '/otp');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _companyCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _referredByCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryBg,
      appBar: AppBar(
        title: Text('নিবন্ধন করুন',
            style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w700)),
        backgroundColor: AppTheme.primaryAccent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              BanglaTextField(
                controller: _nameCtrl,
                label: 'পূর্ণ নাম *',
                hint: 'আপনার পূর্ণ নাম',
                prefixIcon: Icons.person_outline_rounded,
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'নাম দিন' : null,
              ),
              const SizedBox(height: 14),
              BanglaTextField(
                controller: _emailCtrl,
                label: 'ইমেইল *',
                hint: 'example@gmail.com',
                prefixIcon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: (v) =>
                    (v == null || !v.contains('@')) ? 'সঠিক ইমেইল দিন' : null,
              ),
              const SizedBox(height: 14),
              BanglaTextField(
                controller: _phoneCtrl,
                label: 'মোবাইল নম্বর *',
                hint: '01XXXXXXXXX',
                prefixIcon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                validator: (v) =>
                    (v == null || v.length < 11) ? 'সঠিক নম্বর দিন' : null,
              ),
              const SizedBox(height: 14),
              BanglaTextField(
                controller: _companyCtrl,
                label: 'প্রতিষ্ঠান (ঐচ্ছিক)',
                hint: 'প্রতিষ্ঠানের নাম',
                prefixIcon: Icons.business_outlined,
              ),
              const SizedBox(height: 14),
              // Zela dropdown
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('জেলা *',
                      style: GoogleFonts.hindSiliguri(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _selectedZela,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.location_on_outlined,
                          color: AppTheme.primaryAccent, size: 20),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: AppTheme.divider, width: 1.5)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: AppTheme.divider, width: 1.5)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: AppTheme.primaryAccent, width: 2)),
                    ),
                    style: GoogleFonts.hindSiliguri(
                        fontSize: 14, color: AppTheme.textDark),
                    isExpanded: true,
                    items: UserModel.zelaList
                        .map((z) => DropdownMenuItem(
                            value: z,
                            child: Text(z,
                                style: GoogleFonts.hindSiliguri(
                                    fontSize: 14))))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedZela = v!),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'জেলা বেছে নিন' : null,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              BanglaTextField(
                controller: _referredByCtrl,
                label: 'রেফারেল কোড (ঐচ্ছিক)',
                hint: 'যে রেফার করেছে তার কোড',
                prefixIcon: Icons.card_giftcard_outlined,
              ),
              const SizedBox(height: 14),
              BanglaTextField(
                controller: _passCtrl,
                label: 'পাসওয়ার্ড *',
                hint: '••••••••',
                prefixIcon: Icons.lock_outline_rounded,
                obscureText: _obscurePass,
                suffixIcon: IconButton(
                  icon: Icon(
                      _obscurePass
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppTheme.textGrey,
                      size: 20),
                  onPressed: () =>
                      setState(() => _obscurePass = !_obscurePass),
                ),
                validator: (v) =>
                    (v == null || v.length < 6) ? 'কমপক্ষে ৬ অক্ষর' : null,
              ),
              const SizedBox(height: 14),
              BanglaTextField(
                controller: _confirmCtrl,
                label: 'পাসওয়ার্ড নিশ্চিত করুন *',
                hint: '••••••••',
                prefixIcon: Icons.lock_outline_rounded,
                obscureText: _obscureConfirm,
                suffixIcon: IconButton(
                  icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppTheme.textGrey,
                      size: 20),
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),
                validator: (v) => v != _passCtrl.text ? 'পাসওয়ার্ড মিলছে না' : null,
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _signup,
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor:
                                  AlwaysStoppedAnimation(Colors.white)),
                        )
                      : Text('নিবন্ধন করুন',
                          style: GoogleFonts.hindSiliguri(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('ইতিমধ্যে অ্যাকাউন্ট আছে? ',
                      style: GoogleFonts.hindSiliguri(
                          fontSize: 14, color: AppTheme.textGrey)),
                  GestureDetector(
                    onTap: () =>
                        Navigator.pushReplacementNamed(context, '/login'),
                    child: Text('লগইন করুন',
                        style: GoogleFonts.hindSiliguri(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryAccent)),
                  ),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
