class TargetModel {
  final String id;
  final String userId;
  final String userName;
  final String setById;
  final String setByName;
  final double targetAmount;
  final double commissionPercent;
  final String month; // e.g. "2026-07"
  final DateTime createdAt;

  TargetModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.setById,
    required this.setByName,
    required this.targetAmount,
    required this.commissionPercent,
    required this.month,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'userName': userName,
        'setById': setById,
        'setByName': setByName,
        'targetAmount': targetAmount,
        'commissionPercent': commissionPercent,
        'month': month,
        'createdAt': createdAt.toIso8601String(),
      };

  factory TargetModel.fromMap(Map<String, dynamic> m) => TargetModel(
        id: m['id'] ?? '',
        userId: m['userId'] ?? '',
        userName: m['userName'] ?? '',
        setById: m['setById'] ?? '',
        setByName: m['setByName'] ?? '',
        targetAmount: (m['targetAmount'] as num?)?.toDouble() ?? 0,
        commissionPercent: (m['commissionPercent'] as num?)?.toDouble() ?? 0,
        month: m['month'] ?? '',
        createdAt: DateTime.tryParse(m['createdAt'] ?? '') ?? DateTime.now(),
      );
}
