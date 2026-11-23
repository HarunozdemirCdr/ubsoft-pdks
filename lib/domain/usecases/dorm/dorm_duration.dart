import 'package:ubsoft_pdks/core/utils/date_x.dart';
import 'package:ubsoft_pdks/domain/entities/attendance_event.dart';
import 'package:ubsoft_pdks/domain/entities/dormitory.dart';

/// Tekil içeride veya dışarıda kalma aralığı.
class PresenceInterval {
  const PresenceInterval({
    required this.inside,
    required this.start,
    required this.end,
    this.ongoing = false,
  });

  final bool inside;
  final DateTime start;
  final DateTime end;
  final bool ongoing;

  Duration get duration =>
      end.isAfter(start) ? end.difference(start) : Duration.zero;
}

/// Bir öğrencinin (veya günün) okutmalarından türetilen süre ve hareket özeti.
class StudentMovementSummary {
  const StudentMovementSummary({
    required this.userId,
    required this.insideDuration,
    required this.outsideDuration,
    required this.entryCount,
    required this.exitCount,
    required this.lateCount,
    required this.lateMinutes,
    required this.earlyExitCount,
    required this.earlyEntryCount,
    required this.permittedCount,
    required this.locationWarningCount,
    required this.intervals,
  });

  final String userId;
  final Duration insideDuration;
  final Duration outsideDuration;
  final int entryCount;
  final int exitCount;
  final int lateCount;
  final int lateMinutes;
  final int earlyExitCount;
  final int earlyEntryCount;
  final int permittedCount;
  final int locationWarningCount;
  final List<PresenceInterval> intervals;

  int get totalEvents => entryCount + exitCount;
  int get warningCount => lateCount + earlyExitCount + earlyEntryCount;
}

/// Giriş–çıkış hareketlerinden içeride/dışarıda kalma sürelerini hesaplar.
abstract final class DormDurationCalculator {
  /// Kronolojik hareketlerden aralıkları ve toplam süreleri üretir.
  ///
  /// [now] verildiğinde açık kalan son aralık (şu an içerideyse içeride geçen
  /// süre, dışarıdaysa dışarıda geçen süre) [now] değerine kadar eklenir; yalnızca
  /// [now] son hareketten sonraysa hesaplanır.
  static StudentMovementSummary summarize(
    List<AttendanceEvent> events, {
    String userId = '',
    DateTime? now,
    bool includeOngoing = false,
  }) {
    if (events.isEmpty) {
      return StudentMovementSummary(
        userId: userId,
        insideDuration: Duration.zero,
        outsideDuration: Duration.zero,
        entryCount: 0,
        exitCount: 0,
        lateCount: 0,
        lateMinutes: 0,
        earlyExitCount: 0,
        earlyEntryCount: 0,
        permittedCount: 0,
        locationWarningCount: 0,
        intervals: const <PresenceInterval>[],
      );
    }

    final List<AttendanceEvent> sorted = <AttendanceEvent>[...events]
      ..sort((AttendanceEvent a, AttendanceEvent b) => a.at.compareTo(b.at));

    int entryCount = 0;
    int exitCount = 0;
    int lateCount = 0;
    int lateMinutes = 0;
    int earlyExitCount = 0;
    int earlyEntryCount = 0;
    int permittedCount = 0;
    int locationWarningCount = 0;

    Duration insideDuration = Duration.zero;
    Duration outsideDuration = Duration.zero;
    final List<PresenceInterval> intervals = <PresenceInterval>[];

    bool? currentInside;
    DateTime? segmentStart;

    for (final AttendanceEvent event in sorted) {
      final bool isEntry = event.type.isEntry;
      if (isEntry) {
        entryCount++;
      } else {
        exitCount++;
      }
      if (event.lateMinutes > 0) {
        lateCount++;
        lateMinutes += event.lateMinutes;
      }
      if (event.earlyExit) earlyExitCount++;
      if (event.earlyEntry) earlyEntryCount++;
      if (event.permitted) permittedCount++;
      if (event.verdict.needsAttention) locationWarningCount++;

      if (currentInside == null) {
        currentInside = isEntry;
        segmentStart = event.at;
        continue;
      }

      if (currentInside != isEntry && segmentStart != null) {
        final Duration diff = event.at.isAfter(segmentStart)
            ? event.at.difference(segmentStart)
            : Duration.zero;
        intervals.add(
          PresenceInterval(
            inside: currentInside,
            start: segmentStart,
            end: event.at,
          ),
        );
        if (currentInside) {
          insideDuration += diff;
        } else {
          outsideDuration += diff;
        }
        currentInside = isEntry;
        segmentStart = event.at;
      }
    }

    if (includeOngoing &&
        currentInside != null &&
        segmentStart != null &&
        now != null &&
        now.isAfter(segmentStart)) {
      final Duration diff = now.difference(segmentStart);
      intervals.add(
        PresenceInterval(
          inside: currentInside,
          start: segmentStart,
          end: now,
          ongoing: true,
        ),
      );
      if (currentInside) {
        insideDuration += diff;
      } else {
        outsideDuration += diff;
      }
    }

    return StudentMovementSummary(
      userId: userId.isNotEmpty ? userId : sorted.first.userId,
      insideDuration: insideDuration,
      outsideDuration: outsideDuration,
      entryCount: entryCount,
      exitCount: exitCount,
      lateCount: lateCount,
      lateMinutes: lateMinutes,
      earlyExitCount: earlyExitCount,
      earlyEntryCount: earlyEntryCount,
      permittedCount: permittedCount,
      locationWarningCount: locationWarningCount,
      intervals: intervals,
    );
  }

  /// Öğrencinin şu anki kesintisiz içeride veya dışarıda kalma süresini döndürür.
  static Duration? ongoingDuration(Presence presence, DateTime now) {
    if (presence.inside == null || presence.at == null) return null;
    if (!now.isAfter(presence.at!)) return Duration.zero;
    return now.difference(presence.at!);
  }

  /// İnsan okunur Türkçe süre (`2 gün 4 sa`, `3 sa 15 dk`, `18 dk`).
  static String formatDuration(Duration value) {
    if (value.isNegative) return '0 dk';
    if (value.inDays > 0) {
      final int days = value.inDays;
      final int hours = value.inHours.remainder(24);
      return hours > 0 ? '$days gün $hours sa' : '$days gün';
    }
    if (value.inMinutes == 0 && value.inSeconds > 0) return '1 dk altı';
    return AppDate.durationHuman(value);
  }
}
