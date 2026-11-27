import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:web/web.dart' as web;

bool get isSupported {
  try {
    return web.window.has('Notification');
  } catch (_) {
    return false;
  }
}

String get permission {
  if (!isSupported) return 'unsupported';
  try {
    return web.Notification.permission;
  } catch (_) {
    return 'unsupported';
  }
}

Future<String> requestPermission() async {
  if (!isSupported) return 'unsupported';
  try {
    final JSString res = await web.Notification.requestPermission().toDart;
    return res.toDart;
  } catch (_) {
    return 'denied';
  }
}

void show({required String title, required String body}) {
  if (!isSupported || permission != 'granted') return;
  try {
    web.Notification(
      title,
      web.NotificationOptions(body: body, icon: '/icons/Icon-192.png'),
    );
  } catch (_) {
    // Sessizce yut — tarayıcı bildirimi engellemiş olabilir.
  }
}
