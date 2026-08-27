import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubsoft_pdks/application/attendance/attendance_providers.dart';
import 'package:ubsoft_pdks/application/checkpoint/checkpoint_providers.dart';
import 'package:ubsoft_pdks/application/user/user_providers.dart';
import 'package:ubsoft_pdks/core/utils/date_x.dart';
import 'package:ubsoft_pdks/domain/entities/app_user.dart';
import 'package:ubsoft_pdks/domain/entities/checkpoint.dart';
import 'package:ubsoft_pdks/domain/enums/location_verdict.dart';
import 'package:ubsoft_pdks/domain/enums/punch_type.dart';
import 'package:ubsoft_pdks/domain/enums/user_role.dart';
import 'package:ubsoft_pdks/presentation/features/checkpoints/checkpoint_list_page.dart';
import 'package:ubsoft_pdks/presentation/features/history/history_page.dart';
import 'package:ubsoft_pdks/presentation/features/history/person_history_page.dart';
import 'package:ubsoft_pdks/presentation/features/profile/profile_page.dart';
import 'package:ubsoft_pdks/presentation/features/punch/punch_home_page.dart';
import 'package:ubsoft_pdks/presentation/features/reports/report_page.dart';
import 'package:ubsoft_pdks/presentation/features/settings/settings_page.dart';
import 'package:ubsoft_pdks/presentation/features/today/today_page.dart';
import 'package:ubsoft_pdks/presentation/features/users/user_list_page.dart';

import '../support/test_harness.dart';

