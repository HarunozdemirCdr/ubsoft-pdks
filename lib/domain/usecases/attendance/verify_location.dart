import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:ubsoft_pdks/core/config/app_config.dart';
import 'package:ubsoft_pdks/domain/entities/checkpoint.dart';
import 'package:ubsoft_pdks/domain/entities/scan_location.dart';
import 'package:ubsoft_pdks/domain/enums/location_verdict.dart';

/// Konum doğrulamasının sonucu.
class LocationCheck extends Equatable {
  const LocationCheck({
    required this.verdict,
    this.distanceMeters,
    this.radiusMeters,
    this.accuracyMeters,
  });

  /// Konum hiç alınamadığında.
  const LocationCheck.unavailable()
    : verdict = LocationVerdict.unavailable,
      distanceMeters = null,
      radiusMeters = null,
      accuracyMeters = null;

  final LocationVerdict verdict;

  /// Okutma konumunun noktaya uzaklığı (metre).
  final double? distanceMeters;

  /// Değerlendirmede kullanılan yarıçap.
  final int? radiusMeters;

  /// Cihazın bildirdiği ölçüm hatası.
  final double? accuracyMeters;

  bool get isVerified => verdict.isVerified;

  @override
  List<Object?> get props => <Object?>[
    verdict,
    distanceMeters,
    radiusMeters,
    accuracyMeters,
  ];
}

/// Bir okutmanın gerçekten noktanın yanında yapılıp yapılmadığını değerlendirir.
///
/// Saf bir fonksiyondur: cihaz, izin ya da ağ bilmez. Bu sayede her kural
/// birim testiyle sınanabilir.
///
/// ## Neden basit bir "yarıçap içinde mi" testi yetmez
///
/// Telefon GPS'i tek bir nokta değil, bir **daire** bildirir: "gerçek konum
/// şuranın 40 metre çevresinde bir yerde". Kapalı alanda, yüksek binalar
/// arasında ya da tarayıcı Wi-Fi tabanlı konum kullandığında bu hata payı
/// yüzlerce metreye çıkar. Ham mesafeyi yarıçapla karşılaştırmak, kapının
/// önünde duran personeli düzenli olarak "uzakta" damgalar.
///
/// Bu yüzden üç bölge vardır:
///
/// ```
///  |<-- yarıçap -->|<-- hata payı -->|
///  ●───────────────┼─────────────────┼──────────────>
///  nokta   doğrulandı     sınırda        nokta dışında
/// ```
///
/// Hata payı [AppConfig.maxAccuracySlackMeters] ile sınırlanır: tarayıcı
/// bazen IP tabanlı, kilometrelerce hatalı bir konum verir ve o pay
/// sınırsız bırakılırsa evden yapılan okutma da "sınırda" sayılırdı.
abstract final class VerifyLocation {
  static LocationCheck call({
    required Checkpoint checkpoint,
    required ScanLocation? location,
    int maxSlackMeters = AppConfig.maxAccuracySlackMeters,
  }) {
    // Nokta konumsuz tanımlanmışsa karşılaştırılacak bir şey yok. Okutma
    // yine kabul edilir; yalnız doğrulanamaz olarak işaretlenir.
    if (!checkpoint.hasLocation) return const LocationCheck.unavailable();

    if (location == null || !location.isValid) {
      return const LocationCheck.unavailable();
    }

    final double distance = location.distanceTo(
      checkpoint.latitude,
      checkpoint.longitude,
    );
    final int radius = checkpoint.radiusMeters;
    final double? accuracy = location.accuracy;

    if (distance <= radius) {
      return LocationCheck(
        verdict: LocationVerdict.verified,
        distanceMeters: distance,
        radiusMeters: radius,
        accuracyMeters: accuracy,
      );
    }

    final double slack = math.min(
      math.max(accuracy ?? 0, 0),
      maxSlackMeters.toDouble(),
    );

    return LocationCheck(
      verdict: distance <= radius + slack
          ? LocationVerdict.borderline
          : LocationVerdict.outside,
      distanceMeters: distance,
      radiusMeters: radius,
      accuracyMeters: accuracy,
    );
  }
}
