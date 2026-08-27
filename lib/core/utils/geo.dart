import 'dart:math' as math;

/// Coğrafi hesaplamalar.
///
/// Saf matematiktir: cihaz, izin ya da eklenti bilmez. Bu sayede konum
/// doğrulamasının tamamı birim testiyle sınanabilir — gerçek bir GPS
/// beklemeden.
abstract final class Geo {
  /// Dünya'nın ortalama yarıçapı (metre).
  static const double earthRadiusMeters = 6371008.8;

  /// İki koordinat arasındaki yüzey mesafesi (metre) — haversine.
  ///
  /// Yükseklik farkı hesaba katılmaz; birkaç yüz metrelik ölçekte etkisi
  /// GPS hatasının çok altındadır.
  static double distanceMeters({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);
    final double rLat1 = _toRadians(lat1);
    final double rLat2 = _toRadians(lat2);

    final double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(rLat1) *
            math.cos(rLat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  /// Koordinat geçerli aralıkta mı?
  ///
  /// (0, 0) Gine Körfezi'ndeki bir noktadır ve pratikte "koordinat girilmemiş"
  /// demektir; boş form kaydedildiğinde oraya bir nokta kurulmasın diye
  /// geçersiz sayılır.
  static bool isValidCoordinate(double? latitude, double? longitude) {
    if (latitude == null || longitude == null) return false;
    if (latitude.isNaN || longitude.isNaN) return false;
    if (latitude < -90 || latitude > 90) return false;
    if (longitude < -180 || longitude > 180) return false;
    if (latitude == 0 && longitude == 0) return false;
    return true;
  }

  /// Mesafeyi okunur biçimde verir: `18 m`, `340 m`, `2,4 km`.
  static String formatDistance(double meters) {
    if (meters.isNaN || meters.isInfinite) return '—';
    if (meters < 1000) return '${meters.round()} m';
    final double km = meters / 1000;
    return '${km.toStringAsFixed(1).replaceAll('.', ',')} km';
  }

  /// Koordinatı gösterim biçiminde verir: `41,015137, 28,979530`.
  static String formatCoordinate(double latitude, double longitude) =>
      '${_fixed(latitude)}, ${_fixed(longitude)}';

  static String _fixed(double value) =>
      value.toStringAsFixed(6).replaceAll('.', ',');

  static double _toRadians(double degrees) => degrees * math.pi / 180;
}
