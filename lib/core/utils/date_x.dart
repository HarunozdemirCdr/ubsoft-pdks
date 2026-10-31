import 'package:intl/intl.dart';
import 'package:ubsoft_pdks/domain/entities/dormitory.dart';

/// Tarih ve süre biçimleme.
///
/// Tüm zaman damgaları Firestore'da **sunucu saatiyle (UTC)** tutulur;
/// gösterim yerel saate çevrilir. `dateKey` üretimi gün bazlı sorgular içindir.
abstract final class AppDate {
  static final DateFormat _time = DateFormat('HH:mm', 'tr');
  static final DateFormat _timeSec = DateFormat('HH:mm:ss', 'tr');
  static final DateFormat _date = DateFormat('d MMMM yyyy', 'tr');
  static final DateFormat _dateShort = DateFormat('dd.MM.yyyy', 'tr');
  static final DateFormat _dateTime = DateFormat('dd.MM.yyyy HH:mm', 'tr');
  static final DateFormat _dayName = DateFormat('EEEE', 'tr');
  static final DateFormat _key = DateFormat('yyyy-MM-dd');

  /// `14:32`
  static String time(DateTime value) => _time.format(DormClock.local(value));

  /// `14:32:07`
  static String timeWithSeconds(DateTime value) =>
      _timeSec.format(DormClock.local(value));

  /// `22 Temmuz 2026`
  static String date(DateTime value) => _date.format(DormClock.local(value));

  /// `22.07.2026`
  static String dateShort(DateTime value) =>
      _dateShort.format(DormClock.local(value));

  /// `22.07.2026 14:32`
  static String dateTime(DateTime value) =>
      _dateTime.format(DormClock.local(value));

  /// `Çarşamba`
  static String dayName(DateTime value) =>
      _dayName.format(DormClock.local(value));

  /// Gün bazlı sorgu anahtarı: `2026-07-22`.
  static String dateKey(DateTime value) => _key.format(DormClock.local(value));

  /// Bugünün anahtarı.
  static String todayKey() => dateKey(DateTime.now());

  /// Günün başlangıcı (00:00:00).
  static DateTime startOfDay(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  /// Günün sonu (23:59:59.999).
  static DateTime endOfDay(DateTime value) =>
      DateTime(value.year, value.month, value.day, 23, 59, 59, 999);

  /// Süreyi `01:24:35` biçiminde verir (saat gerekmiyorsa `24:35`).
  static String duration(Duration value) {
    final int hours = value.inHours;
    final String minutes = value.inMinutes
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    final String seconds = value.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  /// Süreyi okunur biçimde verir: `1 sa 24 dk`, `24 dk`, `35 sn`.
  static String durationHuman(Duration value) {
    if (value.inHours > 0) {
      final int minutes = value.inMinutes.remainder(60);
      return minutes > 0
          ? '${value.inHours} sa $minutes dk'
          : '${value.inHours} sa';
    }
    if (value.inMinutes > 0) return '${value.inMinutes} dk';
    return '${value.inSeconds} sn';
  }

  /// Göreli zaman: `az önce`, `12 dk önce`, `3 sa önce`, `dün`, `22.07.2026`.
  static String relative(DateTime value) {
    final DateTime local = DormClock.local(value);
    final Duration diff = DateTime.now().difference(value);

    if (diff.inSeconds < 60) return 'az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
    if (diff.inHours < 24) return '${diff.inHours} sa önce';
    if (diff.inDays == 1) return 'dün ${time(local)}';
    if (diff.inDays < 7) return '${diff.inDays} gün önce';
    return dateShort(local);
  }

  /// Aynı gün mü?
  static bool isSameDay(DateTime a, DateTime b) {
    final DateTime la = DormClock.local(a);
    final DateTime lb = DormClock.local(b);
    return la.year == lb.year && la.month == lb.month && la.day == lb.day;
  }

  static bool isToday(DateTime value) => isSameDay(value, DateTime.now());
}
