import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubsoft_pdks/data/repositories/dorm_repository.dart';
import 'package:ubsoft_pdks/domain/entities/app_user.dart';
import 'package:ubsoft_pdks/domain/entities/attendance_event.dart';
import 'package:ubsoft_pdks/domain/entities/checkpoint.dart';
import 'package:ubsoft_pdks/domain/entities/dormitory.dart';
import 'package:ubsoft_pdks/domain/enums/location_verdict.dart';
import 'package:ubsoft_pdks/domain/enums/punch_type.dart';
import 'package:ubsoft_pdks/domain/enums/user_role.dart';
import 'package:ubsoft_pdks/domain/usecases/dorm/dorm_duration.dart';
import 'package:ubsoft_pdks/presentation/features/auth/login_page.dart';
import 'package:ubsoft_pdks/presentation/features/dorm/dorm_announcements_page.dart';
import 'package:ubsoft_pdks/presentation/features/dorm/dorm_attention_page.dart';
import 'package:ubsoft_pdks/presentation/features/dorm/dorm_pages.dart';
import 'package:ubsoft_pdks/presentation/features/dorm/dorm_rooms_page.dart';
import 'package:ubsoft_pdks/presentation/features/dorm/widgets/dorm_ui.dart';

import '../support/test_harness.dart';

Future<void> _setRoom(
  TestScope scope,
  String uid, {
  required String room,
  String studentNumber = '',
}) => scope.firestore
    .collection('tenants')
    .doc(TestData.tenantId)
    .collection('users')
    .doc(uid)
    .set(<String, Object?>{
      'room': room,
      if (studentNumber.isNotEmpty) 'studentNumber': studentNumber,
    }, SetOptions(merge: true));

