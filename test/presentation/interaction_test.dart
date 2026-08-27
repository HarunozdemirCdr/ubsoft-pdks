import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubsoft_pdks/application/checkpoint/checkpoint_providers.dart';
import 'package:ubsoft_pdks/application/user/user_providers.dart';
import 'package:ubsoft_pdks/core/config/firebase_collections.dart';
import 'package:ubsoft_pdks/core/theme/app_colors.dart';
import 'package:ubsoft_pdks/core/utils/date_x.dart';
import 'package:ubsoft_pdks/domain/entities/app_user.dart';
import 'package:ubsoft_pdks/domain/entities/checkpoint.dart';
import 'package:ubsoft_pdks/domain/enums/punch_type.dart';
import 'package:ubsoft_pdks/domain/enums/user_role.dart';
import 'package:ubsoft_pdks/presentation/features/checkpoints/checkpoint_form_page.dart';
import 'package:ubsoft_pdks/presentation/features/history/history_page.dart';
import 'package:ubsoft_pdks/presentation/features/reports/report_page.dart';
import 'package:ubsoft_pdks/presentation/features/settings/settings_page.dart';
import 'package:ubsoft_pdks/presentation/features/users/permission_editor_page.dart';
import 'package:ubsoft_pdks/presentation/features/users/user_form_page.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_button.dart';

import '../support/test_harness.dart';

