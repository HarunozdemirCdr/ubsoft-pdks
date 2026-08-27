import 'package:equatable/equatable.dart';
import 'package:ubsoft_pdks/core/config/app_config.dart';
import 'package:ubsoft_pdks/domain/enums/tenant_status.dart';

/// Abonelik bilgisi.
class Subscription extends Equatable {
  const Subscription({
    required this.plan,
    required this.startsAt,
    required this.expiresAt,
    required this.maxUsers,
    required this.maxCheckpoints,
  });

  /// Yeni müşteri için 14 günlük deneme aboneliği.
  factory Subscription.trial(DateTime now) => Subscription(
    plan: SubscriptionPlan.trial,
    startsAt: now,
    expiresAt: now.add(const Duration(days: 14)),
    maxUsers: SubscriptionPlan.trial.maxUsers,
    maxCheckpoints: SubscriptionPlan.trial.maxCheckpoints,
  );

  final SubscriptionPlan plan;
  final DateTime startsAt;
  final DateTime expiresAt;
  final int maxUsers;
  final int maxCheckpoints;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Bitişe kalan gün. Süresi dolmuşsa negatif.
  int get daysRemaining => expiresAt.difference(DateTime.now()).inDays;

  /// Yakında bitiyor mu? (Yöneticiye uyarı göstermek için.)
  bool get isExpiringSoon => !isExpired && daysRemaining <= 7;

  Subscription copyWith({
    SubscriptionPlan? plan,
    DateTime? startsAt,
    DateTime? expiresAt,
    int? maxUsers,
    int? maxCheckpoints,
  }) => Subscription(
    plan: plan ?? this.plan,
    startsAt: startsAt ?? this.startsAt,
    expiresAt: expiresAt ?? this.expiresAt,
    maxUsers: maxUsers ?? this.maxUsers,
    maxCheckpoints: maxCheckpoints ?? this.maxCheckpoints,
  );

  @override
  List<Object?> get props => <Object?>[
    plan,
    startsAt,
    expiresAt,
    maxUsers,
    maxCheckpoints,
  ];
}

/// Müşteriye özel devam kontrol ayarları.
class TenantSettings extends Equatable {
  const TenantSettings({
    this.defaultRadiusMeters = AppConfig.defaultRadiusMeters,
    this.requireLocation = true,
    this.blockOutsideScans = false,
    this.workStartMinutes = AppConfig.defaultWorkStartMinutes,
    this.workEndMinutes = AppConfig.defaultWorkEndMinutes,
    this.lateToleranceMinutes = AppConfig.defaultLateToleranceMinutes,
  });

  /// Yeni QR noktası oluşturulurken önerilen yarıçap (metre).
  final int defaultRadiusMeters;

  /// Konum alınamadığında okutma reddedilsin mi?
  ///
  /// Açık olması varsayılandır: konumu kapatarak doğrulamadan kaçmak, aksi
  /// hâlde en kolay yol olurdu. Kapalıyken okutma kabul edilir ama
  /// "Konum yok" damgasıyla kaydedilir.
  final bool requireLocation;

  /// Nokta yarıçapının açıkça dışındaki okutmalar reddedilsin mi?
  ///
  /// Varsayılan kapalıdır. Reddetmek ilk bakışta daha sıkı görünür ama
  /// yanlış bir GPS ölçümü yüzünden reddedilen giriş, personelin o gün hiç
  /// gelmemiş görünmesine yol açar — bu, uzaktan okutmadan daha büyük bir
  /// hatadır. Kapalıyken kayıt tutulur ve yöneticiye kırmızı rozetle
  /// gösterilir; kararı insan verir.
  final bool blockOutsideScans;

  /// Mesai başlangıcı — gün başından itibaren dakika (08:30 → 510).
  final int workStartMinutes;

  /// Mesai bitişi.
  final int workEndMinutes;

  /// Mesai başlangıcından sonra bu kadar dakika tolerans tanınır.
  final int lateToleranceMinutes;

