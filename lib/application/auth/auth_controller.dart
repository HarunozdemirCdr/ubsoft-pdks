import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubsoft_pdks/application/providers.dart';
import 'package:ubsoft_pdks/core/error/failure.dart';
import 'package:ubsoft_pdks/core/result/result.dart';
import 'package:ubsoft_pdks/domain/entities/app_user.dart';
import 'package:ubsoft_pdks/domain/repositories/auth_repository.dart';
import 'package:ubsoft_pdks/domain/repositories/user_repository.dart';

/// Giriş ekranının durumu.
class AuthFormState {
  const AuthFormState({
    this.isSubmitting = false,
    this.failure,
    this.infoMessage,
  });

  final bool isSubmitting;

  /// Son işlemin hatası. Ekran bunu alan altında gösterir.
  final Failure? failure;

  /// Bilgilendirme mesajı (ör. "Sıfırlama bağlantısı gönderildi").
  final String? infoMessage;

  AuthFormState copyWith({
    bool? isSubmitting,
    Failure? failure,
    String? infoMessage,
    bool clearFailure = false,
    bool clearInfo = false,
  }) => AuthFormState(
    isSubmitting: isSubmitting ?? this.isSubmitting,
    failure: clearFailure ? null : (failure ?? this.failure),
    infoMessage: clearInfo ? null : (infoMessage ?? this.infoMessage),
  );
}

/// Giriş, çıkış ve şifre sıfırlama işlemleri.
///
/// Yönlendirme yapmaz: oturum değiştiğinde `sessionProvider` güncellenir ve
/// yönlendirmeyi `RouteGuard` üstlenir. Bu ayrım sayesinde "giriş yaptı ama
/// ekran değişmedi" gibi durumlar oluşmaz.
class AuthController extends Notifier<AuthFormState> {
  @override
  AuthFormState build() => const AuthFormState();

  AuthRepository get _auth => ref.read(authRepositoryProvider);
  UserRepository get _users => ref.read(userRepositoryProvider);

  Future<bool> signIn({required String email, required String password}) async {
    state = state.copyWith(
      isSubmitting: true,
      clearFailure: true,
      clearInfo: true,
    );

    final Result<String> result = await _auth.signIn(
      email: email,
      password: password,
    );

    switch (result) {
      case Ok<String>(:final String value):
        // Son giriş zamanı bilgi amaçlıdır; yazılamazsa giriş yine de başarılı
        // sayılır (ör. kullanıcı dokümanı henüz oluşturulmamışsa).
        final Result<AppUser> profile = await _users.findByUid(value);
        if (profile case Ok<AppUser>(value: final AppUser user)) {
          await _users.touchLastLogin(tenantId: user.tenantId, uid: user.uid);
        }
        state = state.copyWith(isSubmitting: false);
        return true;

      case Err<String>(:final Failure failure):
        state = state.copyWith(isSubmitting: false, failure: failure);
        return false;
    }
  }

  Future<void> sendPasswordReset(String email) async {
    state = state.copyWith(
      isSubmitting: true,
      clearFailure: true,
      clearInfo: true,
    );

    final Result<void> result = await _auth.sendPasswordResetEmail(email);

    state = switch (result) {
      Ok<void>() => state.copyWith(
        isSubmitting: false,
        infoMessage:
            'Şifre sıfırlama bağlantısı $email adresine gönderildi. '
            'Gelen kutunuzu ve spam klasörünü kontrol edin.',
      ),
      Err<void>(:final Failure failure) => state.copyWith(
        isSubmitting: false,
        failure: failure,
      ),
    };
  }

  /// Kullanıcının kendi şifresini değiştirir.
  ///
  /// Giriş formunun durumuna dokunmaz: bu işlem başka bir ekranda yapılır ve
  /// hatası orada gösterilir.
  Future<Result<void>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) => _auth.changePassword(
    currentPassword: currentPassword,
    newPassword: newPassword,
  );

  Future<void> signOut() async {
    state = state.copyWith(isSubmitting: true, clearFailure: true);
    await _auth.signOut();
    state = const AuthFormState();
  }

  /// Kullanıcı yazmaya başlayınca önceki hatayı temizler.
  void clearMessages() {
    if (state.failure == null && state.infoMessage == null) return;
    state = state.copyWith(clearFailure: true, clearInfo: true);
  }
}

final NotifierProvider<AuthController, AuthFormState> authControllerProvider =
    NotifierProvider<AuthController, AuthFormState>(AuthController.new);
