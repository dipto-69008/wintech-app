class LeaveModel {
  final String id;
  final String leaveType;
  final DateTime fromDate;
  final DateTime toDate;
  final String reason;
  final String status; // pending | approved | rejected
  final String srId;
  final String srName;
  final DateTime appliedAt;
  final String adminNote;
  final List<String> attachments; // supporting document photos (paths/URLs)
  final DateTime? joiningDate;    // re-joining date after leave
  final bool isEncashment;        // leave encashment request (payout)
  final int encashmentDays;       // days requested for encashment

  const LeaveModel({
    required this.id,
    required this.leaveType,
    required this.fromDate,
    required this.toDate,
    this.reason = '',
    this.status = 'pending',
    required this.srId,
    required this.srName,
    required this.appliedAt,
    this.adminNote = '',
    this.attachments = const [],
    this.joiningDate,
    this.isEncashment = false,
    this.encashmentDays = 0,
  });

  static const String typeCasual     = 'casual';
  static const String typeSick      = 'sick';
  static const String typeFuneral   = 'funeral';
  static const String typePaternity = 'paternity';
  static const String typeMarriage  = 'marriage';
  static const String typeWithoutPay = 'without_pay';
  static const String typeEncashment = 'encashment';

  static const String statusPending  = 'pending';
  static const String statusApproved = 'approved';
  static const String statusRejected = 'rejected';

  /// Restricted list — only these leave types can be applied for.
  static const List<String> leaveTypes = [
    typeCasual, typeSick, typeFuneral, typePaternity,
    typeMarriage, typeWithoutPay, typeEncashment,
  ];

  String get typeLabel {
    switch (leaveType) {
      case typeCasual:     return 'Casual Leave';
      case typeSick:       return 'Sick Leave';
      case typeFuneral:    return 'Funeral Leave';
      case typePaternity:  return 'Paternity Leave';
      case typeMarriage:   return 'Marriage Leave';
      case typeWithoutPay: return 'Leave Without Pay';
      case typeEncashment: return 'Leave Encashment';
      default:             return 'Casual Leave';
    }
  }

  static String normalizeLeaveType(dynamic raw) {
    final value = (raw ?? '').toString().trim().toLowerCase().replaceAll('-', '_');
    if (value == typeSick || value.contains('sick') || value == 'medical') {
      return typeSick;
    }
    if (value == typeFuneral || value.contains('funeral')) return typeFuneral;
    if (value == typePaternity || value.contains('paternity')) return typePaternity;
    if (value == typeMarriage || value.contains('marriage')) return typeMarriage;
    if (value == typeWithoutPay ||
        value.contains('without pay') ||
        value.contains('without_pay') ||
        value.contains('unpaid')) {
      return typeWithoutPay;
    }
    if (value == typeEncashment || value.contains('encash')) return typeEncashment;
    return typeCasual;
  }

  String get statusLabel {
    switch (status) {
      case statusApproved: return 'Approved';
      case statusRejected: return 'Rejected';
      default:             return 'Pending';
    }
  }

  int get totalDays {
    final start = DateTime.utc(fromDate.year, fromDate.month, fromDate.day);
    final end = DateTime.utc(toDate.year, toDate.month, toDate.day);
    return end.difference(start).inDays + 1;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'leaveType': leaveType,
        'fromDate': fromDate.toIso8601String(),
        'toDate': toDate.toIso8601String(),
        'reason': reason,
        'status': status,
        'srId': srId,
        'srName': srName,
        'appliedAt': appliedAt.toIso8601String(),
        'adminNote': adminNote,
        'attachments': attachments,
        if (joiningDate != null) 'joiningDate': joiningDate!.toIso8601String(),
        'isEncashment': isEncashment,
        'encashmentDays': encashmentDays,
      };

  factory LeaveModel.fromMap(Map<String, dynamic> m) => LeaveModel(
        id: m['id'] ?? '',
        leaveType: normalizeLeaveType(m['leaveType'] ?? m['type']),
        fromDate: DateTime.tryParse(m['fromDate']?.toString() ?? '') ??
            DateTime.now(),
        toDate: DateTime.tryParse(m['toDate']?.toString() ?? '') ??
            DateTime.now(),
        reason: m['reason'] ?? '',
        status: m['status'] ?? statusPending,
        srId: m['srId'] ?? '',
        srName: m['srName'] ?? '',
        appliedAt: DateTime.tryParse(m['appliedAt']?.toString() ?? '') ??
            DateTime.now(),
        adminNote: m['adminNote'] ?? '',
        attachments: (m['attachments'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        joiningDate: (m['joiningDate'] ?? '').toString().isEmpty
            ? null
            : DateTime.tryParse(m['joiningDate'].toString()),
        isEncashment: m['isEncashment'] == true,
        encashmentDays: (m['encashmentDays'] as num?)?.toInt() ?? 0,
      );

  LeaveModel copyWith({String? status, String? adminNote}) => LeaveModel(
        id: id,
        leaveType: leaveType,
        fromDate: fromDate,
        toDate: toDate,
        reason: reason,
        status: status ?? this.status,
        srId: srId,
        srName: srName,
        appliedAt: appliedAt,
        adminNote: adminNote ?? this.adminNote,
        attachments: attachments,
        joiningDate: joiningDate,
        isEncashment: isEncashment,
        encashmentDays: encashmentDays,
      );
}
