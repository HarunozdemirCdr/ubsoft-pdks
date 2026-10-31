import 'package:flutter_test/flutter_test.dart';
import 'package:ubsoft_pdks/domain/entities/dormitory.dart';

DateTime tr(String date) => DateTime.parse('$date+03:00');
void main() {
  const policy = DormPolicy();
  test('gece yarısından sonraki dönüş önceki akşama aittir', () {
    final result = policy.evaluate(tr('2026-11-02T00:15:00'), entry: true);
    expect(result['cycleDate'], '2026-11-01');
    expect(result['lateMinutes'], 105);
  });
  test('sınır saati ve tolerans dahilinde geç giriş yoktur', () {
    const p = DormPolicy(tolerance: 5);
    expect(
      p.evaluate(tr('2026-11-01T22:35:00'), entry: true)['lateMinutes'],
      0,
    );
    expect(
      p.evaluate(tr('2026-11-01T22:36:00'), entry: true)['lateMinutes'],
      1,
    );
  });
  test('erken çıkış ve isteğe bağlı erken giriş bağımsızdır', () {
    const p = DormPolicy(hours: DormHours(earliestEntry: 300));
    expect(
      p.evaluate(tr('2026-11-02T05:59:00'), entry: false)['earlyExit'],
      true,
    );
    expect(
      p.evaluate(tr('2026-11-02T06:00:00'), entry: false)['earlyExit'],
      false,
    );
    expect(
      p.evaluate(tr('2026-11-02T04:00:00'), entry: true)['earlyEntry'],
      true,
    );
  });
  test('gece yarısından sonraya ayarlı dönüş saati desteklenir', () {
    const p = DormPolicy(hours: DormHours(latestEntry: 60));
    expect(
      p.evaluate(tr('2026-11-02T00:30:00'), entry: true)['lateMinutes'],
      0,
    );
    expect(
      p.evaluate(tr('2026-11-02T01:30:00'), entry: true)['lateMinutes'],
      30,
    );
  });
  test('hafta günü ve özel tarih genel kuralı geçersiz kılar', () {
    const p = DormPolicy(
      weekdays: {'7': DormHours(latestEntry: 1380)},
      exceptions: {'2026-11-01': DormHours(latestEntry: 1430)},
    );
    expect(
      p.evaluate(tr('2026-11-01T23:40:00'), entry: true)['lateMinutes'],
      0,
    );
    expect(
      p.evaluate(tr('2026-11-08T23:40:00'), entry: true)['lateMinutes'],
      40,
    );
  });
  test('içeride veya bilinmeyen öğrenci dönmedi sayılmaz', () {
    final now = tr('2026-11-02T23:00:00');
    expect(
      policy.overdue(const Presence(userId: 'a', inside: true), now, null),
      false,
    );
    expect(policy.overdue(const Presence(userId: 'a'), now, null), false);
  });
  test('dönmeyen öğrenci ertesi sabah listeden kaybolmaz', () {
    final p = Presence(
      userId: 'a',
      inside: false,
      at: tr('2026-11-01T10:00:00'),
    );
    expect(policy.overdue(p, tr('2026-11-01T22:30:00'), null), false);
    expect(policy.overdue(p, tr('2026-11-01T22:31:00'), null), true);
    expect(policy.overdue(p, tr('2026-11-02T08:00:00'), null), true);
  });
  test(
    'izin fiziksel durumu değiştirmez ve dönüş saatine kadar uyarıyı kaldırır',
    () {
      final p = Presence(
        userId: 'a',
        inside: false,
        at: tr('2026-11-01T10:00:00'),
      );
      final leave = StudentLeave(
        userId: 'a',
        from: tr('2026-11-01T09:00:00'),
        until: tr('2026-11-03T18:00:00'),
        reason: 'Aile ziyareti',
      );
      expect(policy.overdue(p, tr('2026-11-02T23:00:00'), leave), false);
      expect(policy.overdue(p, tr('2026-11-03T18:01:00'), leave), true);
      expect(p.inside, false);
      expect(
        policy.evaluate(
          tr('2026-11-02T23:00:00'),
          entry: true,
          leave: leave,
        )['lateMinutes'],
        0,
      );
    },
  );
  test('kural kaydetme ve geri okuma aynı sonucu verir', () {
    const p = DormPolicy(
      tolerance: 7,
      weekdays: {'6': DormHours(enabled: false)},
    );
    final restored = DormPolicy.fromMap(Map<String, dynamic>.from(p.toMap()));
    expect(restored.toMap(), p.toMap());
  });
  test('Türkiye günü UTC tarihinden doğru hesaplanır', () {
    expect(DormClock.key(DateTime.parse('2026-11-01T22:30:00Z')), '2026-11-02');
  });
}
