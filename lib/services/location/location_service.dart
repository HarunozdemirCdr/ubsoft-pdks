import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:ubsoft_pdks/core/config/app_config.dart';
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
}

/// Geolocator tabanlı gerçek uygulama.
final class GeolocatorLocationService implements LocationService {
  const GeolocatorLocationService();

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

      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: AppConfig.locationTimeout,
        ),
      );

      return Ok<ScanLocation>(
        ScanLocation(
          latitude: position.latitude,
          longitude: position.longitude,
          accuracy: position.accuracy,
          capturedAt: position.timestamp,
        ),
      );
    } on TimeoutException {
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
