import 'package:ubsoft_pdks/core/utils/date_x.dart';
import 'package:ubsoft_pdks/domain/entities/app_user.dart';
import 'package:ubsoft_pdks/domain/entities/dormitory.dart';
import 'package:ubsoft_pdks/domain/usecases/dorm/dorm_duration.dart';

enum DormAttentionKind {
  /// İzin süresi dolmuş fakat öğrenci hâlâ yurda dönmemiş (en kritik).
  leaveExpiredStillOutside,

  /// Aktif izni olmadan beklenen dönüş saati geçmiş ve hâlâ dışarıda.
  curfewOverdue,

  /// Son okutmasında saat veya konum uyarısı bulunuyor.
  scanWarning,

  /// İlk giriş/çıkış veya başlangıç durumu henüz belirlenmemiş.
  uninitialized,
}

class DormAttentionItem {
  const DormAttentionItem({
    required this.user,
    required this.presence,
    required this.kind,
    required this.title,
    required this.summary,
    this.relatedLeave,
    this.expectedReturnAt,
    this.overdueBy,
    this.outsideFor,
  });

  final AppUser user;
  final Presence presence;
  final DormAttentionKind kind;
  final String title;
  final String summary;
  final StudentLeave? relatedLeave;
  final DateTime? expectedReturnAt;
  final Duration? overdueBy;
  final Duration? outsideFor;

  bool get isCritical =>
      kind == DormAttentionKind.leaveExpiredStillOutside ||
      kind == DormAttentionKind.curfewOverdue;

  int get severityRank => switch (kind) {
    DormAttentionKind.leaveExpiredStillOutside => 0,
    DormAttentionKind.curfewOverdue => 1,
    DormAttentionKind.scanWarning => 2,
    DormAttentionKind.uninitialized => 3,
  };

  /// Bu spesifik olayı benzersiz tanımlayan anahtar. Yönetici "Çözüldü" olarak
  /// işaretlediğinde bu anahtar `attentionLogs` koleksiyonuna kaydedilir; aynı
  /// olay aktif listeden düşerken öğrencinin ilerideki yeni olayları yine
  /// uyarı üretmeye devam eder.
  String get incidentKey {
    final String evId = presence.eventId ?? '';
    final String evStamp = evId.isNotEmpty
        ? evId
        : (presence.at?.millisecondsSinceEpoch.toString() ?? 'none');
    return switch (kind) {
      DormAttentionKind.leaveExpiredStillOutside =>
        'leave_${relatedLeave?.id.isNotEmpty == true ? relatedLeave!.id : '${user.uid}_${expectedReturnAt?.millisecondsSinceEpoch ?? evStamp}'}',
      DormAttentionKind.curfewOverdue => 'curfew_${user.uid}_$evStamp',
      DormAttentionKind.scanWarning => 'scan_${user.uid}_$evStamp',
      DormAttentionKind.uninitialized => 'init_${user.uid}',
    };
  }

  String get relatedEventId => presence.eventId ?? '';

  String get relatedDateKey =>
      presence.at == null ? '' : DormClock.key(presence.at!);

  /// Çözüm loguna kaydedilecek okunabilir özet satırı.
  String get detailLine {
    if (kind == DormAttentionKind.leaveExpiredStillOutside &&
        expectedReturnAt != null) {
      return 'İzin bitişi: ${AppDate.dateTime(expectedReturnAt!)}'
          '${overdueBy == null ? '' : ' · ${DormDurationCalculator.formatDuration(overdueBy!)} gecikti'}';
    }
    if (kind == DormAttentionKind.curfewOverdue && expectedReturnAt != null) {
      return 'Beklenen dönüş: ${AppDate.dateTime(expectedReturnAt!)}'
          '${overdueBy == null ? '' : ' · ${DormDurationCalculator.formatDuration(overdueBy!)} gecikti'}';
    }
    return summary;
  }
}

