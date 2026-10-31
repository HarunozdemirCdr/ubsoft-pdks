import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubsoft_pdks/application/auth/session_provider.dart';
import 'package:ubsoft_pdks/application/providers.dart';
import 'package:ubsoft_pdks/application/user/user_providers.dart';
import 'package:ubsoft_pdks/core/result/result.dart';
import 'package:ubsoft_pdks/domain/entities/app_user.dart';
import 'package:ubsoft_pdks/domain/entities/attendance_day.dart';
import 'package:ubsoft_pdks/domain/entities/report_filter.dart';
import 'package:ubsoft_pdks/domain/enums/day_status.dart';
import 'package:ubsoft_pdks/domain/enums/report_focus.dart';

/// Rapor ekranındaki süzgeç.
final NotifierProvider<ReportFilterController, ReportFilter>
reportFilterProvider = NotifierProvider<ReportFilterController, ReportFilter>(
  ReportFilterController.new,
);

class ReportFilterController extends Notifier<ReportFilter> {
  @override
  ReportFilter build() => ReportFilter.lastDays(7);

  void setRange({required DateTime from, required DateTime to}) =>
      state = state.copyWith(from: from, to: to);

  void setUser(String? userId) => state = userId == null
      ? state.copyWith(clearUser: true)
      : state.copyWith(userId: userId);

  void setFocus(ReportFocus focus) => state = state.copyWith(focus: focus);

  void preset(ReportFilter filter) => state = filter;
}

/// Bir öğrencinin rapor aralığındaki toplamı.
///
/// **Kişi denklemi:** her satır yalnız o kişinin kendi günlerinden hesaplanır.
/// Satırların toplamı ekip geneli bir "gün sayısı" vermez; farklı kişiler
/// aynı günü paylaşır. Ekran bu ayrımı yazar.
class ReportRow {
  const ReportRow({
    required this.userId,
    required this.userName,
    required this.userNote,
    required this.workedMinutes,
    required this.presentDays,
    required this.absentDays,
    required this.lateDays,
    required this.missingExitDays,
    required this.flaggedDays,
    required this.days,
  });

  final String userId;
  final String userName;

  /// Öğrenci kaydındaki serbest açıklama. Belgede adın altında yazar.
  final String userNote;

  /// Toplam çalışılan süre (dakika).
  final int workedMinutes;

  /// En az bir okutma yapılan gün sayısı.
  final int presentDays;

  /// Aralıktaki, hiç okutma yapılmayan gün sayısı.
  final int absentDays;

  final int lateDays;

  /// Girişi olup çıkışı okutulmamış gün sayısı.
  final int missingExitDays;

  /// Konumu doğrulanamayan okutma içeren gün sayısı.
  final int flaggedDays;

  /// Süzgece uyan günler, **eskiden yeniye**.
  ///
  /// Rapor bir belgedir; gün gün okunurken zaman ileri akmalıdır. Ekrandaki
  /// açılır liste de aynı sırayı kullanır ki yazdırılan kâğıtla ekran
  /// birbirini tutsun.
  ///
  /// Satırın toplamları ([workedMinutes], [presentDays] …) bu listeden değil,
  /// aralığın **tamamından** hesaplanır: "geç giriş" süzgeci açıkken de
  /// kişinin o aydaki gerçek toplam süresi görünmelidir.
  final List<AttendanceDay> days;

  Duration get workedDuration => Duration(minutes: workedMinutes);

  /// Süzgece uyan gün sayısı.
  int get matchedDays => days.length;

  /// Günlük ortalama süre (dakika). Hiç gelinmediyse 0.
  int get averageMinutes =>
      presentDays == 0 ? 0 : (workedMinutes / presentDays).round();

  bool get hasProblem =>
      lateDays > 0 || missingExitDays > 0 || flaggedDays > 0 || absentDays > 0;
}

/// Rapor sonucu.
class ReportResult {
  const ReportResult({required this.filter, required this.rows});

  final ReportFilter filter;
  final List<ReportRow> rows;

  bool get isEmpty => rows.isEmpty;

