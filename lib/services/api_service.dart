import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wintech ERP real-time API connection.
///
/// The mobile app talks to the ERP (Next.js + MongoDB) through
/// `/api/mobile/*` endpoints with a Bearer JWT token.
/// Anything created here appears instantly in the ERP, and
/// ERP data (products, customers, targets, orders) is fetched live.
class ApiService {
  // ── Configuration ────────────────────────────────────────────────
  /// ERP server base URL. Change this to your deployed ERP URL.
  /// e.g. https://your-erp.replit.app  (no trailing slash)
  static const String defaultBaseUrl = 'https://wintech.dawatit.online';

  static const _keyBaseUrl = 'erp_base_url';
  static const _keyToken = 'erp_token';
  static const _keyUser = 'erp_user';

  static Future<String> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyBaseUrl) ?? defaultBaseUrl;
  }

  static Future<void> setBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBaseUrl, url.replaceAll(RegExp(r'/+$'), ''));
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken);
  }

  // ── Real-time connectivity ───────────────────────────────────────
  // isConnected = logged in AND the ERP server is actually reachable.
  // The live check is cached for a few seconds so screens can call it
  // freely without spamming the network.
  static bool? _lastPingOk;
  static DateTime? _lastPingAt;
  static const _pingCacheDuration = Duration(seconds: 15);

  static Future<bool> get isConnected async {
    if ((await getToken()) == null) return false;
    return await ping();
  }

  /// True if the ERP responds right now (cached ~15s). Forces a fresh
  /// check with [force] = true.
  static Future<bool> ping({bool force = false}) async {
    final now = DateTime.now();
    if (!force &&
        _lastPingOk != null &&
        _lastPingAt != null &&
        now.difference(_lastPingAt!) < _pingCacheDuration) {
      return _lastPingOk!;
    }
    try {
      final base = await getBaseUrl();
      final res = await http
          .get(Uri.parse('$base/api/mobile/ping'), headers: await _headers())
          .timeout(const Duration(seconds: 6));
      // 200 = live & token valid. 401 = server reachable but session
      // expired — treat as disconnected so the user is asked to re-login.
      _lastPingOk = res.statusCode == 200;
      if (res.statusCode == 401) {
        _lastPingOk = false;
      }
    } catch (_) {
      _lastPingOk = false;
    }
    _lastPingAt = now;
    return _lastPingOk!;
  }

  /// Call after any successful API round-trip to mark the link live.
  static void _markOnline() {
    _lastPingOk = true;
    _lastPingAt = DateTime.now();
  }

  static Future<Map<String, dynamic>?> getErpUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyUser);
    if (raw == null) return null;
    return Map<String, dynamic>.from(jsonDecode(raw));
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyUser);
  }

  // ── Internals ────────────────────────────────────────────────────
  static Future<Map<String, String>> _headers() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, dynamic>> _get(String path,
      [Map<String, String>? params]) async {
    final base = await getBaseUrl();
    var uri = Uri.parse('$base$path');
    if (params != null && params.isNotEmpty) {
      uri = uri.replace(queryParameters: {...uri.queryParameters, ...params});
    }
    final res = await http
        .get(uri, headers: await _headers())
        .timeout(const Duration(seconds: 20));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400) {
      throw ApiException(body['error']?.toString() ?? 'Server error', res.statusCode);
    }
    _markOnline();
    return body;
  }

  static Future<Map<String, dynamic>> _post(
      String path, Map<String, dynamic> data) async {
    final base = await getBaseUrl();
    final res = await http
        .post(Uri.parse('$base$path'),
            headers: await _headers(), body: jsonEncode(data))
        .timeout(const Duration(seconds: 20));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400) {
      throw ApiException(body['error']?.toString() ?? 'Server error', res.statusCode);
    }
    _markOnline();
    return body;
  }

  static Future<Map<String, dynamic>> _patch(
      String path, Map<String, dynamic> data) async {
    final base = await getBaseUrl();
    final res = await http
        .patch(Uri.parse('$base$path'),
            headers: await _headers(), body: jsonEncode(data))
        .timeout(const Duration(seconds: 20));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400) {
      throw ApiException(body['error']?.toString() ?? 'Server error', res.statusCode);
    }
    _markOnline();
    return body;
  }

  static Future<Map<String, dynamic>> _delete(String path) async {
    final base = await getBaseUrl();
    final res = await http
        .delete(Uri.parse('$base$path'), headers: await _headers())
        .timeout(const Duration(seconds: 20));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400) {
      throw ApiException(body['error']?.toString() ?? 'Server error', res.statusCode);
    }
    _markOnline();
    return body;
  }

  // ── Auth ─────────────────────────────────────────────────────────
  /// Login against the ERP. Returns the ERP user map on success.
  static Future<Map<String, dynamic>> login(String identifier, String password) async {
    final body = await _post('/api/mobile/auth/login',
        {'identifier': identifier, 'password': password});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, body['token'] as String);
    await prefs.setString(_keyUser, jsonEncode(body['user']));
    return Map<String, dynamic>.from(body['user'] as Map);
  }

  // ── Live data (real-time from ERP MongoDB) ───────────────────────
  static Future<List<Map<String, dynamic>>> products({String search = ''}) async {
    final body = await _get('/api/mobile/products',
        {if (search.isNotEmpty) 'search': search});
    return List<Map<String, dynamic>>.from(body['data'] as List);
  }

  static Future<List<Map<String, dynamic>>> parties(
      {String search = '', bool allBranches = false}) async {
    final body = await _get('/api/mobile/parties', {
      if (search.isNotEmpty) 'search': search,
      if (allBranches) 'branchId': '0',
    });
    return List<Map<String, dynamic>>.from(body['data'] as List);
  }

  static Future<List<Map<String, dynamic>>> orders(
      {String status = '', bool mineOnly = true}) async {
    final body = await _get('/api/mobile/orders', {
      if (status.isNotEmpty) 'status': status,
      if (!mineOnly) 'mine': '0',
    });
    return List<Map<String, dynamic>>.from(body['data'] as List);
  }

  /// Create an order in the ERP — appears instantly in ERP Sales → Orders.
  static Future<Map<String, dynamic>> createOrder({
    String? partyId,
    required String partyName,
    required List<Map<String, dynamic>> items, // {productId?, productName, quantity, rate, unit?, isBonus?}
    String paymentType = 'Cash',
    double paidAmount = 0,
    String notes = '',
    DateTime? probablePaymentDate,
    bool requestCommission = false,
  }) {
    return _post('/api/mobile/orders', {
      if (partyId != null) 'partyId': partyId,
      'partyName': partyName,
      'items': items,
      'paymentType': paymentType,
      'paidAmount': paidAmount,
      'notes': notes,
      'requestCommission': requestCommission,
      if (probablePaymentDate != null)
        'probablePaymentDate': probablePaymentDate.toIso8601String(),
    });
  }

  /// Live surveys. [mineOnly] false searches every officer's records, which is
  /// what a mobile-number lookup needs.
  static Future<List<Map<String, dynamic>>> surveys(
      {String type = '', bool mineOnly = true}) async {
    final body = await _get('/api/mobile/surveys', {
      if (type.isNotEmpty) 'type': type,
      if (!mineOnly) 'mine': '0',
    });
    return List<Map<String, dynamic>>.from(body['data'] as List);
  }

  /// Submit a farmer/dealer visit — appears instantly in ERP Survey module.
  static Future<Map<String, dynamic>> createSurvey(Map<String, dynamic> data) =>
      _post('/api/mobile/surveys', data);

  static Future<List<Map<String, dynamic>>> targets(
      {String? year, String? assignedTo}) async {
    final body = await _get('/api/mobile/targets', {
      if (year != null) 'year': year,
      if (assignedTo != null) 'assignedTo': assignedTo,
    });
    return List<Map<String, dynamic>>.from(body['data'] as List);
  }

  static Future<void> reportTargetProgress(String targetId, double value) =>
      _post('/api/mobile/targets', {'targetId': targetId, 'currentValue': value});

  /// ADMIN ONLY — set yearly (Jan–Dec) monthly targets for an officer.
  /// months: [{month: 1..12, targetAmount, incentivePerSale}]
  static Future<Map<String, dynamic>> setYearlyTargets({
    required String assignedTo,
    required int year,
    required List<Map<String, dynamic>> months,
    int? branchId,
  }) async {
    final base = await getBaseUrl();
    final res = await http
        .put(Uri.parse('$base/api/mobile/targets'),
            headers: await _headers(),
            body: jsonEncode({
              'assignedTo': assignedTo,
              'year': year,
              'months': months,
              if (branchId != null) 'branchId': branchId,
            }))
        .timeout(const Duration(seconds: 20));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400) {
      throw ApiException(body['error']?.toString() ?? 'Server error', res.statusCode);
    }
    return body;
  }

  static Future<List<Map<String, dynamic>>> stockTransfers({
    bool mineOnly = false,
    String? status,
  }) async {
    final body = await _get('/api/mobile/stock-transfers', {
      if (mineOnly) 'mine': '1',
      if (status != null && status.isNotEmpty) 'status': status,
    });
    return List<Map<String, dynamic>>.from(body['data'] as List);
  }

  /// Consignments addressed to the logged-in officer's own branch — the
  /// transfers they are expected to receive or reject.
  static Future<List<Map<String, dynamic>>> incomingStockTransfers({
    String? status,
  }) async {
    final body = await _get('/api/mobile/stock-transfers', {
      'inbox': '1',
      if (status != null && status.isNotEmpty) 'status': status,
    });
    return List<Map<String, dynamic>>.from(body['data'] as List);
  }

  /// Confirm or refuse an incoming consignment. Only the destination branch
  /// may decide; the ERP rejects anyone else with a 403.
  static Future<Map<String, dynamic>> decideStockTransfer({
    required String id,
    required bool receive,
    String receiveNote = '',
  }) {
    return _patch('/api/mobile/stock-transfers', {
      'id': id,
      'action': receive ? 'receive' : 'reject',
      if (receiveNote.isNotEmpty) 'receiveNote': receiveNote,
    });
  }

  /// ERP transfer-ledger stock available for a product at a branch.
  static Future<Map<String, dynamic>> stockAvailability({
    required String branch,
    String? productId,
    String? productName,
  }) async {
    final body = await _get('/api/mobile/stock-transfers', {
      'availability': '1',
      'branch': branch,
      if (productId != null && productId.isNotEmpty) 'productId': productId,
      if (productName != null && productName.isNotEmpty)
        'productName': productName,
    });
    return Map<String, dynamic>.from(body['data'] as Map? ?? {});
  }

  /// Record a stock transfer — appears instantly in ERP Inventory → Stock Transfer.
  static Future<Map<String, dynamic>> createStockTransfer({
    required String productName,
    required String fromBranch,
    required String toBranch,
    required double quantity,
    String? productId,
    String? packSize,
    String notes = '',
    Map<String, dynamic>? extraFields,
  }) {
    return _post('/api/mobile/stock-transfers', {
      if (productId != null) 'productId': productId,
      'productName': productName,
      if (packSize != null) 'packSize': packSize,
      'fromBranch': fromBranch,
      'toBranch': toBranch,
      'quantity': quantity,
      'notes': notes,
      if (extraFields != null) ...extraFields,
    });
  }

  /// Record a MULTI-product stock transfer.
  /// Each item: {productName, quantity, productId?, packSize?, quantityUnit?,
  /// cartonCount?, bucketCount?, pcsCount?, totalWeight?, weightUnit?}
  static Future<Map<String, dynamic>> createMultiStockTransfer({
    required String fromBranch,
    required String toBranch,
    required List<Map<String, dynamic>> items,
    String transferredBy = '',
    String receivedBy = '',
    String notes = '',
  }) {
    return _post('/api/mobile/stock-transfers', {
      'fromBranch': fromBranch,
      'toBranch': toBranch,
      'items': items,
      if (transferredBy.isNotEmpty) 'transferredBy': transferredBy,
      if (receivedBy.isNotEmpty) 'receivedBy': receivedBy,
      'notes': notes,
    });
  }

  /// Upload a photo (real-time camera capture) to the ERP.
  /// Returns the durable URL to store in payloads instead of device paths.
  /// [folder]: surveys | expenses | leaves | parties
  static Future<String> uploadPhoto(String filePath,
      {String folder = 'misc'}) async {
    final base = await getBaseUrl();
    final token = await getToken();
    // image_picker camera files do not always expose a MIME type to
    // MultipartFile.fromPath. Without an explicit content type the ERP
    // correctly sees application/octet-stream and rejects the upload.
    final lower = filePath.toLowerCase();
    final contentType = lower.endsWith('.png')
        ? MediaType('image', 'png')
        : lower.endsWith('.webp')
            ? MediaType('image', 'webp')
            : lower.endsWith('.gif')
                ? MediaType('image', 'gif')
                : MediaType('image', 'jpeg');
    final req = http.MultipartRequest(
        'POST', Uri.parse('$base/api/mobile/upload'))
      ..headers['Authorization'] = 'Bearer $token'
      ..fields['folder'] = folder
      ..files.add(await http.MultipartFile.fromPath(
        'file',
        filePath,
        filename: lower.endsWith('.png') ? 'camera.png' : 'camera.jpg',
        contentType: contentType,
      ));
    final streamed = await req.send().timeout(const Duration(seconds: 60));
    final res = await http.Response.fromStream(streamed);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400) {
      throw ApiException(
          body['error']?.toString() ?? 'Upload failed', res.statusCode);
    }
    _markOnline();
    return body['url'] as String;
  }

  /// Upload multiple photos, returning the list of URLs.
  /// Photos that fail to upload throw — caller decides to retry or queue.
  static Future<List<String>> uploadPhotos(List<String> filePaths,
      {String folder = 'misc'}) async {
    final urls = <String>[];
    for (final p in filePaths) {
      if (p.trim().isEmpty) continue;
      // Already a remote URL (re-submission) — keep as is.
      if (p.startsWith('http://') || p.startsWith('https://')) {
        urls.add(p);
        continue;
      }
      urls.add(await uploadPhoto(p, folder: folder));
    }
    return urls;
  }

  /// Officer requests the 3% cash commission on a fully-cash-paid order.
  /// Admin must approve it afterwards before it is applied.
  static Future<Map<String, dynamic>> requestCashCommission(String orderId) =>
      _post('/api/mobile/orders/$orderId/commission', {'action': 'request'});

  /// Update a party's trade license from the field (number, expiry, photo URL).
  static Future<Map<String, dynamic>> updatePartyTradeLicense({
    required String partyId,
    String? tradeLicenseNo,
    DateTime? tradeLicenseExpiry,
    String? tradeLicensePhoto,
  }) async {
    final base = await getBaseUrl();
    final res = await http
        .patch(Uri.parse('$base/api/mobile/parties'),
            headers: await _headers(),
            body: jsonEncode({
              'partyId': partyId,
              if (tradeLicenseNo != null) 'tradeLicenseNo': tradeLicenseNo,
              if (tradeLicenseExpiry != null)
                'tradeLicenseExpiry': tradeLicenseExpiry.toIso8601String(),
              if (tradeLicensePhoto != null)
                'tradeLicensePhoto': tradeLicensePhoto,
            }))
        .timeout(const Duration(seconds: 20));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400) {
      throw ApiException(
          body['error']?.toString() ?? 'Server error', res.statusCode);
    }
    _markOnline();
    return body;
  }

  /// List product return invoices submitted by this officer.
  static Future<List<Map<String, dynamic>>> salesReturns() async {
    final body = await _get('/api/mobile/sales-returns');
    return List<Map<String, dynamic>>.from(body['data'] as List);
  }

  /// Create a product return invoice.
  /// items: [{productName, quantity, rate}]
  static Future<Map<String, dynamic>> createSalesReturn({
    required String partyName,
    required List<Map<String, dynamic>> items,
    String invoiceNo = '',
    String reason = '',
    String notes = '',
    DateTime? returnDate,
  }) =>
      _post('/api/mobile/sales-returns', {
        'partyName': partyName,
        'items': items,
        if (invoiceNo.isNotEmpty) 'invoiceNo': invoiceNo,
        'reason': reason,
        'notes': notes,
        if (returnDate != null) 'returnDate': returnDate.toIso8601String(),
      });

  /// ADMIN ONLY — approve or reject a pending cash-commission request.
  static Future<Map<String, dynamic>> decideCashCommission(
          String orderId, bool approve) =>
      _post('/api/mobile/orders/$orderId/commission',
          {'action': approve ? 'approve' : 'reject'});

  static Future<List<Map<String, dynamic>>> expenses() async {
    final body = await _get('/api/mobile/expenses');
    return List<Map<String, dynamic>>.from(body['data'] as List);
  }

  /// Auto-generated Monthly TA/DA Top Sheet (previous dues, sales target,
  /// sales amount, achievement %, recovery, current dues + bill totals).
  static Future<Map<String, dynamic>> taDaTopSheet({String month = ''}) async {
    final body = await _get('/api/mobile/expenses',
        {'topSheet': '1', if (month.isNotEmpty) 'month': month});
    return Map<String, dynamic>.from(body['topSheet'] as Map? ?? {});
  }

  /// Submit an expense/TA-DA bill — appears in ERP HR → Expenses.
  static Future<Map<String, dynamic>> createExpense(Map<String, dynamic> data) =>
      _post('/api/mobile/expenses', data);

  /// Update a mobile TA/DA bill that already has an ERP id.
  static Future<Map<String, dynamic>> updateExpense(Map<String, dynamic> data) =>
      _patch('/api/mobile/expenses', data);

  /// Delete a mobile TA/DA bill from the ERP.
  static Future<Map<String, dynamic>> deleteExpense(String id) =>
      _delete('/api/mobile/expenses/$id');

  static Future<List<Map<String, dynamic>>> leaves() async {
    final body = await _get('/api/mobile/leaves');
    return List<Map<String, dynamic>>.from(body['data'] as List);
  }

  /// Submit a leave application — appears in ERP HR → Leave.
  static Future<Map<String, dynamic>> createLeave(Map<String, dynamic> data) =>
      _post('/api/mobile/leaves', data);

  static Future<List<Map<String, dynamic>>> paymentCollections() async {
    final body = await _get('/api/mobile/payment-collections');
    return List<Map<String, dynamic>>.from(body['data'] as List);
  }

  /// Record a customer payment collection — appears in ERP Accounts.
  static Future<Map<String, dynamic>> createPaymentCollection(
          Map<String, dynamic> data) =>
      _post('/api/mobile/payment-collections', data);

  /// Fetch all ERP branches (for dropdowns).
  static Future<List<Map<String, dynamic>>> branches() async {
    try {
      final body = await _get('/api/mobile/branches');
      return List<Map<String, dynamic>>.from(body['data'] as List);
    } catch (_) {
      return [];
    }
  }

  /// SR dashboard stats: this month's orders/sales/surveys + assigned targets.
  static Future<Map<String, dynamic>> dashboard() => _get('/api/mobile/dashboard');
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  ApiException(this.message, this.statusCode);
  @override
  String toString() => message;
}
