import 'package:equatable/equatable.dart';
import 'package:ubsoft_pdks/core/utils/date_x.dart';
import 'package:ubsoft_pdks/domain/enums/day_status.dart';
import 'package:ubsoft_pdks/domain/enums/location_verdict.dart';

/// Bir personelin bir gündeki devam özeti.
///
/// Okutmalardan türetilir ve her okutmayla **aynı işlemde** güncellenir.
/// Ayrı tutulmasının sebebi maliyet ve hız: "bu ay kim kaç saat çalıştı"
/// sorusu binlerce okutma yerine otuz özet okunarak cevaplanır.
///
/// Doküman kimliği `{userId}_{dateKey}` biçimindedir — aynı gün için ikinci
/// bir özet oluşamaz.
class AttendanceDay extends Equatable {
  const AttendanceDay({
    required this.id,
    required this.tenantId,
    required this.userId,
    required this.userName,
    required this.dateKey,
    this.firstEntryAt,
    this.lastEntryAt,
    this.lastExitAt,
    this.entryCount = 0,
    this.exitCount = 0,
    this.workedMinutes = 0,
    this.open = false,
    this.late = false,
    this.worstVerdict = LocationVerdict.verified,
    this.updatedAt,
  });

  /// Bir personelin verilen günü için boş özet.
  factory AttendanceDay.empty({
    required String tenantId,
    required String userId,
    required String userName,
    required String dateKey,
  }) => AttendanceDay(
    id: buildId(userId: userId, dateKey: dateKey),
    tenantId: tenantId,
    userId: userId,
    userName: userName,
    dateKey: dateKey,
  );

  /// Doküman kimliği üretir.
  static String buildId({required String userId, required String dateKey}) =>
      '${userId}_$dateKey';

  final String id;
  final String tenantId;
  final String userId;
  final String userName;
  final String dateKey;

  /// Günün ilk girişi — "kaçta geldi" sorusunun cevabı.
  final DateTime? firstEntryAt;

  /// En son okutulan giriş. Çıkış geldiğinde çalışılan süre bundan hesaplanır.
  final DateTime? lastEntryAt;

  /// Günün son çıkışı — "kaçta çıktı".
  final DateTime? lastExitAt;

  final int entryCount;
  final int exitCount;

  /// Eşleşmiş giriş–çıkış çiftlerinin toplamı (dakika).
  ///
  /// Açık bir giriş varsa o süre buraya **dahil değildir**; anlık toplam için
  /// [workedMinutesAt] kullanılır.
  final int workedMinutes;

  /// Şu an içeride mi? (Son okutma giriş ise `true`.)
  final bool open;

  /// İlk giriş, mesai başlangıcı + tolerans saatinden sonra mı yapıldı?
  final bool late;

  /// Günün en kötü konum doğrulaması — listede tek rozetle uyarmak için.
  final LocationVerdict worstVerdict;

  final DateTime? updatedAt;

  /// Hiç okutma yapılmamış mı?
  bool get isEmpty => entryCount == 0 && exitCount == 0;

  /// [now] anına kadar çalışılmış toplam süre.
  ///
  /// Personel hâlâ içerideyse açık giriş süresi de eklenir; böylece "şu an
  /// 3 sa 12 dk" canlı olarak görünür.
  int workedMinutesAt(DateTime now) {
    if (!open || lastEntryAt == null) return workedMinutes;
    final int live = now.difference(lastEntryAt!).inMinutes;
    return workedMinutes + (live > 0 ? live : 0);
  }

  Duration get workedDuration => Duration(minutes: workedMinutes);

  /// Günün durumu.
  ///
  /// [now] verilerek geçmiş bir gün değerlendirildiğinde, açık kalmış bir
  /// giriş "içeride" değil "çıkış yok" sayılır — personel dün gece hâlâ
  /// içeride olamaz.
  DayStatus statusAt(DateTime now, {int graceHours = 16}) {
    if (isEmpty) return DayStatus.absent;
    if (!open) return DayStatus.completed;

    final DateTime? since = lastEntryAt ?? firstEntryAt;
    if (since != null && now.difference(since).inHours >= graceHours) {
      return DayStatus.missingExit;
    }
    return DayStatus.present;
  }

  /// `08:42` / `—`
  String get entryLabel =>
      firstEntryAt == null ? '—' : AppDate.time(firstEntryAt!);

  String get exitLabel => lastExitAt == null ? '—' : AppDate.time(lastExitAt!);

  AttendanceDay copyWith({
    String? userName,
    DateTime? firstEntryAt,
    DateTime? lastEntryAt,
    DateTime? lastExitAt,
    int? entryCount,
    int? exitCount,
    int? workedMinutes,
    bool? open,
    bool? late,
    LocationVerdict? worstVerdict,
    DateTime? updatedAt,
  }) => AttendanceDay(
    id: id,
    tenantId: tenantId,
    userId: userId,
    userName: userName ?? this.userName,
    dateKey: dateKey,
    firstEntryAt: firstEntryAt ?? this.firstEntryAt,
    lastEntryAt: lastEntryAt ?? this.lastEntryAt,
    lastExitAt: lastExitAt ?? this.lastExitAt,
    entryCount: entryCount ?? this.entryCount,
    exitCount: exitCount ?? this.exitCount,
    workedMinutes: workedMinutes ?? this.workedMinutes,
    open: open ?? this.open,
    late: late ?? this.late,
    worstVerdict: worstVerdict ?? this.worstVerdict,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  @override
  List<Object?> get props => <Object?>[
    id,
    tenantId,
    userId,
    userName,
    dateKey,
    firstEntryAt,
    lastEntryAt,
    lastExitAt,
    entryCount,
    exitCount,
    workedMinutes,
    open,
    late,
    worstVerdict,
  ];
}
