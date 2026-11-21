import 'package:ubsoft_pdks/core/utils/validators.dart';

/// Toplu içe aktarma sırasında çözümlenen tek öğrenci satırı.
class StudentImportRow {
  const StudentImportRow({
    required this.lineNumber,
    required this.displayName,
    required this.email,
    required this.password,
    this.room = '',
    this.studentNumber = '',
    this.phone = '',
  });

  final int lineNumber;
  final String displayName;
  final String email;
  final String password;
  final String room;
  final String studentNumber;
  final String phone;
}

/// Satır doğrulama hatası.
class StudentImportIssue {
  const StudentImportIssue({required this.lineNumber, required this.message});

  final int lineNumber;
  final String message;
}

/// Ayrıştırma sonucu: geçerli satırlar ve atlanan satır uyarıları.
class StudentImportParseResult {
  const StudentImportParseResult({
    required this.rows,
    required this.issues,
  });

  final List<StudentImportRow> rows;
  final List<StudentImportIssue> issues;

  bool get hasValidRows => rows.isNotEmpty;
}

/// Excel'den kopyalanan (sekme ayracı) ya da CSV (`,` / `;`) metnini ayrıştırır.
///
/// Beklenen sütun sırası:
/// `Ad Soyad`, `E-posta`, `Şifre`, `[Oda]`, `[Öğrenci No]`, `[Telefon]`.
StudentImportParseResult parseStudentTable(String raw) {
  final String cleaned = raw.replaceFirst('\uFEFF', '');
  final List<String> lines = cleaned.split(RegExp(r'\r?\n'));
  final List<StudentImportRow> rows = <StudentImportRow>[];
  final List<StudentImportIssue> issues = <StudentImportIssue>[];
  final Set<String> seenEmails = <String>{};

  bool checkedHeader = false;
  for (int i = 0; i < lines.length; i++) {
    final String line = lines[i].trim();
    if (line.isEmpty) continue;

    final int lineNo = i + 1;
    final String sep = _detectDelimiter(line);
    final List<String> cells = _splitCsvLine(line, sep)
        .map((c) => c.trim())
        .toList(growable: false);

    if (!checkedHeader) {
      checkedHeader = true;
      if (_looksLikeHeader(cells)) continue;
    }

    if (cells.length < 3) {
      issues.add(
        StudentImportIssue(
          lineNumber: lineNo,
          message: 'En az Ad Soyad, E-posta ve Şifre sütunları gereklidir.',
        ),
      );
      continue;
    }

    final String name = cells[0];
    final String email = cells[1].toLowerCase();
    final String password = cells[2];
    final String room = cells.length > 3 ? cells[3] : '';
    final String studentNumber = cells.length > 4 ? cells[4] : '';
    final String phone = cells.length > 5 ? cells[5] : '';

    if (name.length < 2) {
      issues.add(
        StudentImportIssue(lineNumber: lineNo, message: 'Ad Soyad geçersiz.'),
      );
      continue;
    }
    final String? emailError = Validators.email(email);
    if (emailError != null) {
      issues.add(
        StudentImportIssue(lineNumber: lineNo, message: emailError),
      );
      continue;
    }
    if (password.length < 6) {
      issues.add(
        StudentImportIssue(
          lineNumber: lineNo,
          message: 'Şifre en az 6 karakter olmalıdır.',
        ),
      );
      continue;
    }
    if (!seenEmails.add(email)) {
      issues.add(
        StudentImportIssue(
          lineNumber: lineNo,
          message: 'Liste içinde tekrar eden e-posta ($email).',
        ),
      );
      continue;
    }

    rows.add(
      StudentImportRow(
        lineNumber: lineNo,
        displayName: name,
        email: email,
        password: password,
        room: room,
        studentNumber: studentNumber,
        phone: phone,
      ),
    );
  }

  return StudentImportParseResult(rows: rows, issues: issues);
}

/// Microsoft Excel'de Türkçe karakterlerle açılan BOM'lu örnek CSV içeriği.
String buildSampleStudentCsv() =>
    '\uFEFFAd Soyad;E-posta;Şifre;Oda;Öğrenci No;Telefon\r\n'
    'Elif Yılmaz;elif.yilmaz@yurt.edu.tr;123456;101;2026001;5551112233\r\n'
    'Zeynep Kaya;zeynep.kaya@yurt.edu.tr;123456;102;2026002;5551112234\r\n';

String _detectDelimiter(String line) {
  if (line.contains('\t')) return '\t';
  if (line.contains(';')) return ';';
  return ',';
}

bool _looksLikeHeader(List<String> cells) {
  if (cells.length < 2) return false;
  final String first = cells[0].toLowerCase();
  final String second = cells[1].toLowerCase();
  return (first.contains('ad') || first.contains('isim') || first.contains('name')) &&
      (second.contains('posta') || second.contains('mail'));
}

List<String> _splitCsvLine(String line, String sep) {
  final List<String> result = <String>[];
  final StringBuffer buf = StringBuffer();
  bool inQuotes = false;

  for (int i = 0; i < line.length; i++) {
    final String ch = line[i];
    if (ch == '"') {
      if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
        buf.write('"');
        i++;
      } else {
        inQuotes = !inQuotes;
      }
      continue;
    }
    if (!inQuotes && ch == sep) {
      result.add(buf.toString());
      buf.clear();
      continue;
    }
    buf.write(ch);
  }
  result.add(buf.toString());
  return result;
}
