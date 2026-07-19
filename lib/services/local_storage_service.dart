import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/order_model.dart';
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
      'name': 'সুপার অ্যাডমিন',
      'role': UserModel.roleSuperAdmin,
      'id': 'demo-superadmin',
      'referral': 'SADM001',
    },
    'admin@gmail.com': {
      'name': 'অ্যাডমিন ইউজার',
      'role': UserModel.roleAdmin,
      'id': 'demo-admin',
      'referral': 'ADM001',
    },
    'teamowner@gmail.com': {
      'name': 'রহিম উদ্দিন (TL)',
      'role': UserModel.roleTeamLeader,
      'id': 'demo-teamleader',
      'referral': 'TL001',
    },
    'teammember@gmail.com': {
      'name': 'করিম হোসেন (SR)',
      'role': UserModel.roleTeamMember,
      'id': 'demo-teammember',
      'referral': 'TM001',
    },
    'sr@wintech.com': {
      'name': 'সেলস রিপ্রেজেন্টেটিভ',
      'role': UserModel.roleTeamMember,
      'id': 'demo-sr',
      'referral': 'SR001',
      'branch': 'ঢাকা সেন্ট্রাল',
    },
    'customer@gmail.com': {
      'name': 'মেসার্স আল-আমিন ট্রেডার্স',
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
      myReferralCode: data['referral']!,
      zela: 'ঢাকা',
      thana: 'ধানমন্ডি',
      branch: data['branch'] ?? '',
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
            name: 'টিম লিডার রহিম',
            email: 'teamowner@gmail.com',
            role: UserModel.roleTeamLeader,
            myReferralCode: 'TL001'),
        UserModel(
            id: 'demo-teammember',
            name: 'টিম মেম্বার করিম',
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
          title: 'অ্যাপ পরিচিতি — শুরু করুন',
          description: 'Wintech Agro অ্যাপ কিভাবে ব্যবহার করবেন তার সম্পূর্ণ গাইড।',
          videoUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
          category: 'সাধারণ',
          durationMinutes: 5,
        ),
        TutorialModel(
          id: 'tut-2',
          title: 'অর্ডার করার নিয়ম',
          description: 'POS স্ক্রিন থেকে নতুন অর্ডার কিভাবে তৈরি করবেন ও সাবমিট করবেন।',
          videoUrl: '',
          category: 'অর্ডার',
          durationMinutes: 6,
        ),
        TutorialModel(
          id: 'tut-3',
          title: 'কমিশন ও বিক্রয় রিপোর্ট',
          description: 'আপনার কমিশন কিভাবে হিসাব হয় এবং বিক্রয় রিপোর্ট কোথায় দেখবেন।',
          videoUrl: '',
          category: 'কমিশন',
          durationMinutes: 7,
        ),
        TutorialModel(
          id: 'tut-4',
          title: 'টার্গেট ট্র্যাকিং',
          description: 'মাসিক টার্গেট কিভাবে দেখবেন এবং পূরণ করার উপায়।',
          videoUrl: '',
          category: 'টার্গেট',
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
    String category = 'সাধারণ সমস্যা',
  }) async {
    final ticket = {
      'id': 'TKT-${DateTime.now().millisecondsSinceEpoch}',
      'name': name,
      'email': email,
      'category': category,
      'problem': problem,
      'status': 'অপেক্ষমাণ',
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
      // ── ঢাকা ──────────────────────────────────────────────────────────
      UserModel(id: 'emp-01', name: 'রহিম উদ্দিন', email: 'rahim@gmail.com', phone: '01711111001', role: UserModel.roleTeamLeader, zela: 'ঢাকা', thana: 'মিরপুর', myReferralCode: 'TL001', teamId: 'team-dhaka-a', teamName: 'ঢাকা টিম আলফা', totalSales: 2500000, totalCommission: 62500, pendingCommission: 20000),
      UserModel(id: 'emp-02', name: 'করিম হোসেন', email: 'karim@gmail.com', phone: '01711111002', role: UserModel.roleTeamMember, zela: 'ঢাকা', thana: 'ধানমন্ডি', myReferralCode: 'TM002', teamId: 'team-dhaka-a', teamName: 'ঢাকা টিম আলফা', totalSales: 650000, totalCommission: 13000, pendingCommission: 5000),
      UserModel(id: 'emp-03', name: 'সালমা বেগম', email: 'salma@gmail.com', phone: '01711111003', role: UserModel.roleTeamMember, zela: 'ঢাকা', thana: 'উত্তরা', myReferralCode: 'TM003', teamId: 'team-dhaka-a', teamName: 'ঢাকা টিম আলফা', totalSales: 400000, totalCommission: 6000, pendingCommission: 3000),
      UserModel(id: 'emp-14', name: 'তানভীর আহমেদ', email: 'tanvir@gmail.com', phone: '01711111014', role: UserModel.roleTeamMember, zela: 'ঢাকা', thana: 'গুলশান', myReferralCode: 'TM014', teamId: 'team-dhaka-a', teamName: 'ঢাকা টিম আলফা', totalSales: 870000, totalCommission: 17400, pendingCommission: 6500),
      UserModel(id: 'emp-15', name: 'নাহিদা পারভীন', email: 'nahida@gmail.com', phone: '01711111015', role: UserModel.roleTeamMember, zela: 'ঢাকা', thana: 'বনানী', myReferralCode: 'TM015', teamId: 'team-dhaka-a', teamName: 'ঢাকা টিম আলফা', totalSales: 540000, totalCommission: 10800, pendingCommission: 4000),
      UserModel(id: 'emp-16', name: 'সাদেক আলী', email: 'sadek@gmail.com', phone: '01711111016', role: UserModel.roleTeamLeader, zela: 'ঢাকা', thana: 'বসুন্ধরা', myReferralCode: 'TL016', teamId: 'team-dhaka-b', teamName: 'ঢাকা টিম বেটা', totalSales: 3100000, totalCommission: 77500, pendingCommission: 28000),
      UserModel(id: 'emp-17', name: 'রিফাত জামান', email: 'rifat@gmail.com', phone: '01711111017', role: UserModel.roleTeamMember, zela: 'ঢাকা', thana: 'মতিঝিল', myReferralCode: 'TM017', teamId: 'team-dhaka-b', teamName: 'ঢাকা টিম বেটা', totalSales: 720000, totalCommission: 14400, pendingCommission: 5800),
      UserModel(id: 'emp-18', name: 'শারমিন আক্তার', email: 'sharmin@gmail.com', phone: '01711111018', role: UserModel.roleTeamMember, zela: 'ঢাকা', thana: 'রামপুরা', myReferralCode: 'TM018', teamId: 'team-dhaka-b', teamName: 'ঢাকা টিম বেটা', totalSales: 480000, totalCommission: 7200, pendingCommission: 3100),
      UserModel(id: 'emp-19', name: 'জুবায়ের হোসেন', email: 'jubayer@gmail.com', phone: '01711111019', role: UserModel.roleTeamMember, zela: 'ঢাকা', thana: 'মোহাম্মদপুর', myReferralCode: 'TM019', teamId: 'team-dhaka-b', teamName: 'ঢাকা টিম বেটা', totalSales: 310000, totalCommission: 4650, pendingCommission: 1800),
      UserModel(id: 'emp-20', name: 'পিয়াল চৌধুরী', email: 'piyal@gmail.com', phone: '01711111020', role: UserModel.roleTeamMember, zela: 'ঢাকা', thana: 'খিলগাঁও', myReferralCode: 'TM020', teamId: 'team-dhaka-b', teamName: 'ঢাকা টিম বেটা', totalSales: 595000, totalCommission: 11900, pendingCommission: 4500),
      // ── চট্টগ্রাম ──────────────────────────────────────────────────────
      UserModel(id: 'emp-04', name: 'জামাল আহমেদ', email: 'jamal@gmail.com', phone: '01711111004', role: UserModel.roleTeamLeader, zela: 'চট্টগ্রাম', thana: 'পাঁচলাইশ', myReferralCode: 'TL004', teamId: 'team-ctg-a', teamName: 'চট্টগ্রাম টিম আলফা', totalSales: 3200000, totalCommission: 80000, pendingCommission: 25000),
      UserModel(id: 'emp-05', name: 'নাসরিন আক্তার', email: 'nasrin@gmail.com', phone: '01711111005', role: UserModel.roleTeamMember, zela: 'চট্টগ্রাম', thana: 'হালিশহর', myReferralCode: 'TM005', teamId: 'team-ctg-a', teamName: 'চট্টগ্রাম টিম আলফা', totalSales: 900000, totalCommission: 18000, pendingCommission: 7000),
      UserModel(id: 'emp-06', name: 'তারিক মাহমুদ', email: 'tariq@gmail.com', phone: '01711111006', role: UserModel.roleTeamMember, zela: 'চট্টগ্রাম', thana: 'আগ্রাবাদ', myReferralCode: 'TM006', teamId: 'team-ctg-a', teamName: 'চট্টগ্রাম টিম আলফা', totalSales: 560000, totalCommission: 11200, pendingCommission: 4500),
      UserModel(id: 'emp-21', name: 'মিলন সরকার', email: 'milon@gmail.com', phone: '01711111021', role: UserModel.roleTeamMember, zela: 'চট্টগ্রাম', thana: 'কালুরঘাট', myReferralCode: 'TM021', teamId: 'team-ctg-a', teamName: 'চট্টগ্রাম টিম আলফা', totalSales: 430000, totalCommission: 6450, pendingCommission: 2600),
      UserModel(id: 'emp-22', name: 'দিলরুবা বেগম', email: 'dilruba@gmail.com', phone: '01711111022', role: UserModel.roleTeamMember, zela: 'চট্টগ্রাম', thana: 'বাকলিয়া', myReferralCode: 'TM022', teamId: 'team-ctg-a', teamName: 'চট্টগ্রাম টিম আলফা', totalSales: 280000, totalCommission: 4200, pendingCommission: 1700),
      UserModel(id: 'emp-23', name: 'সিরাজুল ইসলাম', email: 'sirajul@gmail.com', phone: '01711111023', role: UserModel.roleTeamLeader, zela: 'চট্টগ্রাম', thana: 'নাসিরাবাদ', myReferralCode: 'TL023', teamId: 'team-ctg-b', teamName: 'চট্টগ্রাম টিম বেটা', totalSales: 2750000, totalCommission: 68750, pendingCommission: 22000),
      UserModel(id: 'emp-24', name: 'আয়েশা সিদ্দিকা', email: 'ayesha@gmail.com', phone: '01711111024', role: UserModel.roleTeamMember, zela: 'চট্টগ্রাম', thana: 'চান্দগাঁও', myReferralCode: 'TM024', teamId: 'team-ctg-b', teamName: 'চট্টগ্রাম টিম বেটা', totalSales: 620000, totalCommission: 12400, pendingCommission: 4900),
      // ── রাজশাহী ─────────────────────────────────────────────────────────
      UserModel(id: 'emp-07', name: 'আব্দুল করিম', email: 'abdulk@gmail.com', phone: '01711111007', role: UserModel.roleTeamLeader, zela: 'রাজশাহী', thana: 'বোয়ালিয়া', myReferralCode: 'TL007', teamId: 'team-raj', teamName: 'রাজশাহী টিম', totalSales: 1800000, totalCommission: 45000, pendingCommission: 12000),
      UserModel(id: 'emp-08', name: 'মোসাম্মৎ রিমা', email: 'rima@gmail.com', phone: '01711111008', role: UserModel.roleTeamMember, zela: 'রাজশাহী', thana: 'শাহমখদুম', myReferralCode: 'TM008', teamId: 'team-raj', teamName: 'রাজশাহী টিম', totalSales: 320000, totalCommission: 4800, pendingCommission: 2000),
      UserModel(id: 'emp-25', name: 'কামাল উদ্দিন', email: 'kamal@gmail.com', phone: '01711111025', role: UserModel.roleTeamMember, zela: 'রাজশাহী', thana: 'রাজপাড়া', myReferralCode: 'TM025', teamId: 'team-raj', teamName: 'রাজশাহী টিম', totalSales: 450000, totalCommission: 6750, pendingCommission: 2500),
      UserModel(id: 'emp-26', name: 'সুমাইয়া খানম', email: 'sumaiya@gmail.com', phone: '01711111026', role: UserModel.roleTeamMember, zela: 'রাজশাহী', thana: 'মতিহার', myReferralCode: 'TM026', teamId: 'team-raj', teamName: 'রাজশাহী টিম', totalSales: 260000, totalCommission: 3900, pendingCommission: 1500),
      UserModel(id: 'emp-27', name: 'হাফিজুর রহমান', email: 'hafizur@gmail.com', phone: '01711111027', role: UserModel.roleTeamMember, zela: 'রাজশাহী', thana: 'পুঠিয়া', myReferralCode: 'TM027', teamId: 'team-raj', teamName: 'রাজশাহী টিম', totalSales: 370000, totalCommission: 5550, pendingCommission: 2100),
      // ── সিলেট ─────────────────────────────────────────────────────────
      UserModel(id: 'emp-10', name: 'মারজিয়া হক', email: 'marzia@gmail.com', phone: '01711111010', role: UserModel.roleTeamLeader, zela: 'সিলেট', thana: 'জালালাবাদ', myReferralCode: 'TL010', teamId: 'team-syl', teamName: 'সিলেট টিম', totalSales: 2100000, totalCommission: 52500, pendingCommission: 18000),
      UserModel(id: 'emp-09', name: 'ফারহান ইসলাম', email: 'farhan@gmail.com', phone: '01711111009', role: UserModel.roleTeamMember, zela: 'সিলেট', thana: 'কোতোয়ালি', myReferralCode: 'TM009', teamId: 'team-syl', teamName: 'সিলেট টিম', totalSales: 780000, totalCommission: 15600, pendingCommission: 6000),
      UserModel(id: 'emp-28', name: 'রাহেলা চৌধুরী', email: 'rahela@gmail.com', phone: '01711111028', role: UserModel.roleTeamMember, zela: 'সিলেট', thana: 'এয়ারপোর্ট', myReferralCode: 'TM028', teamId: 'team-syl', teamName: 'সিলেট টিম', totalSales: 510000, totalCommission: 7650, pendingCommission: 3000),
      UserModel(id: 'emp-29', name: 'ওয়াহিদ মিয়া', email: 'wahid@gmail.com', phone: '01711111029', role: UserModel.roleTeamMember, zela: 'সিলেট', thana: 'দক্ষিণ সুরমা', myReferralCode: 'TM029', teamId: 'team-syl', teamName: 'সিলেট টিম', totalSales: 340000, totalCommission: 5100, pendingCommission: 2000),
      UserModel(id: 'emp-30', name: 'লুবনা আহমেদ', email: 'lubna@gmail.com', phone: '01711111030', role: UserModel.roleTeamMember, zela: 'সিলেট', thana: 'বিশ্বনাথ', myReferralCode: 'TM030', teamId: 'team-syl', teamName: 'সিলেট টিম', totalSales: 290000, totalCommission: 4350, pendingCommission: 1700),
      // ── খুলনা ─────────────────────────────────────────────────────────
      UserModel(id: 'emp-31', name: 'মাহবুব আলম', email: 'mahbub@gmail.com', phone: '01711111031', role: UserModel.roleTeamLeader, zela: 'খুলনা', thana: 'খালিশপুর', myReferralCode: 'TL031', teamId: 'team-khl', teamName: 'খুলনা টিম', totalSales: 1650000, totalCommission: 41250, pendingCommission: 14000),
      UserModel(id: 'emp-11', name: 'শামীম রেজা', email: 'shamim@gmail.com', phone: '01711111011', role: UserModel.roleTeamMember, zela: 'খুলনা', thana: 'সোনাডাঙ্গা', myReferralCode: 'TM011', teamId: 'team-khl', teamName: 'খুলনা টিম', totalSales: 430000, totalCommission: 6450, pendingCommission: 2500),
      UserModel(id: 'emp-12', name: 'পারুল বেগম', email: 'parul@gmail.com', phone: '01711111012', role: UserModel.roleTeamMember, zela: 'খুলনা', thana: 'দৌলতপুর', myReferralCode: 'TM012', teamId: 'team-khl', teamName: 'খুলনা টিম', totalSales: 200000, totalCommission: 3000, pendingCommission: 1200),
      UserModel(id: 'emp-32', name: 'ইকবাল হোসেন', email: 'iqbal@gmail.com', phone: '01711111032', role: UserModel.roleTeamMember, zela: 'খুলনা', thana: 'বটিয়াঘাটা', myReferralCode: 'TM032', teamId: 'team-khl', teamName: 'খুলনা টিম', totalSales: 175000, totalCommission: 2625, pendingCommission: 1000),
      // ── ময়মনসিংহ ──────────────────────────────────────────────────────
      UserModel(id: 'emp-33', name: 'নুরুল ইসলাম', email: 'nurul@gmail.com', phone: '01711111033', role: UserModel.roleTeamLeader, zela: 'ময়মনসিংহ', thana: 'কোতোয়ালি', myReferralCode: 'TL033', teamId: 'team-mym', teamName: 'ময়মনসিংহ টিম', totalSales: 1200000, totalCommission: 30000, pendingCommission: 10000),
      UserModel(id: 'emp-34', name: 'কহিনুর বেগম', email: 'kohinur@gmail.com', phone: '01711111034', role: UserModel.roleTeamMember, zela: 'ময়মনসিংহ', thana: 'সদর', myReferralCode: 'TM034', teamId: 'team-mym', teamName: 'ময়মনসিংহ টিম', totalSales: 380000, totalCommission: 5700, pendingCommission: 2200),
      UserModel(id: 'emp-35', name: 'ইমরান খান', email: 'imran@gmail.com', phone: '01711111035', role: UserModel.roleTeamMember, zela: 'ময়মনসিংহ', thana: 'ভালুকা', myReferralCode: 'TM035', teamId: 'team-mym', teamName: 'ময়মনসিংহ টিম', totalSales: 245000, totalCommission: 3675, pendingCommission: 1400),
      // ── বরিশাল ────────────────────────────────────────────────────────
      UserModel(id: 'emp-36', name: 'আলী আকবর', email: 'aliakbar@gmail.com', phone: '01711111036', role: UserModel.roleTeamLeader, zela: 'বরিশাল', thana: 'কোতোয়ালি', myReferralCode: 'TL036', teamId: 'team-bar', teamName: 'বরিশাল টিম', totalSales: 980000, totalCommission: 24500, pendingCommission: 8500),
      UserModel(id: 'emp-37', name: 'লায়লা বেগম', email: 'layla@gmail.com', phone: '01711111037', role: UserModel.roleTeamMember, zela: 'বরিশাল', thana: 'সদর', myReferralCode: 'TM037', teamId: 'team-bar', teamName: 'বরিশাল টিম', totalSales: 310000, totalCommission: 4650, pendingCommission: 1800),
      UserModel(id: 'emp-38', name: 'হাসান মাহমুদ', email: 'hasan@gmail.com', phone: '01711111038', role: UserModel.roleTeamMember, zela: 'বরিশাল', thana: 'আগৈলঝাড়া', myReferralCode: 'TM038', teamId: 'team-bar', teamName: 'বরিশাল টিম', totalSales: 195000, totalCommission: 2925, pendingCommission: 1100),
      // ── রংপুর ─────────────────────────────────────────────────────────
      UserModel(id: 'emp-39', name: 'মজনু মিয়া', email: 'mojnu@gmail.com', phone: '01711111039', role: UserModel.roleTeamLeader, zela: 'রংপুর', thana: 'কোতোয়ালি', myReferralCode: 'TL039', teamId: 'team-rng', teamName: 'রংপুর টিম', totalSales: 870000, totalCommission: 21750, pendingCommission: 7500),
      UserModel(id: 'emp-40', name: 'সুরাইয়া খাতুন', email: 'suraiya@gmail.com', phone: '01711111040', role: UserModel.roleTeamMember, zela: 'রংপুর', thana: 'তারাগঞ্জ', myReferralCode: 'TM040', teamId: 'team-rng', teamName: 'রংপুর টিম', totalSales: 265000, totalCommission: 3975, pendingCommission: 1500),
      // ── কুমিল্লা ──────────────────────────────────────────────────────
      UserModel(id: 'emp-41', name: 'শফিকুল ইসলাম', email: 'shafiq@gmail.com', phone: '01711111041', role: UserModel.roleTeamLeader, zela: 'কুমিল্লা', thana: 'কোতোয়ালি', myReferralCode: 'TL041', teamId: 'team-cum', teamName: 'কুমিল্লা টিম', totalSales: 1450000, totalCommission: 36250, pendingCommission: 12500),
      UserModel(id: 'emp-42', name: 'ফাতেমা তুজ জোহরা', email: 'fatema@gmail.com', phone: '01711111042', role: UserModel.roleTeamMember, zela: 'কুমিল্লা', thana: 'দেবিদ্বার', myReferralCode: 'TM042', teamId: 'team-cum', teamName: 'কুমিল্লা টিম', totalSales: 395000, totalCommission: 5925, pendingCommission: 2300),
      UserModel(id: 'emp-43', name: 'রাজু আহমেদ', email: 'raju@gmail.com', phone: '01711111043', role: UserModel.roleTeamMember, zela: 'কুমিল্লা', thana: 'মুরাদনগর', myReferralCode: 'TM043', teamId: 'team-cum', teamName: 'কুমিল্লা টিম', totalSales: 220000, totalCommission: 3300, pendingCommission: 1200),
      // ── গাজীপুর / নারায়ণগঞ্জ ─────────────────────────────────────────
      UserModel(id: 'emp-44', name: 'আনোয়ার হোসেন', email: 'anwar@gmail.com', phone: '01711111044', role: UserModel.roleTeamLeader, zela: 'গাজীপুর', thana: 'জয়দেবপুর', myReferralCode: 'TL044', teamId: 'team-gaz', teamName: 'গাজীপুর টিম', totalSales: 1900000, totalCommission: 47500, pendingCommission: 16000),
      UserModel(id: 'emp-45', name: 'নাজমা বেগম', email: 'najma@gmail.com', phone: '01711111045', role: UserModel.roleTeamMember, zela: 'নারায়ণগঞ্জ', thana: 'সিদ্ধিরগঞ্জ', myReferralCode: 'TM045', teamId: 'team-gaz', teamName: 'গাজীপুর টিম', totalSales: 490000, totalCommission: 7350, pendingCommission: 2800),
      // ── Admin ──────────────────────────────────────────────────────────
      UserModel(id: 'emp-13', name: 'মেহেদী হাসান', email: 'mehedi@gmail.com', phone: '01711111013', role: UserModel.roleAdmin, zela: 'ঢাকা', thana: 'মতিঝিল', myReferralCode: 'ADM013', totalSales: 6000000, totalCommission: 150000, pendingCommission: 40000),
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
      {'id': 'TKT-001', 'name': 'করিম হোসেন', 'email': 'karim@gmail.com', 'category': 'অর্ডার সমস্যা', 'problem': 'অর্ডার সাবমিট করার পরে কনফার্মেশন পাচ্ছি না। অর্ডার লিস্টেও দেখাচ্ছে না।', 'status': 'সমাধান হয়েছে', 'createdAt': now.subtract(const Duration(days: 50)).toIso8601String()},
      {'id': 'TKT-002', 'name': 'সালমা বেগম', 'email': 'salma@gmail.com', 'category': 'পেমেন্ট সমস্যা', 'problem': 'গত মাসের পেমেন্ট স্ট্যাটাস আপডেট হচ্ছে না। পেমেন্ট ইতিহাসে দেখাচ্ছে না।', 'status': 'প্রক্রিয়াধীন', 'createdAt': now.subtract(const Duration(days: 40)).toIso8601String()},
      {'id': 'TKT-003', 'name': 'নাসরিন আক্তার', 'email': 'nasrin@gmail.com', 'category': 'লগইন সমস্যা', 'problem': 'পাসওয়ার্ড ভুলে গেছি। রিসেট ইমেইল পাচ্ছি না।', 'status': 'সমাধান হয়েছে', 'createdAt': now.subtract(const Duration(days: 35)).toIso8601String()},
      {'id': 'TKT-004', 'name': 'জামাল আহমেদ', 'email': 'jamal@gmail.com', 'category': 'পণ্য সমস্যা', 'problem': 'পণ্যের স্টক আপডেট করার পরেও পুরনো পরিমাণ দেখাচ্ছে।', 'status': 'অপেক্ষমাণ', 'createdAt': now.subtract(const Duration(days: 28)).toIso8601String()},
      {'id': 'TKT-005', 'name': 'ফারহান ইসলাম', 'email': 'farhan@gmail.com', 'category': 'বিক্রয় রিপোর্ট', 'problem': 'মাসিক বিক্রয় রিপোর্ট লোড হচ্ছে না। স্ক্রিন ফাঁকা দেখাচ্ছে।', 'status': 'প্রক্রিয়াধীন', 'createdAt': now.subtract(const Duration(days: 20)).toIso8601String()},
      {'id': 'TKT-006', 'name': 'মারজিয়া হক', 'email': 'marzia@gmail.com', 'category': 'ডেলিভারি সমস্যা', 'problem': 'অর্ডার ডেলিভারি দেওয়ার পরেও স্ট্যাটাস "পেন্ডিং" দেখাচ্ছে।', 'status': 'অপেক্ষমাণ', 'createdAt': now.subtract(const Duration(days: 14)).toIso8601String()},
      {'id': 'TKT-007', 'name': 'শামীম রেজা', 'email': 'shamim@gmail.com', 'category': 'পেমেন্ট সমস্যা', 'problem': 'bKash পেমেন্ট কালেক্ট করার পর ট্রানজেকশন আইডি পাচ্ছি না।', 'status': 'সমাধান হয়েছে', 'createdAt': now.subtract(const Duration(days: 9)).toIso8601String()},
      {'id': 'TKT-008', 'name': 'তারিক মাহমুদ', 'email': 'tariq@gmail.com', 'category': 'সাধারণ সমস্যা', 'problem': 'অ্যাপ স্লো হয়ে যাচ্ছে। অনেক অর্ডার লোড করতে বেশি সময় লাগছে।', 'status': 'অপেক্ষমাণ', 'createdAt': now.subtract(const Duration(days: 3)).toIso8601String()},
    ];
    await prefs.setString(_keyTickets, jsonEncode(tickets));

    // ── More Team Members ─────────────────────────────────────────────────
    final teamMembers = [
      UserModel(id: 'emp-01', name: 'রহিম উদ্দিন', email: 'rahim@gmail.com', phone: '01711111001', role: UserModel.roleTeamLeader, zela: 'ঢাকা', thana: 'মিরপুর', myReferralCode: 'TL001', teamId: 'team-dhaka-a', teamName: 'ঢাকা টিম আলফা', totalSales: 2500000, totalCommission: 62500, pendingCommission: 20000),
      UserModel(id: 'emp-02', name: 'করিম হোসেন', email: 'karim@gmail.com', phone: '01711111002', role: UserModel.roleTeamMember, zela: 'ঢাকা', thana: 'ধানমন্ডি', myReferralCode: 'TM002', teamId: 'team-dhaka-a', teamName: 'ঢাকা টিম আলফা', totalSales: 650000, totalCommission: 13000, pendingCommission: 5000),
      UserModel(id: 'emp-03', name: 'সালমা বেগম', email: 'salma@gmail.com', phone: '01711111003', role: UserModel.roleTeamMember, zela: 'ঢাকা', thana: 'উত্তরা', myReferralCode: 'TM003', teamId: 'team-dhaka-a', teamName: 'ঢাকা টিম আলফা', totalSales: 400000, totalCommission: 6000, pendingCommission: 3000),
      UserModel(id: 'emp-04', name: 'জামাল আহমেদ', email: 'jamal@gmail.com', phone: '01711111004', role: UserModel.roleTeamLeader, zela: 'চট্টগ্রাম', thana: 'পাঁচলাইশ', myReferralCode: 'TL004', teamId: 'team-ctg-a', teamName: 'চট্টগ্রাম টিম আলফা', totalSales: 3200000, totalCommission: 80000, pendingCommission: 25000),
      UserModel(id: 'emp-05', name: 'নাসরিন আক্তার', email: 'nasrin@gmail.com', phone: '01711111005', role: UserModel.roleTeamMember, zela: 'চট্টগ্রাম', thana: 'হালিশহর', myReferralCode: 'TM005', teamId: 'team-ctg-a', teamName: 'চট্টগ্রাম টিম আলফা', totalSales: 900000, totalCommission: 18000, pendingCommission: 7000),
      UserModel(id: 'emp-06', name: 'তারিক মাহমুদ', email: 'tariq@gmail.com', phone: '01711111006', role: UserModel.roleTeamMember, zela: 'চট্টগ্রাম', thana: 'আগ্রাবাদ', myReferralCode: 'TM006', teamId: 'team-ctg-a', teamName: 'চট্টগ্রাম টিম আলফা', totalSales: 560000, totalCommission: 11200, pendingCommission: 4500),
      UserModel(id: 'emp-14', name: 'তানভীর আহমেদ', email: 'tanvir@gmail.com', phone: '01711111014', role: UserModel.roleTeamMember, zela: 'ঢাকা', thana: 'গুলশান', myReferralCode: 'TM014', teamId: 'team-dhaka-a', teamName: 'ঢাকা টিম আলফা', totalSales: 870000, totalCommission: 17400, pendingCommission: 6500),
      UserModel(id: 'emp-15', name: 'নাহিদা পারভীন', email: 'nahida@gmail.com', phone: '01711111015', role: UserModel.roleTeamMember, zela: 'ঢাকা', thana: 'বনানী', myReferralCode: 'TM015', teamId: 'team-dhaka-a', teamName: 'ঢাকা টিম আলফা', totalSales: 540000, totalCommission: 10800, pendingCommission: 4000),
      UserModel(id: 'emp-16', name: 'সাদেক আলী', email: 'sadek@gmail.com', phone: '01711111016', role: UserModel.roleTeamLeader, zela: 'ঢাকা', thana: 'বসুন্ধরা', myReferralCode: 'TL016', teamId: 'team-dhaka-b', teamName: 'ঢাকা টিম বেটা', totalSales: 3100000, totalCommission: 77500, pendingCommission: 28000),
      UserModel(id: 'emp-10', name: 'মারজিয়া হক', email: 'marzia@gmail.com', phone: '01711111010', role: UserModel.roleTeamLeader, zela: 'সিলেট', thana: 'জালালাবাদ', myReferralCode: 'TL010', teamId: 'team-syl', teamName: 'সিলেট টিম', totalSales: 2100000, totalCommission: 52500, pendingCommission: 18000),
      UserModel(id: 'emp-31', name: 'মাহবুব আলম', email: 'mahbub@gmail.com', phone: '01711111031', role: UserModel.roleTeamLeader, zela: 'খুলনা', thana: 'খালিশপুর', myReferralCode: 'TL031', teamId: 'team-khl', teamName: 'খুলনা টিম', totalSales: 1650000, totalCommission: 41250, pendingCommission: 14000),
      UserModel(id: 'emp-44', name: 'আনোয়ার হোসেন', email: 'anwar@gmail.com', phone: '01711111044', role: UserModel.roleTeamLeader, zela: 'গাজীপুর', thana: 'জয়দেবপুর', myReferralCode: 'TL044', teamId: 'team-gaz', teamName: 'গাজীপুর টিম', totalSales: 1900000, totalCommission: 47500, pendingCommission: 16000),
      UserModel(id: 'emp-23', name: 'সিরাজুল ইসলাম', email: 'sirajul@gmail.com', phone: '01711111023', role: UserModel.roleTeamLeader, zela: 'চট্টগ্রাম', thana: 'নাসিরাবাদ', myReferralCode: 'TL023', teamId: 'team-ctg-b', teamName: 'চট্টগ্রাম টিম বেটা', totalSales: 2750000, totalCommission: 68750, pendingCommission: 22000),
      UserModel(id: 'emp-28', name: 'রাহেলা চৌধুরী', email: 'rahela@gmail.com', phone: '01711111028', role: UserModel.roleTeamMember, zela: 'সিলেট', thana: 'এয়ারপোর্ট', myReferralCode: 'TM028', teamId: 'team-syl', teamName: 'সিলেট টিম', totalSales: 510000, totalCommission: 7650, pendingCommission: 3000),
      UserModel(id: 'emp-07', name: 'আব্দুল করিম', email: 'abdulk@gmail.com', phone: '01711111007', role: UserModel.roleTeamLeader, zela: 'রাজশাহী', thana: 'বোয়ালিয়া', myReferralCode: 'TL007', teamId: 'team-raj', teamName: 'রাজশাহী টিম', totalSales: 1800000, totalCommission: 45000, pendingCommission: 12000),
      UserModel(id: 'emp-25', name: 'কামাল উদ্দিন', email: 'kamal@gmail.com', phone: '01711111025', role: UserModel.roleTeamMember, zela: 'রাজশাহী', thana: 'রাজপাড়া', myReferralCode: 'TM025', teamId: 'team-raj', teamName: 'রাজশাহী টিম', totalSales: 450000, totalCommission: 6750, pendingCommission: 2500),
      UserModel(id: 'emp-17', name: 'রিফাত জামান', email: 'rifat@gmail.com', phone: '01711111017', role: UserModel.roleTeamMember, zela: 'ঢাকা', thana: 'মতিঝিল', myReferralCode: 'TM017', teamId: 'team-dhaka-b', teamName: 'ঢাকা টিম বেটা', totalSales: 720000, totalCommission: 14400, pendingCommission: 5800),
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
                'source': '${o.customerName} — অর্ডার ডেলিভারি',
                'commission': o.total * rate,
                'type': 'অর্ডার কমিশন',
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

  // ── Withdrawal ─────────────────────────────────────────────────────────
  static const _keyWithdrawals = 'withdrawals';

  static Future<List<Map<String, dynamic>>> getWithdrawalHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyWithdrawals);
    if (raw == null) return [];
    final List<dynamic> list = jsonDecode(raw);
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<void> requestWithdrawal({
    required String bkashNumber,
    required double amount,
  }) async {
    final user = await getCurrentUser();
    if (user == null) return;
    // Deduct from pending commission
    final newPending = (user.pendingCommission - amount).clamp(0.0, double.infinity);
    final updated = user.copyWith(pendingCommission: newPending);
    await saveCurrentUser(updated);

    // Save withdrawal record
    final record = {
      'id': 'WD-${DateTime.now().millisecondsSinceEpoch}',
      'userId': user.id,
      'bkashNumber': bkashNumber,
      'amount': amount,
      'status': 'অপেক্ষমাণ',
      'date': DateTime.now().toIso8601String(),
    };
    final list = await getWithdrawalHistory();
    list.insert(0, record);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyWithdrawals, jsonEncode(list));
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

  /// Demo orders seeded on first launch
  static List<OrderModel> _demoOrders() {
    final now = DateTime.now();
    return [
      OrderModel(
        id: 'ORD-DEMO-001',
        srId: 'demo-teammember',
        srName: 'করিম হোসেন (SR)',
        customerId: 'demo-customer',
        customerName: 'মেসার্স আল-আমিন ট্রেডার্স',
        items: [
          const OrderItem(
              productName: 'পণ্য-A ১ কেজি',
              quantity: 20,
              unit: 'কেজি',
              unitPrice: 250),
          const OrderItem(
              productName: 'পণ্য-B ৫০০ গ্রাম',
              quantity: 10,
              unit: 'পিস',
              unitPrice: 120),
        ],
        total: 6200,
        date: now.subtract(const Duration(days: 1)),
        status: 'confirmed',
      ),
      OrderModel(
        id: 'ORD-DEMO-002',
        srId: 'demo-teamleader',
        srName: 'রহিম উদ্দিন (TL)',
        customerId: 'cust-002',
        customerName: 'নিউ ঢাকা এন্টারপ্রাইজ',
        items: [
          const OrderItem(
              productName: 'পণ্য-C ২ লিটার',
              quantity: 5,
              unit: 'লিটার',
              unitPrice: 450),
          const OrderItem(
              productName: 'পণ্য-D বাক্স',
              quantity: 3,
              unit: 'বাক্স',
              unitPrice: 1800),
        ],
        total: 7650,
        date: now.subtract(const Duration(days: 2)),
        status: 'delivered',
      ),
      OrderModel(
        id: 'ORD-DEMO-003',
        srId: 'demo-teammember',
        srName: 'করিম হোসেন (SR)',
        customerId: 'cust-003',
        customerName: 'রহমান স্টোর্স',
        items: [
          const OrderItem(
              productName: 'পণ্য-E ডজন',
              quantity: 8,
              unit: 'ডজন',
              unitPrice: 360),
        ],
        total: 2880,
        date: now.subtract(const Duration(days: 3)),
        status: 'confirmed',
      ),
      OrderModel(
        id: 'ORD-DEMO-004',
        srId: 'demo-teamleader',
        srName: 'রহিম উদ্দিন (TL)',
        customerId: 'demo-customer',
        customerName: 'মেসার্স আল-আমিন ট্রেডার্স',
        items: [
          const OrderItem(
              productName: 'পণ্য-F কার্টন',
              quantity: 4,
              unit: 'কার্টন',
              unitPrice: 2400),
          const OrderItem(
              productName: 'পণ্য-A ১ কেজি',
              quantity: 15,
              unit: 'কেজি',
              unitPrice: 250),
        ],
        total: 13350,
        date: now.subtract(const Duration(days: 5)),
        status: 'delivered',
      ),
      OrderModel(
        id: 'ORD-DEMO-005',
        srId: 'demo-sr',
        srName: 'সেলস রিপ্রেজেন্টেটিভ',
        customerId: 'cust-005',
        customerName: 'সিটি ট্রেডিং কোম্পানি',
        items: [
          const OrderItem(
              productName: 'পণ্য-B ৫০০ গ্রাম',
              quantity: 25,
              unit: 'পিস',
              unitPrice: 120),
          const OrderItem(
              productName: 'পণ্য-D বাক্স',
              quantity: 2,
              unit: 'বাক্স',
              unitPrice: 1800),
        ],
        total: 6600,
        date: now.subtract(const Duration(hours: 6)),
        status: 'pending',
      ),
    ];
  }
}
