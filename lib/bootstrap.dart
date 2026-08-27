import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:ubsoft_pdks/core/config/app_config.dart';
import 'package:ubsoft_pdks/firebase_options.dart';

/// Uygulamayı başlatır.
///
/// Sıra önemlidir:
/// 1. Flutter bağlaması hazırlanır.
/// 2. Türkçe tarih/sayı biçimleri yüklenir (`intl` bunlar olmadan çalışmaz).
/// 3. Firebase bağlanır ve kalıcı önbellek açılır.
/// 4. Yakalanmayan hatalar için tek bir günlük noktası kurulur.
/// 5. Uygulama `ProviderScope` içinde çalıştırılır.
Future<void> bootstrap(Widget Function() builder) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Yakalanmayan hatalar tek bir yerde toplanır. Üretimde kullanıcıya
  // Flutter'ın kırmızı hata ekranı yerine sade bir görünüm gösterilir.
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    if (kDebugMode) {
      debugPrint('Yakalanmayan Flutter hatası: ${details.exception}');
    }
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    if (kDebugMode) {
      debugPrint('Yakalanmayan hata: $error');
    }
    return true;
  };

  await initializeDateFormatting('tr');

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (AppConfig.useEmulator) {
    await _connectToEmulators();
  } else {
    // Web'de sekme başına kalıcı önbellek: kısa ağ kesintilerinde ekran boş
    // kalmaz, aynı veri tekrar tekrar indirilmez.
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }

  // Oturum kalıcılığı hakkında: web'de Firebase zaten `browserLocalPersistence`
  // kullanır — oturum tarayıcı kapatılınca değil, kullanıcı çıkış yapınca
  // sonlanır. Burada `setPersistence` **çağrılmaz**: kalıcılık, saklanan
  // oturum geri yüklenmeden önce yeniden kurulduğunda Firebase o oturumu
  // düşürüyor ve kullanıcı her açılışta yeniden şifre soruyordu.

  runApp(ProviderScope(child: builder()));
}

Future<void> _connectToEmulators() async {
  debugPrint('Firebase emulator kullanılıyor: ${AppConfig.emulatorHost}');
  await FirebaseAuth.instance.useAuthEmulator(
    AppConfig.emulatorHost,
    AppConfig.authEmulatorPort,
  );
  FirebaseFirestore.instance.useFirestoreEmulator(
    AppConfig.emulatorHost,
    AppConfig.firestoreEmulatorPort,
  );
}
