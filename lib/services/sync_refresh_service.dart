import 'package:flutter/foundation.dart';

/// Notifies live screens that the ERP sync cycle completed.
///
/// Screens kept alive inside HomeShell subscribe to this revision so an ERP
/// status or amount change becomes visible without requiring a manual tab
/// reload. Notifications are throttled because HomeShell checks the server
/// frequently.
class SyncRefreshService {
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);
  static DateTime? _lastNotification;
  static const _minimumInterval = Duration(seconds: 15);

  static void notify({bool force = false}) {
    final now = DateTime.now();
    if (!force &&
        _lastNotification != null &&
        now.difference(_lastNotification!) < _minimumInterval) {
      return;
    }
    _lastNotification = now;
    revision.value++;
  }
}