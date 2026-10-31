import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:ubsoft_pdks/application/report/report_providers.dart';
import 'package:ubsoft_pdks/core/utils/date_x.dart';
import 'package:ubsoft_pdks/domain/entities/attendance_day.dart';
import 'package:ubsoft_pdks/domain/entities/report_filter.dart';
import 'package:ubsoft_pdks/domain/enums/day_status.dart';

// Açıklama satırları liste dışında tek tek durur: çok satırlı bir dizeyi
// doğrudan liste literaline yazmak, unutulmuş bir virgülü görünmez kılar.
const String _legendTimes =
    'Giriş / Çıkış: günün ilk giriş ve son çıkış okutması. Bir günde birden '
    'çok okutma varsa satırın açıklamasında sayısı yazar.';
const String _legendLate =
    'Son giriş saati aşıldı: öğrencinin bir girişi yurdun belirlediği son giriş saatinden sonra yapılmış.';
const String _legendFlagged =
    'Konum uyarısı: okutma QR noktasının yarıçapı dışında ölçülmüş ya da '
    'konum hiç alınamamış.';

const List<String> _legendNotes = <String>[
  _legendTimes,
  _legendLate,
  _legendFlagged,
];

/// Rapor renkleri — uygulamanın `AppColors` paletinin PDF karşılığı.
///
/// `AppColors` doğrudan kullanılamaz: `dart:ui` `Color`'ı ile PDF'in
/// `PdfColor`'ı farklı tiplerdir ve bu servis `flutter/material` yerine
/// yalnız `pdf` paketine bağlı kalır. Değerler ekrandaki token'larla birebir
/// aynıdır; rapor uygulamanın devamı gibi görünmelidir.
abstract final class _Ink {
  static const PdfColor primary = PdfColor.fromInt(0xFF1E3A8A);
  static const PdfColor heading = PdfColor.fromInt(0xFF1C1917);
  static const PdfColor body = PdfColor.fromInt(0xFF44403C);
  static const PdfColor muted = PdfColor.fromInt(0xFF78716C);
  static const PdfColor line = PdfColor.fromInt(0xFFE7E5E4);
  static const PdfColor zebra = PdfColor.fromInt(0xFFFAFAF9);
  static const PdfColor tint = PdfColor.fromInt(0xFFDBEAFE);
  static const PdfColor warning = PdfColor.fromInt(0xFFD97706);

  /// Giriş yeşili ve çıkış kırmızısı — ekrandaki çiftin aynısı.
  static const PdfColor entry = PdfColor.fromInt(0xFF047857);
  static const PdfColor exit = PdfColor.fromInt(0xFFB91C1C);
}

/// Rapor fontları.
///
/// Gömülü olmaları şarttır: PDF'in yerleşik Helvetica'sında Türkçe harfler
/// (ş, ğ, İ, ı) yoktur ve rapor kutu karakterleriyle çıkar.
class _ReportFonts {
  const _ReportFonts({
    required this.regular,
    required this.medium,
    required this.bold,
  });

  final pw.Font regular;
  final pw.Font medium;
  final pw.Font bold;

  static _ReportFonts? _cached;

  static Future<_ReportFonts> load() async {
    final _ReportFonts? cached = _cached;
    if (cached != null) return cached;

    Future<pw.Font> read(String name) async =>
        pw.Font.ttf(await rootBundle.load('assets/fonts/$name'));

    final _ReportFonts fonts = _ReportFonts(
      regular: await read('PlusJakartaSans-Regular.ttf'),
      medium: await read('PlusJakartaSans-SemiBold.ttf'),
      bold: await read('PlusJakartaSans-Bold.ttf'),
    );
    return _cached = fonts;
  }
}

