/// ExpenseModel covers all 6 bill types:
/// ta_bill | da | ta_da_top_sheet | out_station | motorcycle_log | others_bill
class ExpenseModel {
  final String id;
  final String type;
  final String month;        // e.g. "July 2026"
  final String applicantName;
  final String designation;
  final String zone;
  final DateTime createdAt;
  final String status;       // pending | approved | rejected
  final String srId;

  // Month-lock: admin can unlock a previous month for re-submission
  final bool isLocked;        // true = locked by system (new month started)
  final bool adminUnlocked;   // true = admin explicitly unlocked

  // TA Bill rows: [{date, from, to, modeOfTransport, description, amount}]
  final List<Map<String, dynamic>> taRows;

  // Motorcycle log rows:
  // [{date, destination, purposes, prevReading, latestReading, totalKm,
  //   petrol, petrolAmount, octane, octaneAmount, mobil, mobilAmount,
  //   others, othersAmount, othersSupportingDoc}]
  final List<Map<String, dynamic>> motoRows;

  // Motorcycle servicing bill rows: [{date, description, amount, supportingDoc}]
  final List<Map<String, dynamic>> motoServicingRows;

  // Motorcycle registration number (stored once per employee in prefs, echoed here)
  final String motoRegNumber;

  // TA/DA Top Sheet rows: [{date, place, ta, da, total}]
  final List<Map<String, dynamic>> tadaRows;

  // Out Station rows: [{date, from, to, ta, da, hotel, total}]
  final List<Map<String, dynamic>> outStationRows;

  // DA bill: [{date, amount, note, dayOfWeek, adminApproved}]
  final List<Map<String, dynamic>> daRows;

