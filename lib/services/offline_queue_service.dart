import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'local_storage_service.dart';

/// Offline queue for orders and stock-transfers.
/// When the app is offline, items are stored locally.
/// Call [syncAll] (e.g. on app-foreground or connectivity restored) to push them.

enum QueueItemType { order, stockTransfer, expense, leave, paymentCollection, survey }

class QueueItem {
  final String id;
  final QueueItemType type;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  int retries;

  QueueItem({
    required this.id,
    required this.type,
    required this.payload,
    required this.createdAt,
    this.retries = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'payload': payload,
        'createdAt': createdAt.toIso8601String(),
        'retries': retries,
      };

  factory QueueItem.fromJson(Map<String, dynamic> j) => QueueItem(
        id: j['id'] as String,
        type: QueueItemType.values.firstWhere(
            (e) => e.name == j['type'],
            orElse: () => QueueItemType.order),
        payload: Map<String, dynamic>.from(j['payload'] as Map),
        createdAt: DateTime.parse(j['createdAt'] as String),
        retries: (j['retries'] as num?)?.toInt() ?? 0,
      );
}

class OfflineQueueService {
  static const _keyQueue = 'offline_sync_queue';

  // ── Read / Write ──────────────────────────────────────────────────────

  static Future<List<QueueItem>> getQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyQueue);
    if (raw == null) return [];
    final List<dynamic> list = jsonDecode(raw);
    return list
        .map((e) => QueueItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static Future<void> _saveQueue(List<QueueItem> q) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyQueue, jsonEncode(q.map((e) => e.toJson()).toList()));
  }

  static Future<int> get pendingCount async => (await getQueue()).length;

  // ── Enqueue ───────────────────────────────────────────────────────────

  /// Add an offline order to the queue.
  static Future<void> enqueueOrder(Map<String, dynamic> payload) async {
    final q = await getQueue();
    q.add(QueueItem(
      id: 'QORD-${DateTime.now().millisecondsSinceEpoch}',
      type: QueueItemType.order,
      payload: payload,
      createdAt: DateTime.now(),
    ));
    await _saveQueue(q);
  }

  /// Add an offline stock-transfer to the queue.
  static Future<void> enqueueStockTransfer(Map<String, dynamic> payload) async {
    final q = await getQueue();
    q.add(QueueItem(
      id: 'QTRX-${DateTime.now().millisecondsSinceEpoch}',
      type: QueueItemType.stockTransfer,
      payload: payload,
      createdAt: DateTime.now(),
    ));
    await _saveQueue(q);
  }

  /// Add an offline expense/TA-DA bill to the queue.
  static Future<void> enqueueExpense(Map<String, dynamic> payload) async {
    final q = await getQueue();
    q.add(QueueItem(
      id: 'QEXP-${DateTime.now().millisecondsSinceEpoch}',
      type: QueueItemType.expense,
      payload: payload,
      createdAt: DateTime.now(),
    ));
    await _saveQueue(q);
  }

  /// Add an offline leave application to the queue.
  static Future<void> enqueueLeave(Map<String, dynamic> payload) async {
    final q = await getQueue();
    q.add(QueueItem(
      id: 'QLVE-${DateTime.now().millisecondsSinceEpoch}',
      type: QueueItemType.leave,
      payload: payload,
      createdAt: DateTime.now(),
    ));
    await _saveQueue(q);
  }

  /// Add an offline payment collection to the queue.
  static Future<void> enqueuePaymentCollection(
      Map<String, dynamic> payload) async {
    final q = await getQueue();
    q.add(QueueItem(
      id: 'QPAY-${DateTime.now().millisecondsSinceEpoch}',
      type: QueueItemType.paymentCollection,
      payload: payload,
      createdAt: DateTime.now(),
    ));
    await _saveQueue(q);
  }

  /// Add an offline survey (farmer/dealer visit) to the queue.
  static Future<void> enqueueSurvey(Map<String, dynamic> payload) async {
    final q = await getQueue();
    q.add(QueueItem(
      id: 'QSUR-${DateTime.now().millisecondsSinceEpoch}',
      type: QueueItemType.survey,
      payload: payload,
      createdAt: DateTime.now(),
    ));
    await _saveQueue(q);
  }

  // ── Sync ──────────────────────────────────────────────────────────────

  /// Returns a [SyncResult] with counts of synced / failed / skipped items.
  static Future<SyncResult> syncAll() async {
    if (!await ApiService.isConnected) {
      return SyncResult(synced: 0, failed: 0, remaining: await pendingCount);
    }

    final q = await getQueue();
    if (q.isEmpty) return SyncResult(synced: 0, failed: 0, remaining: 0);

    final keep = <QueueItem>[];
    int synced = 0;
    int failed = 0;

    for (final item in q) {
      bool ok = false;
      bool rejected = false; // permanent server-side rejection — don't retry
      try {
        if (item.type == QueueItemType.order) {
          final p = item.payload;
          await ApiService.createOrder(
            partyId: p['partyId'] as String?,
            partyName: p['partyName'] as String? ?? '',
            items: List<Map<String, dynamic>>.from(p['items'] as List),
            notes: p['notes'] as String? ?? '',
          );
          ok = true;
        } else if (item.type == QueueItemType.stockTransfer) {
          final p = item.payload;
          await ApiService.createStockTransfer(
            productName: p['productName'] as String,
            fromBranch: p['fromBranch'] as String,
            toBranch: p['toBranch'] as String,
            quantity: (p['quantity'] as num).toDouble(),
            productId: p['productId'] as String?,
            packSize: p['packSize'] as String?,
            notes: p['notes'] as String? ?? '',
          );
          ok = true;
        } else if (item.type == QueueItemType.expense) {
          await ApiService.createExpense(item.payload);
          ok = true;
        } else if (item.type == QueueItemType.leave) {
          await ApiService.createLeave(item.payload);
          ok = true;
        } else if (item.type == QueueItemType.paymentCollection) {
          await ApiService.createPaymentCollection(item.payload);
          ok = true;
        } else if (item.type == QueueItemType.survey) {
          await ApiService.createSurvey(item.payload);
          ok = true;
        }
      } on ApiException catch (e) {
        if (_isTransient(e.statusCode)) {
          // Route missing (404), auth expired (401/403), rate limit or
          // server error — keep the item and retry on a later sync.
        } else {
          // Explicit validation/business rejection (e.g. credit limit) —
          // retrying can never succeed. Drop from the queue but keep the
          // local copy so the record is not lost.
          rejected = true;
        }
      } catch (_) {
        // Network error — retry later
      }

      if (ok) {
        synced++;
        // Remove the local offline copy — the record now lives in the ERP
        // and would otherwise appear twice after the next fetch/merge.
        await _removeLocalCopy(item);
      } else if (rejected) {
        // Dropped from the queue, but the local copy (if any) is preserved
        // so the record is never silently lost.
        failed++;
      } else {
        // Transient failure (offline, missing route, 5xx, auth hiccup) —
        // never drop; keep retrying on every future sync until it lands.
        item.retries++;
        keep.add(item);
      }
    }

    await _saveQueue(keep);
    return SyncResult(synced: synced, failed: failed, remaining: keep.length);
  }

  /// Errors worth retrying: missing route, auth hiccup, throttling, 5xx.
  static bool _isTransient(int statusCode) =>
      statusCode == 401 ||
      statusCode == 403 ||
      statusCode == 404 ||
      statusCode == 408 ||
      statusCode == 429 ||
      statusCode >= 500;

  /// After a successful sync, delete the matching local record so it is not
  /// shown twice (once from ERP with a server id, once from local storage).
  static Future<void> _removeLocalCopy(QueueItem item) async {
    final id = item.payload['id']?.toString();
    if (id == null || id.isEmpty) return;
    switch (item.type) {
      case QueueItemType.expense:
        await LocalStorageService.deleteExpense(id);
        break;
      case QueueItemType.leave:
        await LocalStorageService.deleteLeave(id);
        break;
      case QueueItemType.paymentCollection:
        await LocalStorageService.deletePaymentCollection(id);
        break;
      case QueueItemType.survey:
        await LocalStorageService.deleteSurvey(id);
        break;
      default:
        // Orders/stock transfers were never double-stored locally.
        break;
    }
  }

  /// Clear the entire queue (use only for manual reset / testing).
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyQueue);
  }
}

class SyncResult {
  final int synced;
  final int failed;
  final int remaining;
  SyncResult({required this.synced, required this.failed, required this.remaining});
  bool get hasWork => synced > 0 || remaining > 0;
}
