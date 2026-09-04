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
  final String branch;
  final String areaName;
  final String zoneName;
  final String destination;
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
    this.role = 'Team Member',
    this.zela = '',
    this.thana = '',
    this.myReferralCode = '',
    this.referredByCode = '',
    this.teamId = '',
    this.teamName = '',
    this.branch = '',
    this.areaName = '',
    this.zoneName = '',
    this.destination = '',
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

  static const String roleSuperAdmin = 'Super Admin';
  static const String roleAdmin = 'Admin';
  static const String roleTeamLeader = 'Team Leader';
  static const String roleTeamMember = 'Team Member';
  static const String roleInvestor = 'Investor';
  static const String roleCustomer = 'Customer';

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
    if (totalSales >= 5000000) return 'Platinum';
    if (totalSales >= 2000000) return 'Gold';
    if (totalSales >= 500000) return 'Silver';
    return 'Bronze';
  }

  Color get badgeColor {
    switch (badge) {
      case 'Platinum': return const Color(0xFF7B1FA2);
      case 'Gold':     return const Color(0xFFF57F17);
      case 'Silver':   return const Color(0xFF546E7A);
      default:         return const Color(0xFF6D4C41);
    }
  }

  IconData get badgeIcon {
    switch (badge) {
      case 'Platinum': return Icons.diamond_rounded;
      case 'Gold':     return Icons.workspace_premium_rounded;
      case 'Silver':   return Icons.military_tech_rounded;
      default:         return Icons.emoji_events_rounded;
    }
  }

  double get commissionRate {
    switch (badge) {
      case 'Platinum': return 0.03;
      case 'Gold':     return 0.025;
      case 'Silver':   return 0.02;
      default:         return 0.015;
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
    if (totalSales >= 5000000) return 'Top Level';
    if (totalSales >= 2000000) return 'Platinum';
    if (totalSales >= 500000) return 'Gold';
    return 'Silver';
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
        'branch': branch,
        'areaName': areaName,
        'zoneName': zoneName,
        'destination': destination,
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
        branch: m['branch'] ?? '',
        areaName: m['areaName'] ?? m['branch'] ?? '',
        zoneName: m['zoneName'] ?? '',
        destination: m['destination'] ?? m['areaName'] ?? m['branch'] ?? '',
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
    String? branch,
    String? areaName,
    String? zoneName,
    String? destination,
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
        branch: branch ?? this.branch,
        areaName: areaName ?? this.areaName,
        zoneName: zoneName ?? this.zoneName,
        destination: destination ?? this.destination,
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

  /// Bangladesh — 64 districts (Romanized)
  static const List<String> zelaList = [
    'Dhaka', 'Gazipur', 'Narayanganj', 'Munshiganj', 'Manikganj',
    'Narsingdi', 'Tangail', 'Kishoreganj', 'Faridpur', 'Gopalganj',
    'Madaripur', 'Rajbari', 'Shariatpur', 'Mymensingh', 'Netrokona',
    'Jamalpur', 'Sherpur', 'Chattogram', 'Cox\'s Bazar', 'Cumilla',
    'Feni', 'Brahmanbaria', 'Rangamati', 'Noakhali', 'Chandpur',
    'Lakshmipur', 'Khagrachhari', 'Bandarban', 'Rajshahi', 'Natore',
    'Chapainawabganj', 'Pabna', 'Sirajganj', 'Bogura', 'Joypurhat',
    'Naogaon', 'Khulna', 'Bagerhat', 'Satkhira', 'Jashore', 'Jhenaidah',
    'Magura', 'Narail', 'Kushtia', 'Meherpur', 'Chuadanga',
    'Barishal', 'Patuakhali', 'Bhola', 'Pirojpur', 'Jhalokathi',
    'Barguna', 'Sylhet', 'Moulvibazar', 'Habiganj', 'Sunamganj',
    'Rangpur', 'Dinajpur', 'Gaibandha', 'Kurigram', 'Lalmonirhat',
    'Nilphamari', 'Thakurgaon', 'Panchagarh',
  ];
}