/// Kalabalık gerçek veriyle yerleşim testi.
///
/// Duman testleri ekranları **boş** ya da tek satırlık veriyle çizer; oysa
/// taşma (overflow) hataları tam tersi durumda doğar: uzun ad, dolu rozet
/// satırı, yan yana iki saat ve dar bir telefon ekranı. Flutter taşmayı bir
/// istisna olarak bildirdiği için burada tek bir `takeException` denetimi
/// bütün ekranı kapsar.
///
/// Üç genişlik denenir: küçük telefon (360), tablet (768) ve masaüstü (1440).
void main() {
  setUpAll(initTestLocale);

  const List<(String, Size)> viewports = <(String, Size)>[
    ('telefon 360', Size(360, 690)),
    ('tablet 768', Size(768, 1024)),
    ('masaüstü 1440', Size(1440, 900)),
  ];

  // Uzun adlar bilinçlidir: taşma en çok burada olur.
  final List<AppUser> crowd = <AppUser>[
    TestData.user(uid: 'u1', name: 'Abdülkadir Hüseyinoğlu Karahasanoğlu'),
    TestData.user(uid: 'u2', name: 'Mehmet Demir'),
    TestData.user(uid: 'u3', name: 'Zeynep Korkmaz'),
    TestData.user(uid: 'u4', name: 'Emre Kaya'),
    TestData.user(uid: 'u5', name: 'Fatma Şahin'),
    TestData.user(uid: 'u6', name: 'Hakan Aydın'),
    TestData.user(uid: 'u7', name: 'Osman Çelik'),
    TestData.user(uid: 'u8', name: 'Selim Arslan'),
    TestData.user(uid: 'u9', name: 'Elif Doğan'),
    TestData.user(uid: 'u10', name: 'Burak Yıldız'),
    TestData.user(uid: 'u11', name: 'Ayşe Polat'),
    TestData.user(uid: 'u12', name: 'Kerem Yalçın'),
  ];

  final List<Checkpoint> checkpoints = <Checkpoint>[
    TestData.checkpoint(),
    TestData.checkpoint(
      id: 'cp-out',
      code: '2',
      name: 'Çıkış Kapısı',
      kind: CheckpointKind.exit,
    ),
    TestData.checkpoint(
      id: 'cp-both',
      code: '3',
      name: 'Yan Kapı',
      kind: CheckpointKind.both,
    ),
  ];

  /// On iki kişilik kadro + son on güne ait her türden gün.
  Future<TestScope> crowdedScope() async {
    final TestScope scope = await buildScope(
      signedInAs: TestData.user(
        uid: TestData.adminUid,
        name: 'Mustafa Özdemir',
        role: UserRole.admin,
      ),
      extraUsers: crowd,
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

    final DateTime now = DateTime.now();
    for (int back = 0; back < 10; back++) {
      final String dateKey = AppDate.dateKey(
        now.subtract(Duration(days: back)),
      );

      for (int i = 0; i < crowd.length; i++) {
        final AppUser user = crowd[i];
        final int kind = (i + back) % 5;

        // Beşte biri hiç gelmedi: o günün satırı boş kalır.
        if (kind == 4) continue;

        await seedDay(
          scope,
          userId: user.uid,
          userName: user.displayName,
          dateKey: dateKey,
          entryAt: kind == 1 ? '09:52' : '08:30',
          exitAt: kind == 2 ? null : '18:12',
          late: kind == 1,
          verdict: kind == 3
              ? LocationVerdict.outside
              : LocationVerdict.verified,
        );
      }
    }

    // Bugünün okutmaları: açılan satırların içeriği de çizilsin.
    await seedEvent(
      scope,
      userId: 'u1',
      userName: 'Abdülkadir Hüseyinoğlu Karahasanoğlu',
      dateKey: AppDate.todayKey(),
      type: PunchType.entry,
    );
    await seedEvent(
      scope,
      userId: 'u1',
      userName: 'Abdülkadir Hüseyinoğlu Karahasanoğlu',
      dateKey: AppDate.todayKey(),
      type: PunchType.exit,
      time: '18:12',
    );

    return scope;
  }

  Future<void> renderAll(
    WidgetTester tester,
    Size size,
    Widget Function() page, {
    bool dark = false,
  }) async {
    final TestScope scope = await crowdedScope();
    addTearDown(scope.dispose);

    await tester.pumpWidget(
      wrapPage(page(), container: scope.container, size: size, dark: dark),
    );
    await settle(tester);

    expect(tester.takeException(), isNull);
  }

  for (final (String label, Size size) in viewports) {
    group('Yerleşim — $label', () {
      testWidgets('geçmiş tablosu taşmadan çizilir', (
        WidgetTester tester,
      ) async {
        await renderAll(tester, size, HistoryPage.new);
      });

      testWidgets('günlük panel taşmadan çizilir', (WidgetTester tester) async {
        await renderAll(tester, size, TodayPage.new);
      });

      testWidgets('rapor ekranı taşmadan çizilir', (WidgetTester tester) async {
        await renderAll(tester, size, ReportPage.new);
      });

      testWidgets('personel listesi taşmadan çizilir', (
        WidgetTester tester,
      ) async {
        await renderAll(tester, size, UserListPage.new);
      });

      testWidgets('nokta listesi taşmadan çizilir', (
        WidgetTester tester,
      ) async {
        await renderAll(tester, size, CheckpointListPage.new);
      });

      testWidgets('okutma ekranı taşmadan çizilir', (
        WidgetTester tester,
      ) async {
        await renderAll(tester, size, PunchHomePage.new);
      });

      testWidgets('ayarlar taşmadan çizilir', (WidgetTester tester) async {
        await renderAll(tester, size, SettingsPage.new);
      });

      testWidgets('profil taşmadan çizilir', (WidgetTester tester) async {
        await renderAll(tester, size, ProfilePage.new);
      });

      testWidgets('kişi geçmişi taşmadan çizilir', (WidgetTester tester) async {
        await renderAll(
          tester,
          size,
          () => const PersonHistoryPage(userId: 'u1'),
        );
      });
    });
  }

  group('Yerleşim — açılan satırlar', () {
    testWidgets('dar ekranda geçmiş satırı açılınca taşma olmaz', (
      WidgetTester tester,
    ) async {
      final TestScope scope = await crowdedScope();
      addTearDown(scope.dispose);

      await tester.pumpWidget(
        wrapPage(
          const HistoryPage(),
          container: scope.container,
          size: const Size(360, 690),
        ),
      );
      await settle(tester);

      final Finder name = find
          .text('Abdülkadir Hüseyinoğlu Karahasanoğlu')
          .first;
      await tester.ensureVisible(name);
      await tester.tap(name);
      await settle(tester);

      expect(find.text('Ana Giriş'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('dar ekranda rapor dökümü açılınca taşma olmaz', (
      WidgetTester tester,
    ) async {
      final TestScope scope = await crowdedScope();
      addTearDown(scope.dispose);

      await tester.pumpWidget(
        wrapPage(
          const ReportPage(),
          container: scope.container,
          size: const Size(360, 690),
        ),
      );
      await settle(tester);

      final Finder name = find
          .text('Abdülkadir Hüseyinoğlu Karahasanoğlu')
          .first;
      await tester.ensureVisible(name);
      await tester.tap(name);
      await settle(tester);

      // On günün satırı açıldı; saatler ve rozetler dar ekranda sığmalı.
      expect(find.text('18:12'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  /// Karanlık tema, açık temadan ayrı renk dalları kullanır (`context.isDark`).
  /// O dallardan biri unutulduğunda hata görünmez: ekran çizilir ama metin
  /// kendi zemininde okunmaz hâle gelir. Burada en azından **çizilebildiği**
  /// ve taşmadığı kayıt altına alınır.
  group('Yerleşim — karanlık tema', () {
    testWidgets('geçmiş tablosu karanlık temada çizilir', (
      WidgetTester tester,
    ) async {
      await renderAll(
        tester,
        const Size(900, 1200),
        HistoryPage.new,
        dark: true,
      );
    });

    testWidgets('günlük panel karanlık temada çizilir', (
      WidgetTester tester,
    ) async {
      await renderAll(tester, const Size(900, 1200), TodayPage.new, dark: true);
    });

    testWidgets('rapor ekranı karanlık temada çizilir', (
      WidgetTester tester,
    ) async {
      await renderAll(
        tester,
        const Size(900, 1400),
        ReportPage.new,
        dark: true,
      );
    });

    testWidgets('okutma ekranı karanlık temada çizilir', (
      WidgetTester tester,
    ) async {
      await renderAll(
        tester,
        const Size(400, 900),
        PunchHomePage.new,
        dark: true,
      );
    });
  });
}
