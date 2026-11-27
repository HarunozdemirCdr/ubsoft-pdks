import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubsoft_pdks/application/auth/session_provider.dart';
import 'package:ubsoft_pdks/application/providers.dart';
import 'package:ubsoft_pdks/application/user/user_providers.dart';
import 'package:ubsoft_pdks/data/repositories/dorm_repository.dart';
import 'package:ubsoft_pdks/domain/entities/announcement.dart';
import 'package:ubsoft_pdks/domain/entities/app_user.dart';
import 'package:ubsoft_pdks/domain/entities/attendance_event.dart';
import 'package:ubsoft_pdks/domain/entities/dormitory.dart';
import 'package:ubsoft_pdks/domain/usecases/dorm/dorm_attention.dart';

final dormRepositoryProvider = Provider<DormRepository>(
  (ref) => DormRepository(ref.watch(firestoreProvider)),
);
final dormClockProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream<DateTime>.periodic(
    const Duration(seconds: 15),
    (_) => DateTime.now(),
  );
});
final dormNowProvider = Provider<DateTime>(
  (ref) => ref.watch(dormClockProvider).value ?? DateTime.now(),
);
final studentsProvider = Provider<List<AppUser>>(
  (ref) => ref.watch(activeUsersProvider).where((u) => u.role.isStaff).toList(),
);
final residentsProvider = StreamProvider<List<Presence>>(
  (ref) => ref
      .watch(dormRepositoryProvider)
      .watchResidents(ref.watch(tenantIdProvider)),
);
final myPresenceProvider = StreamProvider<Presence>((ref) {
  final user = ref.watch(
    currentUserProvider.select(
      (u) => u == null ? null : (tenantId: u.tenantId, uid: u.uid),
    ),
  );
  if (user == null) return Stream.value(const Presence(userId: ''));
  return ref
      .watch(dormRepositoryProvider)
      .watchPresence(user.tenantId, user.uid);
});
final dormLeavesProvider = StreamProvider<List<StudentLeave>>((ref) {
  final user = ref.watch(
    currentUserProvider.select(
      (u) => u == null
          ? null
          : (tenantId: u.tenantId, uid: u.uid, student: u.role.isStaff),
    ),
  );
  if (user == null) return Stream.value(const <StudentLeave>[]);
  return ref
      .watch(dormRepositoryProvider)
      .watchLeaves(user.tenantId, uid: user.student ? user.uid : null);
});
typedef MovementQuery = ({String from, String to, String? uid});
final recentMovementsProvider = StreamProvider<List<AttendanceEvent>>((ref) {
  final user = ref.watch(
    currentUserProvider.select(
      (u) => u == null ? null : (tenantId: u.tenantId, uid: u.uid),
    ),
  );
  if (user == null) return Stream.value(const <AttendanceEvent>[]);
  return ref.watch(dormRepositoryProvider).watchRecentEvents(user.tenantId);
});
final movementsProvider =
    StreamProvider.family<List<AttendanceEvent>, MovementQuery>((ref, query) {
      final user = ref.watch(
        currentUserProvider.select(
          (u) => u == null
              ? null
              : (tenantId: u.tenantId, uid: u.uid, student: u.role.isStaff),
        ),
      );
      if (user == null) return Stream.value(const <AttendanceEvent>[]);
      return ref
          .watch(dormRepositoryProvider)
          .watchEvents(
            user.tenantId,
            query.from,
            query.to,
            uid: user.student ? user.uid : query.uid,
          );
    });
StudentLeave? leaveAt(List<StudentLeave> leaves, String uid, DateTime at) {
  for (final leave in leaves) {
    if (leave.userId == uid && leave.covers(at)) return leave;
  }
  return null;
}

StudentLeave? relevantLeave(
  List<StudentLeave> leaves,
  Presence p,
  DateTime now,
) {
  final current = leaveAt(leaves, p.userId, now);
  if (current != null) return current;
  final candidates =
      leaves
          .where(
            (l) =>
                l.userId == p.userId &&
                !l.revoked &&
                p.at != null &&
                !l.until.isBefore(p.at!) &&
                !l.from.isAfter(now),
          )
          .toList()
        ..sort((a, b) => b.until.compareTo(a.until));
  return candidates.isEmpty ? null : candidates.first;
}

/// Yurt duyuruları akışı.
final dormAnnouncementsProvider = StreamProvider<List<DormAnnouncement>>((ref) {
  final String tid = ref.watch(tenantIdProvider);
  if (tid.isEmpty) return Stream.value(const <DormAnnouncement>[]);
  return ref.watch(dormRepositoryProvider).watchAnnouncements(tid);
});

/// Mevcut kullanıcının okuduğu duyuru kimlikleri.
final myAnnouncementReadsProvider = StreamProvider<Set<String>>((ref) {
  final user = ref.watch(
    currentUserProvider.select(
      (u) => u == null ? null : (tenantId: u.tenantId, uid: u.uid),
    ),
  );
  if (user == null) return Stream.value(const <String>{});
  return ref
      .watch(dormRepositoryProvider)
      .watchReadAnnouncementIds(user.tenantId, user.uid);
});

/// Kullanıcının kendisini ilgilendiren duyuruları.
final visibleAnnouncementsProvider = Provider<List<DormAnnouncement>>((ref) {
  final AppUser? user = ref.watch(currentUserProvider);
  if (user == null) return const <DormAnnouncement>[];
  final List<DormAnnouncement> all =
      ref.watch(dormAnnouncementsProvider).value ?? const <DormAnnouncement>[];
  return all.where((a) => a.appliesTo(user)).toList(growable: false);
});

/// Öğrencinin henüz görmediği (okumadığı) duyuru sayısı — menüdeki kırmızı rozet.
final unreadAnnouncementsCountProvider = Provider<int>((ref) {
  final AppUser? user = ref.watch(currentUserProvider);
  if (user == null || !user.role.isStaff) return 0;
  final List<DormAnnouncement> visible = ref.watch(
    visibleAnnouncementsProvider,
  );
  final Set<String> readIds =
      ref.watch(myAnnouncementReadsProvider).value ?? const <String>{};
  return visible.where((a) => !readIds.contains(a.id)).length;
});

/// Yönetici için dikkat edilmesi gereken tüm yurt durumları (izni bitip
/// dönmeyenler, dönüşü gecikenler, saat/konum uyarıları, kayıtsızlar).
final dormAttentionItemsProvider = Provider<List<DormAttentionItem>>((ref) {
  final tenant = ref.watch(currentTenantProvider);
  if (tenant == null) return const <DormAttentionItem>[];
  final List<AppUser> students = ref.watch(studentsProvider);
  final List<Presence> states =
      ref.watch(residentsProvider).value ?? const <Presence>[];
  final List<StudentLeave> leaves =
      ref.watch(dormLeavesProvider).value ?? const <StudentLeave>[];
  final DateTime now = ref.watch(dormNowProvider);
  final Map<String, Presence> byId = <String, Presence>{
    for (final Presence p in states) p.userId: p,
  };
  return DormAttentionAnalyzer.analyzeAll(
    students: students,
    presenceById: byId,
    leaves: leaves,
    policy: tenant.settings.dormPolicy,
    now: now,
  );
});

/// Menüde rozet olarak gösterilen kritik/dikkat gerektiren durum sayısı.
final dormAttentionCountProvider = Provider<int>(
  (ref) => ref.watch(dormAttentionItemsProvider).length,
);
