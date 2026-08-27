import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubsoft_pdks/application/auth/session_provider.dart';
import 'package:ubsoft_pdks/application/providers.dart';
import 'package:ubsoft_pdks/core/error/failure.dart';
import 'package:ubsoft_pdks/core/result/result.dart';
import 'package:ubsoft_pdks/core/utils/validators.dart';
import 'package:ubsoft_pdks/domain/entities/app_user.dart';
import 'package:ubsoft_pdks/domain/entities/tenant.dart';
import 'package:ubsoft_pdks/domain/enums/user_role.dart';
import 'package:ubsoft_pdks/domain/enums/user_status.dart';
import 'package:ubsoft_pdks/domain/permissions/app_permission.dart';
import 'package:ubsoft_pdks/domain/permissions/permission_set.dart';
import 'package:ubsoft_pdks/domain/repositories/user_repository.dart';

/// Müşterinin kullanıcıları — silinmişler hariç.
///
/// Yetkisi olmayan kullanıcı için sorgu **hiç açılmaz**. Güvenlik kuralları
/// zaten reddederdi; ama reddedilen bir dinleyici, kendi geçmişini açan her
/// personelin ekranında sessiz bir "permission-denied" bırakır ve gerçek
/// hatalar bu gürültüde kaybolur.
final StreamProvider<List<AppUser>> usersProvider =
    StreamProvider<List<AppUser>>((ref) {
      final PermissionSet permissions = ref.watch(permissionsProvider);
      final bool allowed = permissions.canAny(<AppPermission>[
        AppPermission.userView,
        AppPermission.attendanceViewAll,
      ]);
      if (!allowed) return Stream<List<AppUser>>.value(const <AppUser>[]);

      return ref
          .watch(userRepositoryProvider)
          .watchUsers(ref.watch(tenantIdProvider));
    });

/// Yalnız aktif kullanıcılar — devam tabloları bu kadrodan kurulur.
final Provider<List<AppUser>> activeUsersProvider = Provider<List<AppUser>>(
  (ref) =>
      ref
          .watch(usersProvider)
          .value
          ?.where((AppUser user) => user.status.isActive)
          .toList(growable: false) ??
      const <AppUser>[],
);

/// Kimlikten kullanıcıya hızlı erişim — listelerde ad çözmek için.
final Provider<Map<String, AppUser>> usersByIdProvider =
    Provider<Map<String, AppUser>>(
      (ref) => <String, AppUser>{
        for (final AppUser user
            in ref.watch(usersProvider).value ?? const <AppUser>[])
          user.uid: user,
      },
    );

/// Tek bir kullanıcı — düzenleme ve geçmiş ekranları için.
final userProvider = Provider.family<AppUser?, String>(
  (ref, uid) => ref.watch(usersByIdProvider)[uid],
);

/// Müşterinin rol varsayılanları: `{ 'staff': {'punch.create': true, …}, … }`.
///
/// Yetki ekranı bunu okur ki bir anahtarın "açık" görünmesi gerçekten o rolün
/// varsayılanından mı geliyor, yoksa kullanıcıya özel mi ayarlanmış ayırt
/// edilebilsin. Okunamazsa koddaki yedek tablo devreye girer.
final roleDefaultsProvider =
    FutureProvider.autoDispose<Map<String, Map<String, bool>>>((ref) async {
      final Result<Map<String, Map<String, bool>>> result = await ref
          .watch(tenantRepositoryProvider)
          .getRoleDefaults(ref.watch(tenantIdProvider));
      return result.valueOrNull ?? const <String, Map<String, bool>>{};
    });

