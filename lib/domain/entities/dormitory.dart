/// Yurt saati cihazın saat diliminden bağımsızdır (Türkiye, UTC+3).
abstract final class DormClock {
  static DateTime local(DateTime value) =>
      value.toUtc().add(const Duration(hours: 3));
  static String key(DateTime value) {
    final DateTime d = local(value);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  static DateTime at(DateTime localDay, int minute) => DateTime.utc(
    localDay.year,
    localDay.month,
    localDay.day,
  ).add(Duration(minutes: minute - 180));
}

class DormHours {
  const DormHours({
    this.earliestExit = 360,
    this.latestEntry = 1350,
    this.earliestEntry,
    this.enabled = true,
  });
  final int earliestExit;
  final int latestEntry;
  final int? earliestEntry;
  final bool enabled;
  Map<String, Object?> toMap() => <String, Object?>{
    'earliestExit': earliestExit,
    'latestEntry': latestEntry,
    'earliestEntry': earliestEntry,
    'enabled': enabled,
  };
  factory DormHours.fromMap(Map<String, dynamic> m) => DormHours(
    earliestExit: (m['earliestExit'] as num?)?.toInt() ?? 360,
    latestEntry: (m['latestEntry'] as num?)?.toInt() ?? 1350,
    earliestEntry: (m['earliestEntry'] as num?)?.toInt(),
    enabled: m['enabled'] as bool? ?? true,
  );
}

class DormPolicy {
  const DormPolicy({
    this.hours = const DormHours(),
    this.tolerance = 0,
    this.weekdays = const <String, DormHours>{},
    this.exceptions = const <String, DormHours>{},
  });
  final DormHours hours;
  final int tolerance;
  final Map<String, DormHours> weekdays;
  final Map<String, DormHours> exceptions;
  DormHours forDay(DateTime localDay) {
    final String key =
        '${localDay.year}-${localDay.month.toString().padLeft(2, '0')}-${localDay.day.toString().padLeft(2, '0')}';
    return exceptions[key] ?? weekdays['${localDay.weekday}'] ?? hours;
  }

  Map<String, Object?> toMap() => <String, Object?>{
    'hours': hours.toMap(),
    'tolerance': tolerance,
    'weekdays': weekdays.map((k, v) => MapEntry(k, v.toMap())),
    'exceptions': exceptions.map((k, v) => MapEntry(k, v.toMap())),
  };
  factory DormPolicy.fromMap(Map<String, dynamic> m) {
    Map<String, DormHours> entries(String field) =>
        ((m[field] as Map?) ?? <String, Object?>{}).map(
          (dynamic k, dynamic v) => MapEntry(
            k.toString(),
            DormHours.fromMap(Map<String, dynamic>.from(v as Map)),
          ),
        );
    return DormPolicy(
      hours: DormHours.fromMap(
        Map<String, dynamic>.from((m['hours'] as Map?) ?? <String, Object?>{}),
      ),
      tolerance: (m['tolerance'] as num?)?.toInt() ?? 0,
      weekdays: entries('weekdays'),
      exceptions: entries('exceptions'),
    );
  }

  /// Sabahki açılışa kadar giriş, önceki akşamın dönüşüne aittir.
  DateTime cycleDay(DateTime value) {
    final DateTime d = DormClock.local(value);
    final DateTime day = DateTime.utc(d.year, d.month, d.day);
    return d.hour * 60 + d.minute < forDay(day).earliestExit
        ? day.subtract(const Duration(days: 1))
        : day;
  }

  DateTime deadline(DateTime cycle) {
    final DormHours h = forDay(cycle);
    final int minutes = h.latestEntry < h.earliestExit
        ? h.latestEntry + 1440
        : h.latestEntry;
    return DormClock.at(cycle, minutes + tolerance);
  }

  Map<String, Object?> evaluate(
    DateTime at, {
    required bool entry,
    StudentLeave? leave,
    DateTime? departedAt,
  }) {
    final DateTime d = DormClock.local(at);
    final DateTime cycle = cycleDay(at);
    final DormHours h = forDay(cycle);
    final bool permitted = leave?.covers(at) ?? false;
    int late = entry && h.enabled && !permitted && at.isAfter(deadline(cycle))
        ? at.difference(deadline(cycle)).inMinutes
        : 0;
    if (entry &&
        !permitted &&
        leave != null &&
        !leave.revoked &&
        departedAt != null &&
        !leave.until.isBefore(departedAt) &&
        at.isAfter(leave.until)) {
      late = at.difference(leave.until).inMinutes;
    }
    final bool earlyExit =
        !entry &&
        !permitted &&
        forDay(d).enabled &&
        d.hour * 60 + d.minute < forDay(d).earliestExit;
    final bool earlyEntry =
        entry &&
        !permitted &&
        forDay(d).enabled &&
        forDay(d).earliestEntry != null &&
        d.hour * 60 + d.minute < forDay(d).earliestEntry!;
    return <String, Object?>{
      'lateMinutes': late,
      'earlyExit': earlyExit,
      'earlyEntry': earlyEntry,
      'permitted': permitted,
      'cycleDate':
          '${cycle.year}-${cycle.month.toString().padLeft(2, '0')}-${cycle.day.toString().padLeft(2, '0')}',
      'policy': toMap(),
    };
  }

  bool overdue(Presence presence, DateTime now, StudentLeave? leave) {
    if (presence.inside != false || presence.at == null) return false;
    if (leave?.covers(now) ?? false) return false;
    // Süresi biten izin, kendi dönüş zamanını taşır; sonraki güne kaybolmaz.
    if (leave != null &&
        !leave.revoked &&
        !leave.until.isBefore(presence.at!) &&
        !now.isBefore(leave.until)) {
      return true;
    }
    final DateTime departureCycle = cycleDay(presence.at!);
    DateTime cycle = departureCycle;
    final DateTime current = cycleDay(now);
    while (!cycle.isAfter(current)) {
      final DateTime due = deadline(cycle);
      if (forDay(cycle).enabled &&
          due.isAfter(presence.at!) &&
          now.isAfter(due) &&
          !(leave?.covers(due) ?? false)) {
        return true;
      }
      cycle = cycle.add(const Duration(days: 1));
    }
    return false;
  }
}

class StudentLeave {
  const StudentLeave({
    required this.userId,
    required this.from,
    required this.until,
    required this.reason,
    this.id = '',
    this.revoked = false,
  });
  final String id;
  final String userId;
  final DateTime from;
  final DateTime until;
  final String reason;
  final bool revoked;
  bool covers(DateTime at) =>
      !revoked && !at.isBefore(from) && !at.isAfter(until);
}

class Presence {
  const Presence({
    required this.userId,
    this.inside,
    this.at,
    this.eventId,
    this.checkpoint = '',
    this.lateMinutes = 0,
    this.earlyExit = false,
    this.earlyEntry = false,
    this.permitted = false,
  });
  final String userId;
  final bool? inside;
  final DateTime? at;
  final String? eventId;
  final String checkpoint;
  final int lateMinutes;
  final bool earlyExit;
  final bool earlyEntry;
  final bool permitted;
  String get label => inside == null
      ? 'Başlangıç kaydı yok'
      : inside!
      ? 'İçeride'
      : 'Dışarıda';
  List<String> get warnings => <String>[
    if (lateMinutes > 0) '$lateMinutes dk geç giriş',
    if (earlyExit) 'Erken çıkış',
    if (earlyEntry) 'Erken giriş',
  ];
}
