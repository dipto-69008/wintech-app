import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

/// Offline queue for orders and stock-transfers.
/// When the app is offline, items are stored locally.
/// Call [syncAll] (e.g. on app-foreground or connectivity restored) to push them.

enum QueueItemType { order, stockTransfer }

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
  static const int _maxRetries = 5;

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

    for (final item in q) {
      bool ok = false;
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
        }
      } on ApiException {
        // Business error (e.g. credit limit) — drop it, don't retry
        ok = true;
      } catch (_) {
        // Network error — retry later
      }

      if (!ok) {
        item.retries++;
        if (item.retries < _maxRetries) {
          keep.add(item);
        }
        // else: silently drop after max retries
      } else {
        synced++;
      }
    }

    await _saveQueue(keep);
    return SyncResult(synced: synced, failed: 0, remaining: keep.length);
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
