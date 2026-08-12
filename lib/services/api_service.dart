import 'dart:convert';
import 'package:http/http.dart' as http;
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

  static Future<bool> get isConnected async => (await getToken()) != null;

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
    return body;
  }

  // ── Auth ─────────────────────────────────────────────────────────
  /// Login against the ERP. Returns the ERP user map on success.
  static Future<Map<String, dynamic>> login(String email, String password) async {
    final body = await _post('/api/mobile/auth/login',
        {'email': email, 'password': password});
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
    required List<Map<String, dynamic>> items, // {productId?, productName, quantity, rate, unit?}
    String paymentType = 'Cash',
    double paidAmount = 0,
    String notes = '',
  }) {
    return _post('/api/mobile/orders', {
      if (partyId != null) 'partyId': partyId,
      'partyName': partyName,
      'items': items,
      'paymentType': paymentType,
      'paidAmount': paidAmount,
      'notes': notes,
    });
  }

  static Future<List<Map<String, dynamic>>> surveys({String type = ''}) async {
    final body =
        await _get('/api/mobile/surveys', {if (type.isNotEmpty) 'type': type});
    return List<Map<String, dynamic>>.from(body['data'] as List);
  }

  /// Submit a farmer/dealer visit — appears instantly in ERP Survey module.
  static Future<Map<String, dynamic>> createSurvey(Map<String, dynamic> data) =>
      _post('/api/mobile/surveys', data);

  static Future<List<Map<String, dynamic>>> targets() async {
    final body = await _get('/api/mobile/targets');
    return List<Map<String, dynamic>>.from(body['data'] as List);
  }

  static Future<void> reportTargetProgress(String targetId, double value) =>
      _post('/api/mobile/targets', {'targetId': targetId, 'currentValue': value});

  static Future<List<Map<String, dynamic>>> stockTransfers({bool mineOnly = false}) async {
    final body = await _get(
        '/api/mobile/stock-transfers', {if (mineOnly) 'mine': '1'});
    return List<Map<String, dynamic>>.from(body['data'] as List);
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
  }) {
    return _post('/api/mobile/stock-transfers', {
      if (productId != null) 'productId': productId,
      'productName': productName,
      if (packSize != null) 'packSize': packSize,
      'fromBranch': fromBranch,
      'toBranch': toBranch,
      'quantity': quantity,
      'notes': notes,
    });
  }

  static Future<List<Map<String, dynamic>>> expenses() async {
    final body = await _get('/api/mobile/expenses');
    return List<Map<String, dynamic>>.from(body['data'] as List);
  }

  /// Submit an expense/TA-DA bill — appears in ERP HR → Expenses.
  static Future<Map<String, dynamic>> createExpense(Map<String, dynamic> data) =>
      _post('/api/mobile/expenses', data);

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
