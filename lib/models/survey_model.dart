// ── Survey Model ──────────────────────────────────────────────────────────────
// Two survey types: 'farmer' (Farmer Visit) and 'dealer' (Dealer Visit)
// Survey models used by the Flutter field-survey screens.

class SurveyModel {
  static const typeFarmer = 'farmer';
  static const typeDealer = 'dealer';

  final String id;
  final String type; // 'farmer' | 'dealer'
  final String workerName;
  final String postingId;
  final String visitDate; // ISO date string yyyy-MM-dd

  // ── Farmer fields ──────────────────────────────────────────────────────
  final String farmName;
  final String farmerMobile;
  final String village;
  final String diseases;
  final List<String> wintechProducts;
  final String prescription;

  // ── Dealer fields ──────────────────────────────────────────────────────
  final String shopName;
  final String dealerName;
  final String dealerMobile;
  final String bazarName;
  final String wintechStock;
  final String competitorProduct;
  final double? collectionAmount;
  final String remarks;

  // ── Common ─────────────────────────────────────────────────────────────
  final String photo;
  final String createdAt; // ISO datetime string

  const SurveyModel({
    required this.id,
    required this.type,
    required this.workerName,
    this.postingId = '',
    required this.visitDate,
    // farmer
    this.farmName = '',
    this.farmerMobile = '',
    this.village = '',
    this.diseases = '',
    this.wintechProducts = const [],
    this.prescription = '',
    // dealer
    this.shopName = '',
    this.dealerName = '',
    this.dealerMobile = '',
    this.bazarName = '',
    this.wintechStock = '',
    this.competitorProduct = '',
    this.collectionAmount,
    this.remarks = '',
    // common
    this.photo = '',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type,
        'workerName': workerName,
        'postingId': postingId,
        'visitDate': visitDate,
        'farmName': farmName,
        'farmerMobile': farmerMobile,
        'village': village,
        'diseases': diseases,
        'wintechProducts': wintechProducts,
        'prescription': prescription,
        'shopName': shopName,
        'dealerName': dealerName,
        'dealerMobile': dealerMobile,
        'bazarName': bazarName,
        'wintechStock': wintechStock,
        'competitorProduct': competitorProduct,
        'collectionAmount': collectionAmount,
        'remarks': remarks,
        'photo': photo,
        'createdAt': createdAt,
      };

  factory SurveyModel.fromMap(Map<String, dynamic> m) => SurveyModel(
        id: m['id'] as String? ?? '',
        type: m['type'] as String? ?? typeFarmer,
        workerName: m['workerName'] as String? ?? '',
        postingId: m['postingId'] as String? ?? '',
        visitDate: m['visitDate'] as String? ?? '',
        farmName: m['farmName'] as String? ?? '',
        farmerMobile: m['farmerMobile'] as String? ?? '',
        village: m['village'] as String? ?? '',
        diseases: m['diseases'] as String? ?? '',
        wintechProducts: (m['wintechProducts'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        prescription: m['prescription'] as String? ?? '',
        shopName: m['shopName'] as String? ?? '',
        dealerName: m['dealerName'] as String? ?? '',
        dealerMobile: m['dealerMobile'] as String? ?? '',
        bazarName: m['bazarName'] as String? ?? '',
        wintechStock: m['wintechStock'] as String? ?? '',
        competitorProduct: m['competitorProduct'] as String? ?? '',
        collectionAmount: (m['collectionAmount'] as num?)?.toDouble(),
        remarks: m['remarks'] as String? ?? '',
        photo: m['photo'] as String? ?? '',
        createdAt: m['createdAt'] as String? ?? '',
      );

  SurveyModel copyWith({
    String? id,
    String? type,
    String? workerName,
    String? postingId,
    String? visitDate,
    String? farmName,
    String? farmerMobile,
    String? village,
    String? diseases,
    List<String>? wintechProducts,
    String? prescription,
    String? shopName,
    String? dealerName,
    String? dealerMobile,
    String? bazarName,
    String? wintechStock,
    String? competitorProduct,
    double? collectionAmount,
    bool clearCollection = false,
    String? remarks,
    String? photo,
    String? createdAt,
  }) =>
      SurveyModel(
        id: id ?? this.id,
        type: type ?? this.type,
        workerName: workerName ?? this.workerName,
        postingId: postingId ?? this.postingId,
        visitDate: visitDate ?? this.visitDate,
        farmName: farmName ?? this.farmName,
        farmerMobile: farmerMobile ?? this.farmerMobile,
        village: village ?? this.village,
        diseases: diseases ?? this.diseases,
        wintechProducts: wintechProducts ?? this.wintechProducts,
        prescription: prescription ?? this.prescription,
        shopName: shopName ?? this.shopName,
        dealerName: dealerName ?? this.dealerName,
        dealerMobile: dealerMobile ?? this.dealerMobile,
        bazarName: bazarName ?? this.bazarName,
        wintechStock: wintechStock ?? this.wintechStock,
        competitorProduct: competitorProduct ?? this.competitorProduct,
        collectionAmount:
            clearCollection ? null : (collectionAmount ?? this.collectionAmount),
        remarks: remarks ?? this.remarks,
        photo: photo ?? this.photo,
        createdAt: createdAt ?? this.createdAt,
      );
}
