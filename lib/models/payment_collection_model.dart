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
  final String proofImage;
  final String invoiceNo;
  final bool commissionRequested;
  final double commissionPct;
  final double commissionAmount;

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
    this.proofImage = '',
    this.invoiceNo = '',
    this.commissionRequested = false,
    this.commissionPct = 0,
    this.commissionAmount = 0,
  });

  static const String statusPending   = 'pending';
  static const String statusConfirmed = 'confirmed';
  static const String statusRejected  = 'rejected';

  String get statusLabel {
    switch (status) {
      case statusConfirmed: return 'Confirmed';
      case statusRejected:  return 'Rejected';
      default:              return 'Pending';
    }
  }

  String get methodLabel {
    switch (paymentMethod) {
      case 'cheque': return 'Cheque';
      case 'bKash':  return 'bKash';
      case 'nagad':  return 'Nagad';
      case 'bank':   return 'Bank';
      default:       return 'Cash';
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
        'proofImage': proofImage,
        if (invoiceNo.isNotEmpty) 'invoiceNo': invoiceNo,
        if (commissionRequested && invoiceNo.isNotEmpty) ...{
          'commissionRequested': true,
           'commissionPct': 3,
        },
      };

  factory PaymentCollectionModel.fromMap(Map<String, dynamic> m) =>
      PaymentCollectionModel(
        id: m['id']?.toString() ?? '',
        customerName: m['customerName']?.toString() ?? '',
        customerId: m['customerId']?.toString() ?? '',
        amount: (m['amount'] as num?)?.toDouble() ?? 0,
        paymentMethod: m['paymentMethod']?.toString() ?? 'cash',
        notes: m['notes']?.toString() ?? '',
        date: DateTime.tryParse(m['date']?.toString() ?? '') ?? DateTime.now(),
        status: m['status']?.toString() ?? statusPending,
        srId: m['srId']?.toString() ?? '',
        srName: m['srName']?.toString() ?? '',
        chequeNumber: m['chequeNumber']?.toString() ?? '',
        proofImage: m['proofImage']?.toString() ?? '',
        invoiceNo: m['invoiceNo']?.toString() ?? '',
        commissionRequested: m['commissionRequested'] == true,
        commissionPct: (m['commissionPct'] as num?)?.toDouble() ?? 0,
        commissionAmount: (m['commissionAmount'] as num?)?.toDouble() ?? 0,
      );

  PaymentCollectionModel copyWith({String? status, String? proofImage}) =>
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
        proofImage: proofImage ?? this.proofImage,
        invoiceNo: invoiceNo,
        commissionRequested: commissionRequested,
        commissionPct: commissionPct,
        commissionAmount: commissionAmount,
      );
}