  // TA/DA Top Sheet summary (Others Bill renamed to top sheet)
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
    this.isLocked = false,
    this.adminUnlocked = false,
    this.taRows = const [],
    this.motoRows = const [],
    this.motoServicingRows = const [],
    this.motoRegNumber = '',
    this.tadaRows = const [],
    this.outStationRows = const [],
    this.daRows = const [],
    this.othersBill = const {},
  });

  static const String typeTaBill      = 'ta_bill';
  static const String typeDa          = 'da';
  static const String typeTaDaSheet   = 'ta_da_top_sheet';
  static const String typeOutStation  = 'out_station';
  static const String typeMotorcycle  = 'motorcycle_log';
  static const String typeOthersBill  = 'others_bill';  // kept for legacy

  static const String statusPending  = 'pending';
  static const String statusApproved = 'approved';
  static const String statusRejected = 'rejected';

  /// Designation → DA amount per day (BDT)
  static const Map<String, double> daByDesignation = {
    'Managing Director':         800,
    'General Manager':           700,
    'Deputy General Manager':    650,
    'Assistant General Manager': 600,
    'Senior Manager':            550,
    'Manager':                   500,
    'Deputy Manager':            450,
    'Assistant Manager':         400,
    'Senior Executive':          350,
    'Executive':                 300,
    'Junior Executive':          250,
    'Officer':                   250,
    'Senior Officer':            300,
    'Field Officer':             250,
    'Sales Officer':             250,
    'Marketing Officer':         250,
    'Area Manager':              400,
    'Regional Manager':          450,
    'Territory Manager':         350,
    'District Manager':          350,
    'Zonal Manager':             500,
    'Team Leader':               300,
    'Team Member':               250,
    'Sales Representative':      250,
    'Senior Sales Representative': 300,
    'Driver':                    200,
    'Mechanic':                  200,
    'Support Staff':             200,
    'Others':                    200,
  };

  static const List<String> designationList = [
    'Managing Director',
    'General Manager',
    'Deputy General Manager',
    'Assistant General Manager',
    'Senior Manager',
    'Manager',
    'Deputy Manager',
    'Assistant Manager',
    'Senior Executive',
    'Executive',
    'Junior Executive',
    'Officer',
    'Senior Officer',
    'Field Officer',
    'Sales Officer',
    'Marketing Officer',
    'Area Manager',
    'Regional Manager',
    'Territory Manager',
    'District Manager',
    'Zonal Manager',
    'Team Leader',
    'Team Member',
    'Sales Representative',
    'Senior Sales Representative',
    'Driver',
    'Mechanic',
    'Support Staff',
    'Others',
  ];

  String get typeLabel {
    switch (type) {
      case typeTaBill:     return 'TA Bill';
      case typeDa:         return 'DA Bill';
      case typeTaDaSheet:  return 'TA/DA Top Sheet';
      case typeOutStation: return 'Out Station';
      case typeMotorcycle: return 'Motorcycle Log';
      case typeOthersBill: return 'TA/DA Top Sheet';
      default:             return type;
    }
  }

  String get statusLabel {
    switch (status) {
      case statusApproved: return 'Approved';
      case statusRejected: return 'Rejected';
      default:             return 'Pending';
    }
  }

  double get totalAmount {
    switch (type) {
      case typeTaBill:
        return taRows.fold(0.0,
            (s, r) => s + ((r['amount'] as num?)?.toDouble() ?? 0));
      case typeTaDaSheet:
      case typeOthersBill:
        final sheetTotal = (othersBill['totalTaka'] as num?)?.toDouble() ?? 0;
        if (sheetTotal > 0) return sheetTotal;
        return tadaRows.fold(0.0,
            (s, r) => s + ((r['total'] as num?)?.toDouble() ?? 0));
      case typeOutStation:
        return outStationRows.fold(0.0,
            (s, r) => s + ((r['total'] as num?)?.toDouble() ?? 0));
      case typeDa:
        return daRows.fold(0.0,
            (s, r) => s + ((r['amount'] as num?)?.toDouble() ?? 0));
      default:
        return (othersBill['totalTaka'] as num?)?.toDouble() ?? 0;
    }
  }

  /// Returns true if today is in a different (later) month from [month]
  static bool isMonthLocked(String month) {
    try {
      const months = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December',
      ];
      final parts = month.trim().split(' ');
      if (parts.length < 2) return false;
      final mIdx = months.indexOf(parts[0]);
      final yr = int.tryParse(parts[1]) ?? 0;
      if (mIdx < 0 || yr == 0) return false;
      final now = DateTime.now();
      return now.year > yr || (now.year == yr && now.month > mIdx + 1);
    } catch (_) {
      return false;
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
        'isLocked': isLocked,
        'adminUnlocked': adminUnlocked,
        'taRows': taRows,
        'motoRows': motoRows,
        'motoServicingRows': motoServicingRows,
        'motoRegNumber': motoRegNumber,
        'tadaRows': tadaRows,
        'outStationRows': outStationRows,
        'daRows': daRows,
        'othersBill': othersBill,
      };

  factory ExpenseModel.fromMap(Map<String, dynamic> m) => ExpenseModel(
        id: m['id'] ?? '',
        // 'ta_da_sheet' is the legacy name for the top sheet
        type: (m['type'] == 'ta_da_sheet') ? typeTaDaSheet : (m['type'] ?? typeTaBill),
        month: m['month'] ?? '',
        applicantName: m['applicantName'] ?? '',
        designation: m['designation'] ?? '',
        zone: m['zone'] ?? '',
        createdAt: DateTime.parse(
            m['createdAt'] ?? DateTime.now().toIso8601String()),
        status: m['status'] ?? statusPending,
        srId: m['srId'] ?? '',
        isLocked: m['isLocked'] as bool? ?? false,
        adminUnlocked: m['adminUnlocked'] as bool? ?? false,
        taRows: _mapList(m['taRows']),
        motoRows: _mapList(m['motoRows']),
        motoServicingRows: _mapList(m['motoServicingRows']),
        motoRegNumber: m['motoRegNumber'] as String? ?? '',
        tadaRows: _mapList(m['tadaRows']),
        outStationRows: _mapList(m['outStationRows']),
        daRows: _mapList(m['daRows']),
        othersBill: Map<String, dynamic>.from(m['othersBill'] as Map? ?? {}),
      );

  static List<Map<String, dynamic>> _mapList(dynamic raw) =>
      List<Map<String, dynamic>>.from(
          (raw as List<dynamic>? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map)));
}
