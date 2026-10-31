import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ubsoft_pdks/core/routing/app_routes.dart';
import 'package:ubsoft_pdks/core/routing/route_guard.dart';
import 'package:ubsoft_pdks/domain/entities/session.dart';
import 'package:ubsoft_pdks/domain/enums/user_role.dart';
import 'package:ubsoft_pdks/domain/permissions/app_permission.dart';
import 'package:ubsoft_pdks/domain/permissions/permission_set.dart';
import 'package:ubsoft_pdks/domain/permissions/role_defaults.dart';
import 'package:ubsoft_pdks/presentation/shell/nav_destinations.dart';

import '../support/test_harness.dart';

/// [GoRouterState] yerine geçen en küçük sahte.
///
/// Yalnız iki alan okunur: eşleşen adres ve sorgu parametreleri.
class _FakeState implements GoRouterState {
  _FakeState(this.matchedLocation, [this._query = const <String, String>{}]);

  @override
  final String matchedLocation;

  final Map<String, String> _query;

  @override
  Uri get uri => Uri(path: matchedLocation, queryParameters: _query);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Session _active(UserRole role, {Map<String, bool> overrides = const {}}) =>
    Session.active(
      user: TestData.user(role: role, overrides: overrides),
      tenant: TestData.tenant(),
      permissions: PermissionSet(
        role: role,
        overrides: overrides,
        roleDefaults: RoleDefaults.toMap(role),
      ),
    );

void main() {
  group('RouteGuard — oturum yok', () {
    test('korumalı adres giriş ekranına yönlendirir', () {
      final String? target = RouteGuard.resolve(
        const Session.signedOut(),
        _FakeState(AppRoutes.today),
      );

      expect(target, contains(AppRoutes.login));
      expect(target, contains('next='));
    });

    test('giriş ekranı serbesttir', () {
      expect(
        RouteGuard.resolve(
          const Session.signedOut(),
          _FakeState(AppRoutes.login),
        ),
        isNull,
      );
    });

    test('KVKK metni oturumsuz açılır', () {
      expect(
        RouteGuard.resolve(
          const Session.signedOut(),
          _FakeState(AppRoutes.privacy),
        ),
        isNull,
      );
    });
  });

  group('RouteGuard — oturum çözülmedi', () {
    test('hiçbir yönlendirme yapılmaz', () {
      // Aksi hâlde kullanıcı bir an giriş ekranına düşer ve geri zıplar.
      for (final String location in <String>[
        AppRoutes.root,
        AppRoutes.today,
        AppRoutes.login,
      ]) {
        expect(
          RouteGuard.resolve(const Session.unknown(), _FakeState(location)),
          isNull,
        );
      }
    });
  });

  group('RouteGuard — engellenmiş oturum', () {
    test('her yerden engel ekranına gider', () {
      const Session blocked = Session.blocked(SessionBlockReason.userInactive);

      expect(
        RouteGuard.resolve(blocked, _FakeState(AppRoutes.punch)),
        AppRoutes.blocked,
      );
      expect(
        RouteGuard.resolve(blocked, _FakeState(AppRoutes.blocked)),
        isNull,
      );
    });

    test('KVKK metni engellenmiş kullanıcıya da açıktır', () {
      expect(
        RouteGuard.resolve(
          const Session.blocked(SessionBlockReason.subscriptionExpired),
          _FakeState(AppRoutes.privacy),
        ),
        isNull,
      );
    });
  });

  group('RouteGuard — öğrenci', () {
    final Session staff = _active(UserRole.staff);

    test('kök adres okutma ekranına götürür', () {
      expect(
        RouteGuard.resolve(staff, _FakeState(AppRoutes.root)),
        AppRoutes.punch,
      );
    });

    test('yönetim ekranları kapalıdır', () {
      for (final String location in <String>[
        AppRoutes.users,
        AppRoutes.checkpoints,
        AppRoutes.reports,
        AppRoutes.settings,
        AppRoutes.today,
      ]) {
        expect(
          RouteGuard.resolve(staff, _FakeState(location)),
          AppRoutes.punch,
          reason: location,
        );
      }
    });

    test('geçmiş ekranı kapalıdır', () {
      expect(
        RouteGuard.resolve(staff, _FakeState(AppRoutes.history)),
        AppRoutes.punch,
      );
      expect(
        RouteGuard.resolve(
          staff,
          _FakeState(AppRoutes.personHistoryPath('staff-uid')),
        ),
        AppRoutes.punch,
      );
    });

    test('süper admin bölümü kapalıdır', () {
      expect(
        RouteGuard.resolve(staff, _FakeState(AppRoutes.tenants)),
        AppRoutes.punch,
      );
    });

    test('okutma yetkisi alınmışsa başka bir bölüme düşer', () {
      // Tercih edilen sayfaya yönlendirmek sonsuz döngü olurdu.
      final Session limited = _active(
        UserRole.staff,
        overrides: <String, bool>{'punch.create': false},
      );

      final String? home = RouteGuard.resolve(
        limited,
        _FakeState(AppRoutes.root),
      );
      expect(home, isNot(AppRoutes.punch));
      expect(home, AppRoutes.profile);
    });

    test('hiçbir yetkisi kalmayan kullanıcı profile düşer', () {
      final Session none = _active(
        UserRole.staff,
        overrides: <String, bool>{
          'punch.create': false,
          'attendance.viewOwn': false,
        },
      );

      expect(
        RouteGuard.resolve(none, _FakeState(AppRoutes.root)),
        AppRoutes.profile,
      );
    });
  });

  group('RouteGuard — yönetici', () {
    final Session admin = _active(UserRole.admin);

    test('kök adres günlük panele götürür', () {
      expect(
        RouteGuard.resolve(admin, _FakeState(AppRoutes.root)),
        AppRoutes.today,
      );
    });

    test('okutma dışındaki yönetim bölümleri açıktır', () {
      for (final String location in <String>[
        AppRoutes.today,
        AppRoutes.leaves,
        AppRoutes.history,
        AppRoutes.checkpoints,
        AppRoutes.users,
        AppRoutes.reports,
        AppRoutes.settings,
        AppRoutes.profile,
      ]) {
        expect(
          RouteGuard.resolve(admin, _FakeState(location)),
          isNull,
          reason: location,
        );
      }
    });

    test('okutma ekranı yöneticiye kapalıdır', () {
      expect(
        RouteGuard.resolve(admin, _FakeState(AppRoutes.punch)),
        AppRoutes.today,
      );
    });

    test('alt sayfalar üst bölümün iznine tabidir', () {
      expect(
        RouteGuard.resolve(admin, _FakeState(AppRoutes.userEditPath('x'))),
        isNull,
      );
    });

    test('öğrenci bir başkasının kaydını açamaz', () {
      final Session staff = _active(UserRole.staff);
      expect(
        RouteGuard.resolve(staff, _FakeState(AppRoutes.userEditPath('x'))),
        isNot(isNull),
      );
    });

    test('giriş ekranı ana sayfaya yönlendirir', () {
      expect(
        RouteGuard.resolve(admin, _FakeState(AppRoutes.login)),
        AppRoutes.today,
      );
    });
  });

  group('RouteGuard — süper admin', () {
    final Session superAdmin = Session.superAdmin(
      TestData.user(role: UserRole.superAdmin, tenant: '_system'),
    );

    test('yurt listesine yönlendirilir', () {
      expect(
        RouteGuard.resolve(superAdmin, _FakeState(AppRoutes.root)),
        AppRoutes.tenants,
      );
      expect(
        RouteGuard.resolve(superAdmin, _FakeState(AppRoutes.tenants)),
        isNull,
      );
    });

    test('yurt ekranları ona anlamsızdır', () {
      expect(
        RouteGuard.resolve(superAdmin, _FakeState(AppRoutes.today)),
        AppRoutes.tenants,
      );
      expect(
        RouteGuard.resolve(superAdmin, _FakeState(AppRoutes.punch)),
        AppRoutes.tenants,
      );
    });

    test('profil açıktır', () {
      expect(
        RouteGuard.resolve(superAdmin, _FakeState(AppRoutes.profile)),
        isNull,
      );
    });
  });

  group('RouteGuard.redirectTarget', () {
    test('giriş sonrası hedefe döner', () {
      expect(
        RouteGuard.redirectTarget(
          _FakeState(AppRoutes.login, <String, String>{
            'next': AppRoutes.reports,
          }),
        ),
        AppRoutes.reports,
      );
    });

    test('genel adresler hedef olmaz', () {
      for (final String next in <String>[
        AppRoutes.login,
        AppRoutes.blocked,
        AppRoutes.privacy,
      ]) {
        expect(
          RouteGuard.redirectTarget(
            _FakeState(AppRoutes.login, <String, String>{'next': next}),
          ),
          isNull,
          reason: next,
        );
      }
    });

    test('parametre yoksa null döner', () {
      expect(RouteGuard.redirectTarget(_FakeState(AppRoutes.login)), isNull);
    });
  });

  group('Menü ve yönlendirme tutarlılığı', () {
    test('menüde görünen her bölüm açılabilir olmalı', () {
      // Menüde görünüp açılmayan bir sekme, kullanıcıyı kendi ana sayfasına
      // geri fırlatır ve "uygulama bozuk" hissi verir.
      for (final UserRole role in <UserRole>[UserRole.admin, UserRole.staff]) {
        final Session session = _active(role);
        final PermissionSet permissions = session.permissionsOrNone;

        for (final NavDestination destination in AppNavigation.visibleFor(
          permissions,
          isSuperAdmin: false,
        )) {
          expect(
            RouteGuard.canOpen(session, destination.path),
            isTrue,
            reason: '${role.key} → ${destination.path}',
          );
        }
      }
    });

    test('izin gerektiren her bölümün menü karşılığı da izin ister', () {
      for (final NavDestination destination in AppNavigation.all) {
        final List<AppPermission>? any = RouteGuard.requirementFor(
          destination.path,
        );
        final List<AppPermission>? all = RouteGuard.allRequirementFor(
          destination.path,
        );

        if (any == null && all == null) continue;

        expect(
          destination.requires.isNotEmpty || destination.requiresAll.isNotEmpty,
          isTrue,
          reason:
              '${destination.path} yönlendirmede izin istiyor ama menüde '
              'herkese görünüyor',
        );
      }
    });
  });
}