/// 500+ öğrenci arasında gözden kaçabilecek kritik yurt durumlarını otomatik
/// tespit eder (izni bitip dönmeyenler, izinsiz gecikenler, uyarılar).
abstract final class DormAttentionAnalyzer {
  static DormAttentionItem? evaluateStudent({
    required AppUser user,
    required Presence presence,
    required List<StudentLeave> userLeaves,
    required DormPolicy policy,
    required DateTime now,
  }) {
    if (presence.inside == null) {
      return DormAttentionItem(
        user: user,
        presence: presence,
        kind: DormAttentionKind.uninitialized,
        title: 'Başlangıç kaydı yok',
        summary: 'Henüz ilk QR okutması veya yönetici doğrulaması yapılmadı.',
      );
    }

    final Duration? elapsed = presence.at != null && now.isAfter(presence.at!)
        ? now.difference(presence.at!)
        : null;

    if (presence.inside == false && presence.at != null) {
      // 1. Önce aktif izin kontrolü: şu an hâlâ izinli ise kritik uyarı yok.
      final bool hasActiveLeave = userLeaves.any(
        (l) => !l.revoked && l.covers(now),
      );
      if (!hasActiveLeave) {
        // 2. Çıkışını kapsayan veya çıkışından sonra bitmiş en son izin var mı?
        final List<StudentLeave> expiredLeaves = userLeaves
            .where(
              (l) =>
                  !l.revoked &&
                  !l.until.isAfter(now) &&
                  !l.until.isBefore(presence.at!) &&
                  !l.from.isAfter(now),
            )
            .toList()
          ..sort((a, b) => b.until.compareTo(a.until));

        if (expiredLeaves.isNotEmpty) {
          final StudentLeave expired = expiredLeaves.first;
          final Duration overdueBy = now.difference(expired.until);
          return DormAttentionItem(
            user: user,
            presence: presence,
            kind: DormAttentionKind.leaveExpiredStillOutside,
            title: 'İzin süresi doldu · Hâlâ dışarıda',
            summary: 'İzni bittiği hâlde yurda giriş kaydı bulunmuyor.',
            relatedLeave: expired,
            expectedReturnAt: expired.until,
            overdueBy: overdueBy,
            outsideFor: elapsed,
          );
        }

        // 3. İzin olmadan normal dönüş saatini geçmiş mi?
        final DateTime? expected = _expectedCurfewReturn(
          policy,
          presence.at!,
        );
        if (policy.overdue(presence, now, null) &&
            expected != null &&
            now.isAfter(expected)) {
          return DormAttentionItem(
            user: user,
            presence: presence,
            kind: DormAttentionKind.curfewOverdue,
            title: 'Dönüş saati geçti',
            summary: 'Aktif izni olmadan beklenen dönüş saatini aştı.',
            expectedReturnAt: expected,
            overdueBy: now.difference(expected),
            outsideFor: elapsed,
          );
        }
      }
    }

    if (presence.warnings.isNotEmpty) {
      return DormAttentionItem(
        user: user,
        presence: presence,
        kind: DormAttentionKind.scanWarning,
        title: 'Son okutmada uyarı var',
        summary: presence.warnings.join(' · '),
        outsideFor: presence.inside == false ? elapsed : null,
      );
    }

    return null;
  }

  static List<DormAttentionItem> analyzeAll({
    required List<AppUser> students,
    required Map<String, Presence> presenceById,
    required List<StudentLeave> leaves,
    required DormPolicy policy,
    required DateTime now,
    Set<String> resolvedIncidentKeys = const <String>{},
  }) {
    final Map<String, List<StudentLeave>> byUser = <String, List<StudentLeave>>{};
    for (final StudentLeave l in leaves) {
      byUser.putIfAbsent(l.userId, () => <StudentLeave>[]).add(l);
    }

    final List<DormAttentionItem> items = <DormAttentionItem>[];
    for (final AppUser u in students) {
      final Presence p = presenceById[u.uid] ?? Presence(userId: u.uid);
      final DormAttentionItem? item = evaluateStudent(
        user: u,
        presence: p,
        userLeaves: byUser[u.uid] ?? const <StudentLeave>[],
        policy: policy,
        now: now,
      );
      if (item != null && !resolvedIncidentKeys.contains(item.incidentKey)) {
        items.add(item);
      }
    }

    items.sort((a, b) {
      final int sev = a.severityRank.compareTo(b.severityRank);
      if (sev != 0) return sev;
      final Duration oa = a.overdueBy ?? Duration.zero;
      final Duration ob = b.overdueBy ?? Duration.zero;
      final int od = ob.compareTo(oa);
      if (od != 0) return od;
      return a.user.displayName.compareTo(b.user.displayName);
    });
    return items;
  }

  static DateTime? _expectedCurfewReturn(DormPolicy policy, DateTime exitAt) {
    final DateTime localExit = DormClock.local(exitAt);
    final DormHours h = policy.forDay(localExit);
    if (!h.enabled) return null;
    final int deadlineMin = h.latestEntry + policy.tolerance;
    final DateTime baseDay = DateTime.utc(
      localExit.year,
      localExit.month,
      localExit.day,
    );
    final int exitMin = localExit.hour * 60 + localExit.minute;
    final bool nextDay = h.latestEntry < h.earliestExit || exitMin > deadlineMin;
    final DateTime targetDay = baseDay.add(Duration(days: nextDay ? 1 : 0));
    return DormClock.at(targetDay, deadlineMin);
  }
}
