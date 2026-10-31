import 'package:equatable/equatable.dart';
import 'package:ubsoft_pdks/domain/entities/app_user.dart';
import 'package:ubsoft_pdks/domain/entities/tenant.dart';
import 'package:ubsoft_pdks/domain/permissions/app_permission.dart';
import 'package:ubsoft_pdks/domain/permissions/permission_set.dart';

/// Oturumun engellenme nedeni.
enum SessionBlockReason {
  /// Auth kaydı var ama Firestore'da kullanıcı dokümanı yok.
  profileMissing('Hesabınız sistemde tanımlı değil. Yöneticinizle görüşün.'),

  /// Kullanıcı pasif ya da silinmiş.
  userInactive('Hesabınız devre dışı bırakılmış. Yöneticinizle görüşün.'),

  /// Yurt hesabı askıya alınmış.
  tenantSuspended(
    'Yurt aboneliğiniz askıya alınmış. Lütfen yöneticinizle görüşün.',
  ),

  /// Aboneliğin süresi dolmuş.
  ///
  /// [tenantSuspended]'dan ayrı tutulur: askıya alma bilinçli bir karardır,
  /// süre dolması ise kendiliğinden olur. Öğrencie "askıya alındınız" demek
  /// yanlış yönlendirir; yöneticisine sorduğunda kimsenin haberi olmaz.
  subscriptionExpired(
    'Yurdunizin abonelik süresi doldu. Lütfen yöneticinizle görüşün.',
  ),

  /// Kullanıcının tenant'ı bulunamadı.
  tenantMissing('Yurt kaydınıza ulaşılamadı. Yöneticinizle görüşün.');

  const SessionBlockReason(this.message);

  /// Kullanıcıya gösterilecek Türkçe açıklama.
  final String message;
}

/// Oturum durumu.
///
/// Uygulamanın tüm yönlendirme ve yetki kararları bu tipe bakar. Beş hâl
/// vardır ve `switch` ile hepsinin ele alınması derleyici tarafından zorunlu
/// tutulur — "kullanıcı var mı, tenant yüklendi mi" kontrolleri ekranlara
/// dağılmaz.
sealed class Session extends Equatable {
  const Session();

  /// Henüz belirlenmedi (uygulama açılıyor). Bu hâlde yönlendirme yapılmaz.
  const factory Session.unknown() = SessionUnknown;

  /// Oturum yok.
  const factory Session.signedOut() = SessionSignedOut;

  /// Giriş yapıldı ve erişim var.
  const factory Session.active({
    required AppUser user,
    required Tenant tenant,
    required PermissionSet permissions,
  }) = SessionActive;

  /// Süper admin — bir tenant'a bağlı değil.
  const factory Session.superAdmin(AppUser user) = SessionSuperAdmin;

  /// Giriş yapıldı ama erişim engellendi.
  const factory Session.blocked(SessionBlockReason reason) = SessionBlocked;

  /// Oturumun sahibi (varsa).
  AppUser? get userOrNull => switch (this) {
    SessionActive(:final AppUser user) => user,
    SessionSuperAdmin(:final AppUser user) => user,
    _ => null,
  };

  Tenant? get tenantOrNull => switch (this) {
    SessionActive(:final Tenant tenant) => tenant,
    _ => null,
  };

  /// Çözülmüş izinler. Oturum yoksa hiçbir izin yoktur.
  PermissionSet get permissionsOrNone => switch (this) {
    SessionActive(:final PermissionSet permissions) => permissions,
    SessionSuperAdmin() => PermissionSet.fromRole(userOrNull!.role),
    _ => PermissionSet.none,
  };

  bool get isAuthenticated =>
      this is SessionActive || this is SessionSuperAdmin;

  bool get isUnknown => this is SessionUnknown;

  bool can(AppPermission permission) => permissionsOrNone.can(permission);

  @override
  List<Object?> get props => <Object?>[runtimeType];
}

final class SessionUnknown extends Session {
  const SessionUnknown();
}

final class SessionSignedOut extends Session {
  const SessionSignedOut();
}

final class SessionActive extends Session {
  const SessionActive({
    required this.user,
    required this.tenant,
    required this.permissions,
  });

  final AppUser user;
  final Tenant tenant;
  final PermissionSet permissions;

  @override
  List<Object?> get props => <Object?>[user, tenant, permissions];
}

final class SessionSuperAdmin extends Session {
  const SessionSuperAdmin(this.user);

  final AppUser user;

  @override
  List<Object?> get props => <Object?>[user];
}

final class SessionBlocked extends Session {
  const SessionBlocked(this.reason);

  final SessionBlockReason reason;

  @override
  List<Object?> get props => <Object?>[reason];
}
