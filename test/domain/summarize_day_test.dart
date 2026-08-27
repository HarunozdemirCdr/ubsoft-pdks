import 'package:flutter_test/flutter_test.dart';
import 'package:ubsoft_pdks/domain/entities/attendance_day.dart';
import 'package:ubsoft_pdks/domain/entities/attendance_event.dart';
import 'package:ubsoft_pdks/domain/entities/tenant.dart';
import 'package:ubsoft_pdks/domain/enums/day_status.dart';
import 'package:ubsoft_pdks/domain/enums/location_verdict.dart';
import 'package:ubsoft_pdks/domain/enums/punch_type.dart';
import 'package:ubsoft_pdks/domain/usecases/attendance/summarize_day.dart';

import '../support/test_harness.dart';

const String _dateKey = '2026-08-27';
const TenantSettings _settings = TenantSettings();

AttendanceDay _empty() => AttendanceDay.empty(
  tenantId: TestData.tenantId,
  userId: TestData.staffUid,
  userName: 'Ahmet Yılmaz',
  dateKey: _dateKey,
);

AttendanceEvent _event({
  required PunchType type,
  required DateTime at,
  LocationVerdict verdict = LocationVerdict.verified,
}) => AttendanceEvent(
  id: '${type.key}-${at.millisecondsSinceEpoch}',
  tenantId: TestData.tenantId,
  userId: TestData.staffUid,
  userName: 'Ahmet Yılmaz',
  type: type,
  at: at,
  dateKey: _dateKey,
  checkpointId: 'cp',
  checkpointName: 'Ana Giriş',
  checkpointCode: '1',
  verdict: verdict,
);

DateTime _at(int hour, int minute) => DateTime(2026, 8, 27, hour, minute);

