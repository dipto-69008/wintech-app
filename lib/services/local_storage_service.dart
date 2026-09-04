import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/expense_model.dart';
import '../models/leave_model.dart';
import '../models/order_model.dart';
import '../models/payment_collection_model.dart';
import '../models/survey_model.dart';
import '../models/tutorial_model.dart';
import '../models/user_model.dart';
import '../models/target_model.dart';

class LocalStorageService {
  static const _keyTutorials = 'tutorials';
  static const _keyLoggedIn = 'isLoggedIn';
  static const _keyCurrentUser = 'currentUser';
  static const _keyDarkMode = 'darkMode';
  static const _keyTeamMembers = 'teamMembers';

  // ── Demo accounts ────────────────────────────────────────────────────
  static const Map<String, Map<String, String>> _demoAccounts = {
    'superadmin@gmail.com': {
      'name': 'Super Admin',
      'role': UserModel.roleSuperAdmin,
      'id': 'demo-superadmin',
      'referral': 'SADM001',
      'designation': 'Super Admin',
    },
    'admin@gmail.com': {
      'name': 'Admin User',
      'role': UserModel.roleAdmin,
      'id': 'demo-admin',
      'referral': 'ADM001',
      'designation': 'Admin',
    },
    'teamowner@gmail.com': {
      'name': 'Rahim Uddin (TL)',
      'role': UserModel.roleTeamLeader,
      'id': 'demo-teamleader',
      'referral': 'TL001',
      'designation': 'Team Leader',
    },
    'teammember@gmail.com': {
      'name': 'Karim Hossain (SR)',
      'role': UserModel.roleTeamMember,
      'id': 'demo-teammember',
      'referral': 'TM001',
      'designation': 'Team Member',
    },
    'sr@wintech.com': {
      'name': 'Sales Representative',
      'role': UserModel.roleTeamMember,
      'id': 'demo-sr',
      'referral': 'SR001',
      'branch': 'Gouripur',
      'designation': 'Sales Representative',
    },
    'customer@gmail.com': {
      'name': 'M/s Akhonda Traders',
      'role': UserModel.roleCustomer,
      'id': 'demo-customer',
      'referral': 'CUST001',
    },
  };

  static bool isDemoAccount(String email) =>
      _demoAccounts.containsKey(email.toLowerCase().trim());

  static UserModel? getDemoUser(String email) {
    final data = _demoAccounts[email.toLowerCase().trim()];
    if (data == null) return null;
    final role = data['role']!;
    double sales = 0;
    if (role == UserModel.roleTeamLeader) sales = 2500000;
    if (role == UserModel.roleTeamMember) sales = 650000;
    if (role == UserModel.roleAdmin) sales = 6000000;
    if (role == UserModel.roleSuperAdmin) sales = 8000000;
    final commissionRatePreview = sales >= 5000000
        ? 0.03
        : sales >= 2000000
            ? 0.025
            : sales >= 500000
                ? 0.02
                : 0.015;
    final totalCommission = sales * commissionRatePreview;
    // SR fields
    final double targetAmount =
        (role == UserModel.roleTeamMember || role == UserModel.roleTeamLeader)
            ? 500000
            : 0;
    final double achievedAmount =
        (role == UserModel.roleTeamMember || role == UserModel.roleTeamLeader)
            ? sales * 0.3
            : 0;
    // Customer credit fields
    final double creditLimit =
        role == UserModel.roleCustomer ? 500000 : 0;
    final double creditUsed =
        role == UserModel.roleCustomer ? 175000 : 0;
    return UserModel(
      id: data['id']!,
      name: data['name']!,
      email: email.toLowerCase().trim(),
      role: role,
      designation: data['designation'] ?? '',
      myReferralCode: data['referral']!,
      zela: 'Mymensingh',
      thana: 'Sadar',
      branch: data['branch'] ?? '',
      areaName: data['branch'] ?? '',
      zoneName: data['branch'] == null || data['branch']!.isEmpty
          ? ''
          : 'Mymensingh',
      totalSales: sales,
      totalCommission: totalCommission,
      pendingCommission: totalCommission * 0.3,
      targetAmount: targetAmount,
      achievedAmount: achievedAmount,
      creditLimit: creditLimit,
      creditUsed: creditUsed,
    );
  }

