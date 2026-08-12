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
  });

  static const String typeCasual     = 'casual';
  static const String typeMedical    = 'medical';
  static const String typeAnnual     = 'annual';
  static const String typeEarn       = 'earn';
  static const String typeWithoutPay = 'without_pay';
  static const String typeOther      = 'other';

  static const String statusPending  = 'pending';
  static const String statusApproved = 'approved';
  static const String statusRejected = 'rejected';

  static const List<String> leaveTypes = [
    typeCasual, typeMedical, typeAnnual,
    typeEarn, typeWithoutPay, typeOther,
  ];

  String get typeLabel {
    switch (leaveType) {
      case typeCasual:     return 'Casual Leave';
      case typeMedical:    return 'Medical Leave';
      case typeAnnual:     return 'Annual Leave';
      case typeEarn:       return 'Earned Leave';
      case typeWithoutPay: return 'Leave Without Pay';
      default:             return 'Other Leave';
    }
  }

  String get statusLabel {
    switch (status) {
      case statusApproved: return 'Approved';
      case statusRejected: return 'Rejected';
      default:             return 'Pending';
    }
  }

  int get totalDays => toDate.difference(fromDate).inDays + 1;

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
      };

  factory LeaveModel.fromMap(Map<String, dynamic> m) => LeaveModel(
        id: m['id'] ?? '',
        leaveType: m['leaveType'] ?? typeCasual,
        fromDate: DateTime.parse(
            m['fromDate'] ?? DateTime.now().toIso8601String()),
        toDate: DateTime.parse(
            m['toDate'] ?? DateTime.now().toIso8601String()),
        reason: m['reason'] ?? '',
        status: m['status'] ?? statusPending,
        srId: m['srId'] ?? '',
        srName: m['srName'] ?? '',
        appliedAt: DateTime.parse(
            m['appliedAt'] ?? DateTime.now().toIso8601String()),
        adminNote: m['adminNote'] ?? '',
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
      );
}
