/// ExpenseModel covers all bill types:
/// ta_bill | da | ta_da_top_sheet | out_station | motorcycle_log |
/// others_bill | entertainment_bill | courier_bill
class ExpenseModel {
  final String id;
  final String type;
  final String month;        // e.g. "July 2026"
  final String applicantName;
  final String designation;
  final String zone;
  final DateTime createdAt;
  final String status;       // pending | approved | rejected | paid
  final String srId;

  // Month-lock: admin can unlock a previous month for re-submission
  final bool isLocked;        // true = locked by system (new month started)
  final bool adminUnlocked;   // true = admin explicitly unlocked

  // TA Bill rows: [{date, from, to, modeOfTransport, description, amount,
  // prevReading, latestReading, totalKm, oil, oilQuantity, oilAmount}]
  final List<Map<String, dynamic>> taRows;

  // Motorcycle log rows:
  // [{date, from, to, destination (legacy), purposes, prevReading, latestReading, totalKm,
  //   petrol, petrolAmount, octane, octaneAmount, mobil, mobilAmount,
  //   othersAmount, supportingDoc (legacy first photo), supportingDocs[]}]
  // Petrol, octane and mobil each have their own voucher, so a row may carry
  // several photos in supportingDocs[].
  final List<Map<String, dynamic>> motoRows;

  // Motorcycle servicing bill rows: [{date, description, amount, supportingDoc}]
  final List<Map<String, dynamic>> motoServicingRows;

  // Motorcycle registration number (stored once per employee in prefs, echoed here)
  final String motoRegNumber;

  // TA/DA Top Sheet rows: [{date, place, ta, da, total}]
  final List<Map<String, dynamic>> tadaRows;

  // Out Station rows:
  // [{date, from, to, place (legacy), ta, da, hotel, total, supportingDocs[]}]
  // Supporting documents are optional here; a row may hold several vouchers.
  final List<Map<String, dynamic>> outStationRows;

  // DA bill: [{date, amount, note, dayOfWeek, adminApproved}]
  final List<Map<String, dynamic>> daRows;

  // Entertainment bill rows:
  // [{date, place, purpose, guestCount, amount, supportingDocs[]}]
  // A receipt photo is mandatory on every row.
  final List<Map<String, dynamic>> entertainmentRows;

  // Courier bill rows:
  // [{date, courierName, docketNo, sentTo, particulars, amount, supportingDocs[]}]
  // A receipt photo is mandatory on every row.
  final List<Map<String, dynamic>> courierRows;

  // TA/DA Top Sheet summary (Others Bill renamed to top sheet)
  final Map<String, dynamic> othersBill;

  /// Amount as recorded by the ERP. The head office can correct the payable
  /// figure of a bill submitted from the app; when it does, that number wins
  /// over the locally computed row total so both sides show the same value.
  final double? erpAmount;

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
    this.entertainmentRows = const [],
    this.courierRows = const [],
    this.othersBill = const {},
    this.erpAmount,
  });

  static const String typeTaBill      = 'ta_bill';
  static const String typeDa          = 'da';
  static const String typeTaDaSheet   = 'ta_da_top_sheet';
  static const String typeOutStation  = 'out_station';
  static const String typeMotorcycle  = 'motorcycle_log';
  static const String typeOthersBill  = 'others_bill';  // kept for legacy
  static const String typeEntertainment = 'entertainment_bill';
  static const String typeCourier       = 'courier_bill';

  /// Bill types the head office reimburses only against an uploaded receipt.
  static const List<String> docMandatoryTypes = [
    typeEntertainment,
    typeCourier,
  ];

  static bool requiresSupportingDoc(String type) =>
      docMandatoryTypes.contains(type);

  static const String statusPending  = 'pending';
  static const String statusApproved = 'approved';
  static const String statusRejected = 'rejected';
  static const String statusPaid = 'paid';

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
      case typeEntertainment: return 'Entertainment Bill';
      case typeCourier:       return 'Courier Bill';
      default:             return type;
    }
  }

  String get statusLabel {
    switch (status) {
      case statusApproved: return 'Approved';
      case statusRejected: return 'Rejected';
      case statusPaid: return 'Paid';
      default:             return 'Pending';
    }
  }

  double get totalAmount {
    // An ERP correction is authoritative: when the head office changes the
    // payable amount, the app must show that figure, not the row sum.
    final adjusted = erpAmount;
    if (adjusted != null && adjusted > 0) return adjusted;
    return rowTotal;
  }

  /// Total computed purely from the entered rows, before any ERP correction.
  double get rowTotal {
    switch (type) {
      case typeTaBill:
        return taRows.fold(0.0,
            (s, r) => s +
                ((r['amount'] as num?)?.toDouble() ?? 0) +
                ((r['oilAmount'] as num?)?.toDouble() ?? 0));
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
      case typeEntertainment:
        return entertainmentRows.fold(0.0,
            (s, r) => s + ((r['amount'] as num?)?.toDouble() ?? 0));
      case typeCourier:
        return courierRows.fold(0.0,
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
        'entertainmentRows': entertainmentRows,
        'courierRows': courierRows,
        'othersBill': othersBill,
        if (erpAmount != null) 'totalAmount': erpAmount,
      };

  factory ExpenseModel.fromMap(Map<String, dynamic> m) => ExpenseModel(
        id: m['id'] ?? '',
        // 'ta_da_sheet' is the legacy name for the top sheet
        type: (m['type'] == 'ta_da_sheet') ? typeTaDaSheet : (m['type'] ?? typeTaBill),
        month: m['month'] ?? '',
        applicantName: m['applicantName'] ?? '',
        designation: m['designation'] ?? '',
        zone: m['zone'] ?? '',
        createdAt: DateTime.tryParse(m['createdAt']?.toString() ?? '') ??
            DateTime.now(),
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
        entertainmentRows: _mapList(m['entertainmentRows']),
        courierRows: _mapList(m['courierRows']),
        othersBill: Map<String, dynamic>.from(m['othersBill'] as Map? ?? {}),
        erpAmount: (m['totalAmount'] as num?)?.toDouble(),
      );

  static List<Map<String, dynamic>> _mapList(dynamic raw) =>
      List<Map<String, dynamic>>.from(
          (raw as List<dynamic>? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map)));
}