/// Ekranların yalnız çizilmediğini, **çalıştığını** gösteren testler.
///
/// Duman testi bir sağlayıcının bağlı olduğunu söyler; bunlar düğmeye
/// basıldığında doğru verinin Firestore'a gittiğini söyler.
void main() {
  setUpAll(initTestLocale);

  Future<TestScope> adminScope({
    List<Checkpoint> checkpoints = const <Checkpoint>[],
    List<AppUser> extraUsers = const <AppUser>[],
  }) async {
    final TestScope scope = await buildScope(
      signedInAs: TestData.user(
        uid: TestData.adminUid,
        name: 'Mustafa Özdemir',
        role: UserRole.admin,
      ),
      extraUsers: extraUsers,
      checkpoints: checkpoints,
      location: TestData.locationNorthOf(8, accuracy: 6),
    );
    scope
      ..retain(scope.container.listen(usersProvider, (_, _) {}))
      ..retain(scope.container.listen(checkpointsProvider, (_, _) {}));
    return scope;
  }

  group('QR noktası formu', () {
    testWidgets('boş form kaydedilemez', (WidgetTester tester) async {
      final TestScope scope = await adminScope();
      addTearDown(scope.dispose);

      await tester.pumpWidget(
        wrapPage(
          const CheckpointFormPage(),
          container: scope.container,
          size: const Size(800, 1600),
        ),
      );
      await settle(tester);

      await tester.tap(find.text('Noktayı oluştur'));
      await settle(tester);

      expect(find.text('Nokta adı zorunludur.'), findsOneWidget);
      expect(find.text('QR kodu zorunludur.'), findsOneWidget);

      // Hiçbir kayıt yazılmadı.
      final int count = await scope.firestore
          .collection(FsPaths.tenants)
          .doc(TestData.tenantId)
          .collection(FsPaths.checkpoints)
          .get()
          .then((s) => s.docs.length);
      expect(count, 0);
    });

    testWidgets('"Bulunduğum konumu al" koordinatları doldurur', (
      WidgetTester tester,
    ) async {
      final TestScope scope = await adminScope();
      addTearDown(scope.dispose);

      await tester.pumpWidget(
        wrapPage(
          const CheckpointFormPage(),
          container: scope.container,
          size: const Size(800, 1600),
        ),
      );
      await settle(tester);

      expect(scope.location.currentCalls, 0);

      await tester.ensureVisible(find.text('Bulunduğum konumu al'));
      await settle(tester);
      await tester.tap(find.text('Bulunduğum konumu al'));
      await settle(tester);

      expect(scope.location.currentCalls, 1);

      final TextField latitude = tester.widget<TextField>(
        find.byWidgetPredicate(
          (Widget w) =>
              w is TextField && w.controller?.text.startsWith('41') == true,
        ),
      );
      expect(latitude.controller!.text, isNotEmpty);
      // Ölçüm hassasiyeti kullanıcıya söylenir: yarıçabı bundan küçük
      // seçmek, kendi kendini yanlışlayan bir kurulum olurdu.
      expect(find.textContaining('Ölçüm hassasiyeti'), findsOneWidget);
    });

    testWidgets('geçerli form Firestore\'a yazar', (WidgetTester tester) async {
      final TestScope scope = await adminScope();
      addTearDown(scope.dispose);

      await tester.pumpWidget(
        wrapRouted(
          const CheckpointFormPage(),
          container: scope.container,
          size: const Size(800, 1600),
        ),
      );
      await settle(tester);

      await tester.enterText(
        find.byWidgetPredicate(
          (Widget w) =>
              w is TextField && w.decoration?.hintText == 'Ana Giriş Kapısı',
        ),
        'Yan Kapı',
      );
      await tester.enterText(
        find.byWidgetPredicate(
          (Widget w) => w is TextField && w.decoration?.hintText == '1',
        ),
        '7',
      );
      await tester.ensureVisible(find.text('Bulunduğum konumu al'));
      await settle(tester);
      await tester.tap(find.text('Bulunduğum konumu al'));
      await settle(tester);

      await tester.tap(find.text('Noktayı oluştur'));
      await settle(tester);

      final List<Map<String, dynamic>> saved = await scope.firestore
          .collection(FsPaths.tenants)
          .doc(TestData.tenantId)
          .collection(FsPaths.checkpoints)
          .get()
          .then((s) => s.docs.map((d) => d.data()).toList());

      expect(saved.length, 1);
      expect(saved.single['name'], 'Yan Kapı');
      expect(saved.single['code'], '7');
      expect(saved.single['latitude'], closeTo(TestData.lat, 0.001));

      // Kod defteri de aynı işlemde yazılır; tekillik buna bağlıdır.
      final bool indexed = await scope.firestore
          .collection(FsPaths.tenants)
          .doc(TestData.tenantId)
          .collection(FsPaths.qrIndex)
          .doc('7')
          .get()
          .then((d) => d.exists);
      expect(indexed, isTrue);
    });

    testWidgets('kullanılan kod ikinci kez verilemez', (
      WidgetTester tester,
    ) async {
      final TestScope scope = await adminScope(
        checkpoints: <Checkpoint>[TestData.checkpoint(code: '3')],
      );
      addTearDown(scope.dispose);

      await tester.pumpWidget(
        wrapPage(
          const CheckpointFormPage(),
          container: scope.container,
          size: const Size(800, 1600),
        ),
      );
      await settle(tester);

      await tester.enterText(
        find.byWidgetPredicate(
          (Widget w) =>
              w is TextField && w.decoration?.hintText == 'Ana Giriş Kapısı',
        ),
        'İkinci Kapı',
      );
      await tester.enterText(
        find.byWidgetPredicate(
          (Widget w) => w is TextField && w.decoration?.hintText == '1',
        ),
        '3',
      );
      await tester.ensureVisible(find.text('Bulunduğum konumu al'));
      await settle(tester);
      await tester.tap(find.text('Bulunduğum konumu al'));
      await settle(tester);
      await tester.tap(find.text('Noktayı oluştur'));
      await settle(tester);

      // Tekillik defteri işlem (transaction) içinde kontrol edilir; ikinci
      // nokta hiç oluşmaz.
      final int count = await scope.firestore
          .collection(FsPaths.tenants)
          .doc(TestData.tenantId)
          .collection(FsPaths.checkpoints)
          .get()
          .then((s) => s.docs.length);
      expect(count, 1);
    });
  });

  group('Ayarlar', () {
    testWidgets('konum kuralları kaydedilir', (WidgetTester tester) async {
      final TestScope scope = await adminScope();
      addTearDown(scope.dispose);

      await tester.pumpWidget(
        wrapPage(
          const SettingsPage(),
          container: scope.container,
          size: const Size(800, 2000),
        ),
      );
      await settle(tester);

      final Finder blockToggle = find.ancestor(
        of: find.text('Nokta dışındaki okutmaları reddet'),
        matching: find.byType(SwitchListTile),
      );
      await tester.ensureVisible(blockToggle);
      await settle(tester);
      await tester.tap(blockToggle);
      await settle(tester);

      await tester.tap(find.text('Ayarları kaydet'));
      await settle(tester);

      final Map<String, dynamic> tenant = await scope.firestore
          .collection(FsPaths.tenants)
          .doc(TestData.tenantId)
          .get()
          .then((d) => d.data()!);

      final Map<String, dynamic> settings =
          tenant['settings'] as Map<String, dynamic>;
      expect(settings['blockOutsideScans'], isTrue);
      expect(settings['requireLocation'], isTrue);
    });
  });

  group('Yetki düzenleme', () {
    testWidgets('personelin izni açılıp kaydedilir', (
      WidgetTester tester,
    ) async {
      final TestScope scope = await adminScope(
        extraUsers: <AppUser>[TestData.user(uid: 'u1')],
      );
      addTearDown(scope.dispose);

      await tester.pumpWidget(
        wrapRouted(
          const PermissionEditorPage(userId: 'u1'),
          container: scope.container,
          size: const Size(800, 2400),
        ),
      );
      await settle(tester);

      // "Tüm personelin kayıtlarını görüntüle" personelde varsayılan
      // olarak kapalıdır.
      final Finder row = find.ancestor(
        of: find.text('Tüm personelin kayıtlarını görüntüle'),
        matching: find.byType(Row),
      );
      final Finder toggle = find.descendant(
        of: row.first,
        matching: find.byType(Switch),
      );

      await tester.ensureVisible(toggle);
      await settle(tester);
      await tester.tap(toggle);
      await settle(tester);

      await tester.tap(find.widgetWithText(AppButton, 'Kaydet'));
      await settle(tester);

      final Map<String, dynamic> saved = await scope.firestore
          .collection(FsPaths.tenants)
          .doc(TestData.tenantId)
          .collection(FsPaths.users)
          .doc('u1')
          .get()
          .then((d) => d.data()!);

      final Map<String, dynamic> permissions =
          saved['permissions'] as Map<String, dynamic>;
      expect(permissions['attendance.viewAll'], isTrue);
    });

    testWidgets('yönetici için yetki ekranı açılmaz', (
      WidgetTester tester,
    ) async {
      final TestScope scope = await adminScope();
      addTearDown(scope.dispose);

      await tester.pumpWidget(
        wrapPage(
          const PermissionEditorPage(userId: TestData.adminUid),
          container: scope.container,
          size: const Size(800, 1200),
        ),
      );
      await settle(tester);

      // Ürün kararı: yönetici tenant içinde koşulsuz yetkilidir.
      expect(find.textContaining('tüm yetkilere sahiptir'), findsOneWidget);
    });
  });

  group('Geçmiş — günlük tablo', () {
    final List<AppUser> team = <AppUser>[
      TestData.user(uid: 'u1'),
      TestData.user(uid: 'u2', name: 'Mehmet Demir'),
    ];

    testWidgets('giriş yeşil, çıkış kırmızı, gelmeyen soluk gösterilir', (
      WidgetTester tester,
    ) async {
      final TestScope scope = await adminScope(extraUsers: team);
      addTearDown(scope.dispose);

      await seedDay(scope, userId: 'u1', dateKey: AppDate.todayKey());

      await tester.pumpWidget(
        wrapPage(
          const HistoryPage(),
          container: scope.container,
          size: const Size(900, 1200),
        ),
      );
      await settle(tester);

      // Kolon başlıkları bir kez yazılır; satırlarda yalnız renk kalır.
      expect(find.text('GİRİŞ'), findsOneWidget);
      expect(find.text('ÇIKIŞ'), findsOneWidget);

      final Text entry = tester.widget<Text>(find.text('08:30'));
      final Text exit = tester.widget<Text>(find.text('17:30'));
      expect(entry.style?.color, AppColors.entry);
      expect(exit.style?.color, AppColors.exit);

      // Okutma yapmayanlar satırını korur: iki kişi × iki kolon.
      expect(find.text('—'), findsNWidgets(4));
      expect(tester.takeException(), isNull);
    });

    testWidgets('satıra dokunmak günden çıkarmaz, okutmaları açar', (
      WidgetTester tester,
    ) async {
      final TestScope scope = await adminScope(extraUsers: team);
      addTearDown(scope.dispose);

      final String today = AppDate.todayKey();
      await seedDay(scope, userId: 'u1', dateKey: today);
      await seedEvent(
        scope,
        userId: 'u1',
        dateKey: today,
        type: PunchType.entry,
      );

      await tester.pumpWidget(
        wrapPage(
          const HistoryPage(),
          container: scope.container,
          size: const Size(900, 1200),
        ),
      );
      await settle(tester);

      expect(find.text('Ana Giriş'), findsNothing);

      await tester.ensureVisible(find.text('Ahmet Yılmaz'));
      await tester.tap(find.text('Ahmet Yılmaz'));
      await settle(tester);

      // Okutma yerinde açıldı ve ekran hâlâ Geçmiş: gün gözlemi bölünmedi.
      expect(find.textContaining('Ana Giriş'), findsOneWidget);
      expect(find.byType(HistoryPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Raporlar — gün gün döküm', () {
    final List<AppUser> team = <AppUser>[
      TestData.user(uid: 'u1'),
      TestData.user(uid: 'u2', name: 'Mehmet Demir'),
    ];

    Future<TestScope> reportScope() async {
      final TestScope scope = await adminScope(extraUsers: team);
      final String today = AppDate.todayKey();
      final String yesterday = AppDate.dateKey(
        DateTime.now().subtract(const Duration(days: 1)),
      );

      await seedDay(scope, userId: 'u1', dateKey: yesterday);
      await seedDay(
        scope,
        userId: 'u1',
        dateKey: today,
        entryAt: '09:45',
        late: true,
      );
      return scope;
    }

    testWidgets('personele dokununca günleri yerinde açılır', (
      WidgetTester tester,
    ) async {
      final TestScope scope = await reportScope();
      addTearDown(scope.dispose);

      await tester.pumpWidget(
        wrapPage(
          const ReportPage(),
          container: scope.container,
          size: const Size(1000, 1600),
        ),
      );
      await settle(tester);

      // Kapalı satırda saat yazmaz; yalnız toplamlar yazar.
      expect(find.text('08:30'), findsNothing);

      await tester.ensureVisible(find.text('Ahmet Yılmaz').first);
      await tester.tap(find.text('Ahmet Yılmaz').first);
      await settle(tester);

      expect(find.text('08:30'), findsOneWidget);
      expect(find.text('09:45'), findsOneWidget);
      expect(find.text('17:30'), findsNWidgets(2));
      expect(find.byType(ReportPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('geç giriş süzgeci yalnız o günleri bırakır', (
      WidgetTester tester,
    ) async {
      final TestScope scope = await reportScope();
      addTearDown(scope.dispose);

      await tester.pumpWidget(
        wrapPage(
          const ReportPage(),
          container: scope.container,
          size: const Size(1000, 1600),
        ),
      );
      await settle(tester);

      // Süzgeçsiz hâlde kadronun tamamı satırını korur.
      expect(find.textContaining(' gün geldi'), findsNWidgets(3));

      await tester.ensureVisible(find.text('Geç giriş'));
      await tester.tap(find.text('Geç giriş'));
      await settle(tester);

      // Geç gelinmiş tek gün var; geri kalan personel rapordan düşer.
      expect(find.textContaining(' gün geldi'), findsOneWidget);
      expect(find.textContaining('1 gün geç giriş'), findsOneWidget);

      await tester.ensureVisible(find.text('Ahmet Yılmaz').first);
      await tester.tap(find.text('Ahmet Yılmaz').first);
      await settle(tester);

      // Açılan dökümde yalnız geç gelinen gün listelenir.
      expect(find.text('09:45'), findsOneWidget);
      expect(find.text('08:30'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('Personel formu', () {
    testWidgets('yeni personel Auth hesabı ve Firestore kaydı üretir', (
      WidgetTester tester,
    ) async {
      final TestScope scope = await adminScope();
      addTearDown(scope.dispose);

      // Kayıt başarılı olunca ekran personel listesine gider; yönlendirme
      // için gerçek bir router gerekir.
      await tester.pumpWidget(
        wrapRouted(
          const UserFormPage(),
          container: scope.container,
          size: const Size(800, 1600),
        ),
      );
      await settle(tester);

      // Alan etiketleri girdinin ÜSTÜNDE ayrı bir Text'tir (labelText değil);
      // bu yüzden alanlar form sırasına göre bulunur.
      await tester.enterText(find.byType(TextField).at(0), 'Yeni Personel');
      await tester.enterText(
        find.byType(TextField).at(1),
        'yeni@beyazyapi.com',
      );
      await tester.enterText(find.byType(TextField).at(2), 'Pdks2026!');
      await tester.enterText(
        find.byWidgetPredicate(
          (Widget w) =>
              w is TextField && w.decoration?.hintText == 'Gece vardiyası',
        ),
        'Gece vardiyası',
      );
      await settle(tester);

      final Finder save = find.widgetWithText(AppButton, 'Personeli ekle');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await settle(tester);

      final QuerySnapshot<Map<String, dynamic>> users = await scope.firestore
          .collection(FsPaths.tenants)
          .doc(TestData.tenantId)
          .collection(FsPaths.users)
          .where('email', isEqualTo: 'yeni@beyazyapi.com')
          .get();

      expect(users.docs, hasLength(1));
      final Map<String, dynamic> saved = users.docs.single.data();
      expect(saved['displayName'], 'Yeni Personel');
      expect(saved['role'], 'staff');
      expect(saved['status'], 'active');
      // Sicil no ve görev alanları kaldırıldı; yerlerine tek bir açıklama.
      expect(saved['note'], 'Gece vardiyası');
      expect(saved.containsKey('employeeNo'), isFalse);

      // Kaydın ardından personel listesine dönülür.
      expect(find.text('→ /kullanicilar'), findsOneWidget);
    });

    testWidgets('geçersiz e-posta ile kayıt yapılmaz', (
      WidgetTester tester,
    ) async {
      final TestScope scope = await adminScope();
      addTearDown(scope.dispose);

      // Kayıt başarılı olunca ekran personel listesine gider; yönlendirme
      // için gerçek bir router gerekir.
      await tester.pumpWidget(
        wrapRouted(
          const UserFormPage(),
          container: scope.container,
          size: const Size(800, 1600),
        ),
      );
      await settle(tester);

      await tester.enterText(find.byType(TextField).at(0), 'Hatalı Kayıt');
      await tester.enterText(
        find.byType(TextField).at(1),
        'bu-bir-eposta-degil',
      );
      await settle(tester);

      final Finder save = find.widgetWithText(AppButton, 'Personeli ekle');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await settle(tester);

      final QuerySnapshot<Map<String, dynamic>> users = await scope.firestore
          .collection(FsPaths.tenants)
          .doc(TestData.tenantId)
          .collection(FsPaths.users)
          .get();

      // Yalnız yöneticinin kendi kaydı durur; hatalı form yazmadı ve ekran
      // formda kaldı.
      expect(users.docs, hasLength(1));
      expect(find.text('→ /kullanicilar'), findsNothing);
    });
  });
}
