import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubsoft_pdks/domain/enums/user_role.dart';
import 'package:ubsoft_pdks/presentation/features/dorm/dorm_pages.dart';
import 'package:ubsoft_pdks/presentation/features/dorm/widgets/dorm_ui.dart';
import 'package:ubsoft_pdks/presentation/shell/app_shell.dart';
import '../support/test_harness.dart';

void main() {
  for (final page in [
    const DormHistoryPage(),
    const DormReportPage(),
    const StudentHomePage(),
  ]) {
    testWidgets(
      '${page.runtimeType} ilk açılışta boş sonuç yüklemeyi bitirir',
      (tester) async {
        await initTestLocale();
        final scope = await buildScope(
          signedInAs: TestData.user(
            uid: page is StudentHomePage
                ? TestData.staffUid
                : TestData.adminUid,
            role: page is StudentHomePage ? UserRole.staff : UserRole.admin,
          ),
        );
        addTearDown(scope.dispose);
        await tester.pumpWidget(wrapPage(page, container: scope.container));
        await settle(tester);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(
          find.text(
            page is StudentHomePage
                ? 'Henüz hareket yok'
                : 'Bu aralıkta hareket yok',
          ),
          findsOneWidget,
        );
      },
    );
  }
  for (final width in [320.0, 360.0, 390.0]) {
    testWidgets(
      '$width pikselde alt menünün bütün harfleri ekran içinde kalır',
      (tester) async {
        await initTestLocale();
        await tester.binding.setSurfaceSize(Size(width, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final scope = await buildScope(
          signedInAs: TestData.user(
            uid: TestData.adminUid,
            role: UserRole.admin,
          ),
        );
        addTearDown(scope.dispose);
        await settle(tester);
        await tester.pumpWidget(
          wrapRouted(
            const AppShell(child: SizedBox.shrink()),
            container: scope.container,
            size: Size(width, 844),
          ),
        );
        await settle(tester);
        final label = tester.renderObject<RenderParagraph>(
          find.text('Yurt Durumu'),
        );
        final bar = tester.getRect(find.byType(NavigationBar));
        final boxes = label.getBoxesForSelection(
          const TextSelection(baseOffset: 0, extentOffset: 11),
        );
        expect(boxes, isNotEmpty);
        for (final box in boxes) {
          final rect = box.toRect().shift(label.localToGlobal(Offset.zero));
          expect(rect.left, greaterThanOrEqualTo(bar.left));
          expect(rect.right, lessThanOrEqualTo(bar.right));
          expect(rect.top, greaterThanOrEqualTo(bar.top));
          expect(rect.bottom, lessThanOrEqualTo(bar.bottom));
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('tarih etiketi kutunun üzerinde ayrı ve tam görünür', (
    tester,
  ) async {
    await initTestLocale();
    final scope = await buildScope(
      signedInAs: TestData.user(uid: TestData.adminUid, role: UserRole.admin),
    );
    addTearDown(scope.dispose);
    await tester.pumpWidget(
      wrapPage(const DormHistoryPage(), container: scope.container),
    );
    await settle(tester);
    final field = find.byType(DormActionField).first;
    final label = tester.getRect(
      find.descendant(of: field, matching: find.text('Tarih aralığı')),
    );
    final box = tester.getRect(
      find.descendant(of: field, matching: find.byType(InputDecorator)),
    );
    expect(label.bottom, lessThan(box.top));
  });
}
