import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:ubsoft_pdks/core/utils/date_x.dart';
import 'package:ubsoft_pdks/domain/entities/app_user.dart';
import 'package:ubsoft_pdks/domain/entities/attendance_event.dart';
import 'package:ubsoft_pdks/domain/usecases/dorm/dorm_duration.dart';

abstract final class DormPdfService {
  static Future<Uint8List> build(
    String dorm,
    String range,
    List<AttendanceEvent> events, {
    Map<String, AppUser> usersById = const <String, AppUser>{},
  }) async {
    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/PlusJakartaSans-Regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/PlusJakartaSans-Bold.ttf'),
    );
    pw.MemoryImage? logo;
    try {
      final logoBytes = await rootBundle.load('assets/images/ubs_logo.png');
      logo = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (_) {
      logo = null;
    }
    final doc = pw.Document(title: 'Yurt giriş–çıkış raporu', author: dorm);
    final sorted = [...events]..sort((a, b) => b.at.compareTo(a.at));
    final byUser = <String, List<AttendanceEvent>>{};
    for (final e in events) {
      byUser.putIfAbsent(e.userId, () => <AttendanceEvent>[]).add(e);
    }
    Duration totalInside = Duration.zero;
    Duration totalOutside = Duration.zero;
    for (final entry in byUser.entries) {
      final s = DormDurationCalculator.summarize(entry.value, userId: entry.key);
      totalInside += s.insideDuration;
      totalOutside += s.outsideDuration;
    }
    doc.addPage(
      pw.MultiPage(
        maxPages: 500,
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
        footer: (c) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            '${c.pageNumber} / ${c.pagesCount}',
            style: const pw.TextStyle(fontSize: 8),
          ),
        ),
        build: (c) => [
          pw.Row(
            children: [
              if (logo != null) ...[
                pw.Image(logo, width: 108),
                pw.SizedBox(width: 14),
              ],
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(dorm, style: pw.TextStyle(font: bold, fontSize: 20)),
                    pw.Text('Öğrenci giriş–çıkış raporu · $range'),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            '${events.length} hareket · ${events.where((e) => e.lateMinutes > 0).length} geç giriş · ${events.where((e) => e.earlyExit).length} erken çıkış · İçeride: ${DormDurationCalculator.formatDuration(totalInside)} · Dışarıda: ${DormDurationCalculator.formatDuration(totalOutside)}',
          ),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: ['Öğrenci', 'Oda', 'Tarih / saat', 'İşlem', 'Nokta', 'Açıklama'],
            cellStyle: const pw.TextStyle(fontSize: 8),
            headerStyle: pw.TextStyle(font: bold, fontSize: 8),
            data: sorted
                .map(
                  (e) => [
                    e.userName,
                    usersById[e.userId]?.room ?? '',
                    AppDate.dateTime(e.at),
                    e.type.label,
                    e.checkpointName,
                    [
                      if (e.lateMinutes > 0) '${e.lateMinutes} dk geç',
                      if (e.earlyExit) 'Erken çıkış',
                      if (e.earlyEntry) 'Erken giriş',
                      if (e.permitted) 'İzinli',
                      if (e.verdict.needsAttention) e.verdict.label,
                    ].join(', '),
                  ],
                )
                .toList(),
          ),
        ],
      ),
    );
    return doc.save();
  }
}
