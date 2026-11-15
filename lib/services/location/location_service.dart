import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:ubsoft_pdks/core/error/failure.dart';
import 'package:ubsoft_pdks/core/result/result.dart';
import 'package:ubsoft_pdks/domain/entities/scan_location.dart';

/// Cihazın konumunu okur.
///
/// Tek sorumluluğu ölçüm almaktır; ölçümün **anlamı** (nokta içinde mi,
/// sınırda mı) `VerifyLocation` içinde, saf bir fonksiyonda çözülür. Bu ayrım
/// sayesinde doğrulama kuralları gerçek bir GPS beklemeden test edilebilir.
abstract interface class LocationService {
  /// Şu anki konumu döner.
  ///
  /// Hata durumunda [LocationFailure] verir; çağıran taraf buna bakarak
  /// kullanıcıya ne yapması gerektiğini söyler.
  Future<Result<ScanLocation>> current();

  /// Konum servisi ve izin durumu okutmaya hazır mı?
  ///
  /// Okutma ekranı açılır açılmaz çağrılır: izin istemi kamera açılmadan
  /// önce çıksın, kullanıcı QR'ı okuttuktan sonra ikinci bir istemle
  /// karşılaşmasın.
  Future<bool> ensurePermission();

  /// Bellekte önceden alınmış ve tazeliğini koruyan konum (varsa).
  ///
  /// QR okutma anında GPS uydusu beklememek (0 ms okuma süresi) için
  /// uygulama girişinde önden ısıtılır ve burada tutulur.
  ScanLocation? get cachedLocation;

  /// Konumu arka planda ısıtır ve belleğe yazar.
  Future<Result<ScanLocation>> warmUp({bool force = false});
}

/// Geolocator tabanlı gerçek uygulama.
final class GeolocatorLocationService implements LocationService {
  const GeolocatorLocationService();

  static ScanLocation? _cached;
  static DateTime? _cachedAt;

  @override
  ScanLocation? get cachedLocation {
    final ScanLocation? loc = _cached;
    final DateTime? at = _cachedAt;
    if (loc != null && at != null) {
      if (DateTime.now().difference(at) < const Duration(minutes: 3)) {
        return loc;
      }
    }
    return null;
  }

  @override
  Future<Result<ScanLocation>> warmUp({bool force = false}) async {
    if (!force) {
      final ScanLocation? warm = cachedLocation;
      if (warm != null) return Ok<ScanLocation>(warm);
    }
    return current();
  }

  @override
  Future<bool> ensurePermission() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      return permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    } catch (_) {
      // Tarayıcı konum API'sini hiç sunmuyorsa (güvensiz bağlam, eski
      // sürüm) burada patlamak yerine "izin yok" denir; okutma akışı
      // kararını ayarlara göre verir.
      return false;
    }
  }

  @override
  Future<Result<ScanLocation>> current() async {
    // 1) Bellekte önceden ısıtılmış taze konum varsa (< 90 sn) 0 ms'de dön.
    final ScanLocation? warm = cachedLocation;
    if (warm != null &&
        _cachedAt != null &&
        DateTime.now().difference(_cachedAt!) < const Duration(seconds: 90)) {
      return Ok<ScanLocation>(warm);
    }

    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const Err<ScanLocation>(
          LocationFailure(
            'Cihazınızın konum servisi kapalı. Açıp tekrar deneyin.',
            code: 'service-disabled',
          ),
        );
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        return const Err<ScanLocation>(
          LocationFailure(
            'Konum izni kalıcı olarak reddedilmiş. Tarayıcı ayarlarından bu '
            'siteye konum iznini yeniden verin.',
            code: 'denied-forever',
          ),
        );
      }

      if (permission == LocationPermission.denied) {
        return const Err<ScanLocation>(
          LocationFailure(
            'Konum izni verilmedi. Okutma yapabilmek için izin gerekiyor.',
            code: 'denied',
          ),
        );
      }

      // 2) İşletim sisteminde son bilinen taze konum varsa anında al.
      try {
        final Position? lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null &&
            DateTime.now().difference(lastKnown.timestamp) <
                const Duration(minutes: 2)) {
          final ScanLocation loc = ScanLocation(
            latitude: lastKnown.latitude,
            longitude: lastKnown.longitude,
            accuracy: lastKnown.accuracy,
            capturedAt: lastKnown.timestamp,
          );
          _cached = loc;
          _cachedAt = DateTime.now();
          return Ok<ScanLocation>(loc);
        }
      } catch (_) {
        // Fallback to active position
      }

      // 3) Uydu kilidi için 10 saniye beklemek yerine medium doğrulukta
      // hızlı baz istasyonu/Wi-Fi konumunu 3-4 saniye içinde al.
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 4),
        ),
      );

      final ScanLocation loc = ScanLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        capturedAt: position.timestamp,
      );
      _cached = loc;
      _cachedAt = DateTime.now();

      return Ok<ScanLocation>(loc);
    } on TimeoutException {
      // Zaman aşımına uğrarsa eldeki son konumu kurtarıcı olarak dene
      try {
        final Position? fallback = await Geolocator.getLastKnownPosition();
        if (fallback != null) {
          final ScanLocation loc = ScanLocation(
            latitude: fallback.latitude,
            longitude: fallback.longitude,
            accuracy: fallback.accuracy,
            capturedAt: fallback.timestamp,
          );
          _cached = loc;
          _cachedAt = DateTime.now();
          return Ok<ScanLocation>(loc);
        }
      } catch (_) {}

      return const Err<ScanLocation>(
        LocationFailure(
          'Konum alınamadı: sinyal zayıf olabilir. Açık bir alanda tekrar '
          'deneyin.',
          code: 'timeout',
        ),
      );
    } catch (error) {
      return Err<ScanLocation>(
        LocationFailure(
          'Konum alınamadı. Cihazınızın konum iznini kontrol edin.',
          technical: error.toString(),
          code: 'unknown',
        ),
      );
    }
  }
}

/// Konum servisi sağlayıcısı.
///
/// Testlerde bu sağlayıcı sahte bir uygulamayla değiştirilir; hiçbir test
/// gerçek bir GPS ölçümüne bağlı değildir.
final Provider<LocationService> locationServiceProvider =
    Provider<LocationService>((ref) => const GeolocatorLocationService());
