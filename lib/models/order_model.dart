class OrderItem {
  final String productName;
  final double quantity;
  final String unit;
  final double unitPrice;

  const OrderItem({
    required this.productName,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
  });

  double get total => quantity * unitPrice;

  Map<String, dynamic> toMap() => {
        'productName': productName,
        'quantity': quantity,
        'unit': unit,
        'unitPrice': unitPrice,
      };

  factory OrderItem.fromMap(Map<String, dynamic> m) => OrderItem(
        productName: m['productName'] ?? '',
        quantity: (m['quantity'] as num?)?.toDouble() ?? 0,
        unit: m['unit'] ?? 'পিস',
        unitPrice: (m['unitPrice'] as num?)?.toDouble() ?? 0,
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
  });

  static String get statusPending => 'pending';
  static String get statusConfirmed => 'confirmed';
  static String get statusDelivered => 'delivered';
  static String get statusCancelled => 'cancelled';

  String get statusLabel {
    switch (status) {
      case 'confirmed': return 'নিশ্চিত';
      case 'delivered': return 'ডেলিভারি হয়েছে';
      case 'cancelled': return 'বাতিল';
      default: return 'অপেক্ষমাণ';
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
      );
}
