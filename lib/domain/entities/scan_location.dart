import 'package:equatable/equatable.dart';
import 'package:ubsoft_pdks/core/utils/geo.dart';

/// Okutma anında cihazdan okunan konum.
///
/// [accuracy], cihazın "gerçek konum bu dairenin içinde" dediği yarıçaptır
/// (metre, %68 güven). Kaydedilmesi şart: doğrulama sonucunu sonradan
/// tartışmak gerektiğinde, ölçümün ne kadar güvenilir olduğunu yalnız bu
/// sayı söyler.
class ScanLocation extends Equatable {
  const ScanLocation({
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.capturedAt,
  });

  final double latitude;
  final double longitude;

  /// Cihazın bildirdiği yatay hata payı (metre). Bilinmiyorsa `null`.
  final double? accuracy;

  /// Konumun ölçüldüğü an. Okutma anından belirgin biçimde eskiyse, cihaz
  /// önbellekten bir konum vermiş olabilir.
  final DateTime? capturedAt;

  bool get isValid => Geo.isValidCoordinate(latitude, longitude);

  /// `41,015137, 28,979530`
  String get formatted => Geo.formatCoordinate(latitude, longitude);

  /// Bu konumdan verilen noktaya mesafe (metre).
  double distanceTo(double lat, double lon) =>
      Geo.distanceMeters(lat1: latitude, lon1: longitude, lat2: lat, lon2: lon);

  @override
  List<Object?> get props => <Object?>[
    latitude,
    longitude,
    accuracy,
    capturedAt,
  ];
}
