import 'package:equatable/equatable.dart';
import 'package:ubsoft_pdks/core/config/app_config.dart';
import 'package:ubsoft_pdks/core/utils/geo.dart';
import 'package:ubsoft_pdks/domain/enums/punch_type.dart';

/// QR noktası — duvara asılan etiketin sistemdeki karşılığı.
///
/// Yönetici noktayı oluştururken konumunu da girer (haritadan değil, o anda
/// oradayken "Bulunduğum konumu al" ile ya da elle koordinat yazarak).
/// Okutma sırasında personelin konumu bu noktayla karşılaştırılır.
class Checkpoint extends Equatable {
  const Checkpoint({
    required this.id,
    required this.code,
    required this.name,
    required this.kind,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.createdAt,
    this.description,
    this.active = true,
    this.order = 0,
    this.updatedAt,
    this.createdBy,
  });

  final String id;

  /// Etikete basılan sayısal kod (1–10 hane). Tenant içinde tekildir.
  final String code;

  /// Görünen ad — "Ana Giriş Kapısı".
  final String name;

  final String? description;

  /// Giriş noktası mı, çıkış noktası mı, ikisi birden mi?
  final CheckpointKind kind;

  final double latitude;
  final double longitude;

  /// Bu yarıçap (metre) içindeki okutmalar doğrulanmış sayılır.
  final int radiusMeters;

  final bool active;
  final int order;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? createdBy;

  /// Konum bilgisi kullanılabilir durumda mı?
  ///
  /// Koordinatı olmayan bir nokta doğrulama yapamaz; okutmayı yine kabul
  /// eder ama sonucu [LocationVerdict.unavailable] olur.
  bool get hasLocation => Geo.isValidCoordinate(latitude, longitude);

  /// `41,015137, 28,979530`
  String get coordinateLabel => Geo.formatCoordinate(latitude, longitude);

  Checkpoint copyWith({
    String? code,
    String? name,
    String? description,
    CheckpointKind? kind,
    double? latitude,
    double? longitude,
    int? radiusMeters,
    bool? active,
    int? order,
    DateTime? updatedAt,
  }) => Checkpoint(
    id: id,
    code: code ?? this.code,
    name: name ?? this.name,
    description: description ?? this.description,
    kind: kind ?? this.kind,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    radiusMeters: radiusMeters ?? this.radiusMeters,
    active: active ?? this.active,
    order: order ?? this.order,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    createdBy: createdBy,
  );

  /// Yeni bir nokta için taslak.
  static Checkpoint draft({
    required String code,
    required String name,
    CheckpointKind kind = CheckpointKind.entry,
  }) => Checkpoint(
    id: '',
    code: code,
    name: name,
    kind: kind,
    latitude: 0,
    longitude: 0,
    radiusMeters: AppConfig.defaultRadiusMeters,
    createdAt: DateTime.now(),
  );

  @override
  List<Object?> get props => <Object?>[
    id,
    code,
    name,
    description,
    kind,
    latitude,
    longitude,
    radiusMeters,
    active,
    order,
    createdAt,
    updatedAt,
  ];
}
