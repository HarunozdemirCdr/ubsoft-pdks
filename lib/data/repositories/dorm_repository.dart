import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ubsoft_pdks/core/error/failure.dart';
import 'package:ubsoft_pdks/core/result/result.dart';
import 'package:ubsoft_pdks/data/mappers/attendance_mapper.dart';
import 'package:ubsoft_pdks/data/mappers/tenant_mapper.dart';
import 'package:ubsoft_pdks/data/repositories/firestore_repository_base.dart';
import 'package:ubsoft_pdks/domain/entities/app_user.dart';
import 'package:ubsoft_pdks/domain/entities/attendance_day.dart';
import 'package:ubsoft_pdks/domain/entities/attendance_event.dart';
import 'package:ubsoft_pdks/domain/entities/checkpoint.dart';
import 'package:ubsoft_pdks/domain/entities/dormitory.dart';
import 'package:ubsoft_pdks/domain/entities/scan_location.dart';
import 'package:ubsoft_pdks/domain/entities/tenant.dart';
import 'package:ubsoft_pdks/domain/enums/punch_type.dart';
import 'package:ubsoft_pdks/domain/usecases/attendance/resolve_punch.dart';
import 'package:ubsoft_pdks/domain/usecases/attendance/summarize_day.dart';
import 'package:ubsoft_pdks/domain/usecases/attendance/verify_location.dart';

final class DormRepository extends FirestoreRepositoryBase {
  const DormRepository(super.firestore);
  static DateTime? _date(dynamic v) => v is Timestamp ? v.toDate() : null;
  static Presence presence(String uid, Map<String, dynamic>? data) {
    final Map<String, dynamic> m = data ?? <String, dynamic>{};
    return Presence(
      userId: uid,
      inside: m['inside'] as bool?,
      at: _date(m['at']),
      eventId: m['eventId'] as String?,
      checkpoint: m['checkpoint'] as String? ?? '',
      lateMinutes: (m['lateMinutes'] as num?)?.toInt() ?? 0,
      earlyExit: m['earlyExit'] == true,
      earlyEntry: m['earlyEntry'] == true,
      permitted: m['permitted'] == true,
    );
  }

  static StudentLeave leave(String id, Map<String, dynamic> m) => StudentLeave(
    id: id,
    userId: m['userId'] as String,
    from: _date(m['from'])!,
    until: _date(m['until'])!,
    reason: m['reason'] as String? ?? '',
    revoked: m['revoked'] == true,
  );
  Stream<Presence> watchPresence(String tid, String uid) => guardStream(
    subcollection(
      tid,
      'presence',
    ).doc(uid).snapshots().map((d) => presence(uid, d.data())),
  );
  Stream<List<Presence>> watchResidents(String tid) => guardStream(
    subcollection(tid, 'presence').snapshots().map(
      (q) => q.docs.map((d) => presence(d.id, d.data())).toList(),
    ),
  );
  Stream<List<StudentLeave>> watchLeaves(String tid, {String? uid}) {
    Query<Map<String, dynamic>> query = subcollection(tid, 'leaves');
    if (uid != null) query = query.where('userId', isEqualTo: uid);
    return guardStream(
      query.snapshots().map(
        (q) => q.docs.map((d) => leave(d.id, d.data())).toList(),
      ),
    );
  }

  Stream<List<AttendanceEvent>> watchEvents(
    String tid,
    String from,
    String to, {
    String? uid,
  }) {
    Query<Map<String, dynamic>> q = subcollection(
      tid,
      'attendance',
    ).where('dateKey', isGreaterThanOrEqualTo: from, isLessThanOrEqualTo: to);
    if (uid != null) q = q.where('userId', isEqualTo: uid);
    return guardStream(
      q.snapshots().map(
        (s) =>
            s.docs
                .where((d) => d.data()['voided'] != true)
                .map(AttendanceEventMapper.fromDoc)
                .toList()
              ..sort((a, b) => b.at.compareTo(a.at)),
      ),
    );
  }

