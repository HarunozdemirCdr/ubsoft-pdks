import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubsoft_pdks/core/result/result.dart';
import 'package:ubsoft_pdks/data/repositories/dorm_repository.dart';
import 'package:ubsoft_pdks/domain/entities/attendance_event.dart';
import 'package:ubsoft_pdks/domain/entities/dormitory.dart';
import 'package:ubsoft_pdks/domain/enums/punch_type.dart';
import 'package:ubsoft_pdks/domain/usecases/attendance/verify_location.dart';
import '../support/test_harness.dart';

void main() {
  late TestScope scope;
  late DormRepository repo;
  setUp(() async {
    await initTestLocale();
    scope = await buildScope(
      signedInAs: TestData.user(),
      checkpoints: [
        TestData.checkpoint(),
        TestData.checkpoint(id: 'cp-out', code: '2', kind: CheckpointKind.exit),
      ],
    );
    repo = DormRepository(scope.firestore);
  });
  tearDown(() => scope.dispose());
  Future<Result<AttendanceEvent>> punch({required bool entry}) async {
    final cp = entry
        ? TestData.checkpoint()
        : TestData.checkpoint(
            id: 'cp-out',
            code: '2',
            kind: CheckpointKind.exit,
          );
    return repo.record(
      tenant: TestData.tenant(),
      user: TestData.user(),
      checkpoint: cp,
      check: VerifyLocation.call(
        checkpoint: cp,
        location: TestData.locationNorthOf(10),
      ),
      location: TestData.locationNorthOf(10),
      cooldown: Duration.zero,
    );
  }

  test(
    'dünün girişi bugünkü çıkışa izin verir, durum günlük sıfırlanmaz',
    () async {
      final user = TestData.user();
      await scope.firestore
          .doc('tenants/${user.tenantId}/presence/${user.uid}')
          .set({
            'userId': user.uid,
            'inside': true,
            'revision': 1,
            'at': Timestamp.fromDate(
              DateTime.now().subtract(const Duration(days: 1)),
            ),
          });
      final result = await punch(entry: false);
      expect(result.isOk, true);
      expect(result.valueOrNull!.type, PunchType.exit);
      await flush();
      final state = await repo.watchPresence(user.tenantId, user.uid).first;
      expect(state.inside, false);
    },
  );
  test('çoklu giriş çıkış tüm hareketleri ayrı kaydeder', () async {
    expect((await punch(entry: true)).isOk, true);
    expect((await punch(entry: false)).isOk, true);
    expect((await punch(entry: true)).isOk, true);
    expect((await punch(entry: false)).isOk, true);
    expect(
      (await scope.firestore
              .collection('tenants/${TestData.tenantId}/attendance')
              .get())
          .docs
          .length,
      4,
    );
  });
  test('aynı yöndeki ikinci hareket transaction içinde reddedilir', () async {
    expect((await punch(entry: true)).isOk, true);
    expect((await punch(entry: true)).isErr, true);
  });
  test(
    'ilk hareket çıkış olabilir; bilinmeyen durum içeride varsayılmaz',
    () async {
      expect((await punch(entry: false)).isOk, true);
    },
  );
  test('izin kaydı durumu değiştirmez, iptal geçmişte korunur', () async {
    final user = TestData.user();
    final now = DateTime.now();
    final result = await repo.saveLeave(
      user.tenantId,
      StudentLeave(
        userId: user.uid,
        from: now,
        until: now.add(const Duration(days: 1)),
        reason: 'Aile ziyareti',
      ),
      'admin-1',
    );
    expect(result.isOk, true);
    expect(
      (await repo.watchPresence(user.tenantId, user.uid).first).inside,
      isNull,
    );
    final leave = (await repo.watchLeaves(user.tenantId).first).single;
    expect(
      (await repo.revokeLeave(user.tenantId, leave, 'admin-1')).isOk,
      true,
    );
    expect((await repo.watchLeaves(user.tenantId).first).single.revoked, true);
  });
  test('çakışan izin reddedilir', () async {
    final now = DateTime.now();
    final leave = StudentLeave(
      userId: 'staff-1',
      from: now,
      until: now.add(const Duration(days: 1)),
      reason: 'İzin',
    );
    expect(
      (await repo.saveLeave(TestData.tenantId, leave, 'admin-1')).isOk,
      true,
    );
    expect(
      (await repo.saveLeave(TestData.tenantId, leave, 'admin-1')).isErr,
      true,
    );
  });
  test(
    'yanlış hareket gerekçeyle geçersiz kılınır, asıl kayıt korunur',
    () async {
      final entered = (await punch(entry: true) as Ok<AttendanceEvent>).value;
      final exited = (await punch(entry: false) as Ok<AttendanceEvent>).value;
      final user = TestData.user();
      expect(
        (await repo.voidEvent(
          TestData.tenant(),
          exited,
          'admin-1',
          'Yanlış QR okutuldu',
        )).isOk,
        true,
      );
      final raw = await scope.firestore
          .doc('tenants/${user.tenantId}/attendance/${exited.id}')
          .get();
      expect(raw.data()?['voided'], true);
      expect(raw.data()?['voidReason'], 'Yanlış QR okutuldu');
      final state = await repo.watchPresence(user.tenantId, user.uid).first;
      expect(state.inside, true);
      expect(state.eventId, entered.id);
    },
  );
}
