import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubsoft_pdks/application/auth/session_provider.dart';
import 'package:ubsoft_pdks/application/providers.dart';
import 'package:ubsoft_pdks/application/user/user_providers.dart';
import 'package:ubsoft_pdks/core/utils/date_x.dart';
import 'package:ubsoft_pdks/domain/entities/app_user.dart';
import 'package:ubsoft_pdks/domain/entities/attendance_day.dart';
import 'package:ubsoft_pdks/domain/entities/attendance_event.dart';
import 'package:ubsoft_pdks/domain/entities/report_filter.dart';
import 'package:ubsoft_pdks/domain/enums/day_status.dart';

/// Geçmiş ekranlarında seçili gün. Varsayılan: bugün.
final NotifierProvider<SelectedDay, String> selectedDayProvider =
    NotifierProvider<SelectedDay, String>(SelectedDay.new);

class SelectedDay extends Notifier<String> {
  @override
  String build() => AppDate.todayKey();

  void select(DateTime date) => state = AppDate.dateKey(date);

  void selectKey(String dateKey) => state = dateKey;

  void today() => state = AppDate.todayKey();
}

/// Giriş yapmış kullanıcının bugünkü özeti.
///
/// Okutma ekranının kalbi: "Giriş yaptım mı, kaçta, ne kadar oldu" bilgisini
/// canlı taşır ve bir sonraki okutmanın yönünü belirler.
final StreamProvider<AttendanceDay> myTodayProvider =
    StreamProvider<AttendanceDay>((ref) {
      final AppUser? user = ref.watch(currentUserProvider);
      if (user == null) return const Stream<AttendanceDay>.empty();

      return ref
          .watch(attendanceRepositoryProvider)
          .watchDay(
            tenantId: user.tenantId,
            userId: user.uid,
            userName: user.displayName,
            dateKey: AppDate.todayKey(),
          );
    });

/// Giriş yapmış kullanıcının bugünkü okutmaları.
final StreamProvider<List<AttendanceEvent>> myTodayEventsProvider =
    StreamProvider<List<AttendanceEvent>>((ref) {
      final AppUser? user = ref.watch(currentUserProvider);
      if (user == null) return const Stream<List<AttendanceEvent>>.empty();

      return ref
          .watch(attendanceRepositoryProvider)
          .watchDayEvents(
            tenantId: user.tenantId,
            userId: user.uid,
            dateKey: AppDate.todayKey(),
          );
    });

/// Bir günün tüm personel özetleri (yönetici görünümü).
final daySummariesProvider = StreamProvider.family<List<AttendanceDay>, String>(
  (ref, dateKey) => ref
      .watch(attendanceRepositoryProvider)
      .watchDaySummaries(
        tenantId: ref.watch(tenantIdProvider),
        dateKey: dateKey,
      ),
);

/// Bir personelin belirli gündeki okutmaları.
final personDayEventsProvider =
    StreamProvider.family<
      List<AttendanceEvent>,
      ({String userId, String dateKey})
    >(
      (ref, args) => ref
          .watch(attendanceRepositoryProvider)
          .watchDayEvents(
            tenantId: ref.watch(tenantIdProvider),
            userId: args.userId,
            dateKey: args.dateKey,
          ),
    );

/// Bir personelin tarih aralığındaki günleri, yeniden eskiye.
final personDaysProvider =
    StreamProvider.family<
      List<AttendanceDay>,
      ({String userId, ReportFilter filter})
    >(
      (ref, args) => ref
          .watch(attendanceRepositoryProvider)
          .watchUserDays(
            tenantId: ref.watch(tenantIdProvider),
            userId: args.userId,
            fromKey: args.filter.fromKey,
            toKey: args.filter.toKey,
          ),
    );

