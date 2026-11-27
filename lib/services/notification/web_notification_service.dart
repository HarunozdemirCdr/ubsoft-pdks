import 'package:ubsoft_pdks/services/notification/web_notification_service_stub.dart'
    if (dart.library.js_interop) 'package:ubsoft_pdks/services/notification/web_notification_service_web.dart'
    as impl;

/// Tarayıcı bildirim izni ve anlık duyuru bildirimi.
abstract final class WebNotificationService {
  static bool get isSupported => impl.isSupported;

  /// `'granted'`, `'denied'`, `'default'` veya `'unsupported'`.
  static String get permission => impl.permission;

  static Future<String> requestPermission() => impl.requestPermission();

  static void show({required String title, required String body}) =>
      impl.show(title: title, body: body);
}