  // ── Auth ──────────────────────────────────────────────────────────────
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyLoggedIn) ?? false;
  }

  static Future<void> setLoggedIn(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyLoggedIn, value);
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyLoggedIn, false);
  }

  // ── Current User ──────────────────────────────────────────────────────
  static Future<void> saveCurrentUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCurrentUser, jsonEncode(user.toMap()));
  }

  static Future<UserModel?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyCurrentUser);
    if (raw == null) return null;
    return UserModel.fromMap(Map<String, dynamic>.from(jsonDecode(raw)));
  }

  // Legacy profile helpers (backward compat)
  static Future<void> saveUserProfile({
    required String name,
    required String email,
    String phone = '',
    String company = '',
    String designation = '',
    String role = '',
    String zela = '',
    String myReferralCode = '',
    String referredByCode = '',
    String? investorType,
  }) async {
    final existing = await getCurrentUser();
    final user = UserModel(
      id: existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      email: email,
      phone: phone,
      company: company,
      designation: designation,
      role: role.isNotEmpty ? role : (existing?.role ?? UserModel.roleTeamMember),
      zela: zela.isNotEmpty ? zela : (existing?.zela ?? ''),
      thana: existing?.thana ?? '',
      myReferralCode: myReferralCode.isNotEmpty
          ? myReferralCode
          : (existing?.myReferralCode ?? ''),
      referredByCode: referredByCode.isNotEmpty
          ? referredByCode
          : (existing?.referredByCode ?? ''),
      teamId: existing?.teamId ?? '',
      teamName: existing?.teamName ?? '',
      totalSales: existing?.totalSales ?? 0,
      totalCommission: existing?.totalCommission ?? 0,
      pendingCommission: existing?.pendingCommission ?? 0,
      targetAmount: existing?.targetAmount ?? 0,
      achievedAmount: existing?.achievedAmount ?? 0,
      creditLimit: existing?.creditLimit ?? 0,
      creditUsed: existing?.creditUsed ?? 0,
      customerPropertyId: existing?.customerPropertyId ?? '',
      customerPropertyTitle: existing?.customerPropertyTitle ?? '',
      investorType: investorType ?? existing?.investorType ?? '',
    );
    await saveCurrentUser(user);
  }

  static Future<Map<String, String>> getUserProfile() async {
    final user = await getCurrentUser();
    return {
      'name': user?.name ?? '',
      'email': user?.email ?? '',
      'phone': user?.phone ?? '',
      'company': user?.company ?? '',
      'designation': user?.designation ?? '',
      'role': user?.role ?? '',
      'zela': user?.zela ?? '',
      'myReferralCode': user?.myReferralCode ?? '',
      'referredByCode': user?.referredByCode ?? '',
    };
  }

  // ── Team members (demo list) ──────────────────────────────────────────
  static Future<List<UserModel>> getTeamMembers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyTeamMembers);
    if (raw == null) {
      // Return demo team members
      return [
        UserModel(
            id: 'demo-teamleader',
            name: 'Rahim Uddin (TL)',
            email: 'teamowner@gmail.com',
            role: UserModel.roleTeamLeader,
            myReferralCode: 'TL001'),
        UserModel(
            id: 'demo-teammember',
            name: 'Karim Hossain (SR)',
            email: 'teammember@gmail.com',
            role: UserModel.roleTeamMember,
            myReferralCode: 'TM001'),
      ];
    }
    final List<dynamic> list = jsonDecode(raw);
    return list
        .map((e) => UserModel.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  // ── Tutorials ─────────────────────────────────────────────────────────
  static Future<List<TutorialModel>> getTutorials() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyTutorials);
    if (raw == null) return _defaultTutorials();
    final List<dynamic> list = jsonDecode(raw);
    final saved = list
        .map((e) => TutorialModel.fromMap(Map<String, dynamic>.from(e)))
        .toList();
    return saved.isEmpty ? _defaultTutorials() : saved;
  }

  static Future<void> saveTutorial(TutorialModel t) async {
    final list = await getTutorials();
    final idx = list.indexWhere((x) => x.id == t.id);
    if (idx >= 0) {
      list[idx] = t;
    } else {
      list.insert(0, t);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _keyTutorials, jsonEncode(list.map((x) => x.toMap()).toList()));
  }

  static Future<void> deleteTutorial(String id) async {
    final list = await getTutorials();
    list.removeWhere((t) => t.id == id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _keyTutorials, jsonEncode(list.map((x) => x.toMap()).toList()));
  }

  static List<TutorialModel> _defaultTutorials() => [
        TutorialModel(
          id: 'tut-1',
          title: 'Getting Started with the App',
          description: 'A complete guide to using the Wintech Agro app.',
          videoUrl: '',
          category: 'General',
          durationMinutes: 5,
        ),
        TutorialModel(
          id: 'tut-2',
          title: 'How to Place an Order',
          description: 'How to create and submit a new order from the Orders Entry screen.',
          videoUrl: '',
          category: 'Orders',
          durationMinutes: 6,
        ),
        TutorialModel(
          id: 'tut-3',
          title: 'Commission & Sales Reports',
          description: 'How your commission is calculated and where to view sales reports.',
          videoUrl: '',
          category: 'Commission',
          durationMinutes: 7,
        ),
        TutorialModel(
          id: 'tut-4',
          title: 'Target Tracking',
          description: 'How to view your monthly target and tips on achieving it.',
          videoUrl: '',
          category: 'Target',
          durationMinutes: 5,
        ),
      ];

  // ── Commission / Sales ────────────────────────────────────────────────
  static Future<void> addSaleCommission(double saleAmount) async {
    final user = await getCurrentUser();
    if (user == null) return;
    final commission = saleAmount * user.commissionRate;
    final updated = user.copyWith(
      totalSales: user.totalSales + saleAmount,
      totalCommission: user.totalCommission + commission,
      pendingCommission: user.pendingCommission + commission,
    );
    await saveCurrentUser(updated);
  }

  static Future<void> withdrawCommission() async {
    final user = await getCurrentUser();
    if (user == null) return;
    final updated = user.copyWith(pendingCommission: 0);
    await saveCurrentUser(updated);
  }

  // ── Support Tickets ───────────────────────────────────────────────────
  static const _keyTickets = 'supportTickets';

  static Future<List<Map<String, dynamic>>> getSupportTickets() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyTickets);
    if (raw == null) return [];
    final List<dynamic> list = jsonDecode(raw);
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<void> createSupportTicket({
    required String name,
    required String email,
    required String problem,
    String category = 'General Issue',
  }) async {
    final ticket = {
      'id': 'TKT-${DateTime.now().millisecondsSinceEpoch}',
      'name': name,
      'email': email,
      'category': category,
      'problem': problem,
      'status': 'Pending',
      'createdAt': DateTime.now().toIso8601String(),
    };
    final list = await getSupportTickets();
    list.insert(0, ticket);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTickets, jsonEncode(list));
  }

  static Future<void> saveSupportTicket(Map<String, dynamic> ticket) async {
    final list = await getSupportTickets();
    list.insert(0, ticket);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTickets, jsonEncode(list));
  }

  // ── Theme ─────────────────────────────────────────────────────────────
  static Future<bool> isDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyDarkMode) ?? false;
  }

  static Future<void> setDarkMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDarkMode, value);
  }

  // ── All Employees (admin / super admin) ────────────────────────────────
  static Future<List<UserModel>> getAllEmployees() async {
    return [
      // ── Dhaka ──────────────────────────────────────────────────────────
      UserModel(id: 'emp-01', name: 'Rahim Uddin', email: 'rahim@gmail.com', phone: '01711111001', role: UserModel.roleTeamLeader, zela: 'Dhaka', thana: 'Mirpur', myReferralCode: 'TL001', teamId: 'team-dhaka-a', teamName: 'Dhaka Team Alpha', totalSales: 2500000, totalCommission: 62500, pendingCommission: 20000),
      UserModel(id: 'emp-02', name: 'Karim Hossain', email: 'karim@gmail.com', phone: '01711111002', role: UserModel.roleTeamMember, zela: 'Dhaka', thana: 'Dhanmondi', myReferralCode: 'TM002', teamId: 'team-dhaka-a', teamName: 'Dhaka Team Alpha', totalSales: 650000, totalCommission: 13000, pendingCommission: 5000),
      UserModel(id: 'emp-03', name: 'Salma Begum', email: 'salma@gmail.com', phone: '01711111003', role: UserModel.roleTeamMember, zela: 'Dhaka', thana: 'Uttara', myReferralCode: 'TM003', teamId: 'team-dhaka-a', teamName: 'Dhaka Team Alpha', totalSales: 400000, totalCommission: 6000, pendingCommission: 3000),
      UserModel(id: 'emp-14', name: 'Tanvir Ahmed', email: 'tanvir@gmail.com', phone: '01711111014', role: UserModel.roleTeamMember, zela: 'Dhaka', thana: 'Gulshan', myReferralCode: 'TM014', teamId: 'team-dhaka-a', teamName: 'Dhaka Team Alpha', totalSales: 870000, totalCommission: 17400, pendingCommission: 6500),
      UserModel(id: 'emp-15', name: 'Nahida Parveen', email: 'nahida@gmail.com', phone: '01711111015', role: UserModel.roleTeamMember, zela: 'Dhaka', thana: 'Banani', myReferralCode: 'TM015', teamId: 'team-dhaka-a', teamName: 'Dhaka Team Alpha', totalSales: 540000, totalCommission: 10800, pendingCommission: 4000),
      UserModel(id: 'emp-16', name: 'Sadek Ali', email: 'sadek@gmail.com', phone: '01711111016', role: UserModel.roleTeamLeader, zela: 'Dhaka', thana: 'Bashundhara', myReferralCode: 'TL016', teamId: 'team-dhaka-b', teamName: 'Dhaka Team Beta', totalSales: 3100000, totalCommission: 77500, pendingCommission: 28000),
      UserModel(id: 'emp-17', name: 'Rifat Zaman', email: 'rifat@gmail.com', phone: '01711111017', role: UserModel.roleTeamMember, zela: 'Dhaka', thana: 'Motijheel', myReferralCode: 'TM017', teamId: 'team-dhaka-b', teamName: 'Dhaka Team Beta', totalSales: 720000, totalCommission: 14400, pendingCommission: 5800),
      UserModel(id: 'emp-18', name: 'Sharmin Akter', email: 'sharmin@gmail.com', phone: '01711111018', role: UserModel.roleTeamMember, zela: 'Dhaka', thana: 'Rampura', myReferralCode: 'TM018', teamId: 'team-dhaka-b', teamName: 'Dhaka Team Beta', totalSales: 480000, totalCommission: 7200, pendingCommission: 3100),
      UserModel(id: 'emp-19', name: 'Jubayer Hossain', email: 'jubayer@gmail.com', phone: '01711111019', role: UserModel.roleTeamMember, zela: 'Dhaka', thana: 'Mohammadpur', myReferralCode: 'TM019', teamId: 'team-dhaka-b', teamName: 'Dhaka Team Beta', totalSales: 310000, totalCommission: 4650, pendingCommission: 1800),
      UserModel(id: 'emp-20', name: 'Piyal Chowdhury', email: 'piyal@gmail.com', phone: '01711111020', role: UserModel.roleTeamMember, zela: 'Dhaka', thana: 'Khilgaon', myReferralCode: 'TM020', teamId: 'team-dhaka-b', teamName: 'Dhaka Team Beta', totalSales: 595000, totalCommission: 11900, pendingCommission: 4500),
      // ── Chattogram ──────────────────────────────────────────────────────
      UserModel(id: 'emp-04', name: 'Jamal Ahmed', email: 'jamal@gmail.com', phone: '01711111004', role: UserModel.roleTeamLeader, zela: 'Chattogram', thana: 'Panchlaish', myReferralCode: 'TL004', teamId: 'team-ctg-a', teamName: 'Chattogram Team Alpha', totalSales: 3200000, totalCommission: 80000, pendingCommission: 25000),
      UserModel(id: 'emp-05', name: 'Nasrin Akter', email: 'nasrin@gmail.com', phone: '01711111005', role: UserModel.roleTeamMember, zela: 'Chattogram', thana: 'Halishahar', myReferralCode: 'TM005', teamId: 'team-ctg-a', teamName: 'Chattogram Team Alpha', totalSales: 900000, totalCommission: 18000, pendingCommission: 7000),
      UserModel(id: 'emp-06', name: 'Tariq Mahmud', email: 'tariq@gmail.com', phone: '01711111006', role: UserModel.roleTeamMember, zela: 'Chattogram', thana: 'Agrabad', myReferralCode: 'TM006', teamId: 'team-ctg-a', teamName: 'Chattogram Team Alpha', totalSales: 560000, totalCommission: 11200, pendingCommission: 4500),
      UserModel(id: 'emp-21', name: 'Milon Sarker', email: 'milon@gmail.com', phone: '01711111021', role: UserModel.roleTeamMember, zela: 'Chattogram', thana: 'Kalurghat', myReferralCode: 'TM021', teamId: 'team-ctg-a', teamName: 'Chattogram Team Alpha', totalSales: 430000, totalCommission: 6450, pendingCommission: 2600),
      UserModel(id: 'emp-22', name: 'Dilruba Begum', email: 'dilruba@gmail.com', phone: '01711111022', role: UserModel.roleTeamMember, zela: 'Chattogram', thana: 'Bakalia', myReferralCode: 'TM022', teamId: 'team-ctg-a', teamName: 'Chattogram Team Alpha', totalSales: 280000, totalCommission: 4200, pendingCommission: 1700),
      UserModel(id: 'emp-23', name: 'Sirajul Islam', email: 'sirajul@gmail.com', phone: '01711111023', role: UserModel.roleTeamLeader, zela: 'Chattogram', thana: 'Nasirabad', myReferralCode: 'TL023', teamId: 'team-ctg-b', teamName: 'Chattogram Team Beta', totalSales: 2750000, totalCommission: 68750, pendingCommission: 22000),
      UserModel(id: 'emp-24', name: 'Ayesha Siddika', email: 'ayesha@gmail.com', phone: '01711111024', role: UserModel.roleTeamMember, zela: 'Chattogram', thana: 'Chandgaon', myReferralCode: 'TM024', teamId: 'team-ctg-b', teamName: 'Chattogram Team Beta', totalSales: 620000, totalCommission: 12400, pendingCommission: 4900),
      // ── Rajshahi ─────────────────────────────────────────────────────────
      UserModel(id: 'emp-07', name: 'Abdul Karim', email: 'abdulk@gmail.com', phone: '01711111007', role: UserModel.roleTeamLeader, zela: 'Rajshahi', thana: 'Boalia', myReferralCode: 'TL007', teamId: 'team-raj', teamName: 'Rajshahi Team', totalSales: 1800000, totalCommission: 45000, pendingCommission: 12000),
      UserModel(id: 'emp-08', name: 'Mosammat Rima', email: 'rima@gmail.com', phone: '01711111008', role: UserModel.roleTeamMember, zela: 'Rajshahi', thana: 'Shahmokhdum', myReferralCode: 'TM008', teamId: 'team-raj', teamName: 'Rajshahi Team', totalSales: 320000, totalCommission: 4800, pendingCommission: 2000),
      UserModel(id: 'emp-25', name: 'Kamal Uddin', email: 'kamal@gmail.com', phone: '01711111025', role: UserModel.roleTeamMember, zela: 'Rajshahi', thana: 'Rajpara', myReferralCode: 'TM025', teamId: 'team-raj', teamName: 'Rajshahi Team', totalSales: 450000, totalCommission: 6750, pendingCommission: 2500),
      UserModel(id: 'emp-26', name: 'Sumaiya Khanam', email: 'sumaiya@gmail.com', phone: '01711111026', role: UserModel.roleTeamMember, zela: 'Rajshahi', thana: 'Matihar', myReferralCode: 'TM026', teamId: 'team-raj', teamName: 'Rajshahi Team', totalSales: 260000, totalCommission: 3900, pendingCommission: 1500),
      UserModel(id: 'emp-27', name: 'Hafizur Rahman', email: 'hafizur@gmail.com', phone: '01711111027', role: UserModel.roleTeamMember, zela: 'Rajshahi', thana: 'Puthia', myReferralCode: 'TM027', teamId: 'team-raj', teamName: 'Rajshahi Team', totalSales: 370000, totalCommission: 5550, pendingCommission: 2100),
      // ── Sylhet ─────────────────────────────────────────────────────────
      UserModel(id: 'emp-10', name: 'Marzia Haq', email: 'marzia@gmail.com', phone: '01711111010', role: UserModel.roleTeamLeader, zela: 'Sylhet', thana: 'Jalalabad', myReferralCode: 'TL010', teamId: 'team-syl', teamName: 'Sylhet Team', totalSales: 2100000, totalCommission: 52500, pendingCommission: 18000),
      UserModel(id: 'emp-09', name: 'Farhan Islam', email: 'farhan@gmail.com', phone: '01711111009', role: UserModel.roleTeamMember, zela: 'Sylhet', thana: 'Kotwali', myReferralCode: 'TM009', teamId: 'team-syl', teamName: 'Sylhet Team', totalSales: 780000, totalCommission: 15600, pendingCommission: 6000),
      UserModel(id: 'emp-28', name: 'Rahela Chowdhury', email: 'rahela@gmail.com', phone: '01711111028', role: UserModel.roleTeamMember, zela: 'Sylhet', thana: 'Airport', myReferralCode: 'TM028', teamId: 'team-syl', teamName: 'Sylhet Team', totalSales: 510000, totalCommission: 7650, pendingCommission: 3000),
      UserModel(id: 'emp-29', name: 'Wahid Mia', email: 'wahid@gmail.com', phone: '01711111029', role: UserModel.roleTeamMember, zela: 'Sylhet', thana: 'Dakshin Surma', myReferralCode: 'TM029', teamId: 'team-syl', teamName: 'Sylhet Team', totalSales: 340000, totalCommission: 5100, pendingCommission: 2000),
      UserModel(id: 'emp-30', name: 'Lubna Ahmed', email: 'lubna@gmail.com', phone: '01711111030', role: UserModel.roleTeamMember, zela: 'Sylhet', thana: 'Bishwanath', myReferralCode: 'TM030', teamId: 'team-syl', teamName: 'Sylhet Team', totalSales: 290000, totalCommission: 4350, pendingCommission: 1700),
      // ── Khulna ─────────────────────────────────────────────────────────
      UserModel(id: 'emp-31', name: 'Mahbub Alam', email: 'mahbub@gmail.com', phone: '01711111031', role: UserModel.roleTeamLeader, zela: 'Khulna', thana: 'Khalishpur', myReferralCode: 'TL031', teamId: 'team-khl', teamName: 'Khulna Team', totalSales: 1650000, totalCommission: 41250, pendingCommission: 14000),
      UserModel(id: 'emp-11', name: 'Shamim Reza', email: 'shamim@gmail.com', phone: '01711111011', role: UserModel.roleTeamMember, zela: 'Khulna', thana: 'Sonadanga', myReferralCode: 'TM011', teamId: 'team-khl', teamName: 'Khulna Team', totalSales: 430000, totalCommission: 6450, pendingCommission: 2500),
      UserModel(id: 'emp-12', name: 'Parul Begum', email: 'parul@gmail.com', phone: '01711111012', role: UserModel.roleTeamMember, zela: 'Khulna', thana: 'Daulatpur', myReferralCode: 'TM012', teamId: 'team-khl', teamName: 'Khulna Team', totalSales: 200000, totalCommission: 3000, pendingCommission: 1200),
      UserModel(id: 'emp-32', name: 'Iqbal Hossain', email: 'iqbal@gmail.com', phone: '01711111032', role: UserModel.roleTeamMember, zela: 'Khulna', thana: 'Batiaghata', myReferralCode: 'TM032', teamId: 'team-khl', teamName: 'Khulna Team', totalSales: 175000, totalCommission: 2625, pendingCommission: 1000),
      // ── Mymensingh ──────────────────────────────────────────────────────
      UserModel(id: 'emp-33', name: 'Nurul Islam', email: 'nurul@gmail.com', phone: '01711111033', role: UserModel.roleTeamLeader, zela: 'Mymensingh', thana: 'Kotwali', myReferralCode: 'TL033', teamId: 'team-mym', teamName: 'Mymensingh Team', totalSales: 1200000, totalCommission: 30000, pendingCommission: 10000),
      UserModel(id: 'emp-34', name: 'Kohinur Begum', email: 'kohinur@gmail.com', phone: '01711111034', role: UserModel.roleTeamMember, zela: 'Mymensingh', thana: 'Sadar', myReferralCode: 'TM034', teamId: 'team-mym', teamName: 'Mymensingh Team', totalSales: 380000, totalCommission: 5700, pendingCommission: 2200),
      UserModel(id: 'emp-35', name: 'Imran Khan', email: 'imran@gmail.com', phone: '01711111035', role: UserModel.roleTeamMember, zela: 'Mymensingh', thana: 'Valuka', myReferralCode: 'TM035', teamId: 'team-mym', teamName: 'Mymensingh Team', totalSales: 245000, totalCommission: 3675, pendingCommission: 1400),
      // ── Barishal ────────────────────────────────────────────────────────
      UserModel(id: 'emp-36', name: 'Ali Akbar', email: 'aliakbar@gmail.com', phone: '01711111036', role: UserModel.roleTeamLeader, zela: 'Barishal', thana: 'Kotwali', myReferralCode: 'TL036', teamId: 'team-bar', teamName: 'Barishal Team', totalSales: 980000, totalCommission: 24500, pendingCommission: 8500),
      UserModel(id: 'emp-37', name: 'Layla Begum', email: 'layla@gmail.com', phone: '01711111037', role: UserModel.roleTeamMember, zela: 'Barishal', thana: 'Sadar', myReferralCode: 'TM037', teamId: 'team-bar', teamName: 'Barishal Team', totalSales: 310000, totalCommission: 4650, pendingCommission: 1800),
      UserModel(id: 'emp-38', name: 'Hasan Mahmud', email: 'hasan@gmail.com', phone: '01711111038', role: UserModel.roleTeamMember, zela: 'Barishal', thana: 'Agailjhara', myReferralCode: 'TM038', teamId: 'team-bar', teamName: 'Barishal Team', totalSales: 195000, totalCommission: 2925, pendingCommission: 1100),
      // ── Rangpur ─────────────────────────────────────────────────────────
      UserModel(id: 'emp-39', name: 'Mojnu Mia', email: 'mojnu@gmail.com', phone: '01711111039', role: UserModel.roleTeamLeader, zela: 'Rangpur', thana: 'Kotwali', myReferralCode: 'TL039', teamId: 'team-rng', teamName: 'Rangpur Team', totalSales: 870000, totalCommission: 21750, pendingCommission: 7500),
      UserModel(id: 'emp-40', name: 'Suraiya Khatun', email: 'suraiya@gmail.com', phone: '01711111040', role: UserModel.roleTeamMember, zela: 'Rangpur', thana: 'Taraganj', myReferralCode: 'TM040', teamId: 'team-rng', teamName: 'Rangpur Team', totalSales: 265000, totalCommission: 3975, pendingCommission: 1500),
      // ── Cumilla ──────────────────────────────────────────────────────
      UserModel(id: 'emp-41', name: 'Shafiqul Islam', email: 'shafiq@gmail.com', phone: '01711111041', role: UserModel.roleTeamLeader, zela: 'Cumilla', thana: 'Kotwali', myReferralCode: 'TL041', teamId: 'team-cum', teamName: 'Cumilla Team', totalSales: 1450000, totalCommission: 36250, pendingCommission: 12500),
      UserModel(id: 'emp-42', name: 'Fatema Tuz Zohra', email: 'fatema@gmail.com', phone: '01711111042', role: UserModel.roleTeamMember, zela: 'Cumilla', thana: 'Debidwar', myReferralCode: 'TM042', teamId: 'team-cum', teamName: 'Cumilla Team', totalSales: 395000, totalCommission: 5925, pendingCommission: 2300),
      UserModel(id: 'emp-43', name: 'Raju Ahmed', email: 'raju@gmail.com', phone: '01711111043', role: UserModel.roleTeamMember, zela: 'Cumilla', thana: 'Muradnagar', myReferralCode: 'TM043', teamId: 'team-cum', teamName: 'Cumilla Team', totalSales: 220000, totalCommission: 3300, pendingCommission: 1200),
      // ── Gazipur / Narayanganj ─────────────────────────────────────────
      UserModel(id: 'emp-44', name: 'Anwar Hossain', email: 'anwar@gmail.com', phone: '01711111044', role: UserModel.roleTeamLeader, zela: 'Gazipur', thana: 'Joydebpur', myReferralCode: 'TL044', teamId: 'team-gaz', teamName: 'Gazipur Team', totalSales: 1900000, totalCommission: 47500, pendingCommission: 16000),
      UserModel(id: 'emp-45', name: 'Najma Begum', email: 'najma@gmail.com', phone: '01711111045', role: UserModel.roleTeamMember, zela: 'Narayanganj', thana: 'Siddhirganj', myReferralCode: 'TM045', teamId: 'team-gaz', teamName: 'Gazipur Team', totalSales: 490000, totalCommission: 7350, pendingCommission: 2800),
      // ── Admin ──────────────────────────────────────────────────────────
      UserModel(id: 'emp-13', name: 'Mehedi Hasan', email: 'mehedi@gmail.com', phone: '01711111013', role: UserModel.roleAdmin, zela: 'Dhaka', thana: 'Motijheel', myReferralCode: 'ADM013', totalSales: 6000000, totalCommission: 150000, pendingCommission: 40000),
    ];
  }

  // ── Demo Data Seeding ─────────────────────────────────────────────────
  static const _keyDemoSeeded = 'demoDataSeeded_v4';

  static Future<void> seedDemoData() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_keyDemoSeeded) == true) return;

    final now = DateTime.now();

    // ── 8 Support Tickets ─────────────────────────────────────────────────
    final tickets = [
      {'id': 'TKT-001', 'name': 'Karim Hossain', 'email': 'karim@gmail.com', 'category': 'Order Issue', 'problem': 'Not receiving order confirmation after submitting. The order is also not showing in the order list.', 'status': 'Resolved', 'createdAt': now.subtract(const Duration(days: 50)).toIso8601String()},
      {'id': 'TKT-002', 'name': 'Salma Begum', 'email': 'salma@gmail.com', 'category': 'Payment Issue', 'problem': 'Last month\'s payment status is not updating. It does not appear in the payment history.', 'status': 'In Progress', 'createdAt': now.subtract(const Duration(days: 40)).toIso8601String()},
      {'id': 'TKT-003', 'name': 'Nasrin Akter', 'email': 'nasrin@gmail.com', 'category': 'Login Issue', 'problem': 'Forgot my password. Not receiving the password reset email.', 'status': 'Resolved', 'createdAt': now.subtract(const Duration(days: 35)).toIso8601String()},
      {'id': 'TKT-004', 'name': 'Jamal Ahmed', 'email': 'jamal@gmail.com', 'category': 'Product Issue', 'problem': 'After updating product stock the old quantity is still showing.', 'status': 'Pending', 'createdAt': now.subtract(const Duration(days: 28)).toIso8601String()},
      {'id': 'TKT-005', 'name': 'Farhan Islam', 'email': 'farhan@gmail.com', 'category': 'Sales Report', 'problem': 'Monthly sales report is not loading. The screen appears blank.', 'status': 'In Progress', 'createdAt': now.subtract(const Duration(days: 20)).toIso8601String()},
      {'id': 'TKT-006', 'name': 'Marzia Haq', 'email': 'marzia@gmail.com', 'category': 'Delivery Issue', 'problem': 'Order delivery status still shows "Pending" even after delivery was made.', 'status': 'Pending', 'createdAt': now.subtract(const Duration(days: 14)).toIso8601String()},
      {'id': 'TKT-007', 'name': 'Shamim Reza', 'email': 'shamim@gmail.com', 'category': 'Payment Issue', 'problem': 'Not receiving the transaction ID after collecting bKash payment.', 'status': 'Resolved', 'createdAt': now.subtract(const Duration(days: 9)).toIso8601String()},
      {'id': 'TKT-008', 'name': 'Tariq Mahmud', 'email': 'tariq@gmail.com', 'category': 'General Issue', 'problem': 'App is running slow. Loading a large number of orders is taking too long.', 'status': 'Pending', 'createdAt': now.subtract(const Duration(days: 3)).toIso8601String()},
    ];
    await prefs.setString(_keyTickets, jsonEncode(tickets));

    // ── More Team Members ─────────────────────────────────────────────────
    final teamMembers = [
      UserModel(id: 'emp-01', name: 'Rahim Uddin', email: 'rahim@gmail.com', phone: '01711111001', role: UserModel.roleTeamLeader, zela: 'Dhaka', thana: 'Mirpur', myReferralCode: 'TL001', teamId: 'team-dhaka-a', teamName: 'Dhaka Team Alpha', totalSales: 2500000, totalCommission: 62500, pendingCommission: 20000),
      UserModel(id: 'emp-02', name: 'Karim Hossain', email: 'karim@gmail.com', phone: '01711111002', role: UserModel.roleTeamMember, zela: 'Dhaka', thana: 'Dhanmondi', myReferralCode: 'TM002', teamId: 'team-dhaka-a', teamName: 'Dhaka Team Alpha', totalSales: 650000, totalCommission: 13000, pendingCommission: 5000),
      UserModel(id: 'emp-03', name: 'Salma Begum', email: 'salma@gmail.com', phone: '01711111003', role: UserModel.roleTeamMember, zela: 'Dhaka', thana: 'Uttara', myReferralCode: 'TM003', teamId: 'team-dhaka-a', teamName: 'Dhaka Team Alpha', totalSales: 400000, totalCommission: 6000, pendingCommission: 3000),
      UserModel(id: 'emp-04', name: 'Jamal Ahmed', email: 'jamal@gmail.com', phone: '01711111004', role: UserModel.roleTeamLeader, zela: 'Chattogram', thana: 'Panchlaish', myReferralCode: 'TL004', teamId: 'team-ctg-a', teamName: 'Chattogram Team Alpha', totalSales: 3200000, totalCommission: 80000, pendingCommission: 25000),
      UserModel(id: 'emp-05', name: 'Nasrin Akter', email: 'nasrin@gmail.com', phone: '01711111005', role: UserModel.roleTeamMember, zela: 'Chattogram', thana: 'Halishahar', myReferralCode: 'TM005', teamId: 'team-ctg-a', teamName: 'Chattogram Team Alpha', totalSales: 900000, totalCommission: 18000, pendingCommission: 7000),
      UserModel(id: 'emp-06', name: 'Tariq Mahmud', email: 'tariq@gmail.com', phone: '01711111006', role: UserModel.roleTeamMember, zela: 'Chattogram', thana: 'Agrabad', myReferralCode: 'TM006', teamId: 'team-ctg-a', teamName: 'Chattogram Team Alpha', totalSales: 560000, totalCommission: 11200, pendingCommission: 4500),
      UserModel(id: 'emp-14', name: 'Tanvir Ahmed', email: 'tanvir@gmail.com', phone: '01711111014', role: UserModel.roleTeamMember, zela: 'Dhaka', thana: 'Gulshan', myReferralCode: 'TM014', teamId: 'team-dhaka-a', teamName: 'Dhaka Team Alpha', totalSales: 870000, totalCommission: 17400, pendingCommission: 6500),
      UserModel(id: 'emp-15', name: 'Nahida Parveen', email: 'nahida@gmail.com', phone: '01711111015', role: UserModel.roleTeamMember, zela: 'Dhaka', thana: 'Banani', myReferralCode: 'TM015', teamId: 'team-dhaka-a', teamName: 'Dhaka Team Alpha', totalSales: 540000, totalCommission: 10800, pendingCommission: 4000),
      UserModel(id: 'emp-16', name: 'Sadek Ali', email: 'sadek@gmail.com', phone: '01711111016', role: UserModel.roleTeamLeader, zela: 'Dhaka', thana: 'Bashundhara', myReferralCode: 'TL016', teamId: 'team-dhaka-b', teamName: 'Dhaka Team Beta', totalSales: 3100000, totalCommission: 77500, pendingCommission: 28000),
      UserModel(id: 'emp-10', name: 'Marzia Haq', email: 'marzia@gmail.com', phone: '01711111010', role: UserModel.roleTeamLeader, zela: 'Sylhet', thana: 'Jalalabad', myReferralCode: 'TL010', teamId: 'team-syl', teamName: 'Sylhet Team', totalSales: 2100000, totalCommission: 52500, pendingCommission: 18000),
      UserModel(id: 'emp-31', name: 'Mahbub Alam', email: 'mahbub@gmail.com', phone: '01711111031', role: UserModel.roleTeamLeader, zela: 'Khulna', thana: 'Khalishpur', myReferralCode: 'TL031', teamId: 'team-khl', teamName: 'Khulna Team', totalSales: 1650000, totalCommission: 41250, pendingCommission: 14000),
      UserModel(id: 'emp-44', name: 'Anwar Hossain', email: 'anwar@gmail.com', phone: '01711111044', role: UserModel.roleTeamLeader, zela: 'Gazipur', thana: 'Joydebpur', myReferralCode: 'TL044', teamId: 'team-gaz', teamName: 'Gazipur Team', totalSales: 1900000, totalCommission: 47500, pendingCommission: 16000),
      UserModel(id: 'emp-23', name: 'Sirajul Islam', email: 'sirajul@gmail.com', phone: '01711111023', role: UserModel.roleTeamLeader, zela: 'Chattogram', thana: 'Nasirabad', myReferralCode: 'TL023', teamId: 'team-ctg-b', teamName: 'Chattogram Team Beta', totalSales: 2750000, totalCommission: 68750, pendingCommission: 22000),
      UserModel(id: 'emp-28', name: 'Rahela Chowdhury', email: 'rahela@gmail.com', phone: '01711111028', role: UserModel.roleTeamMember, zela: 'Sylhet', thana: 'Airport', myReferralCode: 'TM028', teamId: 'team-syl', teamName: 'Sylhet Team', totalSales: 510000, totalCommission: 7650, pendingCommission: 3000),
      UserModel(id: 'emp-07', name: 'Abdul Karim', email: 'abdulk@gmail.com', phone: '01711111007', role: UserModel.roleTeamLeader, zela: 'Rajshahi', thana: 'Boalia', myReferralCode: 'TL007', teamId: 'team-raj', teamName: 'Rajshahi Team', totalSales: 1800000, totalCommission: 45000, pendingCommission: 12000),
      UserModel(id: 'emp-25', name: 'Kamal Uddin', email: 'kamal@gmail.com', phone: '01711111025', role: UserModel.roleTeamMember, zela: 'Rajshahi', thana: 'Rajpara', myReferralCode: 'TM025', teamId: 'team-raj', teamName: 'Rajshahi Team', totalSales: 450000, totalCommission: 6750, pendingCommission: 2500),
      UserModel(id: 'emp-17', name: 'Rifat Zaman', email: 'rifat@gmail.com', phone: '01711111017', role: UserModel.roleTeamMember, zela: 'Dhaka', thana: 'Motijheel', myReferralCode: 'TM017', teamId: 'team-dhaka-b', teamName: 'Dhaka Team Beta', totalSales: 720000, totalCommission: 14400, pendingCommission: 5800),
    ];
    await prefs.setString(_keyTeamMembers,
        jsonEncode(teamMembers.map((m) => m.toMap()).toList()));

    await prefs.setBool(_keyDemoSeeded, true);
  }

  // ── Targets ────────────────────────────────────────────────────────────
  static const _keyTargets = 'targets';

  static Future<List<TargetModel>> getTargets() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyTargets);
    if (raw == null) return [];
    final List<dynamic> list = jsonDecode(raw);
    return list
        .map((e) => TargetModel.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<void> saveTarget(TargetModel t) async {
    final list = await getTargets();
    final idx = list.indexWhere(
        (x) => x.userId == t.userId && x.month == t.month);
    if (idx >= 0) {
      list[idx] = t;
    } else {
      list.insert(0, t);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _keyTargets, jsonEncode(list.map((e) => e.toMap()).toList()));
  }

  // ── Motorcycle registration number (entered once per employee) ────────
  static const _keyMotoReg = 'wintech_moto_reg_';

  static Future<String> getMotoRegNumber(String employeeId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_keyMotoReg$employeeId') ?? '';
  }

  static Future<void> setMotoRegNumber(String employeeId, String reg) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_keyMotoReg$employeeId', reg.trim());
  }

  // ── Expenses ───────────────────────────────────────────────────────────
  static const _keyExpenses = 'wintech_expenses';

  static Future<List<ExpenseModel>> getExpenses() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyExpenses);
    if (raw == null) return [];
    final List<dynamic> list = jsonDecode(raw);
    return list
        .map((e) => ExpenseModel.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static Future<void> saveExpense(ExpenseModel e) async {
    final list = await getExpenses();
    final idx = list.indexWhere((x) => x.id == e.id);
    if (idx >= 0) {
      list[idx] = e;
    } else {
      list.insert(0, e);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _keyExpenses, jsonEncode(list.map((x) => x.toMap()).toList()));
  }

  /// Replaces stale ERP-backed cache entries in one write. Callers retain
  /// unsynced queued records before handing the list to this method.
  static Future<void> replaceExpenses(List<ExpenseModel> expenses) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _keyExpenses, jsonEncode(expenses.map((x) => x.toMap()).toList()));
  }

  static Future<void> deleteExpense(String id) async {
    final list = await getExpenses();
    list.removeWhere((x) => x.id == id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _keyExpenses, jsonEncode(list.map((x) => x.toMap()).toList()));
  }

  // ── Leaves ─────────────────────────────────────────────────────────────
  static const _keyLeaves = 'wintech_leaves';

  static Future<List<LeaveModel>> getLeaves() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyLeaves);
    if (raw == null) return [];
    final List<dynamic> list = jsonDecode(raw);
    return list
        .map((e) => LeaveModel.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static Future<void> saveLeave(LeaveModel l) async {
    final list = await getLeaves();
    final idx = list.indexWhere((x) => x.id == l.id);
    if (idx >= 0) {
      list[idx] = l;
    } else {
      list.insert(0, l);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _keyLeaves, jsonEncode(list.map((x) => x.toMap()).toList()));
  }

  static Future<void> replaceLeaves(List<LeaveModel> leaves) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _keyLeaves, jsonEncode(leaves.map((x) => x.toMap()).toList()));
  }

  static Future<void> deleteLeave(String id) async {
    final list = await getLeaves();
    list.removeWhere((x) => x.id == id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _keyLeaves, jsonEncode(list.map((x) => x.toMap()).toList()));
  }

  // ── Payment Collections ────────────────────────────────────────────────
  static const _keyPaymentCollections = 'wintech_payment_collections';

  static Future<List<PaymentCollectionModel>> getPaymentCollections() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyPaymentCollections);
    if (raw == null) return [];
    final List<dynamic> list = jsonDecode(raw);
    return list
        .map((e) =>
            PaymentCollectionModel.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static Future<void> savePaymentCollection(PaymentCollectionModel p) async {
    final list = await getPaymentCollections();
    final idx = list.indexWhere((x) => x.id == p.id);
    if (idx >= 0) {
      list[idx] = p;
    } else {
      list.insert(0, p);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPaymentCollections,
        jsonEncode(list.map((x) => x.toMap()).toList()));
  }

  static Future<void> deletePaymentCollection(String id) async {
    final list = await getPaymentCollections();
    list.removeWhere((x) => x.id == id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPaymentCollections,
        jsonEncode(list.map((x) => x.toMap()).toList()));
  }

  // ── Surveys ────────────────────────────────────────────────────────────
  static const _keySurveys = 'wintech_surveys';

  static Future<List<SurveyModel>> getSurveys() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keySurveys);
    if (raw == null) return [];
    final List<dynamic> list = jsonDecode(raw);
    return list
        .map((e) => SurveyModel.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static Future<void> saveSurvey(SurveyModel s) async {
    final list = await getSurveys();
    final idx = list.indexWhere((x) => x.id == s.id);
    if (idx >= 0) {
      list[idx] = s;
    } else {
      list.insert(0, s);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _keySurveys, jsonEncode(list.map((x) => x.toMap()).toList()));
  }

  static Future<void> replaceSurveys(List<SurveyModel> surveys) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _keySurveys, jsonEncode(surveys.map((x) => x.toMap()).toList()));
  }

  static Future<void> deleteSurvey(String id) async {
    final list = await getSurveys();
    list.removeWhere((x) => x.id == id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _keySurveys, jsonEncode(list.map((x) => x.toMap()).toList()));
  }

  // ── Commission History ─────────────────────────────────────────────────
  static const _keyCommissionHistory = 'commissionHistory';

  static Future<List<Map<String, dynamic>>> getCommissionHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyCommissionHistory);
    // If no saved history, build from delivered orders
    if (raw == null) {
      final orders = await getOrders();
      final user = await getCurrentUser();
      final rate = user?.commissionRate ?? 0.015;
      return orders
          .where((o) => o.status == OrderModel.statusDelivered)
          .map((o) => {
                'id': o.id,
                'source': '${o.customerName} — Order Delivered',
                'commission': o.total * rate,
                'type': 'Order Commission',
                'date': o.date.toIso8601String(),
              })
          .toList();
    }
    final List<dynamic> list = jsonDecode(raw);
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<void> addCommissionEntry(Map<String, dynamic> entry) async {
    final list = await getCommissionHistory();
    list.insert(0, entry);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCommissionHistory, jsonEncode(list));
  }

  // ── Orders (Wintech Agro POS) ────────────────────────────────────────────
  static const _keyOrders = 'wintech_orders';

  static Future<List<OrderModel>> getOrders() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyOrders);
    if (raw == null) return _demoOrders();
    final List<dynamic> list = jsonDecode(raw);
    return list
        .map((e) => OrderModel.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static Future<void> saveOrder(OrderModel order) async {
    final orders = await getOrders();
    final idx = orders.indexWhere((o) => o.id == order.id);
    if (idx >= 0) {
      orders[idx] = order;
    } else {
      orders.insert(0, order);
    }
    await _writeOrders(orders);
  }

  static Future<void> deleteOrder(String id) async {
    final orders = await getOrders();
    orders.removeWhere((o) => o.id == id);
    await _writeOrders(orders);
  }

  static Future<void> _writeOrders(List<OrderModel> orders) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _keyOrders, jsonEncode(orders.map((o) => o.toMap()).toList()));
  }

  /// Demo orders seeded on first launch — real Wintech products & parties
  static List<OrderModel> _demoOrders() {
    final now = DateTime.now();
    return [
      OrderModel(
        id: 'ORD-DEMO-001',
        srId: 'demo-teammember',
        srName: 'Karim Hossain (SR)',
        customerId: 'WP-001',
        customerName: 'M/s Akhonda Traders',
        items: [
          const OrderItem(
              productName: 'Aqua Safe Plus 5 Kg',
              quantity: 10,
              unit: 'Pcs',
              unitPrice: 680),
          const OrderItem(
              productName: 'Win C 500gm',
              quantity: 5,
              unit: 'Pcs',
              unitPrice: 780),
          const OrderItem(
              productName: 'Win C 100gm',
              quantity: 2,
              unit: 'Pcs',
              unitPrice: 0,
              isBonus: true),
        ],
        total: 10700,
        date: now.subtract(const Duration(days: 1)),
        status: 'confirmed',
      ),
      OrderModel(
        id: 'ORD-DEMO-002',
        srId: 'demo-teamleader',
        srName: 'Rahim Uddin (TL)',
        customerId: 'WP-002',
        customerName: 'M/s Baly Enterprise',
        items: [
          const OrderItem(
              productName: 'Bencidal Plus 500ml',
              quantity: 6,
              unit: 'Pcs',
              unitPrice: 1180),
          const OrderItem(
              productName: 'Eco Fresh 1Kg',
              quantity: 12,
              unit: 'Pcs',
              unitPrice: 290),
        ],
        total: 10560,
        date: now.subtract(const Duration(days: 2)),
        status: 'delivered',
      ),
      OrderModel(
        id: 'ORD-DEMO-003',
        srId: 'demo-teammember',
        srName: 'Karim Hossain (SR)',
        customerId: 'WP-003',
        customerName: 'M/s Bismillah Traders',
        items: [
          const OrderItem(
              productName: 'Oxy-Win (Granular) 1kg',
              quantity: 8,
              unit: 'Pcs',
              unitPrice: 680),
        ],
        total: 5440,
        date: now.subtract(const Duration(days: 3)),
        status: 'confirmed',
      ),
      OrderModel(
        id: 'ORD-DEMO-004',
        srId: 'demo-teamleader',
        srName: 'Rahim Uddin (TL)',
        customerId: 'WP-001',
        customerName: 'M/s Akhonda Traders',
        items: [
          const OrderItem(
              productName: 'Win Health 500ml',
              quantity: 4,
              unit: 'Pcs',
              unitPrice: 1350),
          const OrderItem(
              productName: 'Bottom Light 500gm',
              quantity: 3,
              unit: 'Pcs',
              unitPrice: 1510),
        ],
        total: 9930,
        date: now.subtract(const Duration(days: 5)),
        status: 'delivered',
      ),
      OrderModel(
        id: 'ORD-DEMO-005',
        srId: 'demo-sr',
        srName: 'Sales Representative',
        customerId: 'WP-004',
        customerName: 'M/s Rahman Fish Feed',
        items: [
          const OrderItem(
              productName: 'Pro Yucca for Fish 500ml',
              quantity: 5,
              unit: 'Pcs',
              unitPrice: 1250),
          const OrderItem(
              productName: 'Vitazyme Aqua 500gm',
              quantity: 4,
              unit: 'Pcs',
              unitPrice: 695),
        ],
        total: 9030,
        date: now.subtract(const Duration(hours: 6)),
        status: 'pending',
      ),
    ];
  }
}
