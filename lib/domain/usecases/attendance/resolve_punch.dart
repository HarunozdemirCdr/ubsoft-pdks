import 'package:ubsoft_pdks/core/error/failure.dart';
import 'package:ubsoft_pdks/domain/entities/attendance_day.dart';
import 'package:ubsoft_pdks/domain/entities/checkpoint.dart';
import 'package:ubsoft_pdks/domain/entities/tenant.dart';
import 'package:ubsoft_pdks/domain/enums/location_verdict.dart';
import 'package:ubsoft_pdks/domain/enums/punch_type.dart';
import 'package:ubsoft_pdks/domain/usecases/attendance/verify_location.dart';

/// Okutma çözümlemesinin sonucu.
sealed class PunchResolution {
  const PunchResolution();

  /// Kayıt yazılabilir.
  const factory PunchResolution.accepted({
    required PunchType type,
    required LocationCheck location,
  }) = PunchAccepted;

  /// Reddedildi — sebebi [failure] içinde, kullanıcıya gösterilebilir Türkçe
  /// mesajla birlikte.
  const factory PunchResolution.rejected(Failure failure) = PunchRejected;

  bool get isAccepted => this is PunchAccepted;

  Failure? get failureOrNull =>
      this is PunchRejected ? (this as PunchRejected).failure : null;
}

final class PunchAccepted extends PunchResolution {
  const PunchAccepted({required this.type, required this.location});

  final PunchType type;
  final LocationCheck location;

  /// Kullanıcıya gösterilecek başlık.
  String get title => type.isEntry ? 'Giriş yapıldı' : 'Çıkış yapıldı';
}

final class PunchRejected extends PunchResolution {
  const PunchRejected(this.failure);

  final Failure failure;
}

/// Okunan bir QR kodunun devam kaydına dönüşüp dönüşmeyeceğine karar verir.
///
/// Saf bir kural motorudur: ağ, veritabanı ya da arayüz bilmez. Aynı mantık
/// hem okutma ekranında hem de yazma anında (çift kontrol) kullanılır.
///
/// Denetim sırası, kullanıcıya **en yararlı** hata mesajını verecek şekilde
/// seçildi:
/// 1. Nokta etkin mi?
/// 2. Yön nedir? (Noktanın türü sabitse ondan, değilse kişinin o anki
///    durumundan çözülür.)
/// 3. Aynı yön üst üste tekrarlanıyor mu?
/// 4. Konum kuralları sağlanıyor mu?
abstract final class ResolvePunch {
  static PunchResolution call({
    required Checkpoint checkpoint,
    required AttendanceDay today,
    required TenantSettings settings,
    required LocationCheck location,
  }) {
    if (!checkpoint.active) {
      return PunchResolution.rejected(
        PunchFailure('${checkpoint.name} noktası devre dışı bırakılmış.'),
      );
    }

    final PunchType type = resolveType(
      kind: checkpoint.kind,
      isInside: today.open,
    );

    // Üst üste iki giriş ya da iki çıkış: kayıt yanlış olurdu.
    //
    // Çıkış okutmadan tekrar giriş okutulursa hangi aralığın çalışıldığı
    // belirsizleşir. Kullanıcıya ne yapması gerektiği açıkça söylenir.
    if (type.isEntry && today.open) {
      return const PunchResolution.rejected(
        PunchFailure(
          'Zaten giriş yapmışsınız. Önce çıkış kodunu okutmalısınız.',
        ),
      );
    }
    if (type.isExit && !today.open) {
      return const PunchResolution.rejected(
        PunchFailure(
          'Açık bir girişiniz yok. Önce giriş kodunu okutmalısınız.',
        ),
      );
    }

    // Konumu kapatmak, doğrulamadan kaçmanın en kolay yolu olurdu. Ayar
    // açıkken okutma reddedilir; kapalıyken kayıt "Konum yok" damgasıyla
    // tutulur ve karar yöneticiye bırakılır.
    if (location.verdict == LocationVerdict.unavailable &&
        settings.requireLocation &&
        checkpoint.hasLocation) {
      return const PunchResolution.rejected(
        LocationFailure(
          'Konum bilgisi alınamadı. Okutma yapabilmek için cihazınızın konum '
          'iznini açın.',
        ),
      );
    }

    if (location.verdict.isOutside && settings.blockOutsideScans) {
      return PunchResolution.rejected(
        PunchFailure(
          '${checkpoint.name} noktasından çok uzaktasınız. Okutmayı noktanın '
          'yanında yapın.',
        ),
      );
    }

    return PunchResolution.accepted(type: type, location: location);
  }

  /// Okutmanın yönünü çözer.
  ///
  /// Nokta türü sabitse (yalnız giriş / yalnız çıkış) yön odur. Tek etiketin
  /// iki iş gördüğü noktalarda yön kişinin o anki durumundan çıkar: içeride
  /// değilse giriş, içerideyse çıkış.
  static PunchType resolveType({
    required CheckpointKind kind,
    required bool isInside,
  }) {
    final PunchType? fixed = kind.fixedType;
    if (fixed != null) return fixed;
    return isInside ? PunchType.exit : PunchType.entry;
  }
}
