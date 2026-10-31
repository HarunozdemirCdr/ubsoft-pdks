import 'package:equatable/equatable.dart';

/// Uygulama genelinde tek hata tipi.
///
/// `data` katmanı tüm platform istisnalarını (FirebaseException, TypeError,
/// PlatformException…) burada tanımlı bir [Failure]'a çevirir. Bu sayede
/// `presentation` katmanı hiçbir zaman Firebase tipiyle karşılaşmaz ve
/// kullanıcıya her zaman Türkçe, anlaşılır bir mesaj gösterilir.
///
/// [message] doğrudan kullanıcıya gösterilebilir. [technical] yalnız günlüğe
/// yazılır, arayüzde gösterilmez.
sealed class Failure extends Equatable implements Exception {
  const Failure(this.message, {this.technical, this.code});

  /// Kullanıcıya gösterilecek Türkçe mesaj.
  final String message;

  /// Geliştirici için ham hata metni.
  final String? technical;

  /// Kaynak hata kodu (ör. `permission-denied`).
  final String? code;

  @override
  List<Object?> get props => <Object?>[message, technical, code];

  @override
  String toString() => '$runtimeType($code): $message';
}

/// Ağ erişilemedi veya istek zaman aşımına uğradı.
final class NetworkFailure extends Failure {
  const NetworkFailure({
    String message =
        'İnternet bağlantısı kurulamadı. Bağlantınızı kontrol edin.',
    super.technical,
    super.code,
  }) : super(message);
}

/// Kimlik doğrulama hataları: hatalı şifre, kullanıcı yok, oturum süresi doldu.
final class AuthFailure extends Failure {
  const AuthFailure(super.message, {super.technical, super.code});
}

/// Güvenlik kuralı reddi veya uygulama içi yetki kontrolü başarısız.
final class PermissionFailure extends Failure {
  const PermissionFailure({
    String message = 'Bu işlem için yetkiniz yok.',
    super.technical,
    super.code,
  }) : super(message);
}

/// Girdi doğrulaması başarısız (boş alan, geçersiz QR kodu, hatalı e-posta).
final class ValidationFailure extends Failure {
  const ValidationFailure(super.message, {super.technical, super.code});
}

/// İstenen kayıt bulunamadı.
final class NotFoundFailure extends Failure {
  const NotFoundFailure({
    String message = 'Kayıt bulunamadı.',
    super.technical,
    super.code,
  }) : super(message);
}

/// Benzersizlik ihlali veya eşzamanlı değişiklik çakışması.
///
/// Örnek: aynı QR kodunun başka bir noktada kullanılıyor olması.
final class ConflictFailure extends Failure {
  const ConflictFailure(super.message, {super.technical, super.code});
}

/// Okutma akışına özgü iş kuralı ihlalleri.
///
/// Örnek: tanımsız QR kodu, pasif nokta, üst üste iki giriş okutulması,
/// nokta dışından okutma (engelleme açıkken).
final class PunchFailure extends Failure {
  const PunchFailure(super.message, {super.technical, super.code});
}

/// Konum alınamadı — izin reddedildi, servis kapalı ya da zaman aşımı.
///
/// Ayrı bir tip olması şart: kullanıcıya gösterilecek çözüm tümüyle
/// farklıdır ("tarayıcı ayarlarından konum iznini açın"), ve arayüz bu
/// durumda okutmayı reddetmek yerine yardım gösterir.
final class LocationFailure extends Failure {
  const LocationFailure(super.message, {super.technical, super.code});
}

/// Abonelik limiti aşıldı veya yurt hesabı askıya alındı.
final class SubscriptionFailure extends Failure {
  const SubscriptionFailure(super.message, {super.technical, super.code});
}

/// Sınıflandırılamayan hata.
final class UnknownFailure extends Failure {
  const UnknownFailure({
    String message = 'Beklenmeyen bir hata oluştu. Lütfen tekrar deneyin.',
    super.technical,
    super.code,
  }) : super(message);
}