  int get totalMinutes =>
      rows.fold(0, (int sum, ReportRow row) => sum + row.workedMinutes);

  /// Belgede listelenen toplam gün satırı sayısı.
  int get totalDayRows =>
      rows.fold(0, (int sum, ReportRow row) => sum + row.matchedDays);
}

/// Rapor sorgusunun **okuma anahtarı**: yalnız Firestore'a giden alanlar.
///
/// Gün süzgeci ([ReportFilter.focus]) bilinçli olarak burada yoktur; o süzgeç
/// tümüyle istemci tarafında uygulanır. Süzgeç anahtara dahil edilseydi her
/// çip dokunuşu aynı aralığı Firestore'dan yeniden okurdu: otuz günlük ve on
/// iki kişilik bir raporda tek dokunuş yüzlerce belge okuması demektir.
@immutable
class ReportQuery {
  const ReportQuery({required this.fromKey, required this.toKey, this.userId});

  factory ReportQuery.of(ReportFilter filter) => ReportQuery(
    fromKey: filter.fromKey,
    toKey: filter.toKey,
    userId: filter.userId,
  );

  final String fromKey;
  final String toKey;
  final String? userId;

  @override
  bool operator ==(Object other) =>
      other is ReportQuery &&
      other.fromKey == fromKey &&
      other.toKey == toKey &&
      other.userId == userId;

  @override
  int get hashCode => Object.hash(fromKey, toKey, userId);
}

/// Aralıktaki gün özetleri — tek seferlik okuma.
///
/// Canlı akış değil: rapor bir **fotoğraftır**, kullanıcı bakarken satırların
/// altından kayması istenmez. Ayrıca canlı bir dinleyici, ekran açık kaldığı
/// sürece her yeni okutmada yeniden belge okurdu.
///
/// `keepAlive` bilinçlidir: kullanıcı süzgeçler arasında gezinirken ya da
/// aralığa geri dönerken aynı veri yeniden okunmaz. Oturum boyunca birkaç
/// aralık bellekte durur; Firestore faturasında bunun karşılığı sıfırdır.
final reportDaysProvider =
    FutureProvider.family<List<AttendanceDay>, ReportQuery>((ref, query) async {
      ref.keepAlive();

      final Result<List<AttendanceDay>> fetched = await ref
          .watch(attendanceRepositoryProvider)
          .fetchDays(
            tenantId: ref.watch(tenantIdProvider),
            fromKey: query.fromKey,
            toKey: query.toKey,
            userId: query.userId,
          );

      if (fetched case Err<List<AttendanceDay>>(:final failure)) {
        throw failure;
      }
      return (fetched as Ok<List<AttendanceDay>>).value;
    });

/// Süzgeçe göre rapor verisi.
///
/// Okuma [reportDaysProvider]'dan gelir; bu sağlayıcı yalnız **hesaplar**.
/// Gün süzgecini değiştirmek ağa çıkmaz, satırlar anında yeniden kurulur.
final reportProvider = FutureProvider.family<ReportResult, ReportFilter>((
  ref,
  filter,
) async {
  final List<AppUser> roster = ref.watch(activeUsersProvider);
  final List<AttendanceDay> days = await ref.watch(
    reportDaysProvider(ReportQuery.of(filter)).future,
  );

  return buildReport(
    filter: filter,
    days: days,
    roster: filter.userId == null
        ? roster
        : roster.where((AppUser u) => u.uid == filter.userId).toList(),
  );
});

