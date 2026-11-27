import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:ubsoft_pdks/core/utils/date_x.dart';
import 'package:ubsoft_pdks/domain/entities/app_user.dart';
import 'package:ubsoft_pdks/domain/entities/attendance_event.dart';
import 'package:ubsoft_pdks/domain/entities/attention_resolution.dart';

abstract final class DormPdfService {
  static Future<Uint8List> build(
    String dorm,
    String range,
    List<AttendanceEvent> events, {
    Map<String, AppUser> usersById = const <String, AppUser>{},
    List<AttentionResolution> attentionLogs = const <AttentionResolution>[],
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
    final int entryCount = events.where((e) => e.type.isEntry).length;
    final int exitCount = events.where((e) => e.type.isExit).length;
    final int lateCount = events.where((e) => e.lateMinutes > 0).length;
    final int earlyExitCount = events.where((e) => e.earlyExit).length;

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
                pw.Image(logo, width: 120),
                pw.SizedBox(width: 14),
              ],
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(dorm, style: pw.TextStyle(font: bold, fontSize: 18)),
                    pw.Text('Öğrenci giriş–çıkış raporu · $range'),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            '${events.length} hareket ($entryCount giriş · $exitCount çıkış) · $lateCount geç giriş · $earlyExitCount erken çıkış'
            '${attentionLogs.isEmpty ? '' : ' · ${attentionLogs.length} çözülmüş uyarı kaydı'}',
          ),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: [
              'Öğrenci',
              'Oda',
              'Tarih / saat',
              'İşlem',
              'Nokta',
              'Açıklama & Çözüm Notu',
            ],
            cellStyle: const pw.TextStyle(fontSize: 8),
            headerStyle: pw.TextStyle(font: bold, fontSize: 8),
            data: sorted.map((e) {
              final String logNote = attentionLogs
                  .where(
                    (l) =>
                        (l.eventId.isNotEmpty && l.eventId == e.id) ||
                        (l.eventId.isEmpty &&
                            l.userId == e.userId &&
                            l.dateKey == e.dateKey),
                  )
                  .map(
                    (l) =>
                        'Çözüm (${l.resolvedByName.isEmpty ? 'Yönetici' : l.resolvedByName}): ${l.resolutionNote}',
                  )
                  .join(' | ');
              return [
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
                  if (logNote.isNotEmpty) logNote,
                ].join(', '),
              ];
            }).toList(),
          ),
          if (attentionLogs.isNotEmpty) ...[
            pw.SizedBox(height: 18),
            pw.Text(
              'Uyarı ve Çözüm Kayıtları (${attentionLogs.length})',
              style: pw.TextStyle(font: bold, fontSize: 12),
            ),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: [
                'Tarih',
                'Öğrenci',
                'Oda',
                'Uyarı',
                'Çözüm Notu',
                'Çözen',
              ],
              cellStyle: const pw.TextStyle(fontSize: 8),
              headerStyle: pw.TextStyle(font: bold, fontSize: 8),
              data: attentionLogs
                  .map(
                    (l) => [
                      AppDate.dateTime(l.resolvedAt),
                      l.userName,
                      l.room,
                      l.title,
                      l.resolutionNote,
                      l.resolvedByName,
                    ],
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
    return doc.save();
  }
}
