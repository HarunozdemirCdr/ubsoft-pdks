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