void main() {
  group('SummarizeDay.applyPunch', () {
    test('ilk giriş günü açar', () {
      final AttendanceDay day = SummarizeDay.applyPunch(
        day: _empty(),
        type: PunchType.entry,
        at: _at(8, 25),
        verdict: LocationVerdict.verified,
        userName: 'Ahmet Yılmaz',
        settings: _settings,
      );

      expect(day.open, isTrue);
      expect(day.entryCount, 1);
      expect(day.firstEntryAt, _at(8, 25));
      expect(day.workedMinutes, 0);
      expect(day.late, isFalse);
    });

    test('çıkış çalışılan süreyi ekler ve günü kapatır', () {
      AttendanceDay day = SummarizeDay.applyPunch(
        day: _empty(),
        type: PunchType.entry,
        at: _at(8, 30),
        verdict: LocationVerdict.verified,
        userName: 'Ahmet Yılmaz',
        settings: _settings,
      );
      day = SummarizeDay.applyPunch(
        day: day,
        type: PunchType.exit,
        at: _at(17, 30),
        verdict: LocationVerdict.verified,
        userName: 'Ahmet Yılmaz',
        settings: _settings,
      );

      expect(day.open, isFalse);
      expect(day.workedMinutes, 9 * 60);
      expect(day.lastExitAt, _at(17, 30));
    });

    test('öğle arası ikinci çifti toplar', () {
      AttendanceDay day = _empty();
      for (final (PunchType type, DateTime at) in <(PunchType, DateTime)>[
        (PunchType.entry, _at(8, 0)),
        (PunchType.exit, _at(12, 0)),
        (PunchType.entry, _at(13, 0)),
        (PunchType.exit, _at(17, 0)),
      ]) {
        day = SummarizeDay.applyPunch(
          day: day,
          type: type,
          at: at,
          verdict: LocationVerdict.verified,
          userName: 'Ahmet Yılmaz',
          settings: _settings,
        );
      }

      // 4 saat + 4 saat; öğle arası sayılmaz.
      expect(day.workedMinutes, 8 * 60);
      expect(day.entryCount, 2);
      expect(day.exitCount, 2);
      expect(day.open, isFalse);
    });

    test('ilk giriş geç ise gün geç işaretlenir', () {
      final AttendanceDay day = SummarizeDay.applyPunch(
        day: _empty(),
        type: PunchType.entry,
        // Mesai 08:30, tolerans 15 dk → 08:45'ten sonrası geç.
        at: _at(9, 5),
        verdict: LocationVerdict.verified,
        userName: 'Ahmet Yılmaz',
        settings: _settings,
      );

      expect(day.late, isTrue);
    });

    test('tolerans içindeki giriş geç sayılmaz', () {
      final AttendanceDay day = SummarizeDay.applyPunch(
        day: _empty(),
        type: PunchType.entry,
        at: _at(8, 44),
        verdict: LocationVerdict.verified,
        userName: 'Ahmet Yılmaz',
        settings: _settings,
      );

      expect(day.late, isFalse);
    });

    test('ikinci giriş "geç" bayrağını bozmaz', () {
      // Geçlik günün İLK girişine bakar; öğleden sonra dönen biri geç
      // sayılmamalı.
      AttendanceDay day = SummarizeDay.applyPunch(
        day: _empty(),
        type: PunchType.entry,
        at: _at(8, 20),
        verdict: LocationVerdict.verified,
        userName: 'Ahmet Yılmaz',
        settings: _settings,
      );
      day = SummarizeDay.applyPunch(
        day: day,
        type: PunchType.exit,
        at: _at(12, 0),
        verdict: LocationVerdict.verified,
        userName: 'Ahmet Yılmaz',
        settings: _settings,
      );
      day = SummarizeDay.applyPunch(
        day: day,
        type: PunchType.entry,
        at: _at(13, 30),
        verdict: LocationVerdict.verified,
        userName: 'Ahmet Yılmaz',
        settings: _settings,
      );

      expect(day.late, isFalse);
      expect(day.firstEntryAt, _at(8, 20));
    });

    test('günün en kötü konum sonucu korunur', () {
      AttendanceDay day = SummarizeDay.applyPunch(
        day: _empty(),
        type: PunchType.entry,
        at: _at(8, 0),
        verdict: LocationVerdict.outside,
        userName: 'Ahmet Yılmaz',
        settings: _settings,
      );
      day = SummarizeDay.applyPunch(
        day: day,
        type: PunchType.exit,
        at: _at(17, 0),
        verdict: LocationVerdict.verified,
        userName: 'Ahmet Yılmaz',
        settings: _settings,
      );

      expect(day.worstVerdict, LocationVerdict.outside);
    });
  });

  group('SummarizeDay.rebuild', () {
    test('artımlı hesapla aynı sonucu verir', () {
      // İki yolun ayrışması, silinen bir kayıttan sonra yanlış çalışma
      // süresi bırakırdı. Bu test o eşitliği kilitler.
      final List<AttendanceEvent> events = <AttendanceEvent>[
        _event(type: PunchType.entry, at: _at(8, 10)),
        _event(type: PunchType.exit, at: _at(12, 0)),
        _event(type: PunchType.entry, at: _at(12, 45)),
        _event(type: PunchType.exit, at: _at(18, 5)),
      ];

      AttendanceDay incremental = _empty();
      for (final AttendanceEvent event in events) {
        incremental = SummarizeDay.applyPunch(
          day: incremental,
          type: event.type,
          at: event.at,
          verdict: event.verdict,
          userName: event.userName,
          settings: _settings,
        );
      }

      final AttendanceDay rebuilt = SummarizeDay.rebuild(
        base: _empty(),
        events: events,
        settings: _settings,
      );

      expect(rebuilt.workedMinutes, incremental.workedMinutes);
      expect(rebuilt.entryCount, incremental.entryCount);
      expect(rebuilt.exitCount, incremental.exitCount);
      expect(rebuilt.open, incremental.open);
      expect(rebuilt.late, incremental.late);
      expect(rebuilt.firstEntryAt, incremental.firstEntryAt);
      expect(rebuilt.lastExitAt, incremental.lastExitAt);
    });

    test('sırası karışık kayıtlar zamana göre çözülür', () {
      final AttendanceDay day = SummarizeDay.rebuild(
        base: _empty(),
        events: <AttendanceEvent>[
          _event(type: PunchType.exit, at: _at(17, 0)),
          _event(type: PunchType.entry, at: _at(9, 0)),
        ],
        settings: _settings,
      );

      expect(day.workedMinutes, 8 * 60);
      expect(day.firstEntryAt, _at(9, 0));
    });

    test('kayıt kalmayınca gün boşalır', () {
      final AttendanceDay day = SummarizeDay.rebuild(
        base: _empty(),
        events: const <AttendanceEvent>[],
        settings: _settings,
      );

      expect(day.isEmpty, isTrue);
      expect(day.workedMinutes, 0);
      expect(day.open, isFalse);
    });

    test('girişi silinmiş bir çıkış süre üretmez', () {
      // Yönetici girişi sildi; geriye yalnız çıkış kaldı. Uygulama
      // "ne zaman geldiği" bilgisini uydurmamalı.
      final AttendanceDay day = SummarizeDay.rebuild(
        base: _empty(),
        events: <AttendanceEvent>[_event(type: PunchType.exit, at: _at(17, 0))],
        settings: _settings,
      );

      expect(day.workedMinutes, 0);
      expect(day.firstEntryAt, isNull);
      expect(day.open, isFalse);
    });
  });

  group('AttendanceDay durumu', () {
    test('açık gün, aynı gün içinde "içeride"dir', () {
      final AttendanceDay day = SummarizeDay.applyPunch(
        day: _empty(),
        type: PunchType.entry,
        at: _at(9, 0),
        verdict: LocationVerdict.verified,
        userName: 'Ahmet Yılmaz',
        settings: _settings,
      );

      expect(day.statusAt(_at(14, 0)), DayStatus.present);
    });

    test('ertesi güne sarkan açık gün "çıkış yok" olur', () {
      final AttendanceDay day = SummarizeDay.applyPunch(
        day: _empty(),
        type: PunchType.entry,
        at: _at(9, 0),
        verdict: LocationVerdict.verified,
        userName: 'Ahmet Yılmaz',
        settings: _settings,
      );

      // Personel dün gece hâlâ içeride olamaz.
      expect(
        day.statusAt(_at(9, 0).add(const Duration(hours: 20))),
        DayStatus.missingExit,
      );
    });

    test('hiç okutması olmayan gün "gelmedi"dir', () {
      expect(_empty().statusAt(DateTime.now()), DayStatus.absent);
    });

    test('unutulmuş çıkışta canlı sayaç durur', () {
      final AttendanceDay day = SummarizeDay.applyPunch(
        day: _empty(),
        type: PunchType.entry,
        at: _at(9, 0),
        verdict: LocationVerdict.verified,
        userName: 'Ahmet Yılmaz',
        settings: _settings,
      );

      // Gün "çıkış yok"a döndükten sonra süre büyümeye devam etmemeli:
      // uygulama personelin ne zaman çıktığını bilmiyor.
      expect(
        day.statusAt(_at(9, 0).add(const Duration(hours: 20))),
        DayStatus.missingExit,
      );
      expect(day.workedMinutesAt(_at(9, 0).add(const Duration(hours: 20))), 0);
      expect(day.workedMinutesAt(_at(9, 0).add(const Duration(days: 3))), 0);
    });

    test('eşleşmiş süre unutulmuş çıkıştan sonra da korunur', () {
      // Sabah gelip öğlen çıkan, öğleden sonra tekrar girip çıkışını
      // unutan bir gün: ilk çift sayılır, açık kalan ikinci giriş sayılmaz.
      AttendanceDay day = SummarizeDay.applyPunch(
        day: _empty(),
        type: PunchType.entry,
        at: _at(9, 0),
        verdict: LocationVerdict.verified,
        userName: 'Ahmet Yılmaz',
        settings: _settings,
      );
      day = SummarizeDay.applyPunch(
        day: day,
        type: PunchType.exit,
        at: _at(12, 0),
        verdict: LocationVerdict.verified,
        userName: 'Ahmet Yılmaz',
        settings: _settings,
      );
      day = SummarizeDay.applyPunch(
        day: day,
        type: PunchType.entry,
        at: _at(13, 0),
        verdict: LocationVerdict.verified,
        userName: 'Ahmet Yılmaz',
        settings: _settings,
      );

      expect(day.workedMinutes, 180);
      expect(day.workedMinutesAt(_at(13, 0).add(const Duration(days: 2))), 180);
    });

    test('canlı süre açık girişi de sayar', () {
      final AttendanceDay day = SummarizeDay.applyPunch(
        day: _empty(),
        type: PunchType.entry,
        at: _at(9, 0),
        verdict: LocationVerdict.verified,
        userName: 'Ahmet Yılmaz',
        settings: _settings,
      );

      expect(day.workedMinutes, 0);
      expect(day.workedMinutesAt(_at(12, 30)), 210);
    });
  });
}
