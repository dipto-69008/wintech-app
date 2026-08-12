import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../models/user_model.dart';
import '../../services/local_storage_service.dart';

class EmployeeTypeScreen extends StatefulWidget {
  const EmployeeTypeScreen({super.key});

  @override
  State<EmployeeTypeScreen> createState() => _EmployeeTypeScreenState();
}

enum _Step { category, subRole, locating }

class _EmployeeTypeScreenState extends State<EmployeeTypeScreen> {
  _Step _step = _Step.category;
  String? _category;
  Future<void> _selectCategory(String category) async {
    setState(() => _category = category);
    if (category == 'distributor') {
      await _finish(UserModel.roleInvestor, 'investor');
    } else {
      setState(() => _step = _Step.subRole);
    }
  }

  Future<void> _selectSubRole(String role) async {
    await _finish(role, 'zero');
  }

  Future<void> _finish(String role, String investorType) async {
    setState(() => _step = _Step.locating);
    await _requestLocationPermission();

    final current = await LocalStorageService.getCurrentUser();
    await LocalStorageService.saveUserProfile(
      name: current?.name ?? '',
      email: current?.email ?? '',
      phone: current?.phone ?? '',
      company: current?.company ?? '',
      designation: current?.designation ?? '',
      role: role,
      zela: current?.zela ?? '',
      myReferralCode: current?.myReferralCode ?? '',
      referredByCode: current?.referredByCode ?? '',
      investorType: investorType,
    );

    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/home');
  }

  Future<void> _requestLocationPermission() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        child: _step == _Step.locating
            ? _locatingView()
            : _step == _Step.subRole
                ? _subRoleView()
                : _categoryView(),
      ),
    );
  }

  Widget _categoryView() {
    return Column(
      key: const ValueKey('category'),
      children: [
        // Header
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: AppTheme.primaryAccent,
            borderRadius:
                BorderRadius.vertical(bottom: Radius.circular(32)),
          ),
          padding: EdgeInsets.fromLTRB(
              24,
              MediaQuery.of(context).padding.top + 20,
              24,
              32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.person_pin_rounded,
                    color: Colors.white, size: 28),
              ),
              const SizedBox(height: 16),
              Text('Select Your Role',
                  style: GoogleFonts.hindSiliguri(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
              const SizedBox(height: 6),
              Text('Choose your category before getting started',
                  style: GoogleFonts.hindSiliguri(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.75))),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              _categoryCard(
                icon: Icons.storefront_rounded,
                iconColor: AppTheme.primaryAccent,
                title: 'Sales Representative (SR)',
                subtitle: 'Order entry, sales management and target tracking',
                onTap: () => _selectCategory('zero'),
              ),
              const SizedBox(height: 16),
              _categoryCard(
                icon: Icons.handshake_rounded,
                iconColor: const Color(0xFF1565C0),
                title: 'Distributor / Partner',
                subtitle: 'Product distribution, investment and partnership',
                onTap: () => _selectCategory('distributor'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _subRoleView() {
    return Column(
      key: const ValueKey('subrole'),
      children: [
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: AppTheme.primaryAccent,
            borderRadius:
                BorderRadius.vertical(bottom: Radius.circular(32)),
          ),
          padding: EdgeInsets.fromLTRB(
              24,
              MediaQuery.of(context).padding.top + 20,
              24,
              32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => setState(() => _step = _Step.category),
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
              const SizedBox(height: 16),
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.badge_rounded,
                    color: Colors.white, size: 28),
              ),
              const SizedBox(height: 16),
              Text('Select Designation',
                  style: GoogleFonts.hindSiliguri(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
              const SizedBox(height: 6),
              Text('What is your role in the sales team?',
                  style: GoogleFonts.hindSiliguri(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.75))),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              _categoryCard(
                icon: Icons.supervisor_account_rounded,
                iconColor: AppTheme.secondaryAccent,
                title: 'Senior SR / Team Leader',
                subtitle: 'Order management, team supervision and target setting',
                onTap: () => _selectSubRole(UserModel.roleTeamLeader),
              ),
              const SizedBox(height: 16),
              _categoryCard(
                icon: Icons.person_rounded,
                iconColor: AppTheme.primaryAccent,
                title: 'SR / Team Member',
                subtitle: 'Order entry and achieving sales targets',
                onTap: () => _selectSubRole(UserModel.roleTeamMember),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _locatingView() {
    return Center(
      key: const ValueKey('locating'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.primaryAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.settings_rounded,
                color: AppTheme.primaryAccent, size: 40),
          ),
          const SizedBox(height: 24),
          const CircularProgressIndicator(color: AppTheme.primaryAccent),
          const SizedBox(height: 20),
          Text('Setting up your profile...',
              style: GoogleFonts.hindSiliguri(
                  fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Please wait',
              style: GoogleFonts.hindSiliguri(
                  fontSize: 13, color: AppTheme.textGrey)),
        ],
      ),
    );
  }

  Widget _categoryCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.darkCard
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.divider),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04), blurRadius: 10)
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.hindSiliguri(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppTheme.darkText
                              : AppTheme.textDark)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: GoogleFonts.hindSiliguri(
                          fontSize: 12,
                          color: AppTheme.textGrey,
                          height: 1.4)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios_rounded,
                color: AppTheme.textGrey, size: 14),
          ],
        ),
      ),
    );
  }
}
