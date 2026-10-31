import 'dart:io';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ubsoft_pdks/application/user/user_providers.dart';
import 'package:ubsoft_pdks/core/theme/app_colors.dart';
import 'package:ubsoft_pdks/core/utils/date_x.dart';
import 'package:ubsoft_pdks/domain/enums/punch_type.dart';
import 'package:ubsoft_pdks/domain/enums/user_role.dart';
import 'package:ubsoft_pdks/presentation/features/dorm/dorm_pages.dart';
import '../support/test_harness.dart';

void main() {
  setUpAll(() async {
    await initTestLocale();
    GoogleFonts.config.allowRuntimeFetching = false;
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    for (final item in [
      (FontWeight.w400, 'Regular'),
      (FontWeight.w600, 'SemiBold'),
      (FontWeight.w700, 'Bold'),
    ]) {
      final loader =
          FontLoader(
            GoogleFonts.plusJakartaSans(fontWeight: item.$1).fontFamily!,
          )..addFont(
            rootBundle.load('assets/fonts/PlusJakartaSans-${item.$2}.ttf'),
          );
      await loader.load();
    }
  });
  Future<TestScope> setup(WidgetTester tester) async {
    final scope = await buildScope(
      signedInAs: TestData.user(
        uid: TestData.adminUid,
        name: 'Yurt Yöneticisi',
        role: UserRole.admin,
      ),
      extraUsers: [
        TestData.user(
          uid: 'ayse',
          name: 'Ayşe Nur Yılmaz',
        ).copyWith(room: '204', studentNumber: '2026001'),
        TestData.user(
          uid: 'zeynep',
          name: 'Zeynep Demir',
        ).copyWith(room: '108'),
        TestData.user(uid: 'elif', name: 'Elif Kaya').copyWith(room: '204'),
      ],
    );
    addTearDown(scope.dispose);
    scope.retain(scope.container.listen(usersProvider, (_, _) {}));
    await scope.firestore
        .doc('tenants/${TestData.tenantId}/presence/ayse')
        .set({
          'userId': 'ayse',
          'inside': true,
          'at': Timestamp.fromDate(
            DateTime.now().subtract(const Duration(hours: 2)),
          ),
          'checkpoint': 'Ana Giriş',
        });
    await scope.firestore
        .doc('tenants/${TestData.tenantId}/presence/zeynep')
        .set({
          'userId': 'zeynep',
          'inside': false,
          'at': Timestamp.fromDate(
            DateTime.now().subtract(const Duration(days: 1)),
          ),
          'checkpoint': 'Ana Çıkış',
        });
    final day = AppDate.todayKey();
    for (final pair in [
      (PunchType.entry, '08:30'),
      (PunchType.exit, '16:45'),
    ]) {
      await seedEvent(
        scope,
        userId: 'ayse',
        userName: 'Ayşe Nur Yılmaz',
        dateKey: day,
        type: pair.$1,
        time: pair.$2,
      );
    }
    await settle(tester);
    return scope;
  }

  Future<void> capture(
    WidgetTester tester,
    GlobalKey boundary,
    String file,
  ) async {
    await tester.runAsync(() async {
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await render.toImage(pixelRatio: 1.5);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory('build/ui-previews').create(recursive: true);
      await File(
        'build/ui-previews/$file',
      ).writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final width in [320.0, 360.0, 390.0, 768.0, 1440.0]) {
    testWidgets('panel kartları $width genişliğinde eşit ve dengelidir', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final scope = await setup(tester);
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: wrapPage(
            const DormDashboardPage(),
            container: scope.container,
            size: Size(width, 1000),
          ),
        ),
      );
      await settle(tester);
      final sizes = [
        for (final label in [
          'Toplam öğrenci',
          'İçeride',
          'Dışarıda',
          'Dönüşü geciken',
        ])
          tester.getSize(find.byKey(ValueKey('metric-$label'))),
      ];
      for (final size in sizes) {
        expect(size, sizes.first);
      }
      expect(find.text('Dönüş yapmadı'), findsNothing);
      expect(find.textContaining('başlangıç kaydı yok'), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (width == 390 || width == 1440) {
        await capture(tester, boundary, 'dashboard-${width.toInt()}.png');
      }
      await tester.tap(find.byKey(const ValueKey('metric-Dönüşü geciken')));
      await settle(tester);
      expect(find.text('Zeynep Demir'), findsOneWidget);
      expect(find.text('Ayşe Nur Yılmaz'), findsNothing);
      expect(find.text('Elif Kaya'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'rapor öğrenci ve gün açıldığında renkli giriş çıkışları gösterir',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final scope = await setup(tester);
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: wrapPage(
            const DormReportPage(),
            container: scope.container,
            size: const Size(390, 1000),
          ),
        ),
      );
      await settle(tester);
      expect(find.text('Tüm hareketler'), findsOneWidget);
      final student = find.byKey(const ValueKey('student-group-ayse'));
      await tester.ensureVisible(student);
      await tester.tap(student);
      await settle(tester);
      final day = find.byKey(ValueKey('day-group-ayse-${AppDate.todayKey()}'));
      await tester.ensureVisible(day);
      await tester.tap(day);
      await settle(tester);
      expect(find.text('08:30'), findsNWidgets(2));
      expect(find.text('16:45'), findsNWidgets(2));
      for (final text in tester.widgetList<Text>(find.text('08:30'))) {
        expect(text.style!.color, AppColors.entry);
      }
      for (final text in tester.widgetList<Text>(find.text('16:45'))) {
        expect(text.style!.color, AppColors.exit);
      }
      expect(tester.takeException(), isNull);
      await capture(tester, boundary, 'report-expanded-390.png');
    },
  );
  testWidgets('büyütülmüş metinde metrik kartları taşmaz', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final scope = await setup(tester);
    await tester.pumpWidget(
      wrapPage(
        const DormDashboardPage(),
        container: scope.container,
        size: const Size(360, 1000),
        textScale: 1.5,
      ),
    );
    await settle(tester);
    expect(tester.takeException(), isNull);
  });
}
