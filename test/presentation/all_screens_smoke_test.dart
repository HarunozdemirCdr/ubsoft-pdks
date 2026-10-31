import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubsoft_pdks/application/attendance/attendance_providers.dart';
import 'package:ubsoft_pdks/application/checkpoint/checkpoint_providers.dart';
import 'package:ubsoft_pdks/application/user/user_providers.dart';
import 'package:ubsoft_pdks/core/utils/date_x.dart';
import 'package:ubsoft_pdks/domain/entities/app_user.dart';
import 'package:ubsoft_pdks/domain/entities/checkpoint.dart';
import 'package:ubsoft_pdks/domain/enums/punch_type.dart';
import 'package:ubsoft_pdks/domain/enums/user_role.dart';
import 'package:ubsoft_pdks/presentation/features/admin/tenant_detail_page.dart';
import 'package:ubsoft_pdks/presentation/features/admin/tenant_form_page.dart';
import 'package:ubsoft_pdks/presentation/features/admin/tenant_list_page.dart';
import 'package:ubsoft_pdks/presentation/features/auth/blocked_page.dart';
import 'package:ubsoft_pdks/presentation/features/auth/forgot_password_page.dart';
import 'package:ubsoft_pdks/presentation/features/auth/login_page.dart';
import 'package:ubsoft_pdks/presentation/features/checkpoints/checkpoint_form_page.dart';
import 'package:ubsoft_pdks/presentation/features/checkpoints/checkpoint_list_page.dart';
import 'package:ubsoft_pdks/presentation/features/checkpoints/checkpoint_qr_page.dart';
import 'package:ubsoft_pdks/presentation/features/history/history_page.dart';
import 'package:ubsoft_pdks/presentation/features/history/person_history_page.dart';
import 'package:ubsoft_pdks/presentation/features/legal/privacy_page.dart';
import 'package:ubsoft_pdks/presentation/features/misc/not_found_page.dart';
import 'package:ubsoft_pdks/presentation/features/misc/splash_page.dart';
import 'package:ubsoft_pdks/presentation/features/profile/change_password_page.dart';
import 'package:ubsoft_pdks/presentation/features/profile/profile_page.dart';
import 'package:ubsoft_pdks/presentation/features/punch/punch_home_page.dart';
import 'package:ubsoft_pdks/presentation/features/reports/report_page.dart';
import 'package:ubsoft_pdks/presentation/features/settings/settings_page.dart';
import 'package:ubsoft_pdks/presentation/features/today/today_page.dart';
import 'package:ubsoft_pdks/presentation/features/users/user_form_page.dart';
import 'package:ubsoft_pdks/presentation/features/users/user_list_page.dart';

import '../support/test_harness.dart';

