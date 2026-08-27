import 'package:ubsoft_pdks/core/result/result.dart';

/// Kimlik doğrulama.
///
/// Yalnız **kim olduğu** ile ilgilenir; kullanıcının ne yapabileceği
/// [UserRepository] ve izin katmanının işidir.
abstract interface class AuthRepository {
  /// Oturum durumu akışı. Oturum yoksa `null` yayınlar.
  Stream<String?> authStateChanges();

  /// Giriş yapmış kullanıcının kimliği. Yoksa `null`.
  String? get currentUid;

  Future<Result<String>> signIn({
    required String email,
    required String password,
  });

  Future<Result<void>> signOut();

  Future<Result<void>> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  Future<Result<void>> sendPasswordResetEmail(String email);

  /// Yeni bir Auth hesabı açar ve kimliğini döner.
  ///
  /// Yöneticinin oturumunu düşürmeden çalışır (ikincil uygulama örneği).
  Future<Result<String>> createAuthAccount({
    required String email,
    required String password,
  });
}
