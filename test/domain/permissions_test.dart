import 'package:flutter_test/flutter_test.dart';
import 'package:ubsoft_pdks/domain/enums/user_role.dart';
import 'package:ubsoft_pdks/domain/permissions/app_permission.dart';
import 'package:ubsoft_pdks/domain/permissions/permission_set.dart';
import 'package:ubsoft_pdks/domain/permissions/role_defaults.dart';

void main() {
  group('PermissionSet', () {
    test('süper admin her yetkiye sahiptir', () {
      final PermissionSet permissions = PermissionSet.fromRole(
        UserRole.superAdmin,
      );
      for (final AppPermission permission in AppPermission.values) {
        expect(
          permissions.can(permission),
          permission != AppPermission.punchCreate,
          reason: permission.key,
        );
      }
    });

    test('yönetici tenant içinde koşulsuz yetkilidir', () {
      // Ürün kararı: izin/override sistemi YALNIZ öğrenci içindir.
      final PermissionSet permissions = PermissionSet(
        role: UserRole.admin,
        overrides: const <String, bool>{'user.delete': false},
        roleDefaults: RoleDefaults.toMap(UserRole.admin),
      );

      expect(permissions.can(AppPermission.userDelete), isTrue);
      expect(permissions.can(AppPermission.settingsEdit), isTrue);
    });

    test('öğrenci yalnız varsayılan izinlerine sahiptir', () {
      final PermissionSet permissions = PermissionSet.fromRole(UserRole.staff);

      expect(permissions.can(AppPermission.punchCreate), isTrue);
      expect(permissions.can(AppPermission.attendanceViewOwn), isTrue);
      expect(permissions.can(AppPermission.attendanceViewAll), isFalse);
      expect(permissions.can(AppPermission.userView), isFalse);
      expect(permissions.can(AppPermission.settingsEdit), isFalse);
    });

    test('kullanıcıya özel ayar rol varsayılanını ezer', () {
      final PermissionSet permissions = PermissionSet(
        role: UserRole.staff,
        overrides: const <String, bool>{
          'attendance.viewAll': true,
          'punch.create': false,
        },
        roleDefaults: RoleDefaults.toMap(UserRole.staff),
      );

      expect(permissions.can(AppPermission.attendanceViewAll), isTrue);
      expect(permissions.can(AppPermission.punchCreate), isFalse);
    });

    test('askıya alınmış yurtta yazma izinleri kapanır', () {
      final PermissionSet permissions = PermissionSet(
        role: UserRole.staff,
        overrides: const <String, bool>{},
        roleDefaults: RoleDefaults.toMap(UserRole.staff),
        tenantWritable: false,
      );

      expect(permissions.can(AppPermission.punchCreate), isFalse);
      // Öğrencinin geçmiş okuma izni zaten yoktur.
      expect(permissions.can(AppPermission.attendanceViewOwn), isTrue);
    });

    test('askıya alma yöneticinin de yazmasını engeller', () {
      final PermissionSet permissions = PermissionSet(
        role: UserRole.admin,
        overrides: const <String, bool>{},
        roleDefaults: RoleDefaults.toMap(UserRole.admin),
        tenantWritable: false,
      );

      // Yönetici koşulsuz yetkilidir ama para kapısı ondan da geçer.
      expect(permissions.can(AppPermission.checkpointCreate), isFalse);
      expect(permissions.can(AppPermission.reportView), isTrue);
    });

    test('oturumsuz kümede hiçbir izin yoktur', () {
      for (final AppPermission permission in AppPermission.values) {
        expect(
          PermissionSet.none.can(permission),
          isFalse,
          reason: permission.key,
        );
      }
    });

    test('canAny ve canAll doğru çalışır', () {
      final PermissionSet permissions = PermissionSet.fromRole(UserRole.staff);

      expect(
        permissions.canAny(<AppPermission>[
          AppPermission.attendanceViewOwn,
          AppPermission.attendanceViewAll,
        ]),
        isTrue,
      );
      expect(
        permissions.canAll(<AppPermission>[
          AppPermission.attendanceViewOwn,
          AppPermission.attendanceViewAll,
        ]),
        isFalse,
      );
    });

    test('withOverride varsayılana döndürebilir', () {
      PermissionSet permissions = PermissionSet.fromRole(UserRole.staff);
      permissions = permissions.withOverride(
        AppPermission.attendanceViewAll,
        value: true,
      );
      expect(permissions.isOverridden(AppPermission.attendanceViewAll), isTrue);

      permissions = permissions.withOverride(
        AppPermission.attendanceViewAll,
        value: null,
      );
      expect(
        permissions.isOverridden(AppPermission.attendanceViewAll),
        isFalse,
      );
      expect(permissions.can(AppPermission.attendanceViewAll), isFalse);
    });
  });

  group('RoleDefaults', () {
    test('her izin her rol için açıkça yazılır', () {
      // Eksik bir anahtar, güvenlik kuralındaki `get(perm, false)` çağrısını
      // sessizce "kapalı"ya düşürür ve sebebi anlaşılmayan bir yetki kaybı
      // üretir.
      for (final UserRole role in UserRole.values) {
        final Map<String, bool> map = RoleDefaults.toMap(role);
        expect(map.length, AppPermission.values.length, reason: role.key);
        for (final AppPermission permission in AppPermission.values) {
          expect(map.containsKey(permission.key), isTrue);
        }
      }
    });

    test('öğrenci varsayılanı yönetim yetkisi içermez', () {
      final Set<AppPermission> staff = RoleDefaults.of(UserRole.staff);

      expect(staff.contains(AppPermission.userCreate), isFalse);
      expect(staff.contains(AppPermission.checkpointCreate), isFalse);
      expect(staff.contains(AppPermission.settingsEdit), isFalse);
      expect(staff.contains(AppPermission.attendanceDelete), isFalse);
    });

    test('yönetici varsayılanı tüm izinleri içerir', () {
      final Set<AppPermission> admin = RoleDefaults.of(UserRole.admin);
      expect(admin.length, AppPermission.values.length - 1);
      expect(admin.contains(AppPermission.punchCreate), isFalse);
    });

    test('izin anahtarları tekildir', () {
      final Set<String> keys = AppPermission.values
          .map((AppPermission p) => p.key)
          .toSet();
      expect(keys.length, AppPermission.values.length);
    });

    test('her izin bir gruba aittir ve gruplama eksiksizdir', () {
      final Map<PermissionGroup, List<AppPermission>> grouped =
          AppPermission.grouped();
      final int total = grouped.values.fold(
        0,
        (int sum, List<AppPermission> list) => sum + list.length,
      );
      expect(total, AppPermission.values.length);
    });

    test('anahtardan izin çözümü çalışır', () {
      expect(AppPermission.fromKey('punch.create'), AppPermission.punchCreate);
      expect(AppPermission.fromKey('yok.boyle.bir.izin'), isNull);
    });
  });

  group('UserRole', () {
    test('bilinmeyen rol öğrencie düşer', () {
      expect(UserRole.fromKey('sacma'), UserRole.staff);
      expect(UserRole.fromKey(null), UserRole.staff);
      expect(UserRole.fromKey('guard'), UserRole.staff);
    });

    test('süper admin arayüzden atanamaz', () {
      expect(UserRole.assignable.contains(UserRole.superAdmin), isFalse);
      expect(UserRole.assignable, <UserRole>[UserRole.admin, UserRole.staff]);
    });

    test('yalnız süper admin tenant dışıdır', () {
      expect(UserRole.superAdmin.belongsToTenant, isFalse);
      expect(UserRole.admin.belongsToTenant, isTrue);
      expect(UserRole.staff.belongsToTenant, isTrue);
    });
  });
}