void main() {
  test('DormDurationCalculator computes inside and outside intervals', () {
    final DateTime t0 = DateTime.utc(2026, 11, 20, 5);
    final events = <AttendanceEvent>[
      AttendanceEvent(
        id: 'e1',
        tenantId: 't1',
        userId: 'u1',
        userName: 'Elif Yılmaz',
        checkpointId: 'c1',
        checkpointName: 'Giriş',
        checkpointCode: '1',
        type: PunchType.entry,
        at: t0,
        dateKey: '2026-11-20',
        verdict: LocationVerdict.verified,
      ),
      AttendanceEvent(
        id: 'e2',
        tenantId: 't1',
        userId: 'u1',
        userName: 'Elif Yılmaz',
        checkpointId: 'c2',
        checkpointName: 'Çıkış',
        checkpointCode: '2',
        type: PunchType.exit,
        at: t0.add(const Duration(hours: 3)),
        dateKey: '2026-11-20',
        verdict: LocationVerdict.verified,
      ),
      AttendanceEvent(
        id: 'e3',
        tenantId: 't1',
        userId: 'u1',
        userName: 'Elif Yılmaz',
        checkpointId: 'c1',
        checkpointName: 'Giriş',
        checkpointCode: '1',
        type: PunchType.entry,
        at: t0.add(const Duration(hours: 5, minutes: 30)),
        dateKey: '2026-11-20',
        verdict: LocationVerdict.verified,
      ),
    ];

    final closed = DormDurationCalculator.summarize(events);
    expect(closed.insideDuration, const Duration(hours: 3));
    expect(closed.outsideDuration, const Duration(hours: 2, minutes: 30));

    final live = DormDurationCalculator.summarize(
      events,
      now: t0.add(const Duration(hours: 7)),
      includeOngoing: true,
    );
    expect(live.insideDuration, const Duration(hours: 4, minutes: 30));
    expect(live.outsideDuration, const Duration(hours: 2, minutes: 30));
  });

  testWidgets(
    'Odalar modülü odaları yeşil/kırmızı kartlarla gösterir ve aramayı destekler',
    (WidgetTester tester) async {
      await initTestLocale();
      final AppUser admin = TestData.user(
        uid: TestData.adminUid,
        name: 'Ayşe Müdire',
        role: UserRole.admin,
      );
      final AppUser elif = TestData.user(uid: 's1', name: 'Elif Yılmaz');
      final AppUser merve = TestData.user(uid: 's2', name: 'Merve Arslan');
      final Checkpoint cpIn = TestData.checkpoint();
      final Checkpoint cpOut = TestData.checkpoint(
        id: 'cp-out',
        code: '2',
        kind: CheckpointKind.exit,
      );
      final TestScope scope = await buildScope(
        signedInAs: admin,
        extraUsers: <AppUser>[elif, merve],
        checkpoints: <Checkpoint>[cpIn, cpOut],
      );
      addTearDown(scope.dispose);

      await _setRoom(scope, 's1', room: '101', studentNumber: '202601');
      await _setRoom(scope, 's2', room: '102', studentNumber: '202602');

      await scope.firestore
          .collection('tenants')
          .doc(TestData.tenantId)
          .collection('presence')
          .doc(elif.uid)
          .set(<String, Object?>{
            'userId': elif.uid,
            'inside': true,
            'at': Timestamp.fromDate(
              DateTime.now().subtract(const Duration(hours: 2)),
            ),
            'checkpoint': 'Ana Giriş',
          });
      await scope.firestore
          .collection('tenants')
          .doc(TestData.tenantId)
          .collection('presence')
          .doc(merve.uid)
          .set(<String, Object?>{
            'userId': merve.uid,
            'inside': false,
            'at': Timestamp.fromDate(
              DateTime.now().subtract(const Duration(hours: 1)),
            ),
            'checkpoint': 'Ana Çıkış',
          });

      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        wrapRouted(
          const DormRoomsPage(),
          container: scope.container,
          size: const Size(1280, 900),
        ),
      );
      await settle(tester);

      expect(find.text('Oda 101'), findsOneWidget);
      expect(find.text('Oda 102'), findsOneWidget);
      expect(find.textContaining('İçeride'), findsWidgets);
      expect(find.textContaining('Dışarıda'), findsWidgets);

      await tester.enterText(find.byType(TextField), '102');
      await settle(tester);
      expect(find.text('Oda 101'), findsNothing);
      expect(find.text('Oda 102'), findsOneWidget);

      final s2Tile = find.byKey(const ValueKey('room-student-s2'));
      await tester.ensureVisible(s2Tile);
      await tester.tap(s2Tile);
      await settle(tester);
      expect(find.text('→ /gecmis/s2'), findsOneWidget);
    },
  );

  testWidgets(
    'Yurt Durumu arama çubuğu öğrenci adı ve oda numarasına göre filtreler',
    (WidgetTester tester) async {
      await initTestLocale();
      final TestScope scope = await buildScope(
        signedInAs: TestData.user(uid: TestData.adminUid, role: UserRole.admin),
        extraUsers: <AppUser>[
          TestData.user(uid: 's1', name: 'Elif Yılmaz'),
          TestData.user(uid: 's2', name: 'Zeynep Demir'),
        ],
      );
      addTearDown(scope.dispose);

      await _setRoom(scope, 's1', room: '204');
      await _setRoom(scope, 's2', room: '305');

      await tester.pumpWidget(
        wrapPage(
          const DormDashboardPage(),
          container: scope.container,
          size: const Size(1280, 900),
        ),
      );
      await settle(tester);
      expect(find.byType(DormStudentCard), findsNWidgets(2));

      await tester.enterText(
        find.byKey(const ValueKey('dorm-student-search')),
        '305',
      );
      await settle(tester);
      expect(find.byType(DormStudentCard), findsOneWidget);
      expect(find.text('Zeynep Demir'), findsOneWidget);
      expect(find.text('Elif Yılmaz'), findsNothing);
    },
  );

  testWidgets(
    'İzinler modülü neden, gideceği yer, süre ve iletişim kişisini kaydedip gösterir',
    (WidgetTester tester) async {
      await initTestLocale();
      final TestScope scope = await buildScope(
        signedInAs: TestData.user(uid: TestData.adminUid, role: UserRole.admin),
        extraUsers: <AppUser>[
          TestData.user(uid: 's1', name: 'Elif Yılmaz'),
        ],
      );
      addTearDown(scope.dispose);
      await _setRoom(scope, 's1', room: '101');

      final repo = DormRepository(scope.firestore);
      final saveRes = await repo.saveLeave(
        TestData.tenantId,
        StudentLeave(
          userId: 's1',
          from: DateTime.now(),
          until: DateTime.now().add(const Duration(days: 2)),
          reason: 'Hafta sonu aile ziyareti',
          category: 'Aile ziyareti',
          destination: 'Ankara Çankaya',
          contactName: 'Mustafa Yılmaz',
          contactRelation: 'Dayı',
          contactPhone: '05350001122',
        ),
        TestData.adminUid,
      );
      expect(saveRes.isOk, isTrue);

      await tester.pumpWidget(
        wrapPage(
          const DormLeavePage(),
          container: scope.container,
          size: const Size(1000, 900),
        ),
      );
      await settle(tester);

      expect(find.text('Elif Yılmaz'), findsOneWidget);
      expect(find.text('Aile ziyareti'), findsOneWidget);
      expect(find.textContaining('Ankara Çankaya'), findsOneWidget);
      expect(find.textContaining('Mustafa Yılmaz (Dayı)'), findsOneWidget);
      expect(find.textContaining('Süre: 2 gün'), findsOneWidget);
    },
  );

  testWidgets(
    'Gelişmiş Geçmiş arama + süre özeti ve Raporlar analiz sekmeleri çalışır',
    (WidgetTester tester) async {
      await initTestLocale();
      final AppUser elif = TestData.user(uid: 's1', name: 'Elif Yılmaz');
      final AppUser zeynep = TestData.user(uid: 's2', name: 'Zeynep Demir');
      final TestScope scope = await buildScope(
        signedInAs: TestData.user(uid: TestData.adminUid, role: UserRole.admin),
        extraUsers: <AppUser>[elif, zeynep],
      );
      addTearDown(scope.dispose);
      await _setRoom(scope, 's1', room: '101');
      await _setRoom(scope, 's2', room: '202');

      final DateTime now = DateTime.now();
      final String todayKey = DormClock.key(now);
      Future<void> seedEvent(
        AppUser u, {
        required bool entry,
        required Duration ago,
      }) async {
        final at = now.subtract(ago);
        await scope.firestore
            .collection('tenants')
            .doc(TestData.tenantId)
            .collection('attendance')
            .add(<String, Object?>{
              'userId': u.uid,
              'userName': u.displayName,
              'checkpointId': entry ? 'cp-in' : 'cp-out',
              'checkpointName': entry ? 'Ana Giriş' : 'Ana Çıkış',
              'checkpointCode': entry ? '1' : '2',
              'type': entry ? 'in' : 'out',
              'at': Timestamp.fromDate(at),
              'dateKey': todayKey,
              'verdict': 'verified',
              'distanceMeters': 6.0,
              'lateMinutes': 0,
              'earlyExit': false,
              'earlyEntry': false,
              'permitted': false,
              'voided': false,
              'createdAt': Timestamp.fromDate(at),
            });
      }

      await seedEvent(elif, entry: true, ago: const Duration(hours: 4));
      await seedEvent(elif, entry: false, ago: const Duration(hours: 1));
      await seedEvent(zeynep, entry: true, ago: const Duration(hours: 2));

      // 1. Gelişmiş Geçmiş kontrolü
      await tester.pumpWidget(
        wrapPage(
          const DormHistoryPage(),
          container: scope.container,
          size: const Size(1280, 900),
        ),
      );
      await settle(tester);

      expect(find.text('Toplam içeride'), findsNothing);
      expect(find.byKey(const ValueKey('student-group-s1')), findsOneWidget);
      expect(find.byKey(const ValueKey('student-group-s2')), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('history-search')),
        '202',
      );
      await settle(tester);
      expect(find.byKey(const ValueKey('student-group-s1')), findsNothing);
      expect(find.byKey(const ValueKey('student-group-s2')), findsOneWidget);

      // 1b. Kişi geçmişi kartı + anlık durum + öğrenci detayı + hareket filtresi
      await tester.pumpWidget(
        wrapPage(
          const DormHistoryPage(userId: 's1'),
          container: scope.container,
          size: const Size(1280, 900),
        ),
      );
      await settle(tester);
      expect(find.text('DIŞARIDA TOPLAM SÜRE'), findsNothing);
      expect(find.text('ANLIK DURUM'), findsOneWidget);
      expect(find.text('SON OKUTMA'), findsOneWidget);
      expect(find.text('Öğrenci Detayı'), findsOneWidget);
      expect(find.text('Geç dönüş'), findsOneWidget);

      // 2. Gelişmiş Raporlar analiz sekmeleri kontrolü
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        wrapPage(
          const DormReportPage(),
          container: scope.container,
          size: const Size(1280, 900),
        ),
      );
      await settle(tester);

      expect(find.text('Excel (CSV)'), findsOneWidget);
      expect(find.text('Oda & Gün Kırılımı'), findsNothing);
      final hourlyTab = find.text('Özet & Saatlik Analiz');
      expect(hourlyTab, findsOneWidget);
      await tester.ensureVisible(hourlyTab);
      await tester.tap(hourlyTab);
      await settle(tester);
      expect(find.text('ANLIK İÇERİDE'), findsOneWidget);
      expect(find.text('ANLIK DIŞARIDA'), findsOneWidget);
      expect(find.text('İÇERİDE SÜRE'), findsNothing);
      expect(
        find.text('Saatlik giriş–çıkış yoğunluğu (00:00 – 23:59)'),
        findsOneWidget,
      );

      final rawTab = find.text('Ham Kayıt Tablosu');
      await tester.ensureVisible(rawTab);
      await tester.tap(rawTab);
      await settle(tester);
      expect(find.textContaining('Ana Çıkış'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Dikkat Edilmesi Gerekenler izni bitip dönmeyen öğrenciyi kritik olarak gösterir',
    (WidgetTester tester) async {
      await initTestLocale();
      final AppUser admin = TestData.user(
        uid: TestData.adminUid,
        name: 'Ayşe Demir',
        role: UserRole.admin,
      );
      final AppUser sumeyye = TestData.user(uid: 's4', name: 'Sümeyye Şahin');
      final TestScope scope = await buildScope(
        signedInAs: admin,
        extraUsers: <AppUser>[sumeyye],
      );
      addTearDown(scope.dispose);
      await _setRoom(scope, 's4', room: '201', studentNumber: '2026006');

      final now = DateTime.now();
      await scope.firestore
          .collection('tenants')
          .doc(TestData.tenantId)
          .collection('presence')
          .doc('s4')
          .set(<String, Object?>{
            'userId': 's4',
            'inside': false,
            'at': Timestamp.fromDate(now.subtract(const Duration(days: 4))),
            'checkpoint': 'Ana Çıkış',
            'permitted': true,
          });
      await DormRepository(scope.firestore).saveLeave(
        TestData.tenantId,
        StudentLeave(
          userId: 's4',
          from: now.subtract(const Duration(days: 4)),
          until: now.subtract(const Duration(hours: 18)),
          reason: 'Evci izni',
          category: 'Evci izni',
          destination: 'Ankara / Çankaya',
          contactName: 'Fatma Şahin',
          contactRelation: 'Anne',
          contactPhone: '0532 411 22 10',
        ),
        TestData.adminUid,
      );

      await tester.pumpWidget(
        wrapRouted(
          const DormAttentionPage(),
          container: scope.container,
          size: const Size(1280, 900),
        ),
      );
      await settle(tester);

      expect(find.text('Sümeyye Şahin'), findsOneWidget);
      expect(find.text('İzni bitti · Dönmedi'), findsWidgets);
      expect(find.textContaining('Fatma Şahin'), findsOneWidget);

      // Çözüldü akışı: zorunlu not girmeden kapanmaz, not girilince aktif
      // listeden düşer ve hem Çözülenler logunda hem öğrenci geçmişinde görünür.
      final resolveBtn = find.byKey(const ValueKey('resolve-s4'));
      await tester.ensureVisible(resolveBtn);
      await tester.tap(resolveBtn);
      await settle(tester);

      await tester.tap(find.byKey(const ValueKey('resolve-confirm-btn')));
      await settle(tester);
      expect(find.text('Çözüm notu girmek zorunludur.'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('resolve-note-field')),
        'Annesi Fatma Hanım ile görüşüldü, yarın sabah giriş yapacak.',
      );
      await tester.tap(find.byKey(const ValueKey('resolve-confirm-btn')));
      await settle(tester);

      expect(find.text('Açık dikkat gerektiren durum yok'), findsOneWidget);

      final resolvedTab = find.text('Çözülenler (1)');
      await tester.ensureVisible(resolvedTab);
      await tester.tap(resolvedTab);
      await settle(tester);
      expect(
        find.textContaining('Annesi Fatma Hanım ile görüşüldü'),
        findsOneWidget,
      );

      // Öğrenci geçmişinde çözüm notu ve kayıt kartı görünür.
      await tester.pumpWidget(
        wrapPage(
          const DormHistoryPage(userId: 's4'),
          container: scope.container,
          size: const Size(1280, 900),
        ),
      );
      await settle(tester);
      expect(find.text('Uyarı ve Çözüm Kayıtları (1)'), findsOneWidget);
      expect(
        find.textContaining('Annesi Fatma Hanım ile görüşüldü'),
        findsWidgets,
      );
    },
  );

  testWidgets(
    'Duyurular modülü kat ve oda bazlı hedefleme ve okundu işaretini destekler',
    (WidgetTester tester) async {
      await initTestLocale();
      final AppUser student = TestData.user(uid: 's1', name: 'Elif Yılmaz');
      final TestScope scope = await buildScope(
        signedInAs: student,
      );
      addTearDown(scope.dispose);
      await _setRoom(scope, 's1', room: '201', studentNumber: '2026001');

      final repo = DormRepository(scope.firestore);
      await repo.createAnnouncement(
        tid: TestData.tenantId,
        title: 'Genel Toplantı',
        body: 'Akşam 20:00 yemekhanede toplanıyoruz.',
        targetType: 'all',
        targetValue: '',
        priority: 'urgent',
        createdBy: TestData.adminUid,
        createdByName: 'Ayşe Demir',
      );
      await repo.createAnnouncement(
        tid: TestData.tenantId,
        title: '2. Kat Bakım',
        body: '2. katta su kesintisi olacaktır.',
        targetType: 'floor',
        targetValue: '2',
        priority: 'normal',
        createdBy: TestData.adminUid,
        createdByName: 'Ayşe Demir',
      );
      await repo.createAnnouncement(
        tid: TestData.tenantId,
        title: '3. Kat Duyurusu',
        body: 'Yalnızca 3. kat içindir.',
        targetType: 'floor',
        targetValue: '3',
        priority: 'normal',
        createdBy: TestData.adminUid,
        createdByName: 'Ayşe Demir',
      );

      await tester.pumpWidget(
        wrapPage(
          const DormAnnouncementsPage(),
          container: scope.container,
          size: const Size(1000, 900),
        ),
      );
      await settle(tester);

      expect(find.text('Genel Toplantı'), findsOneWidget);
      expect(find.text('2. Kat Bakım'), findsOneWidget);
      expect(find.text('3. Kat Duyurusu'), findsNothing);
      expect(find.text('Yeni'), findsNWidgets(2));

      final markAllBtn = find.textContaining('okundu işaretle');
      expect(markAllBtn, findsOneWidget);
      await tester.ensureVisible(markAllBtn);
      await tester.tap(markAllBtn);
      await settle(tester);
      expect(find.text('Yeni'), findsNothing);
    },
  );

  testWidgets(
    'Kurumsal giriş ekranı mobil, tablet ve masaüstü boyutlarda taşmadan çizilir',
    (WidgetTester tester) async {
      await initTestLocale();
      final TestScope scope = await buildScope();
      addTearDown(scope.dispose);

      for (final Size size in const <Size>[
        Size(360, 760),
        Size(768, 900),
        Size(1024, 620),
        Size(1440, 900),
      ]) {
        await tester.binding.setSurfaceSize(size);
        await tester.pumpWidget(
          wrapPage(const LoginPage(), container: scope.container, size: size),
        );
        await settle(tester);
        expect(find.text('Hoş Geldiniz'), findsOneWidget);
        expect(find.text('Güvenli Giriş Yap'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      addTearDown(() => tester.binding.setSurfaceSize(null));
    },
  );
}
