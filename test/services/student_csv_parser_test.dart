import 'package:flutter_test/flutter_test.dart';
import 'package:ubsoft_pdks/services/import/student_csv_parser.dart';

void main() {
  test('parseStudentTable supports semicolon CSV with BOM and header', () {
    final result = parseStudentTable(buildSampleStudentCsv());
    expect(result.issues, isEmpty);
    expect(result.rows.length, 2);
    expect(result.rows.first.displayName, 'Elif Yılmaz');
    expect(result.rows.first.email, 'elif.yilmaz@yurt.edu.tr');
    expect(result.rows.first.room, '101');
    expect(result.rows.first.studentNumber, '2026001');
  });

  test('parseStudentTable supports Excel tab-delimited paste and rejects bad rows', () {
    const raw =
        'Ad Soyad\tE-posta\tŞifre\tOda\n'
        'Ayşe Demir\tayse@yurt.edu.tr\t123456\t204\n'
        'Kötü Satır\tgecersiz-mail\t123\n'
        'Tekrar Ayşe\tayse@yurt.edu.tr\t123456\t205\n';
    final result = parseStudentTable(raw);
    expect(result.rows.length, 1);
    expect(result.rows.single.displayName, 'Ayşe Demir');
    expect(result.issues.length, 2);
  });
}
