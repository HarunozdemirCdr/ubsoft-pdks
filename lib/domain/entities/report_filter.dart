import 'package:equatable/equatable.dart';
import 'package:ubsoft_pdks/core/utils/date_x.dart';
import 'package:ubsoft_pdks/domain/enums/report_focus.dart';

/// Rapor ve geçmiş ekranlarının ortak süzgeci.
///
/// Tarih aralığı **kapsayıcıdır**: `from` gününün 00:00'ından `to` gününün
/// 23:59'una kadar. Sorgular gün anahtarı (`dateKey`) üzerinden çalıştığı
/// için saat dilimi karışıklığı oluşmaz — anahtar istemcide yerel güne göre
/// üretilir ve karşılaştırma metin sıralamasıyla yapılır.
class ReportFilter extends Equatable {
  const ReportFilter({
    required this.from,
    required this.to,
    this.userId,
    this.focus = ReportFocus.all,
  });

  /// Bugün.
  factory ReportFilter.today() {
    final DateTime now = DateTime.now();
    return ReportFilter(from: now, to: now);
  }

  /// Son [days] gün (bugün dahil).
  factory ReportFilter.lastDays(int days) {
    final DateTime now = DateTime.now();
    return ReportFilter(
      from: now.subtract(Duration(days: days - 1)),
      to: now,
    );
  }

  /// İçinde bulunulan ay.
  factory ReportFilter.thisMonth() {
    final DateTime now = DateTime.now();
    return ReportFilter(from: DateTime(now.year, now.month), to: now);
  }

  final DateTime from;
  final DateTime to;

  /// Tek bir personele daralt. `null` ise tüm personel.
  final String? userId;

  /// Hangi günler listelenecek. Ayrıntı için [ReportFocus].
  final ReportFocus focus;

  String get fromKey => AppDate.dateKey(from);
  String get toKey => AppDate.dateKey(to);

  /// Aralıktaki gün sayısı (kapsayıcı).
  int get dayCount =>
      AppDate.startOfDay(to).difference(AppDate.startOfDay(from)).inDays + 1;

  bool get isSingleDay => fromKey == toKey;

  /// Aralıktaki tüm gün anahtarları, eskiden yeniye.
  List<String> get dayKeys {
    final DateTime start = AppDate.startOfDay(from);
    return <String>[
      for (int i = 0; i < dayCount; i++)
        AppDate.dateKey(start.add(Duration(days: i))),
    ];
  }

  /// Kullanıcıya gösterilecek aralık metni.
  String get label => isSingleDay
      ? AppDate.date(from)
      : '${AppDate.dateShort(from)} – ${AppDate.dateShort(to)}';

  ReportFilter copyWith({
    DateTime? from,
    DateTime? to,
    String? userId,
    bool clearUser = false,
    ReportFocus? focus,
  }) => ReportFilter(
    from: from ?? this.from,
    to: to ?? this.to,
    userId: clearUser ? null : (userId ?? this.userId),
    focus: focus ?? this.focus,
  );

  @override
  List<Object?> get props => <Object?>[fromKey, toKey, userId, focus];
}
