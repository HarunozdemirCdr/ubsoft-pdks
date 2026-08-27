import 'package:flutter_test/flutter_test.dart';
import 'package:ubsoft_pdks/application/attendance/attendance_admin_controller.dart';
import 'package:ubsoft_pdks/application/attendance/attendance_providers.dart';
import 'package:ubsoft_pdks/application/attendance/punch_controller.dart';
import 'package:ubsoft_pdks/application/auth/session_provider.dart';
import 'package:ubsoft_pdks/application/report/report_providers.dart';
import 'package:ubsoft_pdks/core/error/failure.dart';
import 'package:ubsoft_pdks/core/utils/date_x.dart';
import 'package:ubsoft_pdks/domain/entities/attendance_day.dart';
import 'package:ubsoft_pdks/domain/entities/attendance_event.dart';
import 'package:ubsoft_pdks/domain/entities/checkpoint.dart';
import 'package:ubsoft_pdks/domain/entities/report_filter.dart';
import 'package:ubsoft_pdks/domain/entities/session.dart';
import 'package:ubsoft_pdks/domain/entities/tenant.dart';
import 'package:ubsoft_pdks/domain/enums/day_status.dart';
import 'package:ubsoft_pdks/domain/enums/location_verdict.dart';
import 'package:ubsoft_pdks/domain/enums/punch_type.dart';
import 'package:ubsoft_pdks/domain/enums/report_focus.dart';
import 'package:ubsoft_pdks/domain/enums/tenant_status.dart';
import 'package:ubsoft_pdks/domain/enums/user_role.dart';

import '../support/test_harness.dart';

