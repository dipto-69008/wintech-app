class PaymentCollectionModel {
  final String id;
  final String customerName;
  final String customerId;
  final double amount;
  final String paymentMethod; // cash | cheque | bKash | nagad | bank
  final String notes;
  final DateTime date;
  final String status; // pending | confirmed | rejected
  final String srId;
  final String srName;
  final String chequeNumber;

  const PaymentCollectionModel({
    required this.id,
    required this.customerName,
    this.customerId = '',
    required this.amount,
    this.paymentMethod = 'cash',
    this.notes = '',
    required this.date,
    this.status = 'pending',
    required this.srId,
    required this.srName,
    this.chequeNumber = '',
  });

  static const String statusPending   = 'pending';
  static const String statusConfirmed = 'confirmed';
  static const String statusRejected  = 'rejected';

  String get statusLabel {
    switch (status) {
      case statusConfirmed: return 'নিশ্চিত';
      case statusRejected:  return 'বাতিল';
      default:              return 'অপেক্ষমাণ';
    }
  }

  String get methodLabel {
    switch (paymentMethod) {
      case 'cheque': return 'চেক';
      case 'bKash':  return 'বিকাশ';
      case 'nagad':  return 'নগদ';
      case 'bank':   return 'ব্যাংক';
      default:       return 'নগদ';
    }
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'customerName': customerName,
        'customerId': customerId,
        'amount': amount,
        'paymentMethod': paymentMethod,
        'notes': notes,
        'date': date.toIso8601String(),
        'status': status,
        'srId': srId,
        'srName': srName,
        'chequeNumber': chequeNumber,
      };

  factory PaymentCollectionModel.fromMap(Map<String, dynamic> m) =>
      PaymentCollectionModel(
        id: m['id'] ?? '',
        customerName: m['customerName'] ?? '',
        customerId: m['customerId'] ?? '',
        amount: (m['amount'] as num?)?.toDouble() ?? 0,
        paymentMethod: m['paymentMethod'] ?? 'cash',
        notes: m['notes'] ?? '',
        date: DateTime.parse(
            m['date'] ?? DateTime.now().toIso8601String()),
        status: m['status'] ?? statusPending,
        srId: m['srId'] ?? '',
        srName: m['srName'] ?? '',
        chequeNumber: m['chequeNumber'] ?? '',
      );

  PaymentCollectionModel copyWith({String? status}) =>
      PaymentCollectionModel(
        id: id,
        customerName: customerName,
        customerId: customerId,
        amount: amount,
        paymentMethod: paymentMethod,
        notes: notes,
        date: date,
        status: status ?? this.status,
        srId: srId,
        srName: srName,
        chequeNumber: chequeNumber,
      );
}
