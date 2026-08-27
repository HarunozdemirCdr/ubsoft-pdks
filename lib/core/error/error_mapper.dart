import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:ubsoft_pdks/core/error/failure.dart';

/// Platform istisnalarını kullanıcıya gösterilebilir [Failure]'a çevirir.
///
/// Tek kural: `data` katmanındaki her `catch` bloğu bu sınıftan geçer.
/// Böylece kullanıcı hiçbir zaman `[cloud_firestore/permission-denied]` gibi
/// bir metin görmez.
abstract final class ErrorMapper {
  /// Herhangi bir istisnayı [Failure]'a çevirir.
  static Failure map(Object error, [StackTrace? stackTrace]) {
    if (error is Failure) return error;

    if (error is FirebaseAuthException) return _mapAuth(error);
    if (error is FirebaseException) return _mapFirebase(error);
    if (error is TimeoutException) {
      return NetworkFailure(
        message: 'İşlem zaman aşımına uğradı. Lütfen tekrar deneyin.',
        technical: error.toString(),
        code: 'timeout',
      );
    }
    if (error is FormatException || error is TypeError) {
      return UnknownFailure(
        message: 'Veri okunamadı. Kayıt bozuk olabilir.',
        technical: error.toString(),
        code: 'format',
      );
    }

    if (kDebugMode) {
      debugPrint('Sınıflandırılamayan hata: $error\n$stackTrace');
    }
    return UnknownFailure(technical: error.toString());
  }

  static Failure _mapAuth(FirebaseAuthException e) {
    final String message = switch (e.code) {
      'invalid-email' => 'Geçersiz e-posta adresi.',
      'user-disabled' => 'Bu hesap devre dışı bırakılmış.',
      'user-not-found' ||
      'wrong-password' ||
      'invalid-credential' ||
      'invalid-login-credentials' => 'E-posta veya şifre hatalı.',
      'email-already-in-use' => 'Bu e-posta adresi zaten kayıtlı.',
      'weak-password' => 'Şifre çok zayıf. En az 6 karakter kullanın.',
      'operation-not-allowed' => 'Bu giriş yöntemi etkin değil.',
      'too-many-requests' =>
        'Çok fazla deneme yapıldı. Lütfen birkaç dakika sonra tekrar deneyin.',
      'requires-recent-login' =>
        'Bu işlem için yeniden giriş yapmanız gerekiyor.',
      'network-request-failed' =>
        'İnternet bağlantısı kurulamadı. Bağlantınızı kontrol edin.',
      'missing-password' => 'Şifre alanı boş bırakılamaz.',
      _ => 'Giriş yapılamadı. Lütfen tekrar deneyin.',
    };

    if (e.code == 'network-request-failed') {
      return NetworkFailure(technical: e.message, code: e.code);
    }
    return AuthFailure(message, technical: e.message, code: e.code);
  }

  static Failure _mapFirebase(FirebaseException e) {
    return switch (e.code) {
      'permission-denied' => PermissionFailure(
        technical: e.message,
        code: e.code,
      ),
      'not-found' => NotFoundFailure(technical: e.message, code: e.code),
      'already-exists' => ConflictFailure(
        'Bu kayıt zaten mevcut.',
        technical: e.message,
        code: e.code,
      ),
      'aborted' || 'failed-precondition' => ConflictFailure(
        'İşlem tamamlanamadı; kayıt bu sırada değişmiş olabilir. '
        'Lütfen sayfayı yenileyip tekrar deneyin.',
        technical: e.message,
        code: e.code,
      ),
      'unavailable' => NetworkFailure(
        message:
            'Servise şu anda ulaşılamıyor. Lütfen birazdan tekrar deneyin.',
        technical: e.message,
        code: e.code,
      ),
      'deadline-exceeded' => NetworkFailure(
        message: 'İşlem zaman aşımına uğradı. Lütfen tekrar deneyin.',
        technical: e.message,
        code: e.code,
      ),
      'resource-exhausted' => SubscriptionFailure(
        'Kullanım sınırına ulaşıldı. Lütfen yöneticinizle görüşün.',
        technical: e.message,
        code: e.code,
      ),
      'unauthenticated' => AuthFailure(
        'Oturumunuz sona ermiş. Lütfen tekrar giriş yapın.',
        technical: e.message,
        code: e.code,
      ),
      'cancelled' => UnknownFailure(
        message: 'İşlem iptal edildi.',
        technical: e.message,
        code: e.code,
      ),
      _ => UnknownFailure(technical: '${e.code}: ${e.message}', code: e.code),
    };
  }
}
