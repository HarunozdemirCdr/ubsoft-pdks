import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ubsoft_pdks/core/config/firebase_collections.dart';
import 'package:ubsoft_pdks/core/result/result.dart';
import 'package:ubsoft_pdks/core/utils/date_x.dart';
import 'package:ubsoft_pdks/data/mappers/attendance_mapper.dart';
import 'package:ubsoft_pdks/data/repositories/firestore_repository_base.dart';
import 'package:ubsoft_pdks/domain/entities/app_user.dart';
import 'package:ubsoft_pdks/domain/entities/attendance_day.dart';
import 'package:ubsoft_pdks/domain/entities/attendance_event.dart';
import 'package:ubsoft_pdks/domain/entities/checkpoint.dart';
import 'package:ubsoft_pdks/domain/entities/scan_location.dart';
import 'package:ubsoft_pdks/domain/entities/tenant.dart';
import 'package:ubsoft_pdks/domain/enums/punch_type.dart';
import 'package:ubsoft_pdks/domain/repositories/attendance_repository.dart';
import 'package:ubsoft_pdks/domain/usecases/attendance/summarize_day.dart';
import 'package:ubsoft_pdks/domain/usecases/attendance/verify_location.dart';

/// Firestore tabanlı devam kayıtları.
///
/// ## Zaman damgaları
///
/// Okutmanın `at` alanı **sunucu saatidir** (`serverTimestamp`), güvenlik
/// kuralı da bunu şart koşar: telefonun saatini geri alarak erken giriş
/// yazdırmak aksi hâlde mümkün olurdu.
///
/// Çalışılan sürenin toplanmasında ise istemci saati kullanılır — bir
/// işlem (transaction) içinde sunucunun o anki saati okunamaz. Etkisi
/// yalnız **süre farkındadır**: giriş ve çıkış saatleri her zaman doğrudur,
/// yalnız aradaki dakika hesabı cihaz saatinin kayması kadar sapabilir.
/// Yönetici bir okutmayı sildiğinde gün özeti gerçek sunucu damgalarından
/// sıfırdan kurulur ([SummarizeDay.rebuild]) ve sapma temizlenir.
final class AttendanceRepositoryImpl extends FirestoreRepositoryBase
    implements AttendanceRepository {
  const AttendanceRepositoryImpl(super.firestore);

  CollectionReference<Map<String, dynamic>> _events(String tenantId) =>
      subcollection(tenantId, FsPaths.attendance);

  CollectionReference<Map<String, dynamic>> _days(String tenantId) =>
      subcollection(tenantId, FsPaths.attendanceDays);

  @override
  Future<Result<AttendanceEvent>> recordPunch({
    required Tenant tenant,
    required AppUser user,
    required Checkpoint checkpoint,
    required PunchType type,
    required LocationCheck check,
    required ScanLocation? location,
  }) => guard(() async {
    final DateTime now = DateTime.now();
    final String dateKey = AppDate.dateKey(now);
    final String dayId = AttendanceDay.buildId(
      userId: user.uid,
      dateKey: dateKey,
    );

    final DocumentReference<Map<String, dynamic>> eventDoc = _events(
      tenant.id,
    ).doc();
    final DocumentReference<Map<String, dynamic>> dayDoc = _days(
      tenant.id,
    ).doc(dayId);

    final AttendanceEvent event = AttendanceEvent(
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
      location: location,
      distanceMeters: check.distanceMeters,
      radiusMeters: check.radiusMeters,
      verdict: check.verdict,
    );

    await firestore.runTransaction((Transaction transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> current = await transaction
          .get(dayDoc);

      final AttendanceDay before = current.exists
          ? AttendanceDayMapper.fromDoc(current)
          : AttendanceDay.empty(
              tenantId: tenant.id,
              userId: user.uid,
              userName: user.displayName,
              dateKey: dateKey,
            );

      final AttendanceDay after = SummarizeDay.applyPunch(
        day: before,
        type: type,
        at: now,
        verdict: check.verdict,
        userName: user.displayName,
        settings: tenant.settings,
      );

      transaction
        ..set(eventDoc, AttendanceEventMapper.toCreateMap(event))
        ..set(dayDoc, AttendanceDayMapper.toMap(after));
    });

    return event;
  });

  @override
  Stream<AttendanceDay> watchDay({
    required String tenantId,
    required String userId,
    required String userName,
    required String dateKey,
  }) => guardStream(
    _days(tenantId)
        .doc(AttendanceDay.buildId(userId: userId, dateKey: dateKey))
        .snapshots()
        .map(
          (DocumentSnapshot<Map<String, dynamic>> doc) => doc.exists
              ? AttendanceDayMapper.fromDoc(doc)
              : AttendanceDay.empty(
                  tenantId: tenantId,
                  userId: userId,
                  userName: userName,
                  dateKey: dateKey,
                ),
        ),
  );

  @override
  Stream<List<AttendanceDay>> watchDaySummaries({
    required String tenantId,
    required String dateKey,
  }) => guardStream(
    _days(
      tenantId,
    ).where(FsFields.dateKey, isEqualTo: dateKey).snapshots().map(_mapDays),
  );

  @override
  Stream<List<AttendanceDay>> watchUserDays({
    required String tenantId,
    required String userId,
    required String fromKey,
    required String toKey,
  }) => guardStream(
    _days(tenantId)
        .where(FsFields.userId, isEqualTo: userId)
        .where(
          FsFields.dateKey,
          isGreaterThanOrEqualTo: fromKey,
          isLessThanOrEqualTo: toKey,
        )
        .orderBy(FsFields.dateKey, descending: true)
        .snapshots()
        .map(_mapDays),
  );

  @override
  Future<Result<List<AttendanceDay>>> fetchDays({
    required String tenantId,
    required String fromKey,
    required String toKey,
    String? userId,
  }) => guard(() async {
    Query<Map<String, dynamic>> query = _days(tenantId).where(
      FsFields.dateKey,
      isGreaterThanOrEqualTo: fromKey,
      isLessThanOrEqualTo: toKey,
    );

    if (userId != null && userId.isNotEmpty) {
      query = query.where(FsFields.userId, isEqualTo: userId);
    }

    final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();
    return _mapDays(snapshot);
  });

  @override
  Stream<List<AttendanceEvent>> watchDayEvents({
    required String tenantId,
    required String userId,
    required String dateKey,
  }) => guardStream(
    _events(tenantId)
        .where(FsFields.userId, isEqualTo: userId)
        .where(FsFields.dateKey, isEqualTo: dateKey)
        .snapshots()
        .map(_mapEvents),
  );

  @override
  Future<Result<void>> deleteEvent({
    required Tenant tenant,
    required AttendanceEvent event,
  }) => guardVoid(() async {
    await _events(tenant.id).doc(event.id).delete();

    // Silmeden sonra gün özeti, kalan okutmalardan **sıfırdan** kurulur.
    // Artımlı bir düzeltme (ör. sayacı bir azalt) yetmez: silinen kayıt bir
    // giriş ise ardındaki çıkışla eşleşen süre de geçersiz kalır.
    //
    // Sorgu bir işlem (transaction) içinde çalıştırılamaz; bu yüzden önce
    // silinir, sonra yeniden hesaplanır. Arada bir hata olursa özet eski
    // hâlinde kalır — kayıt kaybolmaz, yalnız yeniden hesaplanmayı bekler.
    final QuerySnapshot<Map<String, dynamic>> remaining =
        await _events(tenant.id)
            .where(FsFields.userId, isEqualTo: event.userId)
            .where(FsFields.dateKey, isEqualTo: event.dateKey)
            .get();

    final String dayId = AttendanceDay.buildId(
      userId: event.userId,
      dateKey: event.dateKey,
    );

    final AttendanceDay rebuilt = SummarizeDay.rebuild(
      base: AttendanceDay.empty(
        tenantId: tenant.id,
        userId: event.userId,
        userName: event.userName,
        dateKey: event.dateKey,
      ),
      events: _mapEvents(remaining),
      settings: tenant.settings,
    );

    await _days(tenant.id).doc(dayId).set(AttendanceDayMapper.toMap(rebuilt));
  });

  List<AttendanceDay> _mapDays(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final List<AttendanceDay> days =
        snapshot.docs.map(AttendanceDayMapper.fromDoc).toList()
          ..sort((AttendanceDay a, AttendanceDay b) {
            final int byDate = b.dateKey.compareTo(a.dateKey);
            return byDate != 0 ? byDate : a.userName.compareTo(b.userName);
          });
    return List<AttendanceDay>.unmodifiable(days);
  }

  List<AttendanceEvent> _mapEvents(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    // Sıralama istemcide yapılır: sunucu tarafında sıralamak `dateKey` +
    // `at` üzerinde ek bir bileşik indeks gerektirirdi ve bir günün okutma
    // sayısı zaten onlarla ölçülür.
    final List<AttendanceEvent> events =
        snapshot.docs.map(AttendanceEventMapper.fromDoc).toList()..sort(
          (AttendanceEvent a, AttendanceEvent b) => a.at.compareTo(b.at),
        );
    return List<AttendanceEvent>.unmodifiable(events);
  }
}
