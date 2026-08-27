import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ubsoft_pdks/data/mappers/firestore_converters.dart';
import 'package:ubsoft_pdks/domain/entities/attendance_day.dart';
import 'package:ubsoft_pdks/domain/entities/attendance_event.dart';
import 'package:ubsoft_pdks/domain/entities/scan_location.dart';
import 'package:ubsoft_pdks/domain/enums/location_verdict.dart';
import 'package:ubsoft_pdks/domain/enums/punch_type.dart';

/// `tenants/{tid}/attendance/{id}` ↔ [AttendanceEvent].
abstract final class AttendanceEventMapper {
  static AttendanceEvent fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      fromMap(doc.data() ?? <String, dynamic>{}, id: doc.id);

  static AttendanceEvent fromMap(
    Map<String, dynamic> data, {
    required String id,
  }) {
    final Map<String, dynamic> loc = data.nested('location');

    return AttendanceEvent(
      id: id,
      tenantId: data.str('tenantId'),
      userId: data.str('userId'),
      userName: data.str('userName'),
      type: PunchType.fromKey(data.strOrNull('type')),
      at: data.dateTime('at'),
      dateKey: data.str('dateKey'),
      checkpointId: data.str('checkpointId'),
      checkpointName: data.str('checkpointName'),
      checkpointCode: data.str('checkpointCode'),
      location: loc.isEmpty
          ? null
          : ScanLocation(
              latitude: _double(loc['latitude']),
              longitude: _double(loc['longitude']),
              accuracy: _doubleOrNull(loc['accuracy']),
              capturedAt: loc.dateTimeOrNull('capturedAt'),
            ),
      distanceMeters: _doubleOrNull(data['distanceMeters']),
      radiusMeters: data.integerOrNull('radiusMeters'),
      verdict: LocationVerdict.fromKey(data.strOrNull('verdict')),
    );
  }

  /// Yeni okutma gövdesi.
  ///
  /// `at` alanı bilinçli olarak **sunucu zaman damgasıdır**: telefonun
  /// saatini geri alarak erken giriş yazdırmak aksi hâlde mümkün olurdu.
  /// Güvenlik kuralı da bu alanın `request.time` olmasını şart koşar.
  static Map<String, Object?> toCreateMap(AttendanceEvent event) {
    final ScanLocation? location = event.location;

    return <String, Object?>{
      'tenantId': event.tenantId,
      'userId': event.userId,
      'userName': event.userName,
      'type': event.type.key,
      'at': FirestoreWrite.serverTime,
      'dateKey': event.dateKey,
      'checkpointId': event.checkpointId,
      'checkpointName': event.checkpointName,
      'checkpointCode': event.checkpointCode,
      'verdict': event.verdict.key,
      if (event.distanceMeters != null) 'distanceMeters': event.distanceMeters,
      if (event.radiusMeters != null) 'radiusMeters': event.radiusMeters,
      if (location != null)
        'location': <String, Object?>{
          'latitude': location.latitude,
          'longitude': location.longitude,
          if (location.accuracy != null) 'accuracy': location.accuracy,
          if (location.capturedAt != null)
            'capturedAt': Timestamp.fromDate(location.capturedAt!),
        },
    };
  }

  static double _double(Object? value) => _doubleOrNull(value) ?? 0;

  static double? _doubleOrNull(Object? value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return null;
  }
}

/// `tenants/{tid}/attendanceDays/{uid}_{dateKey}` ↔ [AttendanceDay].
abstract final class AttendanceDayMapper {
  static AttendanceDay fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      fromMap(doc.data() ?? <String, dynamic>{}, id: doc.id);

  static AttendanceDay fromMap(
    Map<String, dynamic> data, {
    required String id,
  }) => AttendanceDay(
    id: id,
    tenantId: data.str('tenantId'),
    userId: data.str('userId'),
    userName: data.str('userName'),
    dateKey: data.str('dateKey'),
    firstEntryAt: data.dateTimeOrNull('firstEntryAt'),
    lastEntryAt: data.dateTimeOrNull('lastEntryAt'),
    lastExitAt: data.dateTimeOrNull('lastExitAt'),
    entryCount: data.integer('entryCount'),
    exitCount: data.integer('exitCount'),
    workedMinutes: data.integer('workedMinutes'),
    open: data.boolean('open'),
    late: data.boolean('late'),
    worstVerdict: LocationVerdict.fromKey(data.strOrNull('worstVerdict')),
    updatedAt: data.dateTimeOrNull('updatedAt'),
  );

  static Map<String, Object?> toMap(AttendanceDay day) => <String, Object?>{
    'tenantId': day.tenantId,
    'userId': day.userId,
    'userName': day.userName,
    'dateKey': day.dateKey,
    'firstEntryAt': FirestoreWrite.timestamp(day.firstEntryAt),
    'lastEntryAt': FirestoreWrite.timestamp(day.lastEntryAt),
    'lastExitAt': FirestoreWrite.timestamp(day.lastExitAt),
    'entryCount': day.entryCount,
    'exitCount': day.exitCount,
    'workedMinutes': day.workedMinutes,
    'open': day.open,
    'late': day.late,
    'worstVerdict': day.worstVerdict.key,
    'updatedAt': FirestoreWrite.serverTime,
  };
}
