import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubsoft_pdks/application/user/user_providers.dart';
import 'package:ubsoft_pdks/domain/enums/user_role.dart';
import 'package:ubsoft_pdks/presentation/features/dorm/dorm_pages.dart';
import 'package:ubsoft_pdks/presentation/features/dorm/dorm_settings_page.dart';
import '../support/test_harness.dart';

void main() {
  for (final width in [360.0, 768.0, 1440.0]) {
    testWidgets('yurt ekranları $width pikselde taşmadan çizilir', (
      tester,
    ) async {
      await initTestLocale();
      tester.view.resetPhysicalSize();
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final scope = await buildScope(
        signedInAs: TestData.user(uid: TestData.adminUid, role: UserRole.admin),
        extraUsers: [
          TestData.user(name: 'Ayşe Nur Yılmaz Uzun Öğrenci Adı'),
          TestData.user(uid: 'student-2', name: 'Zeynep Demir'),
        ],
      );
      addTearDown(scope.dispose);
      scope.retain(scope.container.listen(usersProvider, (_, _) {}));
      await settle(tester);
      for (final page in const <Widget>[
        DormDashboardPage(),
        DormHistoryPage(),
        DormReportPage(),
        DormLeavePage(),
        DormSettingsPage(),
      ]) {
        await tester.pumpWidget(
          wrapPage(page, container: scope.container, size: Size(width, 900)),
        );
        await settle(tester);
        expect(
          tester.takeException(),
          isNull,
          reason: '${page.runtimeType} @ $width',
        );
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  }
  testWidgets(
    'öğrenci mesai yerine kalıcı durum ve kendi hareketlerini görür',
    (tester) async {
      await initTestLocale();
      final user = TestData.user(name: 'Ayşe Nur');
      final scope = await buildScope(signedInAs: user);
      addTearDown(scope.dispose);
      await settle(tester);
      await tester.pumpWidget(
        wrapPage(const StudentHomePage(), container: scope.container),
      );
      await settle(tester);
      expect(find.text('Başlangıç kaydı yok'), findsOneWidget);
      expect(find.text('Bugünkü hareketlerim'), findsOneWidget);
      expect(find.textContaining('çalışma'), findsNothing);
      expect(find.text('Tamamlandı'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