/// Bir günün personel bazlı tam tablosu.
///
/// **Kadrodan kurulur, kayıtlardan değil.** Yalnız o gün okutma yapmış
/// kişileri listelemek, gelmeyenleri görünmez yapardı — oysa bir devam
/// kontrol sisteminde asıl bakılan şey odur. Bu yüzden liste aktif personel
/// kadrosuyla başlar; kaydı olmayan herkes [DayStatus.absent] olarak satırını
/// korur.
final dayRosterProvider = Provider.family<List<AttendanceDay>, String>((
  ref,
  dateKey,
) {
  final List<AppUser> roster = ref.watch(activeUsersProvider);
  final List<AttendanceDay> records =
      ref.watch(daySummariesProvider(dateKey)).value ?? const <AttendanceDay>[];

  final Map<String, AttendanceDay> byUser = <String, AttendanceDay>{
    for (final AttendanceDay day in records) day.userId: day,
  };

  final String tenantId = ref.watch(tenantIdProvider);

  final List<AttendanceDay> rows = <AttendanceDay>[
    for (final AppUser user in roster)
      byUser[user.uid] ??
          AttendanceDay.empty(
            tenantId: tenantId,
            userId: user.uid,
            userName: user.displayName,
            dateKey: dateKey,
          ),

    // Kadroda olmayan ama o gün kaydı bulunan kişiler (işten ayrılmış
    // personel) düşmez: geçmiş bir günün tablosu, o gün gerçekten ne
    // olduğunu göstermeli.
    ...records.where(
      (AttendanceDay day) => !roster.any((AppUser u) => u.uid == day.userId),
    ),
  ];

  // Önce içeride olanlar, sonra tamamlayanlar, en sonda gelmeyenler.
  final DateTime now = DateTime.now();
  rows.sort((AttendanceDay a, AttendanceDay b) {
    final int byStatus = a.statusAt(now).index.compareTo(b.statusAt(now).index);
    return byStatus != 0 ? byStatus : a.userName.compareTo(b.userName);
  });

  return List<AttendanceDay>.unmodifiable(rows);
});

/// Bir günün özeti — panel kartları için.
class DayOverview {
  const DayOverview({
    required this.total,
    required this.inside,
    required this.completed,
    required this.absent,
    required this.late,
    required this.flagged,
  });

  /// Kadrodaki aktif personel sayısı.
  final int total;

  /// Şu anda içeride olanlar.
  final int inside;

  /// Girişi ve çıkışı tamamlananlar.
  final int completed;

  /// Hiç okutma yapmayanlar.
  final int absent;

  /// Geç giriş yapanlar.
  final int late;

  /// Konumu doğrulanamayan okutması olanlar.
  final int flagged;
}

/// Seçili günün özeti.
final dayOverviewProvider = Provider.family<DayOverview, String>((
  ref,
  dateKey,
) {
  final List<AttendanceDay> rows = ref.watch(dayRosterProvider(dateKey));
  final DateTime now = DateTime.now();

  int inside = 0;
  int completed = 0;
  int absent = 0;
  int late = 0;
  int flagged = 0;

  for (final AttendanceDay day in rows) {
    final DayStatus status = day.statusAt(now);

    switch (status) {
      case DayStatus.present:
        inside++;
      case DayStatus.completed:
        completed++;
      case DayStatus.missingExit:
        // Çıkışı okutulmamış gün "tamamlandı" sayılmaz ama "gelmedi" de
        // değildir; kişi işe gelmiştir. Kendi sayacı yoktur, işaretlenenlere
        // katılır ve satırında kendi rozetiyle görünür.
        break;
      case DayStatus.absent:
        absent++;
    }

    if (day.late) late++;

    // Bir gün en fazla **bir kez** işaretlenir: hem çıkışı eksik hem konumu
    // şüpheli bir gün, kartta iki kişi gibi görünmemeli.
    final bool needsAttention =
        status == DayStatus.missingExit ||
        (!day.isEmpty && day.worstVerdict.needsAttention);
    if (needsAttention) flagged++;
  }

  return DayOverview(
    total: rows.length,
    inside: inside,
    completed: completed,
    absent: absent,
    late: late,
    flagged: flagged,
  );
});