/// Devam raporunu PDF olarak üretir.
///
/// Belge üç bölümden oluşur:
///  1. **Başlık** — şirket, tarih aralığı ve uygulanan süzgeç.
///  2. **Özet** — aralığın toplamları.
///  3. **Personel bölümleri** — her kişi için gün gün giriş ve çıkış saati.
///
/// Belge bilinçli olarak **gün gün**dür. "12 gün geldi, 98 saat çalıştı"
/// biçiminde bir özet, bordro ya da itiraz konuşmasında işe yaramaz; o
/// konuşmada sorulan şey her zaman tek bir günün saatidir.
///
/// Dosya tamamen tarayıcıda üretilir; hiçbir veri sunucuya gönderilmez.
abstract final class PdfReportService {
  static Future<Uint8List> build({
    required ReportResult report,
    required String companyName,
  }) async {
    final _ReportFonts fonts = await _ReportFonts.load();
    final pw.Document document = pw.Document(
      title: 'Devam Raporu',
      author: companyName,
    );

    final DateTime printedAt = DateTime.now();

    document.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(32, 32, 32, 40),
          theme: pw.ThemeData.withFont(
            base: fonts.regular,
            bold: fonts.bold,
            italic: fonts.regular,
          ),
        ),
        header: (pw.Context context) => context.pageNumber == 1
            ? pw.SizedBox()
            : _runningHeader(fonts, companyName, report.filter),
        footer: (pw.Context context) => _footer(fonts, context, printedAt),
        build: (pw.Context context) => <pw.Widget>[
          _title(fonts, companyName, report.filter, printedAt),
          pw.SizedBox(height: 20),
          _summary(fonts, report),
          pw.SizedBox(height: 20),
          if (report.isEmpty)
            _empty(fonts)
          else
            for (final ReportRow row in report.rows)
              _personSection(fonts, row, printedAt),
          pw.SizedBox(height: 8),
          _legend(fonts),
        ],
      ),
    );

    return document.save();
  }

  /// `devam-raporu-beyaz-yapi-2026-08-27.pdf`
  static String fileName(String companyName, ReportFilter filter) {
    final String slug = companyName
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c')
        .replaceAll(RegExp('[^a-z0-9]+'), '-')
        .replaceAll(RegExp('^-+|-+\$'), '');

    final String range = filter.isSingleDay
        ? filter.fromKey
        : '${filter.fromKey}_${filter.toKey}';

    return 'devam-raporu-${slug.isEmpty ? 'sirket' : slug}-$range.pdf';
  }

  static pw.Widget _title(
    _ReportFonts fonts,
    String companyName,
    ReportFilter filter,
    DateTime printedAt,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        pw.Text(
          companyName.toUpperCase(),
          style: pw.TextStyle(
            font: fonts.bold,
            fontSize: 10,
            letterSpacing: 1.2,
            color: _Ink.primary,
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          'Yurt Giriş-Çıkış Raporu',
          style: pw.TextStyle(
            font: fonts.bold,
            fontSize: 22,
            color: _Ink.heading,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          '${filter.label} · ${filter.dayCount} gün',
          style: pw.TextStyle(
            font: fonts.medium,
            fontSize: 11,
            color: _Ink.body,
          ),
        ),
        if (!filter.focus.isAll) ...<pw.Widget>[
          pw.SizedBox(height: 4),
          pw.Text(
            'Süzgeç: ${filter.focus.label} — ${filter.focus.description}',
            style: pw.TextStyle(
              font: fonts.regular,
              fontSize: 9,
              color: _Ink.warning,
            ),
          ),
        ],
        pw.SizedBox(height: 2),
        pw.Text(
          'Oluşturulma: ${AppDate.dateTime(printedAt)}',
          style: pw.TextStyle(
            font: fonts.regular,
            fontSize: 9,
            color: _Ink.muted,
          ),
        ),
      ],
    );
  }

  static pw.Widget _runningHeader(
    _ReportFonts fonts,
    String companyName,
    ReportFilter filter,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 8),
      margin: const pw.EdgeInsets.only(bottom: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _Ink.line)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: <pw.Widget>[
          pw.Text(
            companyName,
            style: pw.TextStyle(
              font: fonts.medium,
              fontSize: 9,
              color: _Ink.body,
            ),
          ),
          pw.Text(
            filter.label,
            style: pw.TextStyle(
              font: fonts.regular,
              fontSize: 9,
              color: _Ink.muted,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _footer(
    _ReportFonts fonts,
    pw.Context context,
    DateTime printedAt,
  ) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Text(
        'Sayfa ${context.pageNumber} / ${context.pagesCount}',
        style: pw.TextStyle(
          font: fonts.regular,
          fontSize: 8,
          color: _Ink.muted,
        ),
      ),
    );
  }

  /// Öğrenci, son giriş aşımı ve listelenen gün özeti.
  static pw.Widget _summary(_ReportFonts fonts, ReportResult report) {
    final int late = report.rows.fold(
      0,
      (int sum, ReportRow row) => sum + row.lateDays,
    );

    return pw.Row(
      children: <pw.Widget>[
        _summaryBox(fonts, 'Öğrenci', '${report.rows.length}'),
        pw.SizedBox(width: 8),
        _summaryBox(fonts, 'Son giriş aşımı', '$late'),
        pw.SizedBox(width: 8),
        _summaryBox(fonts, 'Listelenen gün', '${report.totalDayRows}'),
      ],
    );
  }

  static pw.Widget _summaryBox(_ReportFonts fonts, String label, String value) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: _Ink.tint,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: <pw.Widget>[
            pw.Text(
              value,
              style: pw.TextStyle(
                font: fonts.bold,
                fontSize: 16,
                color: _Ink.heading,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              label,
              style: pw.TextStyle(
                font: fonts.regular,
                fontSize: 8,
                color: _Ink.body,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _empty(_ReportFonts fonts) => pw.Text(
    'Seçilen aralıkta gösterilecek kayıt yok.',
    style: pw.TextStyle(font: fonts.regular, fontSize: 10, color: _Ink.muted),
  );

  /// Tek bir öğrencinin başlığı ve gün tablosu.
  static pw.Widget _personSection(
    _ReportFonts fonts,
    ReportRow row,
    DateTime now,
  ) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 16),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          _personHeader(fonts, row),
          pw.SizedBox(height: 6),
          if (row.days.isEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Text(
                'Bu aralıkta gösterilecek gün yok.',
                style: pw.TextStyle(
                  font: fonts.regular,
                  fontSize: 9,
                  color: _Ink.muted,
                ),
              ),
            )
          else
            _dayTable(fonts, row, now),
        ],
      ),
    );
  }

  static pw.Widget _personHeader(_ReportFonts fonts, ReportRow row) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 5),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _Ink.primary, width: 2)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: <pw.Widget>[
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: <pw.Widget>[
                pw.Text(
                  row.userName,
                  style: pw.TextStyle(
                    font: fonts.bold,
                    fontSize: 13,
                    color: _Ink.heading,
                  ),
                ),
                if (row.userNote.isNotEmpty)
                  pw.Text(
                    row.userNote,
                    style: pw.TextStyle(
                      font: fonts.regular,
                      fontSize: 8,
                      color: _Ink.muted,
                    ),
                  ),
              ],
            ),
          ),
          pw.Text(
            '${row.presentDays} kayıtlı gün · ${row.absentDays} kayıtsız gün',
            style: pw.TextStyle(
              font: fonts.medium,
              fontSize: 9,
              color: _Ink.body,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _dayTable(_ReportFonts fonts, ReportRow row, DateTime now) {
    const List<String> headers = <String>[
      'Tarih',
      'Gün',
      'Giriş',
      'Çıkış',
      'Açıklama',
    ];

    return pw.Table(
      border: const pw.TableBorder(
        horizontalInside: pw.BorderSide(color: _Ink.line),
        bottom: pw.BorderSide(color: _Ink.line),
      ),
      columnWidths: const <int, pw.TableColumnWidth>{
        0: pw.FlexColumnWidth(1.3),
        1: pw.FlexColumnWidth(1.2),
        2: pw.FlexColumnWidth(0.9),
        3: pw.FlexColumnWidth(0.9),
        4: pw.FlexColumnWidth(2.6),
      },
      children: <pw.TableRow>[
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _Ink.zebra),
          children: <pw.Widget>[
            for (final String header in headers)
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 6,
                ),
                child: pw.Text(
                  header,
                  style: pw.TextStyle(
                    font: fonts.bold,
                    fontSize: 8,
                    color: _Ink.body,
                  ),
                ),
              ),
          ],
        ),
        for (final AttendanceDay day in row.days)
          pw.TableRow(
            children: <pw.Widget>[
              _cell(fonts, AppDate.dateShort(_dateOf(day)), bold: true),
              _cell(fonts, AppDate.dayName(_dateOf(day)), color: _Ink.muted),
              _cell(
                fonts,
                day.entryLabel,
                color: day.firstEntryAt == null ? _Ink.muted : _Ink.entry,
                bold: day.firstEntryAt != null,
              ),
              _cell(
                fonts,
                day.exitLabel,
                color: day.lastExitAt == null ? _Ink.muted : _Ink.exit,
                bold: day.lastExitAt != null,
              ),
              _cell(fonts, _noteLabel(day, now), color: _noteColor(day, now)),
            ],
          ),
      ],
    );
  }

  /// Gün anahtarını tarihe çevirir. Bozuk anahtar bugüne düşer — satır
  /// kaybolmaktansa yanlış başlıkla görünmesi yeğdir.
  static DateTime _dateOf(AttendanceDay day) =>
      DateTime.tryParse(day.dateKey) ?? DateTime.now();

  /// Günün açıklaması: `Son giriş saati aşıldı · 2 giriş / 2 çıkış · Konum uyarısı`.
  static String _noteLabel(AttendanceDay day, DateTime now) {
    if (day.isEmpty) return 'Gelmedi';

    final List<String> parts = <String>[
      if (day.late) 'Son giriş saati aşıldı',
      if (day.statusAt(now) == DayStatus.missingExit) 'Çıkış yok',
      if (day.worstVerdict.needsAttention) day.worstVerdict.label,
      if (day.entryCount > 1 || day.exitCount > 1)
        '${day.entryCount} giriş / ${day.exitCount} çıkış',
    ];

    return parts.isEmpty ? '—' : parts.join(' · ');
  }

  static PdfColor _noteColor(AttendanceDay day, DateTime now) {
    if (day.isEmpty) return _Ink.muted;
    if (day.worstVerdict.needsAttention) return _Ink.exit;
    if (day.late || day.statusAt(now) == DayStatus.missingExit) {
      return _Ink.warning;
    }
    return _Ink.body;
  }

  static pw.Widget _cell(
    _ReportFonts fonts,
    String text, {
    bool bold = false,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: bold ? fonts.medium : fonts.regular,
          fontSize: 9,
          color: color ?? _Ink.body,
        ),
      ),
    );
  }

  /// Sütunların ne anlama geldiğini yazar.
  ///
  /// Rapor çoğu zaman yazdırılıp masaya konur; o anda uygulamayı açıp
  /// "çıkış yok ne demek" diye bakacak kimse olmaz.
  static pw.Widget _legend(_ReportFonts fonts) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: _Ink.zebra,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Text(
            'Sütun açıklamaları',
            style: pw.TextStyle(
              font: fonts.medium,
              fontSize: 9,
              color: _Ink.heading,
            ),
          ),
          pw.SizedBox(height: 4),
          for (final String note in _legendNotes)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 2),
              child: pw.Text(
                '• $note',
                style: pw.TextStyle(
                  font: fonts.regular,
                  fontSize: 8,
                  color: _Ink.muted,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
