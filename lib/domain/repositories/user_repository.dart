import 'package:ubsoft_pdks/core/result/result.dart';
import 'package:ubsoft_pdks/domain/entities/app_user.dart';
import 'package:ubsoft_pdks/domain/enums/user_role.dart';
import 'package:ubsoft_pdks/domain/enums/user_status.dart';

/// Kullanıcı kayıtları — `tenants/{tid}/users/{uid}`.
abstract interface class UserRepository {
  /// Giriş yapan kullanıcının hangi müşteride olduğunu bulur.
  ///
  /// Oturum çözümünün ilk adımıdır: kullanıcı kendi tenant'ını bilmez, bu
  /// yüzden koleksiyon grubu üzerinde tek seferlik bir arama yapılır.
  Future<Result<AppUser>> findByUid(String uid);

  /// Tek bir kullanıcıyı canlı izler.
  Stream<AppUser?> watchUser(String tenantId, String uid);

  /// Müşterinin kullanıcıları — silinmişler hariç, ada göre sıralı.
  Stream<List<AppUser>> watchUsers(String tenantId);

  Future<Result<AppUser>> createUser(AppUser user);

  Future<Result<void>> updateProfile({
    required String tenantId,
    required String uid,
    required String displayName,
    String? phone,
    String? note,
  });

  Future<Result<void>> updateRole({
    required String tenantId,
    required String uid,
    required UserRole role,
  });

  Future<Result<void>> updateStatus({
    required String tenantId,
    required String uid,
    required UserStatus status,
  });

  /// Kullanıcıyı listeden kaldırır.
  ///
  /// Kayıt fiziksel olarak silinmez, [UserStatus.deleted] işaretlenir:
  /// geçmiş devam kayıtlarında kimin giriş yaptığı okunabilir kalsın.
  Future<Result<void>> softDelete({
    required String tenantId,
    required String uid,
  });

  /// Son giriş zamanını damgalar.
  Future<Result<void>> touchLastLogin({
    required String tenantId,
    required String uid,
  });

  /// Bu e-posta sistemde kayıtlı mı?
  Future<Result<bool>> emailExists(String email);
}
