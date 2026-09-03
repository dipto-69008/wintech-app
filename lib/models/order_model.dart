class OrderItem {
  final String productName;
  final double quantity;
  final String unit;
  final double unitPrice;
  final bool isBonus; // free bonus item — not charged

  const OrderItem({
    required this.productName,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    this.isBonus = false,
  });

  double get total => isBonus ? 0 : quantity * unitPrice;

  Map<String, dynamic> toMap() => {
        'productName': productName,
        'quantity': quantity,
        'unit': unit,
        'unitPrice': unitPrice,
        'isBonus': isBonus,
      };

  factory OrderItem.fromMap(Map<String, dynamic> m) {
    final productName = m['productName']?.toString() ?? '';
    final unitPrice = (m['unitPrice'] as num?)?.toDouble() ?? 0;
    return OrderItem(
      productName: productName,
      quantity: (m['quantity'] as num?)?.toDouble() ?? 0,
      unit: m['unit']?.toString() ?? 'Pcs',
      unitPrice: unitPrice,
      // Keep legacy ERP bonus rows consistent with the details screen.
      isBonus: m['isBonus'] == true ||
          unitPrice == 0 && productName.toLowerCase().contains('(bonus)'),
    );
  }
}

class OrderModel {
  final String id;
  final String srId;
  final String srName;
  final String customerId;
  final String customerName;
  final List<OrderItem> items;
  final double total;
  final DateTime date;
  final String status; // pending | confirmed | delivered | cancelled
  final String notes;
  final DateTime? probablePaymentDate; // expected payment date (like ERP)
  final double paidAmount;
  final String paymentType;
  final double commissionPct; // 3% cash commission when fully paid on delivery date

  const OrderModel({
    required this.id,
    required this.srId,
    required this.srName,
    required this.customerId,
    required this.customerName,
    required this.items,
    required this.total,
    required this.date,
    this.status = 'pending',
    this.notes = '',
    this.probablePaymentDate,
    this.paidAmount = 0,
    this.paymentType = 'Cash',
    this.commissionPct = 0,
  });

  static String get statusPending => 'pending';
  static String get statusConfirmed => 'confirmed';
  static String get statusDelivered => 'delivered';
  static String get statusCancelled => 'cancelled';

  /// Total charged and free quantities, rather than the number of line items.
  /// ERP may update a bonus line's quantity without creating another line.
  double get itemQuantity => items
      .where((item) => !item.isBonus)
      .fold(0.0, (sum, item) => sum + item.quantity);

  double get bonusQuantity => items
      .where((item) => item.isBonus)
      .fold(0.0, (sum, item) => sum + item.quantity);

  String get statusLabel {
    switch (status) {
      case 'confirmed': return 'Confirmed';
      case 'delivered': return 'Delivered';
      case 'cancelled': return 'Cancelled';
      default: return 'Pending';
    }
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'srId': srId,
        'srName': srName,
        'customerId': customerId,
        'customerName': customerName,
        'items': items.map((i) => i.toMap()).toList(),
        'total': total,
        'date': date.toIso8601String(),
        'status': status,
        'notes': notes,
        'probablePaymentDate': probablePaymentDate?.toIso8601String(),
        'paidAmount': paidAmount,
        'paymentType': paymentType,
        'commissionPct': commissionPct,
      };

  factory OrderModel.fromMap(Map<String, dynamic> m) => OrderModel(
        id: m['id'] ?? '',
        srId: m['srId'] ?? '',
        srName: m['srName'] ?? '',
        customerId: m['customerId'] ?? '',
        customerName: m['customerName'] ?? '',
        items: (m['items'] as List<dynamic>? ?? [])
            .map((i) => OrderItem.fromMap(Map<String, dynamic>.from(i as Map)))
            .toList(),
        total: (m['total'] as num?)?.toDouble() ?? 0,
        date: DateTime.tryParse(m['date'] ?? '') ?? DateTime.now(),
        status: m['status'] ?? 'pending',
        notes: m['notes'] ?? '',
        probablePaymentDate:
            DateTime.tryParse(m['probablePaymentDate'] ?? ''),
        paidAmount: (m['paidAmount'] as num?)?.toDouble() ?? 0,
        paymentType: m['paymentType'] ?? 'Cash',
        commissionPct: (m['commissionPct'] as num?)?.toDouble() ?? 0,
      );

  OrderModel copyWith({String? status, String? notes}) => OrderModel(
        id: id,
        srId: srId,
        srName: srName,
        customerId: customerId,
        customerName: customerName,
        items: items,
        total: total,
        date: date,
        status: status ?? this.status,
        notes: notes ?? this.notes,
        probablePaymentDate: probablePaymentDate,
        paidAmount: paidAmount,
        paymentType: paymentType,
        commissionPct: commissionPct,
      );
}