/// Günlük özetleri öğrenci bazlı rapor satırlarına indirger.
///
/// Saf bir fonksiyondur — ağ ya da sağlayıcı bilmez, doğrudan test edilir.
///
/// **Gelmediği günler kadrodan gelir, kayıtlardan değil:** yalnız var olan
/// kayıtlara bakan bir rapor, hiç gelmeyen öğrenciyi sıfır satırıyla değil,
/// hiç göstermezdi.
ReportResult buildReport({
  required ReportFilter filter,
  required List<AttendanceDay> days,
  required List<AppUser> roster,
  DateTime? now,
}) {
  final DateTime moment = now ?? DateTime.now();

  final Map<String, List<AttendanceDay>> byUser =
      <String, List<AttendanceDay>>{};
  final Map<String, String> namesById = <String, String>{
    for (final AppUser user in roster) user.uid: user.displayName,
  };
  final Map<String, String> notesById = <String, String>{
    for (final AppUser user in roster) user.uid: user.note ?? '',
  };

  for (final AttendanceDay day in days) {
    byUser.putIfAbsent(day.userId, () => <AttendanceDay>[]).add(day);
    namesById.putIfAbsent(day.userId, () => day.userName);
  }

  // Kadrodaki herkes + aralıkta kaydı bulunan ama kadroda olmayanlar
  // (işten ayrılmış öğrenci) birlikte raporlanır.
  final Set<String> userIds = <String>{
    for (final AppUser user in roster) user.uid,
    ...byUser.keys,
  };

  final int totalDays = filter.dayCount;
  final String tenantId = roster.isNotEmpty
      ? roster.first.tenantId
      : (days.isNotEmpty ? days.first.tenantId : '');

  final List<ReportRow> rows = <ReportRow>[];

  for (final String userId in userIds) {
    final String userName = namesById[userId] ?? 'Bilinmeyen öğrenci';
    final List<AttendanceDay> userDays =
        byUser[userId] ?? const <AttendanceDay>[];

    int worked = 0;
    int present = 0;
    int late = 0;
    int missingExit = 0;
    int flagged = 0;

    for (final AttendanceDay day in userDays) {
      if (day.isEmpty) continue;

      present++;
      worked += day.workedMinutes;
      if (day.late) late++;
      if (day.statusAt(moment) == DayStatus.missingExit) missingExit++;
      if (day.worstVerdict.needsAttention) flagged++;
    }

    // Gelmediği günler yalnız istendiğinde üretilir; kayıt olarak var
    // olmadıkları için aralık ve kadrodan türetilirler.
    final List<AttendanceDay> pool = filter.focus.needsAbsentDays
        ? _withAbsentDays(
            recorded: userDays,
            filter: filter,
            tenantId: tenantId,
            userId: userId,
            userName: userName,
          )
        : userDays;

    final List<AttendanceDay> matched =
        pool
            .where((AttendanceDay day) => filter.focus.matches(day, moment))
            .toList()
          ..sort(
            (AttendanceDay a, AttendanceDay b) =>
                a.dateKey.compareTo(b.dateKey),
          );

    rows.add(
      ReportRow(
        userId: userId,
        userName: userName,
        userNote: notesById[userId] ?? '',
        workedMinutes: worked,
        presentDays: present,
        absentDays: totalDays - present,
        lateDays: late,
        missingExitDays: missingExit,
        flaggedDays: flagged,
        days: List<AttendanceDay>.unmodifiable(matched),
      ),
    );
  }

  rows.sort((ReportRow a, ReportRow b) => a.userName.compareTo(b.userName));

  // Süzgeç açıkken eşleşen günü olmayan öğrenci rapordan düşer: "geç
  // gelenler" listesinde hiç geç gelmemiş birinin boş satırı gürültüdür.
  final List<ReportRow> visible = filter.focus.isAll
      ? rows
      : rows.where((ReportRow row) => row.matchedDays > 0).toList();

  return ReportResult(
    filter: filter,
    rows: List<ReportRow>.unmodifiable(visible),
  );
}

/// Kayıtlı günlerin üstüne, aralıkta kaydı hiç olmayan günleri ekler.
List<AttendanceDay> _withAbsentDays({
  required List<AttendanceDay> recorded,
  required ReportFilter filter,
  required String tenantId,
  required String userId,
  required String userName,
}) {
  final Set<String> known = <String>{
    for (final AttendanceDay day in recorded) day.dateKey,
  };

  return <AttendanceDay>[
    ...recorded,
    for (final String dateKey in filter.dayKeys)
      if (!known.contains(dateKey))
        AttendanceDay.empty(
          tenantId: tenantId,
          userId: userId,
          userName: userName,
          dateKey: dateKey,
        ),
  ];
}
