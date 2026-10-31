import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubsoft_pdks/data/repositories/tenant_repository_impl.dart';

void main() {
  test(
    'yurt silindiğinde durum ve izin alt koleksiyonları yetim kalmaz',
    () async {
      final db = FakeFirebaseFirestore();
      final tenant = db.collection('tenants').doc('dorm');
      await tenant.set({'name': 'Test Yurdu'});
      const collections = [
        'users',
        'roleDefaults',
        'checkpoints',
        'qrIndex',
        'attendance',
        'attendanceDays',
        'presence',
        'presenceAudit',
        'leaves',
        'leaveLocks',
      ];
      for (final c in collections) {
        await tenant.collection(c).doc('record').set({'value': 'test'});
      }
      final result = await TenantRepositoryImpl(db).deleteTenant('dorm');
      expect(result.isOk, true);
      expect((await tenant.get()).exists, false);
      for (final c in collections) {
        expect((await tenant.collection(c).get()).docs, isEmpty, reason: c);
      }
    },
  );
}
