import 'package:ubsoft_pdks/domain/entities/attendance_day.dart';
import 'package:ubsoft_pdks/domain/entities/attendance_event.dart';
import 'package:ubsoft_pdks/domain/entities/tenant.dart';
import 'package:ubsoft_pdks/domain/enums/location_verdict.dart';
import 'package:ubsoft_pdks/domain/enums/punch_type.dart';

/// Okutmalardan bir günün özetini kurar.
///
/// İki yerde kullanılır ve **aynı sonucu vermek zorundadır**:
///  • Okutma anında — özet artımlı olarak güncellenir ([applyPunch]).
///  • Yönetici bir okutmayı sildiğinde — özet o günün kalan okutmalarından
///    sıfırdan kurulur ([rebuild]).
///
/// İkisinin ayrışması, silinen bir kaydın ardından yanlış çalışma süresi
/// bırakırdı; bu yüzden süre hesabı tek bir yerde ([_pairMinutes]) durur ve
/// iki yolun aynı sonucu verdiği birim testiyle kilitlenir.
abstract final class SummarizeDay {
  /// Bir günün okutmalarından özeti sıfırdan kurar.
  ///
  /// [events] aynı kişiye ve aynı güne ait olmalıdır; sıra önemsizdir,
  /// fonksiyon kendisi zamana göre sıralar.
  static AttendanceDay rebuild({
    required AttendanceDay base,
    required List<AttendanceEvent> events,
    required TenantSettings settings,
  }) {
    if (events.isEmpty) {
      return AttendanceDay.empty(
        tenantId: base.tenantId,
        userId: base.userId,
        userName: base.userName,
        dateKey: base.dateKey,
      );
    }

    final List<AttendanceEvent> sorted = <AttendanceEvent>[...events]
      ..sort((AttendanceEvent a, AttendanceEvent b) => a.at.compareTo(b.at));

    DateTime? firstEntry;
    DateTime? lastEntry;
    DateTime? lastExit;
    DateTime? openSince;
    int entryCount = 0;
    int exitCount = 0;
    int worked = 0;
    LocationVerdict worst = LocationVerdict.verified;

    for (final AttendanceEvent event in sorted) {
      worst = worst.worst(event.verdict);

      if (event.type.isEntry) {
        entryCount++;
        firstEntry ??= event.at;
        lastEntry = event.at;
        openSince = event.at;
      } else {
        exitCount++;
        lastExit = event.at;
        if (openSince != null) {
          worked += _pairMinutes(openSince, event.at);
          openSince = null;
        }
      }
    }

    return AttendanceDay(
      id: base.id,
      tenantId: base.tenantId,
      userId: base.userId,
      userName: sorted.last.userName,
      dateKey: base.dateKey,
      firstEntryAt: firstEntry,
      lastEntryAt: lastEntry,
      lastExitAt: lastExit,
      entryCount: entryCount,
      exitCount: exitCount,
      workedMinutes: worked,
      open: openSince != null,
      late: sorted.any(
        (AttendanceEvent event) =>
            event.type.isEntry && isLate(event.at, settings),
      ),
      worstVerdict: worst,
      updatedAt: DateTime.now(),
    );
  }

  /// Var olan özete tek bir okutmayı işler.
  ///
  /// Okutma anında kullanılır: o günün tüm kayıtlarını yeniden okumadan özet
  /// güncellenir. Sonuç [rebuild] ile aynı olmalıdır.
  static AttendanceDay applyPunch({
    required AttendanceDay day,
    required PunchType type,
    required DateTime at,
    required LocationVerdict verdict,
    required String userName,
    required TenantSettings settings,
  }) {
    final LocationVerdict worst = day.worstVerdict.worst(verdict);

    if (type.isEntry) {
      final DateTime firstEntry = day.firstEntryAt ?? at;
      return day.copyWith(
        userName: userName,
        firstEntryAt: firstEntry,
        lastEntryAt: at,
        entryCount: day.entryCount + 1,
        open: true,
        late: day.late || isLate(at, settings),
        worstVerdict: worst,
        updatedAt: at,
      );
    }

    final DateTime? openSince = day.open ? day.lastEntryAt : null;
    final int added = openSince == null ? 0 : _pairMinutes(openSince, at);

    return day.copyWith(
      userName: userName,
      lastExitAt: at,
      exitCount: day.exitCount + 1,
      workedMinutes: day.workedMinutes + added,
      open: false,
      worstVerdict: worst,
      updatedAt: at,
    );
  }

  /// Giriş, yurdun yöneticice belirlenen son giriş saatinden sonra mı?
  static bool isLate(DateTime firstEntry, TenantSettings settings) {
    final DateTime local = firstEntry.toLocal();
    final int minutes = local.hour * 60 + local.minute;
    return minutes > settings.lateAfterMinutes;
  }

  /// Bir giriş–çıkış çiftinin süresi (dakika).
  ///
  /// Negatif süre üretilmez: iki kayıt aynı saniyeye düşebilir ve eksi bir
  /// değer, toplam çalışma süresini sessizce azaltırdı.
  static int _pairMinutes(DateTime from, DateTime to) {
    final int minutes = to.difference(from).inMinutes;
    return minutes > 0 ? minutes : 0;
  }
}
