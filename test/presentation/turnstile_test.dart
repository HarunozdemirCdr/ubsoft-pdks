import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubsoft_pdks/application/turnstile/turnstile_providers.dart';
import 'package:ubsoft_pdks/domain/entities/attendance_event.dart';
import 'package:ubsoft_pdks/domain/enums/location_verdict.dart';
import 'package:ubsoft_pdks/domain/enums/punch_type.dart';
import 'package:ubsoft_pdks/domain/enums/user_role.dart';
import 'package:ubsoft_pdks/presentation/features/turnstile/turnstile_feedback.dart';
import 'package:ubsoft_pdks/presentation/features/turnstile/turnstile_page.dart';
import '../support/test_harness.dart';

void main() {
  setUpAll(initTestLocale);
  testWidgets(
    'eight relay selectors fit a 360px phone and keep the supplied pin order',
    (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final scope = await buildScope(
        signedInAs: TestData.user(uid: TestData.adminUid, role: UserRole.admin),
        checkpoints: [TestData.checkpoint()],
      );
      addTearDown(scope.dispose);
      await scope.firestore
          .doc('tenants/${TestData.tenantId}/turnstileState/controller')
          .set({
            'paired': true,
            'enabled': true,
            'deviceId': 'a' * 32,
            'relays': <String, String>{},
          });
      await tester.pumpWidget(
        wrapPage(const TurnstilePage(), container: scope.container),
      );
      await settle(tester);
      expect(find.byType(DropdownButtonFormField<String>), findsNWidgets(8));
      expect(relayPins, [26, 27, 25, 32, 14, 12, 13, 15]);
      await tester.ensureVisible(find.text('Röle 8 · GPIO 15'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('a student cannot bind a board', (tester) async {
    final scope = await buildScope(signedInAs: TestData.user());
    addTearDown(scope.dispose);
    await tester.pumpWidget(
      wrapPage(const TurnstilePage(), container: scope.container),
    );
    await settle(tester);
    expect(find.text('Bu bölümü yurt yöneticisi yönetir.'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });
  testWidgets(
    'relay acknowledgement timeout is bounded and a later ack still updates the result',
    (tester) async {
      final scope = await buildScope(signedInAs: TestData.user());
      addTearDown(scope.dispose);
      final event = AttendanceEvent(
        id: 'event',
        tenantId: TestData.tenantId,
        userId: TestData.staffUid,
        userName: 'Öğrenci',
        type: PunchType.entry,
        at: DateTime.now(),
        dateKey: '2026-11-01',
        checkpointId: 'cp-in',
        checkpointName: 'Giriş',
        checkpointCode: '1',
        verdict: LocationVerdict.verified,
      );
      await scope.firestore
          .doc('tenants/${TestData.tenantId}/turnstileState/controller')
          .set({
            'paired': true,
            'relays': {'8': event.checkpointId},
          });
      final record = scope.firestore.doc(
        'tenants/${event.tenantId}/attendance/${event.id}',
      );
      await record.set({
        'turnstile': {'status': 'queued'},
      });
      await tester.pumpWidget(
        wrapPage(TurnstileFeedback(event: event), container: scope.container),
      );
      await settle(tester);
      expect(find.textContaining('yanıtı bekleniyor'), findsOneWidget);
      await tester.pump(const Duration(seconds: 13));
      expect(find.textContaining('görevliye başvurun'), findsOneWidget);
      await record.set({
        'turnstile': {'status': 'pulse_started'},
      });
      await settle(tester);
      expect(find.textContaining('Röle tetiklendi'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
