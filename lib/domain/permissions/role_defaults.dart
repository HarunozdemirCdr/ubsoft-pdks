import 'package:ubsoft_pdks/domain/enums/user_role.dart';
import 'package:ubsoft_pdks/domain/permissions/app_permission.dart';

/// Rollerin varsayılan izin kümeleri.
///
/// Bu tablo iki yerde yaşar:
///  • Burada — istemci tarafı yetki çözümlemesi (arayüzü doğru çizmek için).
///  • Firestore'da `roleDefaults/{role}` — güvenlik kurallarının okuduğu kaynak.
///
/// İkisi aynı olmalıdır. Ayarlar ekranından rol varsayılanları
/// değiştirildiğinde Firestore güncellenir; istemci de o değeri okur ve
/// buradaki tablo yalnız yedek (fallback) olarak kalır.
abstract final class RoleDefaults {
  /// Süper admin dışındaki roller için varsayılan izinler.
  ///
  /// Listede olmayan her izin kapalı kabul edilir.
  static const Map<UserRole, Set<AppPermission>> _defaults =
      <UserRole, Set<AppPermission>>{
        UserRole.admin: <AppPermission>{
          AppPermission.dashboardView,
          AppPermission.attendanceViewOwn,
          AppPermission.attendanceViewAll,
          AppPermission.attendanceDelete,
          AppPermission.checkpointView,
          AppPermission.checkpointCreate,
          AppPermission.checkpointEdit,
          AppPermission.checkpointDelete,
          AppPermission.userView,
          AppPermission.userCreate,
          AppPermission.userEdit,
          AppPermission.userDelete,
          AppPermission.userResetPassword,
          AppPermission.userAssignRole,
          AppPermission.userAssignPermissions,
          AppPermission.reportView,
          AppPermission.reportExport,
          AppPermission.settingsView,
          AppPermission.settingsEdit,
        },

        // Öğrenci: yalnız okutma ve kendi geçmişi.
        //
        // Öğrenci yalnız kendi hareketleri ve izinlerine ulaşır.
        UserRole.staff: <AppPermission>{
          AppPermission.punchCreate,
          AppPermission.attendanceViewOwn,
        },
      };

  /// [role] için varsayılan izin kümesi.
  ///
  /// Süper admin tüm izinlere sahiptir.
  static Set<AppPermission> of(UserRole role) {
    if (role.isSuperAdmin) return AppPermission.values.toSet();
    return _defaults[role] ?? const <AppPermission>{};
  }

  /// Firestore'a yazılacak biçim: `{ 'punch.create': true, ... }`.
  ///
  /// Tüm izinler açıkça yazılır (kapalı olanlar `false`), böylece güvenlik
  /// kurallarındaki `get(perm, false)` çağrısı her zaman net bir değer bulur.
  static Map<String, bool> toMap(UserRole role) {
    final Set<AppPermission> granted = of(role);
    return <String, bool>{
      for (final AppPermission permission in AppPermission.values)
        permission.key: granted.contains(permission),
    };
  }

  /// `roleDefaults` koleksiyonuna yazılacak tüm belgeler.
  ///
  /// Yeni bir kurulumda (veya izin kataloğu genişlediğinde) bu harita
  /// Firestore'a yazılır.
  static Map<String, Map<String, bool>> allAsMaps() =>
      <String, Map<String, bool>>{
        for (final UserRole role in UserRole.values) role.key: toMap(role),
      };
}