/// Uçtan uca okutma akışı.
///
/// Sahte de olsa gerçek bir Firestore üzerinde çalışır: kural motoru,
/// depo katmanı, işlem (transaction) ve gün özeti birlikte sınanır. Birim
/// testleri parçaların doğruluğunu, bu testler birleştiklerinde hâlâ doğru
/// olduklarını gösterir.
void main() {
  late TestScope scope;

  final List<Checkpoint> checkpoints = <Checkpoint>[
    TestData.checkpoint(),
    TestData.checkpoint(
      id: 'cp-out',
      code: '2',
      name: 'Çıkış Kapısı',
      kind: CheckpointKind.exit,
    ),
  ];

  /// Oturumun çözülmesini bekler — tüm akış buna dayanır.
  Future<void> waitForSession(TestScope scope) async {
    final Session session = await scope.container.read(sessionProvider.future);
    expect(session, isA<SessionActive>());
  }

  setUp(() async {
    scope = await buildScope(
      signedInAs: TestData.user(),
      checkpoints: checkpoints,
      location: TestData.locationNorthOf(15),
    );
    await waitForSession(scope);
  });

  tearDown(() => scope.dispose());

  test('oturum, kullanıcı ve müşteriyle birlikte çözülür', () async {
    final Session session = scope.container.read(currentSessionProvider);

    expect(session, isA<SessionActive>());
    final SessionActive active = session as SessionActive;
    expect(active.user.uid, TestData.staffUid);
    expect(active.tenant.name, 'Test Şirketi');
    expect(active.permissions.role, UserRole.staff);
  });

  test('giriş okutması kayıt ve gün özeti üretir', () async {
    final PunchController controller = scope.container.read(
      punchControllerProvider.notifier,
    );

    await controller.submit('1');

    final PunchState state = scope.container.read(punchControllerProvider);
    expect(state, isA<PunchSuccess>(), reason: _describe(state));

    final PunchSuccess success = state as PunchSuccess;
    expect(success.event.type, PunchType.entry);
    expect(success.event.checkpointName, 'Ana Giriş');
    expect(success.event.verdict, LocationVerdict.verified);
    expect(success.event.distanceMeters, closeTo(15, 2));

    await flush();
    final AttendanceDay day = scope.container
        .read(myTodayProvider)
        .requireValue;
    expect(day.open, isTrue);
    expect(day.entryCount, 1);
    expect(day.firstEntryAt, isNotNull);
  });

  test('giriş ve çıkış birlikte çalışma süresi oluşturur', () async {
    final PunchController controller = scope.container.read(
      punchControllerProvider.notifier,
    );

    await controller.submit('1');
    controller.reset();
    await controller.submit('2');

    expect(scope.container.read(punchControllerProvider), isA<PunchSuccess>());

    await flush();
    final AttendanceDay day = scope.container
        .read(myTodayProvider)
        .requireValue;
    expect(day.open, isFalse);
    expect(day.entryCount, 1);
    expect(day.exitCount, 1);
    expect(day.lastExitAt, isNotNull);
  });

  test('üst üste iki giriş reddedilir', () async {
    final PunchController controller = scope.container.read(
      punchControllerProvider.notifier,
    );

    await controller.submit('1');
    controller.reset();
    await controller.submit('1');

    final PunchState state = scope.container.read(punchControllerProvider);
    expect(state, isA<PunchFailed>());
    expect((state as PunchFailed).failure.message, contains('Zaten giriş'));

    // Reddedilen okutma kayıt bırakmaz.
    await flush();
    final AttendanceDay day = scope.container
        .read(myTodayProvider)
        .requireValue;
    expect(day.entryCount, 1);
  });

  test('okutmadan rapora: aynı gün rapora doğru yansır', () async {
    final PunchController controller = scope.container.read(
      punchControllerProvider.notifier,
    );

    await controller.submit('1');
    controller.reset();
    await controller.submit('2');
    await flush();

    // Rapor tek seferlik okuma yapar; kapsam boyunca canlı tutulur.
    final ReportFilter filter = ReportFilter.today();
    scope.retain(scope.container.listen(reportProvider(filter), (_, _) {}));

    final ReportResult report = await scope.container.read(
      reportProvider(filter).future,
    );

    final ReportRow row = report.rows.singleWhere(
      (ReportRow r) => r.userId == TestData.staffUid,
    );

    expect(row.presentDays, 1);
    expect(row.absentDays, 0);
    expect(row.days.single.entryCount, 1);
    expect(row.days.single.exitCount, 1);
    expect(report.totalDayRows, 1);
  });

  test('gün süzgeci ağa yeniden çıkmaz, aynı okumayı kullanır', () async {
    await scope.container.read(punchControllerProvider.notifier).submit('1');
    await flush();

    final ReportFilter all = ReportFilter.today();
    final ReportFilter flagged = all.copyWith(focus: ReportFocus.flagged);

    scope
      ..retain(scope.container.listen(reportProvider(all), (_, _) {}))
      ..retain(scope.container.listen(reportProvider(flagged), (_, _) {}));

    await scope.container.read(reportProvider(all).future);
    await scope.container.read(reportProvider(flagged).future);

    // İki süzgeç de aynı okuma anahtarına düşer: Firestore bir kez okunur.
    expect(ReportQuery.of(all), ReportQuery.of(flagged));

    // Konumu doğrulanmış tek okutma var; "konum uyarısı" süzgeci boş döner.
    final ReportResult onlyFlagged = await scope.container.read(
      reportProvider(flagged).future,
    );
    expect(onlyFlagged.rows, isEmpty);
  });

  test('okutma silinince rapor önbelleği tazelenir', () async {
    final PunchController controller = scope.container.read(
      punchControllerProvider.notifier,
    );

    await controller.submit('1');
    controller.reset();
    await controller.submit('2');
    await flush();

    final ReportFilter filter = ReportFilter.today();
    scope.retain(scope.container.listen(reportProvider(filter), (_, _) {}));

    final ReportResult before = await scope.container.read(
      reportProvider(filter).future,
    );
    expect(before.rows.single.days.single.exitCount, 1);

    final List<AttendanceEvent> events = scope.container
        .read(myTodayEventsProvider)
        .requireValue;
    final AttendanceEvent exit = events.firstWhere(
      (AttendanceEvent e) => e.type == PunchType.exit,
    );

    await scope.container
        .read(attendanceAdminControllerProvider.notifier)
        .deleteEvent(exit);
    await flush();

    // Rapor okuması oturum boyunca önbelleklidir; silme onu geçersiz kılmasa
    // ekranda silinmiş bir çıkış yaşamaya devam ederdi.
    final ReportResult after = await scope.container.read(
      reportProvider(filter).future,
    );
    expect(after.rows.single.days.single.exitCount, 0);
  });

  test('dün çıkış unutulmuşsa bugünkü giriş etkilenmez', () async {
    final String yesterday = AppDate.dateKey(
      DateTime.now().subtract(const Duration(days: 1)),
    );

    // Dün girişi var, çıkışı yok: gün açık kalmış.
    await seedDay(
      scope,
      userId: TestData.staffUid,
      dateKey: yesterday,
      exitAt: null,
    );

    // Bugün normal giriş.
    await scope.container.read(punchControllerProvider.notifier).submit('1');
    final PunchState state = scope.container.read(punchControllerProvider);
    expect(state, isA<PunchSuccess>(), reason: _describe(state));

    await flush();

    // Bugünün özeti temiz başlar: dünün açık günü buraya sızmaz.
    final AttendanceDay today = scope.container
        .read(myTodayProvider)
        .requireValue;
    expect(today.dateKey, AppDate.todayKey());
    expect(today.entryCount, 1);
    expect(today.exitCount, 0);
    expect(today.workedMinutes, 0);

    // Dünün kaydı olduğu gibi durur: uygulama bir çıkış uydurmaz.
    final ({String userId, ReportFilter filter}) args = (
      userId: TestData.staffUid,
      filter: ReportFilter.lastDays(2),
    );
    // Riverpod 3'te dinleyicisi olmayan sağlayıcı okuma sırasında atılır ve
    // future asla tamamlanmaz; akış test boyunca canlı tutulur.
    scope.retain(scope.container.listen(personDaysProvider(args), (_, _) {}));

    final List<AttendanceDay> days = await scope.container.read(
      personDaysProvider(args).future,
    );

    final AttendanceDay past = days.firstWhere(
      (AttendanceDay d) => d.dateKey == yesterday,
    );
    expect(past.open, isTrue);
    expect(past.exitCount, 0);
    expect(past.workedMinutes, 0);
    expect(past.statusAt(DateTime.now()), DayStatus.missingExit);

    // Ve o gün için süre uydurulmaz — sayaç durmuştur.
    expect(past.workedMinutesAt(DateTime.now()), 0);
  });

  test('tanımsız kod reddedilir', () async {
    await scope.container.read(punchControllerProvider.notifier).submit('999');

    final PunchState state = scope.container.read(punchControllerProvider);
    expect(state, isA<PunchFailed>());
    expect((state as PunchFailed).failure, isA<PunchFailure>());
    expect(state.failure.message, contains('tanımlı değil'));
  });

  test('başka bir sistemin QR içeriği reddedilir', () async {
    await scope.container
        .read(punchControllerProvider.notifier)
        .submit('https://baska-uygulama.com/kapi');

    final PunchState state = scope.container.read(punchControllerProvider);
    expect(state, isA<PunchFailed>());
    expect((state as PunchFailed).failure.code, 'invalid-format');
  });

  test('uzaktan okutma kaydedilir ama işaretlenir', () async {
    scope.location.location = TestData.locationNorthOf(4000, accuracy: 20);

    await scope.container.read(punchControllerProvider.notifier).submit('1');

    final PunchState state = scope.container.read(punchControllerProvider);
    expect(state, isA<PunchSuccess>(), reason: _describe(state));
    expect((state as PunchSuccess).event.verdict, LocationVerdict.outside);

    await flush();
    final AttendanceDay day = scope.container
        .read(myTodayProvider)
        .requireValue;
    expect(day.worstVerdict, LocationVerdict.outside);
    expect(day.worstVerdict.needsAttention, isTrue);
  });

  test('konum alınamazsa okutma reddedilir (varsayılan ayar)', () async {
    scope.location.location = null;

    await scope.container.read(punchControllerProvider.notifier).submit('1');

    final PunchState state = scope.container.read(punchControllerProvider);
    expect(state, isA<PunchFailed>());
    expect((state as PunchFailed).failure, isA<LocationFailure>());
  });

  test('konum zorunlu değilse ölçümsüz okutma kabul edilir', () async {
    final TestScope relaxed = await buildScope(
      signedInAs: TestData.user(),
      tenant: TestData.tenant(
        settings: const TenantSettings(requireLocation: false),
      ),
      checkpoints: checkpoints,
    );
    addTearDown(relaxed.dispose);
    await waitForSession(relaxed);

    await relaxed.container.read(punchControllerProvider.notifier).submit('1');

    final PunchState state = relaxed.container.read(punchControllerProvider);
    expect(state, isA<PunchSuccess>(), reason: _describe(state));
    expect((state as PunchSuccess).event.verdict, LocationVerdict.unavailable);
  });

  test('aboneliği bitmiş müşteride okutma yapılamaz', () async {
    final TestScope expired = await buildScope(
      signedInAs: TestData.user(role: UserRole.admin, uid: TestData.adminUid),
      tenant: TestData.tenant(
        expiresAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      checkpoints: checkpoints,
      location: TestData.locationNorthOf(10),
    );
    addTearDown(expired.dispose);

    // Yönetici salt okunur olarak girebilir; personelin oturumu hiç açılmaz.
    await expired.container.read(sessionProvider.future);

    await expired.container.read(punchControllerProvider.notifier).submit('1');

    final PunchState state = expired.container.read(punchControllerProvider);
    expect(state, isA<PunchFailed>());
    expect((state as PunchFailed).failure, isA<SubscriptionFailure>());
  });

  test('askıya alınmış müşteride okutma yapılamaz', () async {
    final TestScope suspended = await buildScope(
      signedInAs: TestData.user(role: UserRole.admin, uid: TestData.adminUid),
      tenant: TestData.tenant(status: TenantStatus.suspended),
      checkpoints: checkpoints,
      location: TestData.locationNorthOf(10),
    );
    addTearDown(suspended.dispose);
    await suspended.container.read(sessionProvider.future);

    await suspended.container
        .read(punchControllerProvider.notifier)
        .submit('1');

    expect(
      suspended.container.read(punchControllerProvider),
      isA<PunchFailed>(),
    );
  });

  test('pasif nokta okutulamaz', () async {
    final TestScope disabled = await buildScope(
      signedInAs: TestData.user(),
      checkpoints: <Checkpoint>[TestData.checkpoint(active: false)],
      location: TestData.locationNorthOf(10),
    );
    addTearDown(disabled.dispose);
    await waitForSession(disabled);

    await disabled.container.read(punchControllerProvider.notifier).submit('1');

    final PunchState state = disabled.container.read(punchControllerProvider);
    expect(state, isA<PunchFailed>());
    expect((state as PunchFailed).failure.message, contains('devre dışı'));
  });

  test('yönetici yanlış okutmayı silince gün yeniden hesaplanır', () async {
    final TestScope admin = await buildScope(
      signedInAs: TestData.user(
        uid: TestData.adminUid,
        name: 'Mustafa Özdemir',
        role: UserRole.admin,
      ),
      checkpoints: checkpoints,
      location: TestData.locationNorthOf(10),
    );
    addTearDown(admin.dispose);
    await waitForSession(admin);

    final PunchController controller = admin.container.read(
      punchControllerProvider.notifier,
    );
    await controller.submit('1');
    controller.reset();
    await controller.submit('2');

    await flush();
    AttendanceDay day = admin.container.read(myTodayProvider).requireValue;
    expect(day.exitCount, 1);

    final List<AttendanceEvent> events = admin.container
        .read(myTodayEventsProvider)
        .requireValue;
    final AttendanceEvent exit = events.firstWhere(
      (AttendanceEvent event) => event.type.isExit,
    );

    await admin.container
        .read(attendanceAdminControllerProvider.notifier)
        .deleteEvent(exit);

    await flush();
    day = admin.container.read(myTodayProvider).requireValue;
    expect(day.exitCount, 0);
    expect(day.open, isTrue, reason: 'çıkış silinince gün yeniden açılmalı');
    expect(day.workedMinutes, 0);
  });

  test('çift yönlü nokta gidiş-gelişi kendisi çözer', () async {
    final TestScope both = await buildScope(
      signedInAs: TestData.user(),
      checkpoints: <Checkpoint>[
        TestData.checkpoint(
          id: 'cp-both',
          code: '5',
          name: 'Turnike',
          kind: CheckpointKind.both,
        ),
      ],
      location: TestData.locationNorthOf(10),
    );
    addTearDown(both.dispose);
    await waitForSession(both);

    final PunchController controller = both.container.read(
      punchControllerProvider.notifier,
    );

    await controller.submit('5');
    expect(
      (both.container.read(punchControllerProvider) as PunchSuccess).event.type,
      PunchType.entry,
    );

    controller.reset();
    await controller.submit('5');
    expect(
      (both.container.read(punchControllerProvider) as PunchSuccess).event.type,
      PunchType.exit,
    );
  });
}

/// Başarısız bir durumu okunur hâle getirir.
///
/// Test çıktısı yalnız "beklenen tip gelmedi" demekle kalmasın, reddin
/// sebebini de yazsın.
String _describe(PunchState state) => switch (state) {
  PunchFailed(:final Failure failure) => 'Reddedildi: ${failure.message}',
  PunchWorking(:final String message) => 'Hâlâ çalışıyor: $message',
  _ => state.runtimeType.toString(),
};
