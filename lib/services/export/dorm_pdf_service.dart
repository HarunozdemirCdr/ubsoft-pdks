import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:ubsoft_pdks/core/utils/date_x.dart';
import 'package:ubsoft_pdks/domain/entities/attendance_event.dart';

abstract final class DormPdfService {
  static Future<Uint8List> build(
    String dorm,
    String range,
    List<AttendanceEvent> events,
  ) async {
    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/PlusJakartaSans-Regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/PlusJakartaSans-Bold.ttf'),
    );
    final doc = pw.Document(title: 'Yurt giriş–çıkış raporu', author: dorm);
    final sorted = [...events]..sort((a, b) => a.at.compareTo(b.at));
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
          pw.Text(dorm, style: pw.TextStyle(font: bold, fontSize: 20)),
          pw.Text('Öğrenci giriş–çıkış raporu · $range'),
          pw.SizedBox(height: 12),
          pw.Text(
            '${events.length} hareket · ${events.where((e) => e.lateMinutes > 0).length} geç giriş · ${events.where((e) => e.earlyExit).length} erken çıkış',
          ),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: ['Öğrenci', 'Tarih / saat', 'İşlem', 'Nokta', 'Açıklama'],
            cellStyle: const pw.TextStyle(fontSize: 8),
            headerStyle: pw.TextStyle(font: bold, fontSize: 8),
            data: sorted
                .map(
                  (e) => [
                    e.userName,
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
