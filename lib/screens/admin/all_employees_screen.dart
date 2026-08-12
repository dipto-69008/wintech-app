import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../models/user_model.dart';
import '../../services/local_storage_service.dart';

class AllEmployeesScreen extends StatefulWidget {
  const AllEmployeesScreen({super.key});

  @override
  State<AllEmployeesScreen> createState() => _AllEmployeesScreenState();
}

class _AllEmployeesScreenState extends State<AllEmployeesScreen> {
  List<UserModel> _all = [];
  List<UserModel> _filtered = [];
  String? _selectedDistrict;
  String _search = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final employees = await LocalStorageService.getAllEmployees();
    if (!mounted) return;
    setState(() {
      _all = employees;
      _filtered = employees;
      _loading = false;
    });
  }

  void _applyFilter() {
    setState(() {
      _filtered = _all.where((e) {
        final matchDistrict =
            _selectedDistrict == null || e.zela == _selectedDistrict;
        final matchSearch = _search.isEmpty ||
            e.name.toLowerCase().contains(_search.toLowerCase()) ||
            e.phone.contains(_search) ||
            e.role.contains(_search);
        return matchDistrict && matchSearch;
      }).toList();
    });
  }

  List<String> get _districts {
    final set = <String>{};
    for (final e in _all) {
      if (e.zela.isNotEmpty) set.add(e.zela);
    }
    final list = set.toList()..sort();
    return list;
  }

  Color _roleColor(String role) {
    switch (role) {
      case UserModel.roleSuperAdmin:
        return const Color(0xFF7B1FA2);
      case UserModel.roleAdmin:
        return const Color(0xFF1565C0);
      case UserModel.roleTeamLeader:
        return AppTheme.primaryAccent;
      default:
        return AppTheme.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('All Employees',
            style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w700)),
        backgroundColor: AppTheme.primaryAccent,
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${_filtered.length} members',
                    style: GoogleFonts.hindSiliguri(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryAccent))
          : Column(
              children: [
                // ── Search + Filter ────────────────────────────────────
                Container(
                  color: isDark ? AppTheme.darkCard : Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(
                    children: [
                      TextField(
                        style: GoogleFonts.hindSiliguri(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Search by name or number...',
                          hintStyle: GoogleFonts.hindSiliguri(
                              fontSize: 14, color: AppTheme.textGrey),
                          prefixIcon: const Icon(Icons.search_rounded,
                              color: AppTheme.primaryAccent, size: 20),
                          filled: true,
                          fillColor: isDark
                              ? AppTheme.darkBg
                              : AppTheme.primaryBg,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 10),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none),
                        ),
                        onChanged: (v) {
                          _search = v;
                          _applyFilter();
                        },
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 36,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            _filterChip('All Districts', null, isDark),
                            ..._districts
                                .map((d) => _filterChip(d, d, isDark)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // ── List ──────────────────────────────────────────────
                Expanded(
                  child: _filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.people_outline_rounded,
                                  size: 52,
                                  color: AppTheme.primaryAccent
                                      .withValues(alpha: 0.3)),
                              const SizedBox(height: 12),
                              Text('No employees found',
                                  style: GoogleFonts.hindSiliguri(
                                      fontSize: 15,
                                      color: isDark
                                          ? AppTheme.darkTextGrey
                                          : AppTheme.textGrey)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) =>
                              _employeeCard(_filtered[i], isDark),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _filterChip(String label, String? value, bool isDark) {
    final selected = _selectedDistrict == value;
    return GestureDetector(
      onTap: () {
        _selectedDistrict = value;
        _applyFilter();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppTheme.primaryAccent
                : (isDark ? AppTheme.darkTextGrey : AppTheme.divider),
          ),
        ),
        child: Text(label,
            style: GoogleFonts.hindSiliguri(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                color: selected
                    ? Colors.white
                    : (isDark ? AppTheme.darkText : AppTheme.textDark))),
      ),
    );
  }

  Widget _employeeCard(UserModel e, bool isDark) {
    final roleColor = _roleColor(e.role);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 6)
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: roleColor.withValues(alpha: 0.12),
            child: Text(
              e.name.isNotEmpty ? e.name[0] : '?',
              style: GoogleFonts.hindSiliguri(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: roleColor),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.name,
                    style: GoogleFonts.hindSiliguri(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppTheme.darkText : AppTheme.textDark)),
                const SizedBox(height: 3),
                Row(children: [
                  if (e.zela.isNotEmpty) ...[
                    Icon(Icons.location_on_rounded,
                        size: 12, color: AppTheme.secondaryAccent),
                    const SizedBox(width: 3),
                    Text(e.zela,
                        style: GoogleFonts.hindSiliguri(
                            fontSize: 12,
                            color: isDark
                                ? AppTheme.darkTextGrey
                                : AppTheme.textGrey)),
                    const SizedBox(width: 8),
                  ],
                  if (e.phone.isNotEmpty)
                    Text(e.phone,
                        style: GoogleFonts.hindSiliguri(
                            fontSize: 12,
                            color: isDark
                                ? AppTheme.darkTextGrey
                                : AppTheme.textGrey)),
                ]),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: roleColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(e.role,
                style: GoogleFonts.hindSiliguri(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: roleColor)),
          ),
        ],
      ),
    );
  }
}
