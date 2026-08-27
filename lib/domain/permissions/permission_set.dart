import 'package:equatable/equatable.dart';
import 'package:ubsoft_pdks/domain/enums/user_role.dart';
import 'package:ubsoft_pdks/domain/permissions/app_permission.dart';
import 'package:ubsoft_pdks/domain/permissions/role_defaults.dart';

/// Bir kullanıcının izinlerinin çözülmüş hâli.
///
/// Çözümleme sırası:
/// 1. Süper admin ise her şeye izinli.
/// 2. Müşteri askıya alınmışsa tüm **yazma** izinleri kapanır.
/// 3. Yönetici (admin) ise geri kalan her yetkiye koşulsuz sahiptir —
///    izin override'ları yalnız personel içindir, yönetici zaten admindir.
/// 4. Personelde: kullanıcının kendi override'ı varsa o geçerli; yoksa rol
///    varsayılanı (Firestore'daki `roleDefaults`, yoksa kod içindeki yedek
///    tablo).
///
/// Aynı mantık `firestore.rules` içinde birebir tekrarlanır. İstemcideki
/// kontrol yalnız arayüzü doğru çizmek içindir; gerçek kapı güvenlik
/// kurallarıdır.
class PermissionSet extends Equatable {
  const PermissionSet({
    required this.role,
    required this.overrides,
    required this.roleDefaults,
    this.tenantWritable = true,
    this.denyAll = false,
  });

  /// Rol varsayılanlarıyla, override olmadan bir küme oluşturur.
  factory PermissionSet.fromRole(UserRole role, {bool tenantWritable = true}) {
    return PermissionSet(
      role: role,
      overrides: const <String, bool>{},
      roleDefaults: RoleDefaults.toMap(role),
      tenantWritable: tenantWritable,
    );
  }

  /// Hiçbir yetkisi olmayan küme — oturum açılmamış veya engellenmiş kullanıcı.
  ///
  /// [denyAll] şart: yalnız boş bir varsayılan haritası vermek yetmez, çünkü
  /// harita boşsa koddaki yedek rol tablosu devreye girer ve kullanıcıya
  /// istemeden izin verilirdi.
  static const PermissionSet none = PermissionSet(
    role: UserRole.staff,
    overrides: <String, bool>{},
    roleDefaults: <String, bool>{},
    tenantWritable: false,
    denyAll: true,
  );

  final UserRole role;

  /// Kullanıcıya özel açık/kapalı ayarlar. Anahtar yoksa rol varsayılanı
  /// geçerlidir.
  final Map<String, bool> overrides;

  /// Firestore'dan okunan rol varsayılanları.
  final Map<String, bool> roleDefaults;

  /// Müşteri hesabı yazma işlemine açık mı?
  final bool tenantWritable;

  /// Her izni koşulsuz reddet.
  ///
  /// Engellenmiş ya da henüz çözülmemiş oturumlar için kullanılır; rol
  /// varsayılanı yedeğinin devreye girmesini engeller.
  final bool denyAll;

  /// Bu izin var mı?
  bool can(AppPermission permission) {
    if (denyAll) return false;
    if (role.isSuperAdmin) return true;
    if (permission.isWrite && !tenantWritable) return false;
    // Yönetici, tenant içinde her yetkiye sahiptir. İzin override'ları yalnız
    // personel için geçerlidir; yöneticiye izin açıp kapatmak anlamsızdır.
    if (role.isAdmin) return true;
    return _resolve(permission);
  }

  /// Verilen izinlerden **en az biri** var mı?
  bool canAny(Iterable<AppPermission> permissions) => permissions.any(can);

  /// Verilen izinlerin **hepsi** var mı?
  bool canAll(Iterable<AppPermission> permissions) => permissions.every(can);

  /// Kullanıcıya özel bir ayar yapılmış mı, yoksa rol varsayılanı mı geçerli?
  ///
  /// Yetki düzenleme ekranı bunu "Varsayılan / Açık / Kapalı" üçlü durumunu
  /// göstermek için kullanır.
  bool isOverridden(AppPermission permission) =>
      overrides.containsKey(permission.key);

  /// Rol varsayılanına göre bu izin açık mı?
  bool defaultValue(AppPermission permission) {
    if (role.isSuperAdmin || role.isAdmin) return true;
    return roleDefaults[permission.key] ??
        RoleDefaults.of(role).contains(permission);
  }

  /// Açık olan tüm izinler.
  Set<AppPermission> get granted => AppPermission.values.where(can).toSet();

  bool _resolve(AppPermission permission) {
    final bool? override = overrides[permission.key];
    if (override != null) return override;
    return defaultValue(permission);
  }

  /// Bir izni açar, kapatır veya varsayılana döndürür ([value] `null` ise).
  PermissionSet withOverride(AppPermission permission, {required bool? value}) {
    final Map<String, bool> next = Map<String, bool>.of(overrides);
    if (value == null) {
      next.remove(permission.key);
    } else {
      next[permission.key] = value;
    }
    return copyWith(overrides: next);
  }

  PermissionSet copyWith({
    UserRole? role,
    Map<String, bool>? overrides,
    Map<String, bool>? roleDefaults,
    bool? tenantWritable,
    bool? denyAll,
  }) {
    return PermissionSet(
      role: role ?? this.role,
      overrides: overrides ?? this.overrides,
      roleDefaults: roleDefaults ?? this.roleDefaults,
      tenantWritable: tenantWritable ?? this.tenantWritable,
      denyAll: denyAll ?? this.denyAll,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    role,
    overrides,
    roleDefaults,
    tenantWritable,
    denyAll,
  ];
}
