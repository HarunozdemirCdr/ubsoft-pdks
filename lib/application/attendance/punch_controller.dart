import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubsoft_pdks/application/attendance/attendance_providers.dart';
import 'package:ubsoft_pdks/application/auth/session_provider.dart';
import 'package:ubsoft_pdks/application/providers.dart';
import 'package:ubsoft_pdks/core/config/app_config.dart';
import 'package:ubsoft_pdks/core/error/failure.dart';
import 'package:ubsoft_pdks/core/result/result.dart';
import 'package:ubsoft_pdks/core/utils/qr_code.dart';
import 'package:ubsoft_pdks/domain/entities/app_user.dart';
import 'package:ubsoft_pdks/domain/entities/attendance_day.dart';
import 'package:ubsoft_pdks/domain/entities/attendance_event.dart';
import 'package:ubsoft_pdks/domain/entities/checkpoint.dart';
import 'package:ubsoft_pdks/domain/entities/scan_location.dart';
import 'package:ubsoft_pdks/domain/entities/session.dart';
import 'package:ubsoft_pdks/domain/entities/tenant.dart';
import 'package:ubsoft_pdks/domain/usecases/attendance/resolve_punch.dart';
import 'package:ubsoft_pdks/domain/usecases/attendance/verify_location.dart';
import 'package:ubsoft_pdks/services/location/location_service.dart';

/// Okutma akışının durumu.
sealed class PunchState {
  const PunchState();

  /// Kamera açık, kod bekleniyor.
  const factory PunchState.idle() = PunchIdle;

  /// Kod okundu; nokta çözülüyor, konum alınıyor, kayıt yazılıyor.
  const factory PunchState.working(String message) = PunchWorking;

  /// Kayıt yazıldı.
  const factory PunchState.success({
    required AttendanceEvent event,
    required Checkpoint checkpoint,
  }) = PunchSuccess;

  /// Reddedildi ya da hata oluştu.
  const factory PunchState.failed(Failure failure) = PunchFailed;

  bool get isBusy => this is PunchWorking;

  /// Sonuç ekranı gösteriliyor mu? (Kamera bu sırada duraklatılır.)
  bool get isResolved => this is PunchSuccess || this is PunchFailed;
}

final class PunchIdle extends PunchState {
  const PunchIdle();
}

final class PunchWorking extends PunchState {
  const PunchWorking(this.message);
  final String message;
}

final class PunchSuccess extends PunchState {
  const PunchSuccess({required this.event, required this.checkpoint});
  final AttendanceEvent event;
  final Checkpoint checkpoint;
}

final class PunchFailed extends PunchState {
  const PunchFailed(this.failure);
  final Failure failure;
}

/// QR okutmasını devam kaydına çeviren akış.
///
/// Sıra kasıtlıdır:
/// 1. **Kod çözülür** — tanımsız bir kod için konum istemenin anlamı yok.
/// 2. **Konum alınır** — kayıt yazılmadan önce, çünkü konum kaydın parçası.
/// 3. **Kural motoru** karar verir ([ResolvePunch]) — saf, test edilebilir.
/// 4. **Kayıt yazılır** — okutma ve gün özeti tek işlemde.
///
/// Konum adımı okutmayı **kendi başına** reddetmez: reddetme kararı tek bir
/// yerde, kural motorunda verilir. Böylece "hangi ayar neyi engelliyor"
/// sorusunun cevabı tek dosyada durur.
/// Aynı kişinin iki okutması arasında olması gereken en az süre.
///
/// Sağlayıcı üzerinden verilir ki testler sıfırlayabilsin: uçtan uca
/// senaryolar bir girişi ve çıkışı milisaniyeler içinde yapar — gerçek bir
/// insanın asla yapamayacağı hızda. Kuralın kendisi
/// `test/domain/resolve_punch_test.dart` içinde ayrıca sınanır.
final Provider<Duration> punchCooldownProvider = Provider<Duration>(
  (ref) => AppConfig.punchCooldown,
);

class PunchController extends Notifier<PunchState> {
  @override
  PunchState build() => const PunchState.idle();

  /// Okutmayı baştan alır — sonuç ekranından kameraya dönerken.
  void reset() => state = const PunchState.idle();

