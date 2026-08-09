class StockTransferModel {
  final String id;
  final String fromWarehouse;
  final String toWarehouse;
  final String productName;
  final double quantity;
  final String unit;
  final DateTime date;
  final String notes;
  final String status; // pending | approved | rejected
  final String srId;
  final String srName;

  const StockTransferModel({
    required this.id,
    required this.fromWarehouse,
    required this.toWarehouse,
    required this.productName,
    required this.quantity,
    required this.unit,
    required this.date,
    this.notes = '',
    this.status = 'pending',
    required this.srId,
    required this.srName,
  });

  static const String statusPending  = 'pending';
  static const String statusApproved = 'approved';
  static const String statusRejected = 'rejected';

  String get statusLabel {
    switch (status) {
      case statusApproved: return 'Approved';
      case statusRejected: return 'Rejected';
      default:             return 'Pending';
    }
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'fromWarehouse': fromWarehouse,
        'toWarehouse': toWarehouse,
        'productName': productName,
        'quantity': quantity,
        'unit': unit,
        'date': date.toIso8601String(),
        'notes': notes,
        'status': status,
        'srId': srId,
        'srName': srName,
      };

  factory StockTransferModel.fromMap(Map<String, dynamic> m) =>
      StockTransferModel(
        id: m['id'] ?? '',
        fromWarehouse: m['fromWarehouse'] ?? '',
        toWarehouse: m['toWarehouse'] ?? '',
        productName: m['productName'] ?? '',
        quantity: (m['quantity'] as num?)?.toDouble() ?? 0,
        unit: m['unit'] ?? '',
        date: DateTime.parse(
            m['date'] ?? DateTime.now().toIso8601String()),
        notes: m['notes'] ?? '',
        status: m['status'] ?? statusPending,
        srId: m['srId'] ?? '',
        srName: m['srName'] ?? '',
      );

  StockTransferModel copyWith({
    String? fromWarehouse,
    String? toWarehouse,
    String? productName,
    double? quantity,
    String? unit,
    DateTime? date,
    String? notes,
    String? status,
  }) =>
      StockTransferModel(
        id: id,
        fromWarehouse: fromWarehouse ?? this.fromWarehouse,
        toWarehouse: toWarehouse ?? this.toWarehouse,
        productName: productName ?? this.productName,
        quantity: quantity ?? this.quantity,
        unit: unit ?? this.unit,
        date: date ?? this.date,
        notes: notes ?? this.notes,
        status: status ?? this.status,
        srId: srId,
        srName: srName,
      );
}
