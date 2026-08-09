/// ExpenseModel covers all 6 bill types:
/// ta_bill | da | ta_da_sheet | out_station | motorcycle_log | others_bill
class ExpenseModel {
  final String id;
  final String type;
  final String month;        // e.g. "জুলাই ২০২৬"
  final String applicantName;
  final String designation;
  final String zone;
  final DateTime createdAt;
  final String status;       // pending | approved | rejected
  final String srId;

  // TA Bill rows: [{date, from, to, modeOfTransport, description, amount}]
  final List<Map<String, dynamic>> taRows;

  // Motorcycle log rows:
  // [{date, destination, purposes, prevReading, latestReading, totalKm, petrol, mobil}]
  final List<Map<String, dynamic>> motoRows;

  // TA/DA Sheet rows: [{date, place, ta, da, total}]
  final List<Map<String, dynamic>> tadaRows;

  // Out Station rows: [{date, from, to, ta, da, hotel, total}]
  final List<Map<String, dynamic>> outStationRows;

  // Others Bill summary map
  final Map<String, dynamic> othersBill;

  const ExpenseModel({
    required this.id,
    required this.type,
    this.month = '',
    this.applicantName = '',
    this.designation = '',
    this.zone = '',
    required this.createdAt,
    this.status = 'pending',
    required this.srId,
    this.taRows = const [],
    this.motoRows = const [],
    this.tadaRows = const [],
    this.outStationRows = const [],
    this.othersBill = const {},
  });

  static const String typeTaBill     = 'ta_bill';
  static const String typeDa         = 'da';
  static const String typeTaDaSheet  = 'ta_da_sheet';
  static const String typeOutStation = 'out_station';
  static const String typeMotorcycle = 'motorcycle_log';
  static const String typeOthersBill = 'others_bill';

  static const String statusPending  = 'pending';
  static const String statusApproved = 'approved';
  static const String statusRejected = 'rejected';

  String get typeLabel {
    switch (type) {
      case typeTaBill:     return 'TA বিল';
      case typeDa:         return 'DA বিল';
      case typeTaDaSheet:  return 'TA/DA শিট';
      case typeOutStation: return 'আউট স্টেশন';
      case typeMotorcycle: return 'মটরসাইকেল লগ';
      case typeOthersBill: return 'অন্যান্য বিল';
      default:             return type;
    }
  }

  String get statusLabel {
    switch (status) {
      case statusApproved: return 'অনুমোদিত';
      case statusRejected: return 'বাতিল';
      default:             return 'অপেক্ষমাণ';
    }
  }

  double get totalAmount {
    switch (type) {
      case typeTaBill:
        return taRows.fold(0.0,
            (s, r) => s + ((r['amount'] as num?)?.toDouble() ?? 0));
      case typeTaDaSheet:
        return tadaRows.fold(0.0,
            (s, r) => s + ((r['total'] as num?)?.toDouble() ?? 0));
      case typeOutStation:
        return outStationRows.fold(0.0,
            (s, r) => s + ((r['total'] as num?)?.toDouble() ?? 0));
      case typeOthersBill:
        return (othersBill['totalTaka'] as num?)?.toDouble() ?? 0;
      default:
        return 0;
    }
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type,
        'month': month,
        'applicantName': applicantName,
        'designation': designation,
        'zone': zone,
        'createdAt': createdAt.toIso8601String(),
        'status': status,
        'srId': srId,
        'taRows': taRows,
        'motoRows': motoRows,
        'tadaRows': tadaRows,
        'outStationRows': outStationRows,
        'othersBill': othersBill,
      };

  factory ExpenseModel.fromMap(Map<String, dynamic> m) => ExpenseModel(
        id: m['id'] ?? '',
        type: m['type'] ?? typeTaBill,
        month: m['month'] ?? '',
        applicantName: m['applicantName'] ?? '',
        designation: m['designation'] ?? '',
        zone: m['zone'] ?? '',
        createdAt: DateTime.parse(
            m['createdAt'] ?? DateTime.now().toIso8601String()),
        status: m['status'] ?? statusPending,
        srId: m['srId'] ?? '',
        taRows: _mapList(m['taRows']),
        motoRows: _mapList(m['motoRows']),
        tadaRows: _mapList(m['tadaRows']),
        outStationRows: _mapList(m['outStationRows']),
        othersBill: Map<String, dynamic>.from(m['othersBill'] as Map? ?? {}),
      );

  static List<Map<String, dynamic>> _mapList(dynamic raw) =>
      List<Map<String, dynamic>>.from(
          (raw as List<dynamic>? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map)));
}
