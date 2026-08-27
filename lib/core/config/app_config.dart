import 'package:flutter/foundation.dart';

/// Uygulama geneli sabitler ve derleme zamanı ayarları.
///
/// Ortam değişkenleri `--dart-define` ile geçilir:
/// `flutter build web --dart-define=USE_EMULATOR=true`
abstract final class AppConfig {
  static const String appName = 'UBSoft PDKS';
  static const String appVersion = '1.1.0';

  /// Yerel Firebase emulator'a bağlan (geliştirme ve kural testleri için).
  static const bool useEmulator = bool.fromEnvironment('USE_EMULATOR');

  static const String emulatorHost = String.fromEnvironment(
    'EMULATOR_HOST',
    defaultValue: 'localhost',
  );
  static const int authEmulatorPort = int.fromEnvironment(
    'AUTH_EMULATOR_PORT',
    defaultValue: 9099,
  );
  static const int firestoreEmulatorPort = int.fromEnvironment(
    'FIRESTORE_EMULATOR_PORT',
    defaultValue: 8080,
  );

  /// Varsayılan saat dilimi — tenant ayarı yoksa kullanılır.
  static const String defaultTimezone = 'Europe/Istanbul';
  static const String defaultLocale = 'tr';

  /// Listelerde tek seferde çekilen kayıt sayısı.
  static const int pageSize = 50;

  /// Rapor dışa aktarımında en fazla kaç kayıt işlenir.
  static const int maxExportRows = 5000;

  /// QR kodunun en fazla hane sayısı.
  ///
  /// Kod sabit uzunlukta değildir: yönetici işyerine özel basit numaralar
  /// (1, 2, 3…) girer. Çok kiracılı olduğu için aynı numara farklı
  /// şirketlerde kullanılabilir; tekillik yalnız tenant içindedir.
  static const int qrCodeMaxLength = 10;

  /// Aynı QR'ın kazara arka arkaya okunmasını engelleyen bekleme süresi.
  static const Duration scanDebounce = Duration(milliseconds: 1500);

  // ─────────────────────────── Konum ───────────────────────────

  /// Yeni bir QR noktası için önerilen yarıçap (metre).
  ///
  /// 10 metre ilk bakışta doğru görünür ama telefon GPS'i şehir içinde
  /// tipik olarak 10–30 m hatayla ölçer; bina içinde daha da kötüdür. O
  /// yarıçapla kapının önünde duran personel bile "uzakta" damgası yerdi.
  /// Bina ölçeğinde ayrım yapmaya yeten ama ölçüm hatasını yutan değer
  /// budur; nokta bazında değiştirilebilir.
  static const int defaultRadiusMeters = 75;

  static const int minRadiusMeters = 10;
  static const int maxRadiusMeters = 1000;

  /// Yarıçap dışındaki okutmalarda ölçüm hatası için tanınan en fazla pay.
  ///
  /// Tarayıcı bazen 2–5 km doğrulukla konum bildirir (IP tabanlı tahmin).
  /// Bu payı sınırsız bırakmak, evden okutan birini de "sınırda" saydırırdı.
  static const int maxAccuracySlackMeters = 150;

  /// Konum alınırken beklenecek en uzun süre.
  static const Duration locationTimeout = Duration(seconds: 12);

  // ─────────────────────────── Mesai ───────────────────────────

  /// Varsayılan mesai başlangıcı (dakika cinsinden, gün başından itibaren).
  static const int defaultWorkStartMinutes = 8 * 60 + 30;

  /// Varsayılan mesai bitişi.
  static const int defaultWorkEndMinutes = 18 * 60;

  /// Bu kadar dakika sonrası "geç giriş" sayılır.
  static const int defaultLateToleranceMinutes = 15;

  /// Çıkış okutulmadan gün kapanırsa günlük kaydın açık kalabileceği süre.
  ///
  /// Bunu aşan açık günler raporda "çıkış yok" olarak işaretlenir; kayıt
  /// silinmez, yalnız işaretlenir — çünkü personelin gerçekten ne zaman
  /// çıktığını uygulama bilemez ve uydurmamalıdır.
  static const int openDayGraceHours = 16;

  static bool get isDebug => kDebugMode;
  static bool get isRelease => kReleaseMode;
}
