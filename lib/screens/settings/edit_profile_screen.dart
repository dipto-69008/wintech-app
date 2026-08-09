import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../models/user_model.dart';
import '../../services/local_storage_service.dart';
import '../../widgets/custom_text_field.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _designationCtrl = TextEditingController();
  final _thanaCtrl = TextEditingController();
  String _selectedZela = 'Dhaka';
  bool _loading = true;
  bool _saving = false;
  UserModel? _user;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = await LocalStorageService.getCurrentUser();
    if (!mounted) return;
    setState(() {
      _user = user;
      _nameCtrl.text = user?.name ?? '';
      _phoneCtrl.text = user?.phone ?? '';
      _companyCtrl.text = user?.company ?? '';
      _designationCtrl.text = user?.designation ?? '';
      _thanaCtrl.text = user?.thana ?? '';
      _selectedZela = (user?.zela.isNotEmpty == true) ? user!.zela : 'Dhaka';
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_user == null) return;
    setState(() => _saving = true);
    final updated = _user!.copyWith(
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      company: _companyCtrl.text.trim(),
      designation: _designationCtrl.text.trim(),
      zela: _selectedZela,
      thana: _thanaCtrl.text.trim(),
    );
    await LocalStorageService.saveCurrentUser(updated);
    // Also sync legacy profile
    await LocalStorageService.saveUserProfile(
      name: updated.name,
      email: updated.email,
      phone: updated.phone,
      company: updated.company,
      designation: updated.designation,
      role: updated.role,
      zela: updated.zela,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Profile updated!',
          style: GoogleFonts.hindSiliguri()),
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppTheme.success,
    ));
    Navigator.pop(context, true);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _companyCtrl.dispose();
    _designationCtrl.dispose();
    _thanaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Profile',
            style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w700)),
        backgroundColor: AppTheme.primaryAccent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryAccent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar
                    Center(
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 42,
                            backgroundColor:
                                AppTheme.primaryAccent.withValues(alpha: 0.12),
                            child: Text(
                              _nameCtrl.text.isNotEmpty
                                  ? _nameCtrl.text[0].toUpperCase()
                                  : '?',
                              style: GoogleFonts.hindSiliguri(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.primaryAccent),
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (_user?.email.isNotEmpty == true)
                            Text(_user!.email,
                                style: GoogleFonts.hindSiliguri(
                                    fontSize: 13, color: AppTheme.textGrey)),
                          if (_user?.role.isNotEmpty == true) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryAccent
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(_user!.role,
                                  style: GoogleFonts.hindSiliguri(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.primaryAccent)),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    _sectionLabel('Personal Information'),
                    const SizedBox(height: 12),
                    BanglaTextField(
                      controller: _nameCtrl,
                      label: 'Full Name *',
                      hint: 'Your name',
                      prefixIcon: Icons.person_outline_rounded,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Please enter a name' : null,
                    ),
                    const SizedBox(height: 12),
                    BanglaTextField(
                      controller: _phoneCtrl,
                      label: 'Mobile Number',
                      hint: '01XXXXXXXXX',
                      prefixIcon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    BanglaTextField(
                      controller: _companyCtrl,
                      label: 'Company',
                      hint: 'Company name',
                      prefixIcon: Icons.business_outlined,
                    ),
                    const SizedBox(height: 12),
                    BanglaTextField(
                      controller: _designationCtrl,
                      label: 'Designation',
                      hint: 'Your designation',
                      prefixIcon: Icons.badge_outlined,
                    ),
                    const SizedBox(height: 20),

                    _sectionLabel('District'),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _selectedZela,
                      isExpanded: true,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.location_city_rounded,
                            color: AppTheme.primaryAccent, size: 20),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 14),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: AppTheme.divider)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: AppTheme.divider)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: AppTheme.primaryAccent, width: 2)),
                      ),
                      items: UserModel.zelaList
                          .map((z) => DropdownMenuItem(
                              value: z,
                              child: Text(z,
                                  style: GoogleFonts.hindSiliguri(fontSize: 14))))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedZela = v!),
                    ),
                    const SizedBox(height: 20),

                    _sectionLabel('Thana / Area (Assigned Area)'),
                    const SizedBox(height: 12),
                    BanglaTextField(
                      controller: _thanaCtrl,
                      label: 'Thana',
                      hint: 'e.g. Dhanmondi, Mirpur',
                      prefixIcon: Icons.pin_drop_rounded,
                    ),
                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation(
                                        Colors.white)))
                            : const Icon(Icons.save_rounded, color: Colors.white),
                        label: Text('Save Changes',
                            style: GoogleFonts.hindSiliguri(
                                fontSize: 15, fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _sectionLabel(String text) => Row(children: [
    Container(
        width: 4, height: 18,
        decoration: BoxDecoration(
            color: AppTheme.primaryAccent,
            borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 8),
    Text(text,
        style: GoogleFonts.hindSiliguri(
            fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
  ]);
}
