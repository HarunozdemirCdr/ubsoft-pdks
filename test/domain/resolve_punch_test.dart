import 'package:flutter_test/flutter_test.dart';
import 'package:ubsoft_pdks/core/error/failure.dart';
import 'package:ubsoft_pdks/domain/entities/attendance_day.dart';
import 'package:ubsoft_pdks/domain/entities/tenant.dart';
import 'package:ubsoft_pdks/domain/enums/location_verdict.dart';
import 'package:ubsoft_pdks/domain/enums/punch_type.dart';
import 'package:ubsoft_pdks/domain/usecases/attendance/resolve_punch.dart';
import 'package:ubsoft_pdks/domain/usecases/attendance/verify_location.dart';

import '../support/test_harness.dart';

AttendanceDay _day({bool open = false}) {
  final AttendanceDay base = AttendanceDay.empty(
    tenantId: TestData.tenantId,
    userId: TestData.staffUid,
    userName: 'Ahmet Yılmaz',
    dateKey: '2026-08-27',
  );
  if (!open) return base;
  return base.copyWith(
    open: true,
    entryCount: 1,
    firstEntryAt: DateTime(2026, 8, 27, 8, 30),
    lastEntryAt: DateTime(2026, 8, 27, 8, 30),
  );
}

const LocationCheck _verified = LocationCheck(
  verdict: LocationVerdict.verified,
  distanceMeters: 12,
  radiusMeters: 75,
);

const LocationCheck _outside = LocationCheck(
  verdict: LocationVerdict.outside,
  distanceMeters: 4200,
  radiusMeters: 75,
);

const LocationCheck _unavailable = LocationCheck.unavailable();

