import 'package:flutter/services.dart';

/// Blocks screenshots/screen recording on Android via FLAG_SECURE.
/// Used on invoice/order screens so officers cannot capture invoices.
class SecureScreenService {
  static const _channel = MethodChannel('wintech/secure_screen');

  static Future<void> enable() async {
    try {
      await _channel.invokeMethod('enableSecure');
    } catch (_) {
      // iOS / unsupported platform — no-op
    }
  }

  static Future<void> disable() async {
    try {
      await _channel.invokeMethod('disableSecure');
    } catch (_) {}
  }
}
