import 'package:flutter/material.dart';
import 'package:ubsoft_pdks/domain/enums/day_status.dart';
import 'package:ubsoft_pdks/domain/enums/location_verdict.dart';
import 'package:ubsoft_pdks/domain/enums/punch_type.dart';
import 'package:ubsoft_pdks/domain/enums/tenant_status.dart';
import 'package:ubsoft_pdks/domain/enums/user_status.dart';
import 'package:ubsoft_pdks/presentation/widgets/status_chip.dart';

/// Enum degerlerinin arayuz karsiliklari — renk tonu ve ikon.
///
/// Tek yerde durur ki ayni durum uygulamanin her yerinde ayni renkte ve ayni
/// ikonla gorunsun.
abstract final class EnumLabels {
  static StatusTone toneOf(DayStatus status) => switch (status) {
    DayStatus.present => StatusTone.info,
    DayStatus.completed => StatusTone.success,
    DayStatus.missingExit => StatusTone.warning,
    DayStatus.absent => StatusTone.neutral,
  };

  static IconData iconOf(DayStatus status) => switch (status) {
    DayStatus.present => Icons.login_rounded,
    DayStatus.completed => Icons.check_circle_outline_rounded,
    DayStatus.missingExit => Icons.error_outline_rounded,
    DayStatus.absent => Icons.remove_circle_outline_rounded,
  };

  static StatusTone toneOfVerdict(LocationVerdict verdict) => switch (verdict) {
    LocationVerdict.verified => StatusTone.success,
    LocationVerdict.borderline => StatusTone.warning,
    LocationVerdict.outside => StatusTone.danger,
    LocationVerdict.unavailable => StatusTone.neutral,
  };

  static IconData iconOfVerdict(LocationVerdict verdict) => switch (verdict) {
    LocationVerdict.verified => Icons.location_on_rounded,
    LocationVerdict.borderline => Icons.location_searching_rounded,
    LocationVerdict.outside => Icons.wrong_location_rounded,
    LocationVerdict.unavailable => Icons.location_off_rounded,
  };

  static IconData iconOfPunch(PunchType type) =>
      type.isEntry ? Icons.login_rounded : Icons.logout_rounded;

  /// Giriş yeşil, çıkış kırmızı.
  ///
  /// Kırmızı burada "hata" demek değildir; çıkış tamamen normaldir. Yön
  /// çiftinin okunabilirliği için bilinçli olarak zıt iki renk seçildi ve
  /// uygulamanın her yerinde aynı çift kullanılır.
  static StatusTone toneOfPunch(PunchType type) =>
      type.isEntry ? StatusTone.success : StatusTone.danger;

  static StatusTone toneOfUser(UserStatus status) => switch (status) {
    UserStatus.active => StatusTone.success,
    UserStatus.inactive => StatusTone.neutral,
    UserStatus.deleted => StatusTone.danger,
  };

  static StatusTone toneOfTenant(TenantStatus status) => switch (status) {
    TenantStatus.active => StatusTone.success,
    TenantStatus.suspended => StatusTone.warning,
    TenantStatus.closed => StatusTone.danger,
  };
}
