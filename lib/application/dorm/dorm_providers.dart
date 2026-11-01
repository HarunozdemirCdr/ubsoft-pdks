import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubsoft_pdks/application/auth/session_provider.dart';
import 'package:ubsoft_pdks/application/providers.dart';
import 'package:ubsoft_pdks/application/user/user_providers.dart';
import 'package:ubsoft_pdks/data/repositories/dorm_repository.dart';
import 'package:ubsoft_pdks/domain/entities/app_user.dart';
import 'package:ubsoft_pdks/domain/entities/attendance_event.dart';
import 'package:ubsoft_pdks/domain/entities/dormitory.dart';

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
