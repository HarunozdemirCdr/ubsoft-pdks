import 'package:ubsoft_pdks/core/result/result.dart';
import 'package:ubsoft_pdks/domain/entities/app_user.dart';
import 'package:ubsoft_pdks/domain/entities/attendance_day.dart';
import 'package:ubsoft_pdks/domain/entities/attendance_event.dart';
import 'package:ubsoft_pdks/domain/entities/checkpoint.dart';
import 'package:ubsoft_pdks/domain/entities/scan_location.dart';
import 'package:ubsoft_pdks/domain/entities/tenant.dart';
import 'package:ubsoft_pdks/domain/enums/punch_type.dart';
import 'package:ubsoft_pdks/domain/usecases/attendance/verify_location.dart';

/// Devam kayıtları — okutmalar ve günlük özetler.
abstract interface class AttendanceRepository {
  /// Bir okutmayı yazar ve aynı işlemde gün özetini günceller.
  ///
  /// Tek bir Firestore işlemi (transaction) kullanılır: okutma yazılıp özet
  /// yazılamazsa, çalışılan süre kalıcı olarak yanlış kalırdı.
  Future<Result<AttendanceEvent>> recordPunch({
    required Tenant tenant,
    required AppUser user,
    required Checkpoint checkpoint,
    required PunchType type,
    required LocationCheck check,
    required ScanLocation? location,
    Duration cooldown = const Duration(minutes: 1),
  });

  /// Bir kişinin belirli gündeki özeti. Kayıt yoksa boş özet yayınlar.
  Stream<AttendanceDay> watchDay({
    required String tenantId,
    required String userId,
    required String userName,
    required String dateKey,
  });

  /// Bir günün tüm öğrenci özetleri.
  Stream<List<AttendanceDay>> watchDaySummaries({
    required String tenantId,
    required String dateKey,
  });

  /// Bir kişinin tarih aralığındaki günlük özetleri, yeniden eskiye.
  Stream<List<AttendanceDay>> watchUserDays({
    required String tenantId,
    required String userId,
    required String fromKey,
    required String toKey,
  });

  /// Tarih aralığındaki tüm özetler — rapor için tek seferlik okuma.
  Future<Result<List<AttendanceDay>>> fetchDays({
    required String tenantId,
    required String fromKey,
    required String toKey,
    String? userId,
  });

  /// Bir kişinin belirli gündeki okutmaları, saate göre sıralı.
  Stream<List<AttendanceEvent>> watchDayEvents({
    required String tenantId,
    required String userId,
    required String dateKey,
  });

  /// Yanlış bir okutmayı siler ve o günün özetini kalan kayıtlardan yeniden
  /// kurar.
  Future<Result<void>> deleteEvent({
    required Tenant tenant,
    required AttendanceEvent event,
  });
}
