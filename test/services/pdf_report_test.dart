import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ubsoft_pdks/application/report/report_providers.dart';
import 'package:ubsoft_pdks/domain/entities/app_user.dart';
import 'package:ubsoft_pdks/domain/entities/attendance_day.dart';
import 'package:ubsoft_pdks/domain/entities/report_filter.dart';
import 'package:ubsoft_pdks/domain/enums/report_focus.dart';
import 'package:ubsoft_pdks/services/export/pdf_report_service.dart';

import '../support/test_harness.dart';

/// PDF raporunun gerçekten üretilebildiğini gösterir.
///
/// Bu testin asıl işi biçim denetlemek değil, **fontları** korumaktır:
/// gömülü font dosyalarının adı değiştiğinde ya da `pubspec.yaml`'daki
/// varlık tanımı düştüğünde rapor üretimi çalışma anında patlar ve bu,
/// `analyze` ile `test`in geri kalanında hiç görünmez.
void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    return initTestLocale();
  });

  AttendanceDay day(String dateKey, {bool late = false, bool open = false}) =>
      AttendanceDay(
        id: AttendanceDay.buildId(userId: 'u1', dateKey: dateKey),
        tenantId: TestData.tenantId,
        userId: 'u1',
        userName: 'Ahmet Yılmaz',
        dateKey: dateKey,
        firstEntryAt: DateTime.parse('${dateKey}T08:30:00'),
        lastEntryAt: DateTime.parse('${dateKey}T08:30:00'),
        lastExitAt: open ? null : DateTime.parse('${dateKey}T17:30:00'),
        entryCount: 1,
        exitCount: open ? 0 : 1,
        workedMinutes: open ? 0 : 480,
        open: open,
        late: late,
      );

  ReportResult report({ReportFocus focus = ReportFocus.all}) => buildReport(
    filter: ReportFilter(
      from: DateTime(2026, 8, 24),
      to: DateTime(2026, 8, 26),
      focus: focus,
    ),
    days: <AttendanceDay>[
      day('2026-08-24'),
      day('2026-08-25', late: true),
      day('2026-08-26', open: true),
    ],
    roster: <AppUser>[TestData.user(uid: 'u1', note: 'Oda / öğrenim notu')],
    now: DateTime(2026, 8, 27, 10),
  );

  test('rapor gerçek bir PDF üretir', () async {
    final Uint8List bytes = await PdfReportService.build(
      report: report(),
      companyName: 'Beyaz Yapı A.Ş.',
    );

    expect(bytes.length, greaterThan(1000));
    expect(ascii.decode(bytes.sublist(0, 4)), '%PDF');
  });

  test('süzgeçli rapor da üretilebilir', () async {
    final ReportResult filtered = report(focus: ReportFocus.lateArrival);

    expect(filtered.rows.single.matchedDays, 1);
    expect(
      (await PdfReportService.build(
        report: filtered,
        companyName: 'Beyaz Yapı',
      )).length,
      greaterThan(1000),
    );
  });

  test('boş rapor hata vermeden üretilir', () async {
    final ReportResult empty = buildReport(
      filter: ReportFilter(
        from: DateTime(2026, 8, 24),
        to: DateTime(2026, 8, 24),
      ),
      days: const <AttendanceDay>[],
      roster: const <AppUser>[],
    );

    expect(empty.isEmpty, isTrue);
    expect(
      (await PdfReportService.build(
        report: empty,
        companyName: 'Beyaz Yapı',
      )).length,
      greaterThan(500),
    );
  });

  test('dosya adı yurt ve aralıktan üretilir', () {
    final String name = PdfReportService.fileName(
      'Beyaz Yapı A.Ş.',
      ReportFilter(from: DateTime(2026, 8, 24), to: DateTime(2026, 8, 26)),
    );

    expect(name, 'devam-raporu-beyaz-yapi-a-s-2026-08-24_2026-08-26.pdf');
  });
}