/// Her ekranın gerçek veriyle çizilebildiğini gösterir.
///
/// Duman testi (smoke test) küçük görünür ama en pahalı hatayı yakalar:
/// "beyaz ekran". Bir sağlayıcının yanlış tipte olması, null bir alan ya da
/// eksik bir yerleşim kısıtı ancak ekran gerçekten çizildiğinde ortaya çıkar.
void main() {
  setUpAll(initTestLocale);

  final List<Checkpoint> checkpoints = <Checkpoint>[
    TestData.checkpoint(),
    TestData.checkpoint(
      id: 'cp-out',
      code: '2',
      name: 'Çıkış Kapısı',
      kind: CheckpointKind.exit,
    ),
  ];

  final List<AppUser> team = <AppUser>[
    TestData.user(uid: 'u1'),
    TestData.user(uid: 'u2', name: 'Mehmet Demir'),
  ];

  Future<TestScope> adminScope() async {
    final TestScope scope = await buildScope(
      signedInAs: TestData.user(
        uid: TestData.adminUid,
        name: 'Mustafa Özdemir',
        role: UserRole.admin,
      ),
      extraUsers: team,
      checkpoints: checkpoints,
      location: TestData.locationNorthOf(12),
    );
    scope
      ..retain(scope.container.listen(usersProvider, (_, _) {}))
      ..retain(scope.container.listen(checkpointsProvider, (_, _) {}))
      ..retain(
        scope.container.listen(
          daySummariesProvider(AppDate.todayKey()),
          (_, _) {},
        ),
      );
    return scope;
  }

  Future<TestScope> staffScope() async {
    final TestScope scope = await buildScope(
      signedInAs: TestData.user(),
      checkpoints: checkpoints,
      location: TestData.locationNorthOf(12),
    );
    return scope;
  }

  group('Oturumsuz ekranlar', () {
    testWidgets('giriş ekranı çizilir', (WidgetTester tester) async {
      final TestScope scope = await buildScope();
      addTearDown(scope.dispose);

      await tester.pumpWidget(
        wrapPage(const LoginPage(), container: scope.container),
      );
      await settle(tester);

      expect(find.text('UBSoft Yurt Kontrol'), findsOneWidget);
      expect(find.text('Öğrenci giriş-çıkış takibi'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('şifremi unuttum ekranı çizilir', (WidgetTester tester) async {
      final TestScope scope = await buildScope();
      addTearDown(scope.dispose);

      await tester.pumpWidget(
        wrapPage(const ForgotPasswordPage(), container: scope.container),
      );
      await settle(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('erişim engeli ekranı çizilir', (WidgetTester tester) async {
      final TestScope scope = await buildScope();
      addTearDown(scope.dispose);

      await tester.pumpWidget(
        wrapPage(const BlockedPage(), container: scope.container),
      );
      await settle(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('KVKK metni konum bölümünü içerir', (
      WidgetTester tester,
    ) async {
      final TestScope scope = await buildScope();
      addTearDown(scope.dispose);

      await tester.pumpWidget(
        wrapPage(const PrivacyPage(), container: scope.container),
      );
      await settle(tester);

      // Konum verisi işlendiği için bu bölüm yasal bir zorunluluktur.
      expect(find.text('3. Konum verisi hakkında'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('açılış ve 404 ekranları çizilir', (WidgetTester tester) async {
      final TestScope scope = await buildScope();
      addTearDown(scope.dispose);

      await tester.pumpWidget(
        wrapPage(const SplashPage(), container: scope.container),
      );
      await settle(tester);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        wrapPage(const NotFoundPage(), container: scope.container),
      );
      await settle(tester);
      expect(find.text('Sayfa bulunamadı'), findsOneWidget);
    });
  });

  group('Öğrenci ekranları', () {
    testWidgets('okutma ekranı "giriş için okut" der', (
      WidgetTester tester,
    ) async {
      final TestScope scope = await staffScope();
      addTearDown(scope.dispose);

      await tester.pumpWidget(
        wrapPage(const PunchHomePage(), container: scope.container),
      );
      await settle(tester);

      expect(find.text('Giriş / çıkış QR kodunu okut'), findsOneWidget);
      expect(find.text('Başlangıç kaydı yok'), findsOneWidget);
      expect(find.text('Bugünkü hareketlerim'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('kendi geçmişi çizilir', (WidgetTester tester) async {
      final TestScope scope = await staffScope();
      addTearDown(scope.dispose);

      await tester.pumpWidget(
        wrapPage(
          const PersonHistoryPage(userId: TestData.staffUid),
          container: scope.container,
        ),
      );
      await settle(tester);

      expect(find.text('Geçmişim'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('profil ekranı çizilir', (WidgetTester tester) async {
      final TestScope scope = await staffScope();
      addTearDown(scope.dispose);

      await tester.pumpWidget(
        wrapPage(const ProfilePage(), container: scope.container),
      );
      await settle(tester);

      expect(find.text('Ahmet Yılmaz'), findsOneWidget);
      expect(find.text('Öğrenci'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('şifre değiştirme ekranı çizilir', (WidgetTester tester) async {
      final TestScope scope = await staffScope();
      addTearDown(scope.dispose);

      await tester.pumpWidget(
        wrapPage(const ChangePasswordPage(), container: scope.container),
      );
      await settle(tester);
      expect(tester.takeException(), isNull);
    });
  });

  group('Yönetici ekranları', () {
    testWidgets('günlük panel kadroyu listeler', (WidgetTester tester) async {
      final TestScope scope = await adminScope();
      addTearDown(scope.dispose);

      await tester.pumpWidget(
        wrapPage(
          const TodayPage(),
          container: scope.container,
          size: const Size(800, 1200),
        ),
      );
      await settle(tester);

      expect(find.text('Bugün'), findsWidgets);
      // Hiç okutma yokken bile kadrodaki herkes satırını korur.
      expect(find.text('Ahmet Yılmaz'), findsOneWidget);
      expect(find.text('Mehmet Demir'), findsOneWidget);
      expect(find.text('Mustafa Özdemir'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('geçmiş ekranı gün seçiciyle çizilir', (
      WidgetTester tester,
    ) async {
      final TestScope scope = await adminScope();
      addTearDown(scope.dispose);

      await tester.pumpWidget(
        wrapPage(
          const HistoryPage(),
          container: scope.container,
          size: const Size(800, 1200),
        ),
      );
      await settle(tester);

      expect(find.text('Bugün'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('nokta listesi çizilir', (WidgetTester tester) async {
      final TestScope scope = await adminScope();
      addTearDown(scope.dispose);

      await tester.pumpWidget(
        wrapPage(
          const CheckpointListPage(),
          container: scope.container,
          size: const Size(800, 1200),
        ),
      );
      await settle(tester);

      expect(find.text('Ana Giriş'), findsOneWidget);
      expect(find.text('Çıkış Kapısı'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('yeni nokta formu konum alanlarını gösterir', (
      WidgetTester tester,
    ) async {
      final TestScope scope = await adminScope();
      addTearDown(scope.dispose);

      await tester.pumpWidget(
        wrapPage(
          const CheckpointFormPage(),
          container: scope.container,
          size: const Size(800, 1400),
        ),
      );
      await settle(tester);

      expect(find.text('Bulunduğum konumu al'), findsOneWidget);
      expect(find.text('Enlem'), findsOneWidget);
      expect(find.text('Boylam'), findsOneWidget);
      expect(find.text('Yarıçap (metre)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('QR etiketi sayfası kodu gösterir', (
      WidgetTester tester,
    ) async {
      final TestScope scope = await adminScope();
      addTearDown(scope.dispose);

      await tester.pumpWidget(
        wrapPage(
          const CheckpointQrPage(checkpointId: 'cp-in'),
          container: scope.container,
          size: const Size(800, 1400),
        ),
      );
      await settle(tester);

      expect(find.text('Ana Giriş'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('öğrenci listesi çizilir', (WidgetTester tester) async {
      final TestScope scope = await adminScope();
      addTearDown(scope.dispose);

      await tester.pumpWidget(
        wrapPage(
          const UserListPage(),
          container: scope.container,
          size: const Size(800, 1200),
        ),
      );
      await settle(tester);

      expect(find.text('Ahmet Yılmaz'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('öğrenci formu ve yetki ekranı çizilir', (
      WidgetTester tester,
    ) async {
      final TestScope scope = await adminScope();
      addTearDown(scope.dispose);

      await tester.pumpWidget(
        wrapPage(
          const UserFormPage(userId: 'u1'),
          container: scope.container,
          size: const Size(800, 1600),
        ),
      );
      await settle(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('rapor ekranı çizilir', (WidgetTester tester) async {
      final TestScope scope = await adminScope();
      addTearDown(scope.dispose);

      await tester.pumpWidget(
        wrapPage(
          const ReportPage(),
          container: scope.container,
          size: const Size(1000, 1400),
        ),
      );
      await settle(tester);

      expect(find.text('Devam raporu'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ayarlar ekranı mesai ve konum bölümlerini gösterir', (
      WidgetTester tester,
    ) async {
      final TestScope scope = await adminScope();
      addTearDown(scope.dispose);

      await tester.pumpWidget(
        wrapPage(
          const SettingsPage(),
          container: scope.container,
          size: const Size(800, 1600),
        ),
      );
      await settle(tester);

      expect(find.text('Yurt giriş saatleri'), findsOneWidget);
      expect(find.text('Konum kuralları'), findsOneWidget);
      expect(find.text('Nokta dışındaki okutmaları reddet'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Süper admin ekranları', () {
    testWidgets('yurt listesi çizilir', (WidgetTester tester) async {
      final TestScope scope = await adminScope();
      addTearDown(scope.dispose);

      await tester.pumpWidget(
        wrapPage(
          const TenantListPage(),
          container: scope.container,
          size: const Size(800, 1200),
        ),
      );
      await settle(tester);

      expect(find.text('Test Yurdu'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('yeni yurt formu çizilir', (WidgetTester tester) async {
      final TestScope scope = await adminScope();
      addTearDown(scope.dispose);

      await tester.pumpWidget(
        wrapPage(
          const TenantFormPage(),
          container: scope.container,
          size: const Size(800, 1600),
        ),
      );
      await settle(tester);

      expect(find.text('İlk yönetici'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('yurt detayı çizilir', (WidgetTester tester) async {
      final TestScope scope = await adminScope();
      addTearDown(scope.dispose);

      await tester.pumpWidget(
        wrapPage(
          const TenantDetailPage(tenantId: TestData.tenantId),
          container: scope.container,
          size: const Size(800, 1600),
        ),
      );
      await settle(tester);

      expect(find.text('Test Yurdu'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
