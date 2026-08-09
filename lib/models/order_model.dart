class OrderItem {
  final String productName;
  final double quantity;
  final String unit;
  final double unitPrice;
  final bool isBonus;

  const OrderItem({
    required this.productName,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    this.isBonus = false,
  });

  double get total => quantity * unitPrice;

  Map<String, dynamic> toMap() => {
        'productName': productName,
        'quantity': quantity,
        'unit': unit,
        'unitPrice': unitPrice,
        'isBonus': isBonus,
      };

  factory OrderItem.fromMap(Map<String, dynamic> m) => OrderItem(
        productName: m['productName'] ?? '',
        quantity: (m['quantity'] as num?)?.toDouble() ?? 0,
        unit: m['unit'] ?? 'Piece',
        unitPrice: (m['unitPrice'] as num?)?.toDouble() ?? 0,
        isBonus: m['isBonus'] == true,
      );
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
  final String invoiceNo;
  final String paymentType;
  final double paidAmount;
  final double dueAmount;
  final String probablePaymentDate;
  final String branch;

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
    this.invoiceNo = '',
    this.paymentType = 'Cash',
    this.paidAmount = 0,
    this.dueAmount = 0,
    this.probablePaymentDate = '',
    this.branch = '',
  });

  static String get statusPending => 'pending';
  static String get statusConfirmed => 'confirmed';
  static String get statusDelivered => 'delivered';
  static String get statusCancelled => 'cancelled';

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
        'invoiceNo': invoiceNo,
        'paymentType': paymentType,
        'paidAmount': paidAmount,
        'dueAmount': dueAmount,
        'probablePaymentDate': probablePaymentDate,
        'branch': branch,
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
        invoiceNo: m['invoiceNo'] ?? '',
        paymentType: m['paymentType'] ?? 'Cash',
        paidAmount: (m['paidAmount'] as num?)?.toDouble() ?? 0,
        dueAmount: (m['dueAmount'] as num?)?.toDouble() ?? 0,
        probablePaymentDate: m['probablePaymentDate'] ?? '',
        branch: m['branch'] ?? '',
      );

  OrderModel copyWith({
    String? status,
    String? notes,
    String? invoiceNo,
    String? paymentType,
    double? paidAmount,
    double? dueAmount,
    String? probablePaymentDate,
    String? branch,
  }) => OrderModel(
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
        invoiceNo: invoiceNo ?? this.invoiceNo,
        paymentType: paymentType ?? this.paymentType,
        paidAmount: paidAmount ?? this.paidAmount,
        dueAmount: dueAmount ?? this.dueAmount,
        probablePaymentDate:
            probablePaymentDate ?? this.probablePaymentDate,
        branch: branch ?? this.branch,
      );
}
