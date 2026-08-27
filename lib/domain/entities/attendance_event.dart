import 'package:equatable/equatable.dart';
import 'package:ubsoft_pdks/core/utils/date_x.dart';
import 'package:ubsoft_pdks/domain/entities/scan_location.dart';
import 'package:ubsoft_pdks/domain/enums/location_verdict.dart';
import 'package:ubsoft_pdks/domain/enums/punch_type.dart';

/// Tek bir okutma — bir giriş ya da bir çıkış.
///
/// Sistemin **tek doğruluk kaynağıdır**; günlük özetler bundan türetilir.
/// Bu yüzden hiçbir zaman güncellenmez: yanlış bir okutma yönetici
/// tarafından silinir, düzeltilmez. Düzeltilebilen bir devam kaydı, devam
/// kaydı olmaktan çıkar.
///
/// Personel ve nokta adları kaydın içine kopyalanır (denormalizasyon):
/// personel işten ayrılıp kaydı silinse ya da noktanın adı değişse bile
/// geçmiş rapor o günkü hâliyle okunabilir kalır.
class AttendanceEvent extends Equatable {
  const AttendanceEvent({
    required this.id,
    required this.tenantId,
    required this.userId,
    required this.userName,
    required this.type,
    required this.at,
    required this.dateKey,
    required this.checkpointId,
    required this.checkpointName,
    required this.checkpointCode,
    required this.verdict,
    this.location,
    this.distanceMeters,
    this.radiusMeters,
  });

  final String id;
  final String tenantId;

  final String userId;

  /// Okutma anındaki personel adı.
  final String userName;

  final PunchType type;

  /// Okutma anı — **sunucu saati**. İstemci saati kullanılmaz: telefonun
  /// saatini geri alarak erken giriş yazdırmak aksi hâlde mümkün olurdu.
  final DateTime at;

  /// Gün bazlı sorgu anahtarı: `2026-08-27`.
  final String dateKey;

  final String checkpointId;
  final String checkpointName;
  final String checkpointCode;

  /// Okutma anında cihazdan okunan konum. İzin verilmediyse `null`.
  final ScanLocation? location;

  /// Okutma konumunun noktaya uzaklığı (metre). Konum yoksa `null`.
  final double? distanceMeters;

  /// Okutma anında geçerli olan yarıçap.
  ///
  /// Nokta sonradan düzenlenip yarıçapı değişebilir; o zaman geçmiş
  /// kayıtların kararı bugünkü ayara göre yeniden yorumlanamaz olurdu.
  final int? radiusMeters;

  final LocationVerdict verdict;

  /// `08:42`
  String get timeLabel => AppDate.time(at);

  @override
  List<Object?> get props => <Object?>[
    id,
    tenantId,
    userId,
    userName,
    type,
    at,
    dateKey,
    checkpointId,
    checkpointName,
    checkpointCode,
    location,
    distanceMeters,
    radiusMeters,
    verdict,
  ];
}