/// Kullanıcı oluşturma ve düzenleme işlemleri.
class UserController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  UserRepository get _users => ref.read(userRepositoryProvider);
  String get _tenantId => ref.read(tenantIdProvider);
  AppUser? get _actor => ref.read(currentUserProvider);

  /// Yeni personel açar: önce Auth hesabı, sonra Firestore kaydı.
  ///
  /// Sıra önemlidir ve tersi mümkün değildir: Firestore kaydının doküman
  /// kimliği Auth'un verdiği `uid`'dir.
  Future<Result<AppUser>> createUser({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
    String? phone,
    String? note,
  }) async {
    state = const AsyncValue<void>.loading();

    final String? emailError = Validators.email(email);
    if (emailError != null) {
      final ValidationFailure failure = ValidationFailure(emailError);
      state = AsyncValue<void>.error(failure, StackTrace.current);
      return Err<AppUser>(failure);
    }

    final Tenant? tenant = ref.read(currentTenantProvider);
    if (tenant != null && tenant.userLimitReached) {
      final SubscriptionFailure failure = SubscriptionFailure(
        'Abonelik planınız en fazla ${tenant.subscription.maxUsers} '
        'kullanıcıya izin veriyor.',
        code: 'user-limit',
      );
      state = AsyncValue<void>.error(failure, StackTrace.current);
      return Err<AppUser>(failure);
    }

    // Kolaylık kontrolü: adres zaten kayıtlıysa kullanıcı formu göndermeden
    // uyarılır. Sorgu güvenlik kuralınca reddedilebilir; o durumda sessizce
    // geçilir ve gerçek engeli Firebase Auth koyar.
    final Result<bool> exists = await _users.emailExists(email);
    if (exists case Ok<bool>(value: true)) {
      const ConflictFailure failure = ConflictFailure(
        'Bu e-posta adresi zaten kayıtlı.',
        code: 'email-exists',
      );
      state = AsyncValue<void>.error(failure, StackTrace.current);
      return const Err<AppUser>(failure);
    }

    final Result<String> account = await ref
        .read(authRepositoryProvider)
        .createAuthAccount(email: email, password: password);

    if (account case Err<String>(:final Failure failure)) {
      state = AsyncValue<void>.error(failure, StackTrace.current);
      return Err<AppUser>(failure);
    }

    final AppUser user = AppUser(
      uid: (account as Ok<String>).value,
      email: email.trim().toLowerCase(),
      displayName: displayName.trim(),
      phone: phone?.trim(),
      note: note?.trim(),
      tenantId: _tenantId,
      role: role,
      status: UserStatus.active,
      createdAt: DateTime.now(),
      createdBy: _actor?.uid,
    );

    final Result<AppUser> created = await _users.createUser(user);
    _finish(created);
    return created;
  }

  Future<Result<void>> updateProfile({
    required AppUser user,
    required String displayName,
    String? phone,
    String? note,
  }) async {
    state = const AsyncValue<void>.loading();
    final Result<void> result = await _users.updateProfile(
      tenantId: user.tenantId,
      uid: user.uid,
      displayName: displayName,
      phone: phone,
      note: note,
    );
    _finish(result);
    return result;
  }

  Future<Result<void>> changeRole(AppUser user, UserRole role) async {
    state = const AsyncValue<void>.loading();
    final Result<void> result = await _users.updateRole(
      tenantId: user.tenantId,
      uid: user.uid,
      role: role,
    );
    _finish(result);
    return result;
  }

  Future<Result<void>> setActive(AppUser user, {required bool active}) async {
    state = const AsyncValue<void>.loading();
    final Result<void> result = await _users.updateStatus(
      tenantId: user.tenantId,
      uid: user.uid,
      status: active ? UserStatus.active : UserStatus.inactive,
    );
    _finish(result);
    return result;
  }

  /// Kullanıcıya özel izin ayarlarını yazar.
  ///
  /// Haritada bulunmayan izinler rol varsayılanına döner; bu yüzden yalnız
  /// bilinçli değiştirilenler gönderilir.
  Future<Result<void>> savePermissions(
    AppUser user,
    Map<String, bool> overrides,
  ) async {
    state = const AsyncValue<void>.loading();
    final Result<void> result = await _users.updatePermissions(
      tenantId: user.tenantId,
      uid: user.uid,
      overrides: overrides,
    );
    _finish(result);
    return result;
  }

  Future<Result<void>> deleteUser(AppUser user) async {
    state = const AsyncValue<void>.loading();
    final Result<void> result = await _users.softDelete(
      tenantId: user.tenantId,
      uid: user.uid,
    );
    _finish(result);
    return result;
  }

  Future<Result<void>> sendPasswordReset(AppUser user) async {
    state = const AsyncValue<void>.loading();
    final Result<void> result = await ref
        .read(authRepositoryProvider)
        .sendPasswordResetEmail(user.email);
    _finish(result);
    return result;
  }

  void _finish(Result<Object?> result) {
    state = switch (result) {
      Ok<Object?>() => const AsyncValue<void>.data(null),
      Err<Object?>(:final Failure failure) => AsyncValue<void>.error(
        failure,
        StackTrace.current,
      ),
    };
  }
}

final AsyncNotifierProvider<UserController, void> userControllerProvider =
    AsyncNotifierProvider<UserController, void>(UserController.new);