  /// Okunan ham QR içeriğini işler.
  Future<void> submit(String rawCode) async {
    if (state.isBusy) return;

    final String code = QrCode.normalize(rawCode);
    if (!QrCode.isValid(code)) {
      state = const PunchState.failed(
        PunchFailure(
          'Okunan kod bu sisteme ait değil. Lütfen şirketinizin QR '
          'etiketini okutun.',
          code: 'invalid-format',
        ),
      );
      return;
    }

    final Session session = ref.read(currentSessionProvider);
    if (session is! SessionActive) {
      state = const PunchState.failed(
        AuthFailure('Oturumunuz sona ermiş. Lütfen tekrar giriş yapın.'),
      );
      return;
    }

    final AppUser user = session.user;
    final Tenant tenant = session.tenant;

    if (!tenant.isWritable) {
      state = const PunchState.failed(
        SubscriptionFailure(
          'Şirket hesabınız şu anda kayıt kabul etmiyor. Yöneticinizle '
          'görüşün.',
          code: 'tenant-readonly',
        ),
      );
      return;
    }

    // 1) Kod çözümü ve konum ölçümü AYNI ANDA başlatılır.
    //
    // Önceden sırayla yapılıyordu: önce kod çözülüyor, sonra konum
    // ölçülüyordu. İkisi birbirinden bağımsız olduğu için toplam süre boş
    // yere ikisinin toplamıydı; şimdi yavaş olanın süresi kadar. Konum
    // ölçümü uzun kuyruklu olandır (GPS ilk sabitlemesi saniyeler sürer),
    // bu yüzden kazanç sahada hissedilir.
    //
    // Günün özeti bu kümeye BİLEREK alınmadı. O, yazma ile yarışan tek
    // girdidir: "zaten giriş yapmışsınız" denetimi onun tazeliğine bağlıdır
    // ve erken okumak, üst üste okutmaya kapı açar. Mümkün olan en geç anda,
    // 3. adımda okunur.
    //
    // Konum, noktanın koordinatı bilinmeden başlatılır; nokta konumsuzsa
    // sonuç yalnızca kullanılmaz.
    state = const PunchState.working('Kod okunuyor…');

    final Future<Result<Checkpoint>> findingCheckpoint = ref
        .read(checkpointRepositoryProvider)
        .findByCode(tenantId: tenant.id, code: code);
    // `ignore()`: kod çözülemezse aşağıda erken dönülür ve konum ölçümü
    // terk edilir. Terk edilen bir Future'ın hatası SAHİPSİZ kalır ve Dart
    // onu yakalanmamış bir istisna olarak bildirir — kullanıcı doğru hata
    // mesajını görürken konsola alakasız bir çökme düşerdi. Hatayı burada
    // sahiplenir; ileride `await` edilirse yine normal biçimde fırlatır.
    final Future<ScanLocation?> readingLocation = _readLocation()..ignore();

    final Result<Checkpoint> found = await findingCheckpoint;

    if (found case Err<Checkpoint>(:final Failure failure)) {
      state = PunchState.failed(failure);
      return;
    }
    final Checkpoint checkpoint = (found as Ok<Checkpoint>).value;

    // 2) Konum — kaydın kanıt tarafı.
    state = const PunchState.working('Konum alınıyor…');

    final ScanLocation? location = checkpoint.hasLocation
        ? await readingLocation
        : null;
    final LocationCheck check = VerifyLocation.call(
      checkpoint: checkpoint,
      location: location,
    );

    // 3) Kural motoru: yön ne, kayıt kabul edilir mi?
    //
    // Bugünün özeti BEKLENEREK okunur (`.future`), o anki değerine
    // bakılarak değil. Henüz yüklenmemiş bir özet "hiç giriş yok" gibi
    // görünür ve zaten içeride olan biri ikinci kez giriş yapardı.
    final AttendanceDay today = await ref.read(myTodayProvider.future);

    final PunchResolution resolution = ResolvePunch.call(
      cooldown: ref.read(punchCooldownProvider),
      checkpoint: checkpoint,
      today: today,
      settings: tenant.settings,
      location: check,
    );

    if (resolution case PunchRejected(:final Failure failure)) {
      state = PunchState.failed(failure);
      return;
    }
    final PunchAccepted accepted = resolution as PunchAccepted;

    // 4) Kayıt.
    state = const PunchState.working('Kaydediliyor…');

    final Result<AttendanceEvent> written = await ref
        .read(attendanceRepositoryProvider)
        .recordPunch(
          tenant: tenant,
          user: user,
          checkpoint: checkpoint,
          type: accepted.type,
          check: check,
          location: location,
        );

    state = switch (written) {
      Ok<AttendanceEvent>(:final AttendanceEvent value) => PunchState.success(
        event: value,
        checkpoint: checkpoint,
      ),
      Err<AttendanceEvent>(:final Failure failure) => PunchState.failed(
        failure,
      ),
    };
  }

  /// Konumu okur; alınamazsa `null` döner.
  ///
  /// Hata burada gösterilmez: konumun **yokluğu** da bir bilgidir ve karar
  /// kural motorunundur. Ayar konumu zorunlu tutmuyorsa okutma "Konum yok"
  /// damgasıyla kabul edilir.
  ///
  /// Nokta filtresi burada DEĞİL, çağıran tarafta uygulanır: ölçüm kod
  /// çözülmeden başlatıldığı için noktanın koordinatı olup olmadığı bu
  /// noktada henüz bilinmez.
  Future<ScanLocation?> _readLocation() async {
    final Result<ScanLocation> result = await ref
        .read(locationServiceProvider)
        .current();
    return result.valueOrNull;
  }
}

final NotifierProvider<PunchController, PunchState> punchControllerProvider =
    NotifierProvider<PunchController, PunchState>(PunchController.new);
