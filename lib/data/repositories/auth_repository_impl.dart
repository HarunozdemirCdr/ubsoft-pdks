import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:ubsoft_pdks/core/error/error_mapper.dart';
import 'package:ubsoft_pdks/core/error/failure.dart';
import 'package:ubsoft_pdks/core/result/result.dart';
import 'package:ubsoft_pdks/domain/repositories/auth_repository.dart';

/// Firebase Authentication tabanlı kimlik doğrulama.
final class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._auth);

  final FirebaseAuth _auth;

  /// Kullanıcı oluştururken kullanılan ikincil uygulama örneği.
  ///
  /// Bir kez açılır, sonraki çağrılarda tekrar kullanılır.
  FirebaseApp? _secondaryApp;

  @override
  Stream<String?> authStateChanges() =>
      _auth.authStateChanges().map((User? user) => user?.uid);

  @override
  String? get currentUid => _auth.currentUser?.uid;

  @override
  Future<Result<String>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      final String? uid = credential.user?.uid;
      if (uid == null) {
        return const Err<String>(
          AuthFailure('Giriş yapılamadı. Lütfen tekrar deneyin.'),
        );
      }
      return Ok<String>(uid);
    } catch (error, stackTrace) {
      return Err<String>(ErrorMapper.map(error, stackTrace));
    }
  }

  @override
  Future<Result<void>> signOut() async {
    try {
      await _auth.signOut();
      return okVoid;
    } catch (error, stackTrace) {
      return Err<void>(ErrorMapper.map(error, stackTrace));
    }
  }

  @override
  Future<Result<void>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final User? user = _auth.currentUser;
      final String? email = user?.email;
      if (user == null || email == null) {
        return const Err<void>(
          AuthFailure('Oturum bulunamadı. Lütfen tekrar giriş yapın.'),
        );
      }

      // Yeniden kimlik doğrulama: Firebase, uzun süredir açık oturumlarda
      // şifre değişimini reddeder ("requires-recent-login"). Mevcut şifreyle
      // önce oturum tazelenir, böylece kullanıcı hata görmez.
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: currentPassword),
      );

      await user.updatePassword(newPassword);
      return okVoid;
    } catch (error, stackTrace) {
      return Err<void>(ErrorMapper.map(error, stackTrace));
    }
  }

  @override
  Future<Result<void>> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim().toLowerCase());
      return okVoid;
    } on FirebaseAuthException catch (error, stackTrace) {
      // Kayıtlı olmayan adres için de başarı döneriz: aksi hâlde bu ekran
      // hangi e-postaların sistemde olduğunu öğrenmek için kullanılabilirdi.
      if (error.code == 'user-not-found' || error.code == 'invalid-email') {
        return okVoid;
      }
      return Err<void>(ErrorMapper.map(error, stackTrace));
    } catch (error, stackTrace) {
      return Err<void>(ErrorMapper.map(error, stackTrace));
    }
  }

  @override
  Future<Result<String>> createAuthAccount({
    required String email,
    required String password,
  }) async {
    try {
      // Ana uygulama örneğiyle hesap açmak yöneticiyi oturumdan düşürürdü:
      // Firebase yeni oluşturulan kullanıcıyı otomatik olarak oturuma alır.
      // Bu yüzden ikincil bir uygulama örneği kullanılır ve işlem bitince
      // o örnekteki oturum kapatılır.
      final FirebaseApp app = await _ensureSecondaryApp();
      final FirebaseAuth secondaryAuth = FirebaseAuth.instanceFor(app: app);

      final UserCredential credential = await secondaryAuth
          .createUserWithEmailAndPassword(
            email: email.trim().toLowerCase(),
            password: password,
          );

      final String? uid = credential.user?.uid;
      await secondaryAuth.signOut();

      if (uid == null) {
        return const Err<String>(
          AuthFailure('Kullanıcı hesabı oluşturulamadı.'),
        );
      }
      return Ok<String>(uid);
    } catch (error, stackTrace) {
      return Err<String>(ErrorMapper.map(error, stackTrace));
    }
  }

  Future<FirebaseApp> _ensureSecondaryApp() async {
    final FirebaseApp? existing = _secondaryApp;
    if (existing != null) return existing;

    final FirebaseApp app = await Firebase.initializeApp(
      name: 'userProvisioning',
      options: Firebase.app().options,
    );
    _secondaryApp = app;
    return app;
  }
}