  Future<Result<void>> saveLeave(
    String tid,
    StudentLeave value,
    String actor,
  ) => guardVoid(() async {
    if (!value.until.isAfter(value.from) || value.reason.trim().isEmpty) {
      throw const ValidationFailure(
        'İzin bitişi başlangıçtan sonra olmalı ve açıklama girilmeli.',
      );
    }
    final DocumentReference<Map<String, dynamic>> lock = subcollection(
      tid,
      'leaveLocks',
    ).doc(value.userId);
    final DocumentReference<Map<String, dynamic>> doc = subcollection(
      tid,
      'leaves',
    ).doc();
    await firestore.runTransaction((tx) async {
      final current = await tx.get(lock);
      final DateTime? end = _date(current.data()?['until']);
      final DateTime? start = _date(current.data()?['from']);
      if (end != null &&
          start != null &&
          !value.from.isAfter(end) &&
          !value.until.isBefore(start)) {
        throw const ConflictFailure(
          'Bu aralıkla çakışan bir izin var. Önce mevcut izni iptal edin.',
        );
      }
      // Tek aktif/gelecek izin; iptal edilenler geçmişte saklanır.
      if (end != null && end.isAfter(DateTime.now())) {
        throw const ConflictFailure(
          'Öğrencinin aktif veya gelecek izni var. Önce onu iptal edin.',
        );
      }
      final body = <String, Object?>{
        'userId': value.userId,
        'from': Timestamp.fromDate(value.from),
        'until': Timestamp.fromDate(value.until),
        'reason': value.reason.trim(),
        'revoked': false,
        'actor': actor,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      tx
        ..set(doc, <String, Object?>{
          ...body,
          'createdAt': FieldValue.serverTimestamp(),
        })
        ..set(lock, <String, Object?>{...body, 'leaveId': doc.id});
    });
  });
  Future<Result<void>> revokeLeave(
    String tid,
    StudentLeave value,
    String actor,
  ) => guardVoid(() async {
    final lock = subcollection(tid, 'leaveLocks').doc(value.userId);
    await firestore.runTransaction((tx) async {
      final current = await tx.get(lock);
      tx.update(subcollection(tid, 'leaves').doc(value.id), <String, Object?>{
        'revoked': true,
        'revokedBy': actor,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (current.data()?['leaveId'] == value.id) tx.delete(lock);
    });
  });
  Future<Result<void>> initializePresence(
    String tid,
    String uid,
    String actor,
    String reason, {
    required bool inside,
  }) => guardVoid(() async {
    if (reason.trim().isEmpty) {
      throw const ValidationFailure('Başlangıç durumu için açıklama girin.');
    }
    final doc = subcollection(tid, 'presence').doc(uid);
    await firestore.runTransaction((tx) async {
      final before = await tx.get(doc);
      if (before.data()?['inside'] != null) {
        throw const ConflictFailure(
          'Öğrencinin durumu zaten biliniyor. Yanlış hareketi gerekçesiyle geçersiz kılın.',
        );
      }
      final audit = subcollection(tid, 'presenceAudit').doc();
      tx
        ..set(audit, <String, Object?>{
          'userId': uid,
          'inside': inside,
          'reason': reason.trim(),
          'actor': actor,
          'at': FieldValue.serverTimestamp(),
        })
        ..set(doc, <String, Object?>{
          'userId': uid,
          'inside': inside,
          'at': FieldValue.serverTimestamp(),
          'eventId': audit.id,
          'checkpoint': 'Başlangıç durumu',
          'revision': 1,
          'initializedBy': actor,
        });
    });
  });

  Future<Result<AttendanceEvent>> record({
    required Tenant tenant,
    required AppUser user,
    required Checkpoint checkpoint,
    required LocationCheck check,
    required ScanLocation? location,
    Duration cooldown = const Duration(minutes: 1),
  }) => guard(() async {
    if (!user.role.isStaff) {
      throw const PermissionFailure(
        message: 'Giriş–çıkış yalnız öğrenciler içindir.',
      );
    }
    if (checkpoint.kind.isBoth) {
      throw const PunchFailure(
        'Bu QR ortak giriş–çıkış kodudur. Yöneticinizden ayrı giriş ve çıkış QR kodları isteyin.',
      );
    }
    final DateTime now = DateTime.now();
    final String dateKey = DormClock.key(now);
    final eventDoc = subcollection(tenant.id, 'attendance').doc();
    final stateDoc = subcollection(tenant.id, 'presence').doc(user.uid);
    final dayDoc = subcollection(
      tenant.id,
      'attendanceDays',
    ).doc('${user.uid}_$dateKey');
    AttendanceEvent? written;
    await firestore.runTransaction((tx) async {
      final state = await tx.get(stateDoc);
      final day = await tx.get(dayDoc);
      final liveCheckpoint = await tx.get(
        subcollection(tenant.id, 'checkpoints').doc(checkpoint.id),
      );
      final liveTenant = await tx.get(tenantRef(tenant.id));
      final lock = await tx.get(
        subcollection(tenant.id, 'leaveLocks').doc(user.uid),
      );
      if (!liveCheckpoint.exists ||
          liveCheckpoint.data()?['active'] != true ||
          liveCheckpoint.data()?['kind'] != checkpoint.kind.key ||
          liveCheckpoint.data()?['code'] != checkpoint.code ||
          liveCheckpoint.data()?['latitude'] != checkpoint.latitude ||
          liveCheckpoint.data()?['longitude'] != checkpoint.longitude ||
          liveCheckpoint.data()?['radiusMeters'] != checkpoint.radiusMeters) {
        throw const ConflictFailure(
          'QR noktası değişmiş. Lütfen yeniden okutun.',
        );
      }
      final Tenant currentTenant = TenantMapper.fromDoc(liveTenant);
      final Presence before = presence(user.uid, state.data());
      final PunchType type = checkpoint.kind.fixedType!;
      if (cooldown > Duration.zero &&
          before.at != null &&
          now.difference(before.at!) < cooldown) {
        throw const PunchFailure(
          'Kaydınız az önce alındı. Tekrar okutmanıza gerek yok.',
          code: 'too-soon',
        );
      }
      if (before.inside != null && before.inside == type.isEntry) {
        throw PunchFailure(
          type.isEntry
              ? 'Zaten içeridesiniz. Çıkarken çıkış QR kodunu okutun.'
              : 'Zaten dışarıdasınız. Döndüğünüzde giriş QR kodunu okutun.',
        );
      }
      final resolution = ResolvePunch.call(
        checkpoint: checkpoint,
        today: AttendanceDay.empty(
          tenantId: tenant.id,
          userId: user.uid,
          userName: user.displayName,
          dateKey: dateKey,
        ).copyWith(open: before.inside ?? type.isExit),
        settings: currentTenant.settings,
        location: check,
        cooldown: Duration.zero,
      );
      if (resolution is PunchRejected) throw resolution.failure;
      final StudentLeave? permitted = lock.exists
          ? leave(lock.id, lock.data()!)
          : null;
      final metadata = currentTenant.settings.dormPolicy.evaluate(
        now,
        entry: type.isEntry,
        leave: permitted,
        departedAt: before.inside == false ? before.at : null,
      );
      final event = AttendanceEvent(
        id: eventDoc.id,
        tenantId: tenant.id,
        userId: user.uid,
        userName: user.displayName,
        type: type,
        at: now,
        dateKey: dateKey,
        checkpointId: checkpoint.id,
        checkpointName: checkpoint.name,
        checkpointCode: checkpoint.code,
        verdict: check.verdict,
        location: location,
        distanceMeters: check.distanceMeters,
        radiusMeters: check.radiusMeters,
        lateMinutes: metadata['lateMinutes']! as int,
        earlyExit: metadata['earlyExit']! as bool,
        earlyEntry: metadata['earlyEntry']! as bool,
        permitted: metadata['permitted']! as bool,
      );
      final AttendanceDay base = day.exists
          ? AttendanceDayMapper.fromDoc(day)
          : AttendanceDay.empty(
              tenantId: tenant.id,
              userId: user.uid,
              userName: user.displayName,
              dateKey: dateKey,
            );
      final AttendanceDay after = SummarizeDay.applyPunch(
        day: base,
        type: type,
        at: now,
        verdict: check.verdict,
        userName: user.displayName,
        settings: currentTenant.settings,
      );
      tx
        ..set(eventDoc, <String, Object?>{
          ...AttendanceEventMapper.toCreateMap(event),
          ...metadata,
          'voided': false,
          'schemaVersion': 2,
        })
        ..set(dayDoc, AttendanceDayMapper.toMap(after))
        ..set(stateDoc, <String, Object?>{
          'userId': user.uid,
          'inside': type.isEntry,
          'eventId': eventDoc.id,
          'at': FieldValue.serverTimestamp(),
          'checkpoint': checkpoint.name,
          'revision': ((state.data()?['revision'] as num?)?.toInt() ?? 0) + 1,
          ...metadata,
        });
      written = event;
    });
    return written!;
  });

  Future<Result<void>> voidEvent(
    Tenant tenant,
    AttendanceEvent event,
    String actor,
    String reason,
  ) => guardVoid(() async {
    if (reason.trim().isEmpty) {
      throw const ValidationFailure('Geçersiz kılma gerekçesi girin.');
    }
    final stateDoc = subcollection(tenant.id, 'presence').doc(event.userId);
    final observed = await stateDoc.get();
    final revision = observed.data()?['revision'];
    final all = await subcollection(
      tenant.id,
      'attendance',
    ).where('userId', isEqualTo: event.userId).get();
    final valid =
        all.docs
            .where((d) => d.id != event.id && d.data()['voided'] != true)
            .toList()
          ..sort(
            (a, b) => AttendanceEventMapper.fromDoc(
              a,
            ).at.compareTo(AttendanceEventMapper.fromDoc(b).at),
          );
    final events = valid.map(AttendanceEventMapper.fromDoc).toList();
    final summary = SummarizeDay.rebuild(
      base: AttendanceDay.empty(
        tenantId: tenant.id,
        userId: event.userId,
        userName: event.userName,
        dateKey: event.dateKey,
      ),
      events: events.where((e) => e.dateKey == event.dateKey).toList(),
      settings: tenant.settings,
    );
    await firestore.runTransaction((tx) async {
      final current = await tx.get(stateDoc);
      final target = await tx.get(
        subcollection(tenant.id, 'attendance').doc(event.id),
      );
      if (current.data()?['revision'] != revision ||
          target.data()?['voided'] == true) {
        throw const ConflictFailure(
          'Bu sırada yeni bir hareket oluştu. Sayfayı yenileyip tekrar deneyin.',
        );
      }
      tx
        ..update(target.reference, <String, Object?>{
          'voided': true,
          'voidReason': reason.trim(),
          'voidedBy': actor,
          'voidedAt': FieldValue.serverTimestamp(),
        })
        ..set(
          subcollection(tenant.id, 'attendanceDays').doc(summary.id),
          AttendanceDayMapper.toMap(summary),
        );
      if (current.data()?['eventId'] == event.id) {
        final last = valid.isEmpty ? null : valid.last;
        tx.set(stateDoc, <String, Object?>{
          'userId': event.userId,
          'inside': last == null ? null : last.data()['type'] == 'in',
          'eventId': last?.id,
          'at': last?.data()['at'],
          'checkpoint': last?.data()['checkpointName'] ?? '',
          'revision': ((revision as num?)?.toInt() ?? 0) + 1,
          'lateMinutes': last?.data()['lateMinutes'] ?? 0,
          'earlyExit': last?.data()['earlyExit'] ?? false,
          'earlyEntry': last?.data()['earlyEntry'] ?? false,
        });
      } else {
        tx.update(stateDoc, <String, Object?>{
          'revision': ((revision as num?)?.toInt() ?? 0) + 1,
        });
      }
    });
  });
}
