import 'package:ubsoft_pdks/domain/entities/attendance_day.dart';
import 'package:ubsoft_pdks/domain/enums/day_status.dart';

/// Raporun hangi günleri listeleyeceği.
///
/// Süzgeç **gün** seviyesinde çalışır, öğrenci seviyesinde değil: "geç
/// gelenler" seçildiğinde amaç geç gelen kişilerin tüm günlerini değil,
/// tam olarak geç gelinen günleri görmektir. Bu yüzden bir öğrencinin
/// satırı, o kişiye ait eşleşen gün kalmadığında rapordan tümüyle düşer.
///
/// [all] dışındaki her seçenek yazdırılan belgeye de yansır; rapor ekranda
/// ne görüyorsa PDF'te de odur.
enum ReportFocus {
  all('Tümü'),
  lateArrival('Son giriş saati aşıldı'),
  missingExit('Çıkış yok'),
  flagged('Konum uyarısı'),
  absent('Gelmediği gün');

  const ReportFocus(this.label);

  /// Süzgeç düğmesinde ve rapor başlığında yazan ad.
  final String label;

  bool get isAll => this == ReportFocus.all;

  /// Bu odağın gelmediği günleri de üretmesi gerekiyor mu?
  ///
  /// Gelmeme bir **kayıt değildir**; hiç okutma olmayan gün Firestore'da
  /// bulunmaz. O günler yalnız bu odak seçildiğinde kadro ve tarih
  /// aralığından üretilir — aksi hâlde her rapor hafta sonlarıyla dolardı.
  bool get needsAbsentDays => this == ReportFocus.absent;

  /// Belgede süzgecin ne yaptığını anlatan cümle.
  String get description => switch (this) {
    ReportFocus.all =>
      'Aralıkta en az bir okutma yapılan tüm günler listelenir.',
    ReportFocus.lateArrival =>
      'Yalnız bir girişi yurdun son giriş saatinden sonra olan '
          'günler listelenir.',
    ReportFocus.missingExit =>
      'Yalnız girişi olup çıkışı hiç okutulmamış günler listelenir.',
    ReportFocus.flagged =>
      'Yalnız konumu doğrulanamayan okutma içeren günler listelenir.',
    ReportFocus.absent =>
      'Yalnız hiç okutma yapılmamış günler listelenir; hafta sonu ve resmî '
          'tatiller de bu listeye girer.',
  };

  /// Bir günün bu odağa girip girmediği.
  bool matches(AttendanceDay day, DateTime now) => switch (this) {
    ReportFocus.all => !day.isEmpty,
    ReportFocus.lateArrival => !day.isEmpty && day.late,
    ReportFocus.missingExit => day.statusAt(now) == DayStatus.missingExit,
    ReportFocus.flagged => !day.isEmpty && day.worstVerdict.needsAttention,
    ReportFocus.absent => day.isEmpty,
  };
}
