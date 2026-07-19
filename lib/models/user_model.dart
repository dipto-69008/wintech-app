import 'package:flutter/material.dart';

class UserModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String company;
  final String designation;
  final String role;
  final String zela;
  final String thana;
  final String myReferralCode;
  final String referredByCode;
  final String teamId;
  final String teamName;
  // SR / Sales performance
  final double totalSales;
  final double totalCommission;
  final double pendingCommission;
  final double targetAmount;    // SR monthly target (BDT)
  final double achievedAmount;  // SR monthly achievement (BDT)
  // Customer-specific
  final double creditLimit;     // Customer credit limit (BDT)
  final double creditUsed;      // Credit already used (BDT)
  // Legacy / backward compat
  final String customerPropertyId;
  final String customerPropertyTitle;
  final String investorType;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone = '',
    this.company = '',
    this.designation = '',
    this.role = 'টিম মেম্বার',
    this.zela = '',
    this.thana = '',
    this.myReferralCode = '',
    this.referredByCode = '',
    this.teamId = '',
    this.teamName = '',
    this.totalSales = 0,
    this.totalCommission = 0,
    this.pendingCommission = 0,
    this.targetAmount = 0,
    this.achievedAmount = 0,
    this.creditLimit = 0,
    this.creditUsed = 0,
    this.customerPropertyId = '',
    this.customerPropertyTitle = '',
    this.investorType = 'zero',
  });

  static const String roleSuperAdmin = 'সুপার অ্যাডমিন';
  static const String roleAdmin = 'অ্যাডমিন';
  static const String roleTeamLeader = 'টিম লিডার';
  static const String roleTeamMember = 'টিম মেম্বার';
  static const String roleInvestor = 'ইনভেস্টর';
  static const String roleCustomer = 'কাস্টমার';

  bool get isSuperAdmin => role == roleSuperAdmin;
  bool get isAdmin => role == roleAdmin || role == roleSuperAdmin;
  bool get isTeamLeader => role == roleTeamLeader;
  bool get isEmployee =>
      role == roleTeamLeader || role == roleTeamMember || role == roleInvestor;
  bool get isSR => isEmployee; // Sales Representative
  bool get canManageTeam => isSuperAdmin || isAdmin || isTeamLeader;
  bool get isCustomer => role == roleCustomer;
  bool get canMeet => isSuperAdmin || isAdmin || isTeamLeader;
  bool get isInvestorEmployee =>
      role == roleInvestor || investorType == 'investor';
  bool get isPendingOnboarding => !isCustomer && investorType.isEmpty;

  double get creditAvailable => (creditLimit - creditUsed).clamp(0, double.infinity);
  double get creditUsedPercent =>
      creditLimit > 0 ? (creditUsed / creditLimit).clamp(0.0, 1.0) : 0;
  double get targetProgress =>
      targetAmount > 0 ? (achievedAmount / targetAmount).clamp(0.0, 1.0) : 0;

  // ── Badge System ────────────────────────────────────────────────────
  String get badge {
    if (totalSales >= 5000000) return 'প্লাটিনাম';
    if (totalSales >= 2000000) return 'গোল্ড';
    if (totalSales >= 500000) return 'সিলভার';
    return 'ব্রোঞ্জ';
  }

  Color get badgeColor {
    switch (badge) {
      case 'প্লাটিনাম': return const Color(0xFF7B1FA2);
      case 'গোল্ড':     return const Color(0xFFF57F17);
      case 'সিলভার':    return const Color(0xFF546E7A);
      default:          return const Color(0xFF6D4C41);
    }
  }

  IconData get badgeIcon {
    switch (badge) {
      case 'প্লাটিনাম': return Icons.diamond_rounded;
      case 'গোল্ড':     return Icons.workspace_premium_rounded;
      case 'সিলভার':    return Icons.military_tech_rounded;
      default:          return Icons.emoji_events_rounded;
    }
  }

  double get commissionRate {
    switch (badge) {
      case 'প্লাটিনাম': return 0.03;
      case 'গোল্ড':     return 0.025;
      case 'সিলভার':    return 0.02;
      default:          return 0.015;
    }
  }

  double get nextBadgeTarget {
    if (totalSales >= 5000000) return 5000000;
    if (totalSales >= 2000000) return 5000000;
    if (totalSales >= 500000) return 2000000;
    return 500000;
  }

  double get badgeProgress {
    if (totalSales >= 5000000) return 1.0;
    if (totalSales >= 2000000) {
      return ((totalSales - 2000000) / 3000000).clamp(0.0, 1.0);
    }
    if (totalSales >= 500000) {
      return ((totalSales - 500000) / 1500000).clamp(0.0, 1.0);
    }
    return (totalSales / 500000).clamp(0.0, 1.0);
  }

  String get nextBadgeName {
    if (totalSales >= 5000000) return 'সর্বোচ্চ পর্যায়';
    if (totalSales >= 2000000) return 'প্লাটিনাম';
    if (totalSales >= 500000) return 'গোল্ড';
    return 'সিলভার';
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'company': company,
        'designation': designation,
        'role': role,
        'zela': zela,
        'thana': thana,
        'myReferralCode': myReferralCode,
        'referredByCode': referredByCode,
        'teamId': teamId,
        'teamName': teamName,
        'totalSales': totalSales,
        'totalCommission': totalCommission,
        'pendingCommission': pendingCommission,
        'targetAmount': targetAmount,
        'achievedAmount': achievedAmount,
        'creditLimit': creditLimit,
        'creditUsed': creditUsed,
        'customerPropertyId': customerPropertyId,
        'customerPropertyTitle': customerPropertyTitle,
        'investorType': investorType,
      };

  factory UserModel.fromMap(Map<String, dynamic> m) => UserModel(
        id: m['id'] ?? '',
        name: m['name'] ?? '',
        email: m['email'] ?? '',
        phone: m['phone'] ?? '',
        company: m['company'] ?? '',
        designation: m['designation'] ?? '',
        role: m['role'] ?? roleTeamMember,
        zela: m['zela'] ?? '',
        thana: m['thana'] ?? '',
        myReferralCode: m['myReferralCode'] ?? '',
        referredByCode: m['referredByCode'] ?? '',
        teamId: m['teamId'] ?? '',
        teamName: m['teamName'] ?? '',
        totalSales: (m['totalSales'] as num?)?.toDouble() ?? 0,
        totalCommission: (m['totalCommission'] as num?)?.toDouble() ?? 0,
        pendingCommission: (m['pendingCommission'] as num?)?.toDouble() ?? 0,
        targetAmount: (m['targetAmount'] as num?)?.toDouble() ?? 0,
        achievedAmount: (m['achievedAmount'] as num?)?.toDouble() ?? 0,
        creditLimit: (m['creditLimit'] as num?)?.toDouble() ?? 0,
        creditUsed: (m['creditUsed'] as num?)?.toDouble() ?? 0,
        customerPropertyId: m['customerPropertyId'] ?? '',
        customerPropertyTitle: m['customerPropertyTitle'] ?? '',
        investorType: m['investorType'] ?? 'zero',
      );

  UserModel copyWith({
    String? name,
    String? phone,
    String? company,
    String? designation,
    String? role,
    String? zela,
    String? thana,
    String? teamId,
    String? teamName,
    double? totalSales,
    double? totalCommission,
    double? pendingCommission,
    double? targetAmount,
    double? achievedAmount,
    double? creditLimit,
    double? creditUsed,
    String? customerPropertyId,
    String? customerPropertyTitle,
    String? investorType,
  }) =>
      UserModel(
        id: id,
        name: name ?? this.name,
        email: email,
        phone: phone ?? this.phone,
        company: company ?? this.company,
        designation: designation ?? this.designation,
        role: role ?? this.role,
        zela: zela ?? this.zela,
        thana: thana ?? this.thana,
        myReferralCode: myReferralCode,
        referredByCode: referredByCode,
        teamId: teamId ?? this.teamId,
        teamName: teamName ?? this.teamName,
        totalSales: totalSales ?? this.totalSales,
        totalCommission: totalCommission ?? this.totalCommission,
        pendingCommission: pendingCommission ?? this.pendingCommission,
        targetAmount: targetAmount ?? this.targetAmount,
        achievedAmount: achievedAmount ?? this.achievedAmount,
        creditLimit: creditLimit ?? this.creditLimit,
        creditUsed: creditUsed ?? this.creditUsed,
        customerPropertyId: customerPropertyId ?? this.customerPropertyId,
        customerPropertyTitle:
            customerPropertyTitle ?? this.customerPropertyTitle,
        investorType: investorType ?? this.investorType,
      );

  /// Bangladesh — 64 districts
  static const List<String> zelaList = [
    'ঢাকা', 'গাজীপুর', 'নারায়ণগঞ্জ', 'মুন্সিগঞ্জ', 'মানিকগঞ্জ',
    'নরসিংদী', 'টাঙ্গাইল', 'কিশোরগঞ্জ', 'ফরিদপুর', 'গোপালগঞ্জ',
    'মাদারীপুর', 'রাজবাড়ী', 'শরীয়তপুর', 'ময়মনসিংহ', 'নেত্রকোণা',
    'জামালপুর', 'শেরপুর', 'চট্টগ্রাম', 'কক্সবাজার', 'কুমিল্লা',
    'ফেনী', 'ব্রাহ্মণবাড়িয়া', 'রাঙ্গামাটি', 'নোয়াখালী', 'চাঁদপুর',
    'লক্ষ্মীপুর', 'খাগড়াছড়ি', 'বান্দরবান', 'রাজশাহী', 'নাটোর',
    'চাঁপাইনবাবগঞ্জ', 'পাবনা', 'সিরাজগঞ্জ', 'বগুড়া', 'জয়পুরহাট',
    'নওগাঁ', 'খুলনা', 'বাগেরহাট', 'সাতক্ষীরা', 'যশোর', 'ঝিনাইদহ',
    'মাগুরা', 'নড়াইল', 'কুষ্টিয়া', 'মেহেরপুর', 'চুয়াডাঙ্গা',
    'বরিশাল', 'পটুয়াখালী', 'ভোলা', 'পিরোজপুর', 'ঝালকাঠি',
    'বরগুনা', 'সিলেট', 'মৌলভীবাজার', 'হবিগঞ্জ', 'সুনামগঞ্জ',
    'রংপুর', 'দিনাজপুর', 'গাইবান্ধা', 'কুড়িগ্রাম', 'লালমনিরহাট',
    'নীলফামারী', 'ঠাকুরগাঁও', 'পঞ্চগড়',
  ];
}
