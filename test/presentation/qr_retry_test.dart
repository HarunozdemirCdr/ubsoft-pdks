import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:ubsoft_pdks/application/attendance/punch_controller.dart';
import 'package:ubsoft_pdks/core/error/failure.dart';
import 'package:ubsoft_pdks/presentation/features/punch/scan_page.dart';
import 'package:ubsoft_pdks/presentation/features/punch/widgets/punch_result_view.dart';
import 'package:ubsoft_pdks/services/qr/qr_scanner_service.dart';
import '../support/test_harness.dart';

void main() {
  Future<void> panel(
    WidgetTester tester,
    Failure failure,
    VoidCallback again,
  ) async {
    final scope = await buildScope();
    addTearDown(scope.dispose);
    await tester.pumpWidget(
      wrapPage(
        Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: PunchResultView(
              state: PunchState.failed(failure),
              onAgain: again,
              onClose: () {},
              autoRetryAfter: const Duration(seconds: 5),
            ),
          ),
        ),
        container: scope.container,
      ),
    );
    await tester.pump();
  }

  testWidgets(
    'hata paneli beş saniye sonra aynı ekranda yeniden taramaya döner',
    (tester) async {
      int retries = 0;
      await panel(
        tester,
        const PunchFailure('Yanlış QR', code: 'invalid-format'),
        () => retries++,
      );
      expect(find.text('5 saniye sonra yeniden taranacak.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      expect(retries, 0);
      await tester.pump(const Duration(seconds: 1));
      expect(retries, 1);
      await tester.pump(const Duration(seconds: 8));
      expect(retries, 1);
    },
  );
  testWidgets('elle tekrar deneme otomatik sayacı iptal eder', (tester) async {
    int retries = 0;
    await panel(tester, const NetworkFailure(), () => retries++);
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.text('Tekrar dene'));
    await tester.pump();
    expect(retries, 1);
    await tester.pump(const Duration(seconds: 6));
    expect(retries, 1);
  });
  testWidgets('ekran kapanınca otomatik yeniden tarama yapılmaz', (
    tester,
  ) async {
    int retries = 0;
    await panel(tester, const NetworkFailure(), () => retries++);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 6));
    expect(retries, 0);
  });
  for (final error in <Failure>[
    const AuthFailure('Giriş yapın'),
    const PermissionFailure(),
    const SubscriptionFailure('Hesap kapalı'),
    const PunchFailure('Biraz bekleyin', code: 'too-soon'),
  ]) {
    testWidgets(
      '${error.runtimeType} kullanıcı müdahalesi gerektiriyorsa otomatik tekrarlanmaz',
      (tester) async {
        int retries = 0;
        await panel(tester, error, () => retries++);
        await tester.pump(const Duration(seconds: 6));
        expect(retries, 0);
        expect(find.text('Tekrar dene'), findsOneWidget);
      },
    );
  }
  testWidgets('aynı hatalı sayısal QR elle anında yeniden denenebilir', (
    tester,
  ) async {
    await initTestLocale();
    final scope = await buildScope(signedInAs: TestData.user());
    addTearDown(scope.dispose);
    final camera = MobileScannerController(autoStart: false);
    addTearDown(camera.dispose);
    await tester.pumpWidget(
      wrapPage(
        ProviderScope(
          overrides: [qrControllerProvider.overrideWithValue(camera)],
          child: const ScanPage(),
        ),
        container: scope.container,
      ),
    );
    await settle(tester);
    final detect = tester
        .widget<MobileScanner>(find.byType(MobileScanner))
        .onDetect!;
    const capture = BarcodeCapture(
      barcodes: [Barcode(rawValue: '999999')],
    );
    detect(capture);
    await settle(tester);
    expect(scope.container.read(punchControllerProvider), isA<PunchFailed>());
    await tester.tap(find.text('Tekrar dene'));
    await tester.pump();
    expect(scope.container.read(punchControllerProvider), isA<PunchIdle>());
    detect(capture);
    await settle(tester);
    expect(scope.container.read(punchControllerProvider), isA<PunchFailed>());
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