void main() {
  group('ResolvePunch — yön çözümü', () {
    test('giriş noktası her zaman giriş yazar', () {
      expect(
        ResolvePunch.resolveType(kind: CheckpointKind.entry, isInside: true),
        PunchType.entry,
      );
      expect(
        ResolvePunch.resolveType(kind: CheckpointKind.entry, isInside: false),
        PunchType.entry,
      );
    });

    test('çıkış noktası her zaman çıkış yazar', () {
      expect(
        ResolvePunch.resolveType(kind: CheckpointKind.exit, isInside: false),
        PunchType.exit,
      );
    });

    test('çift yönlü nokta kişinin durumuna bakar', () {
      expect(
        ResolvePunch.resolveType(kind: CheckpointKind.both, isInside: false),
        PunchType.entry,
      );
      expect(
        ResolvePunch.resolveType(kind: CheckpointKind.both, isInside: true),
        PunchType.exit,
      );
    });
  });

  group('ResolvePunch — kabul ve ret', () {
    const TenantSettings settings = TenantSettings();

    test('dışarıdayken giriş kodu kabul edilir', () {
      final PunchResolution result = ResolvePunch.call(
        checkpoint: TestData.checkpoint(),
        today: _day(),
        settings: settings,
        location: _verified,
      );

      expect(result, isA<PunchAccepted>());
      expect((result as PunchAccepted).type, PunchType.entry);
    });

    test('içerideyken çıkış kodu kabul edilir', () {
      final PunchResolution result = ResolvePunch.call(
        checkpoint: TestData.checkpoint(
          id: 'cp-out',
          code: '2',
          kind: CheckpointKind.exit,
        ),
        today: _day(open: true),
        settings: settings,
        location: _verified,
      );

      expect(result, isA<PunchAccepted>());
      expect((result as PunchAccepted).type, PunchType.exit);
    });

    test('üst üste iki giriş reddedilir', () {
      final PunchResolution result = ResolvePunch.call(
        checkpoint: TestData.checkpoint(),
        today: _day(open: true),
        settings: settings,
        location: _verified,
      );

      expect(result, isA<PunchRejected>());
      expect(result.failureOrNull, isA<PunchFailure>());
      expect(result.failureOrNull!.message, contains('Zaten giriş'));
    });

    test('açık giriş yokken çıkış reddedilir', () {
      final PunchResolution result = ResolvePunch.call(
        checkpoint: TestData.checkpoint(kind: CheckpointKind.exit),
        today: _day(),
        settings: settings,
        location: _verified,
      );

      expect(result, isA<PunchRejected>());
      expect(result.failureOrNull!.message, contains('Açık bir girişiniz yok'));
    });

    test('pasif nokta reddedilir', () {
      final PunchResolution result = ResolvePunch.call(
        checkpoint: TestData.checkpoint(active: false),
        today: _day(),
        settings: settings,
        location: _verified,
      );

      expect(result, isA<PunchRejected>());
      expect(result.failureOrNull!.message, contains('devre dışı'));
    });
  });

  /// Kazara ikinci okutma.
  ///
  /// Sahadan gelen şikâyet buydu: kod okunuyor, sonuç paneli çıkıyor,
  /// kullanıcı telefonu hâlâ etiketin önünde tutarken ikinci bir okutma
  /// gidiyor. En pahalı hâli giriş+çıkış noktasındadır — tek etiket iki iş
  /// gördüğü için kişi bir saniye arayla içeri alınıp dışarı çıkarılır ve o
  /// gün sıfır dakika çalışmış görünür. Kayıt sessizce yanlış olur.
  group('ResolvePunch — kazara ikinci okutma', () {
    // Testin kendi değeri. Varsayılanla (AppConfig.punchCooldown) aynı
    // olsaydı beklentiler yapılandırma sabitine bağlanır, sabit değişince
    // test sessizce başka bir şeyi ölçmeye başlardı.
    const Duration cooldown = Duration(seconds: 30);
    final DateTime punchedAt = DateTime(2026, 8, 27, 8, 30);

    AttendanceDay dayPunchedAt(DateTime at, {bool open = true}) =>
        AttendanceDay.empty(
          tenantId: TestData.tenantId,
          userId: TestData.staffUid,
          userName: 'Ahmet Yılmaz',
          dateKey: '2026-08-27',
        ).copyWith(
          open: open,
          entryCount: 1,
          firstEntryAt: at,
          lastEntryAt: at,
        );

    test('bekleme süresi dolmadan ikinci okutma reddedilir', () {
      final PunchResolution result = ResolvePunch.call(
        checkpoint: TestData.checkpoint(kind: CheckpointKind.both),
        today: dayPunchedAt(punchedAt),
        settings: const TenantSettings(),
        location: _verified,
        now: punchedAt.add(const Duration(seconds: 3)),
        cooldown: cooldown,
      );

      expect(result, isA<PunchRejected>());
      expect((result as PunchRejected).failure.code, 'too-soon');
    });

    test('reddin gerekçesi kişiyi paniğe sevk etmez', () {
      // "Zaten giriş yapmışsınız. Önce çıkış kodunu okutmalısınız." demek,
      // olmayan bir sorunu tarif eder: olan biten yalnızca kodun iki kez
      // okunmasıdır ve kayıt zaten alınmıştır. Bu yüzden bekleme denetimi
      // yön denetiminden ÖNCE gelir.
      final PunchResolution result = ResolvePunch.call(
        checkpoint: TestData.checkpoint(),
        today: dayPunchedAt(punchedAt),
        settings: const TenantSettings(),
        location: _verified,
        now: punchedAt.add(const Duration(seconds: 3)),
        cooldown: cooldown,
      );

      final String message = (result as PunchRejected).failure.message;
      expect(message, contains('Kaydınız alındı'));
      expect(message, isNot(contains('Zaten giriş yapmışsınız')));
    });

    test('süre dolduktan sonra normal kurallar işler', () {
      // Giriş+çıkış noktası: bir dakika sonra bu okutma gerçek bir çıkıştır.
      final PunchResolution result = ResolvePunch.call(
        checkpoint: TestData.checkpoint(kind: CheckpointKind.both),
        today: dayPunchedAt(punchedAt),
        settings: const TenantSettings(),
        location: _verified,
        now: punchedAt.add(const Duration(minutes: 2)),
        cooldown: cooldown,
      );

      expect(result, isA<PunchAccepted>());
      expect((result as PunchAccepted).type, PunchType.exit);
    });

    test('günün ilk okutması beklemeye takılmaz', () {
      final PunchResolution result = ResolvePunch.call(
        checkpoint: TestData.checkpoint(),
        today: _day(),
        settings: const TenantSettings(),
        location: _verified,
        now: punchedAt,
        cooldown: cooldown,
      );

      expect(result, isA<PunchAccepted>());
    });

    test('son okutma anı iki damgadan geç olanıdır', () {
      // Gün içinde giriş de çıkış da varsa, bekleme çıkıştan sayılmalı.
      final AttendanceDay day = dayPunchedAt(punchedAt, open: false).copyWith(
        exitCount: 1,
        lastExitAt: punchedAt.add(const Duration(hours: 4)),
      );

      expect(day.lastPunchAt, punchedAt.add(const Duration(hours: 4)));
    });
  });

  group('ResolvePunch — konum kuralları', () {
    test('konum zorunluyken ölçüm alınamazsa reddedilir', () {
      final PunchResolution result = ResolvePunch.call(
        checkpoint: TestData.checkpoint(),
        today: _day(),
        settings: const TenantSettings(),
        location: _unavailable,
      );

      expect(result, isA<PunchRejected>());
      expect(result.failureOrNull, isA<LocationFailure>());
    });

    test('konum zorunlu değilse ölçümsüz okutma kabul edilir', () {
      final PunchResolution result = ResolvePunch.call(
        checkpoint: TestData.checkpoint(),
        today: _day(),
        settings: const TenantSettings(requireLocation: false),
        location: _unavailable,
      );

      expect(result, isA<PunchAccepted>());
    });

    test('noktanın konumu yoksa zorunluluk uygulanmaz', () {
      // Aksi hâlde koordinatı girilmemiş bir nokta hiç kullanılamazdı.
      final PunchResolution result = ResolvePunch.call(
        checkpoint: TestData.checkpoint(latitude: 0, longitude: 0),
        today: _day(),
        settings: const TenantSettings(),
        location: _unavailable,
      );

      expect(result, isA<PunchAccepted>());
    });

    test('varsayılan ayarda uzaktan okutma KAYDEDİLİR, işaretlenir', () {
      // Reddetmek daha sıkı görünür ama hatalı bir GPS ölçümü yüzünden
      // reddedilen giriş, personeli o gün hiç gelmemiş gösterir.
      final PunchResolution result = ResolvePunch.call(
        checkpoint: TestData.checkpoint(),
        today: _day(),
        settings: const TenantSettings(),
        location: _outside,
      );

      expect(result, isA<PunchAccepted>());
      expect(
        (result as PunchAccepted).location.verdict,
        LocationVerdict.outside,
      );
    });

    test('engelleme açıkken uzaktan okutma reddedilir', () {
      final PunchResolution result = ResolvePunch.call(
        checkpoint: TestData.checkpoint(),
        today: _day(),
        settings: const TenantSettings(blockOutsideScans: true),
        location: _outside,
      );

      expect(result, isA<PunchRejected>());
      expect(result.failureOrNull!.message, contains('uzaktasınız'));
    });

    test('engelleme açıkken bile sınırdaki okutma kabul edilir', () {
      final PunchResolution result = ResolvePunch.call(
        checkpoint: TestData.checkpoint(),
        today: _day(),
        settings: const TenantSettings(blockOutsideScans: true),
        location: const LocationCheck(
          verdict: LocationVerdict.borderline,
          distanceMeters: 90,
          radiusMeters: 75,
        ),
      );

      expect(result, isA<PunchAccepted>());
    });
  });
}