  /// "Geç giriş" sınırı — gün başından itibaren dakika.
  int get lateAfterMinutes => workStartMinutes + lateToleranceMinutes;

  /// Beklenen günlük çalışma süresi (dakika).
  int get expectedDailyMinutes {
    final int span = workEndMinutes - workStartMinutes;
    return span > 0 ? span : 0;
  }

  TenantSettings copyWith({
    int? defaultRadiusMeters,
    bool? requireLocation,
    bool? blockOutsideScans,
    int? workStartMinutes,
    int? workEndMinutes,
    int? lateToleranceMinutes,
  }) => TenantSettings(
    defaultRadiusMeters: defaultRadiusMeters ?? this.defaultRadiusMeters,
    requireLocation: requireLocation ?? this.requireLocation,
    blockOutsideScans: blockOutsideScans ?? this.blockOutsideScans,
    workStartMinutes: workStartMinutes ?? this.workStartMinutes,
    workEndMinutes: workEndMinutes ?? this.workEndMinutes,
    lateToleranceMinutes: lateToleranceMinutes ?? this.lateToleranceMinutes,
  );

  @override
  List<Object?> get props => <Object?>[
    defaultRadiusMeters,
    requireLocation,
    blockOutsideScans,
    workStartMinutes,
    workEndMinutes,
    lateToleranceMinutes,
  ];
}

/// Kullanım sayaçları.
///
/// Abonelik limitlerini kontrol etmek için tutulur; her kayıt eklendiğinde
/// `FieldValue.increment` ile güncellenir.
class TenantCounters extends Equatable {
  const TenantCounters({this.userCount = 0, this.checkpointCount = 0});

  final int userCount;
  final int checkpointCount;

  @override
  List<Object?> get props => <Object?>[userCount, checkpointCount];
}

/// Müşteri (kiracı) — sistemdeki her veri bir tenant'a aittir.
class Tenant extends Equatable {
  const Tenant({
    required this.id,
    required this.name,
    required this.slug,
    required this.status,
    required this.subscription,
    required this.settings,
    required this.counters,
    required this.createdAt,
    this.timezone = AppConfig.defaultTimezone,
    this.locale = AppConfig.defaultLocale,
    this.updatedAt,
    this.createdBy,
  });

  final String id;

  /// Görünen ad — "Beyaz Yapı A.Ş.".
  final String name;

  /// Adres dostu benzersiz kısa ad — "beyaz-yapi".
  final String slug;

  final String timezone;
  final String locale;
  final TenantStatus status;
  final Subscription subscription;
  final TenantSettings settings;
  final TenantCounters counters;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? createdBy;

  /// Hesap veri yazmaya açık mı?
  ///
  /// Askıya alınmış ya da aboneliği bitmiş hesaplar salt okunurdur: veri
  /// kaybolmaz, yalnız yeni kayıt eklenemez.
  bool get isWritable => status.isWritable && !subscription.isExpired;

  bool get userLimitReached => counters.userCount >= subscription.maxUsers;

  bool get checkpointLimitReached =>
      counters.checkpointCount >= subscription.maxCheckpoints;

  Tenant copyWith({
    String? name,
    String? slug,
    String? timezone,
    String? locale,
    TenantStatus? status,
    Subscription? subscription,
    TenantSettings? settings,
    TenantCounters? counters,
    DateTime? updatedAt,
  }) => Tenant(
    id: id,
    name: name ?? this.name,
    slug: slug ?? this.slug,
    timezone: timezone ?? this.timezone,
    locale: locale ?? this.locale,
    status: status ?? this.status,
    subscription: subscription ?? this.subscription,
    settings: settings ?? this.settings,
    counters: counters ?? this.counters,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    createdBy: createdBy,
  );

  @override
  List<Object?> get props => <Object?>[
    id,
    name,
    slug,
    timezone,
    locale,
    status,
    subscription,
    settings,
    counters,
    createdAt,
    updatedAt,
  ];
}
