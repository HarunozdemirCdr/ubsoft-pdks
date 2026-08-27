import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubsoft_pdks/application/auth/session_provider.dart';
import 'package:ubsoft_pdks/application/providers.dart';
import 'package:ubsoft_pdks/core/error/failure.dart';
import 'package:ubsoft_pdks/core/result/result.dart';
import 'package:ubsoft_pdks/domain/entities/app_user.dart';
import 'package:ubsoft_pdks/domain/entities/tenant.dart';
import 'package:ubsoft_pdks/domain/enums/tenant_status.dart';
import 'package:ubsoft_pdks/domain/enums/user_role.dart';
import 'package:ubsoft_pdks/domain/enums/user_status.dart';
import 'package:ubsoft_pdks/domain/permissions/role_defaults.dart';
import 'package:ubsoft_pdks/domain/repositories/tenant_repository.dart';

/// Tüm müşteriler — süper admin listesi.
final StreamProvider<List<Tenant>> tenantsProvider =
    StreamProvider<List<Tenant>>(
      (ref) => ref.watch(tenantRepositoryProvider).watchTenants(),
    );

/// Tek bir müşteri — süper admin detay ekranı.
final tenantProvider = StreamProvider.family<Tenant?, String>(
  (ref, tenantId) => ref.watch(tenantRepositoryProvider).watchTenant(tenantId),
);

/// Bir müşterinin kullanıcıları — süper admin detay ekranı.
final tenantUsersProvider = StreamProvider.family<List<AppUser>, String>(
  (ref, tenantId) => ref.watch(userRepositoryProvider).watchUsers(tenantId),
);

/// Müşteri açma, abonelik ve durum yönetimi. Yalnız süper admin kullanır.
class TenantController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  TenantRepository get _tenants => ref.read(tenantRepositoryProvider);

  /// Yeni müşteri açar ve ilk yöneticisini oluşturur.
  ///
  /// Üç adım tek bir akışta yürür ve **sırası zorunludur**:
  /// 1. Müşteri kaydı — yöneticinin altına yazılacağı yol.
  /// 2. Rol varsayılanları — güvenlik kurallarının izin çözerken okuduğu
  ///    tablo. Bu yazılmadan açılan bir yönetici hiçbir şey yapamaz.
  /// 3. Yönetici hesabı — Auth + Firestore.
  ///
  /// Araya bir hata girerse yarım kalan müşteri süper adminin listesinde
  /// görünür ve elle silinebilir; sessizce kaybolmaz.
  Future<Result<Tenant>> createTenantWithAdmin({
    required String companyName,
    required String slug,
    required String adminEmail,
    required String adminPassword,
    required String adminName,
    SubscriptionPlan plan = SubscriptionPlan.trial,
    DateTime? expiresAt,
  }) async {
    state = const AsyncValue<void>.loading();

    final DateTime now = DateTime.now();
    final Subscription subscription = Subscription(
      plan: plan,
      startsAt: now,
      expiresAt: expiresAt ?? now.add(const Duration(days: 14)),
      maxUsers: plan.maxUsers,
      maxCheckpoints: plan.maxCheckpoints,
    );

    final Result<Tenant> created = await _tenants.createTenant(
      tenant: Tenant(
        id: '',
        name: companyName.trim(),
        slug: slug.trim().toLowerCase(),
        status: TenantStatus.active,
        subscription: subscription,
        settings: const TenantSettings(),
        counters: const TenantCounters(),
        createdAt: now,
      ),
      createdBy: ref.read(currentUserProvider)?.uid,
    );

    if (created case Err<Tenant>(:final Failure failure)) {
      state = AsyncValue<void>.error(failure, StackTrace.current);
      return Err<Tenant>(failure);
    }
    final Tenant tenant = (created as Ok<Tenant>).value;

    final Result<void> defaults = await _tenants.writeRoleDefaults(
      tenantId: tenant.id,
      defaults: RoleDefaults.allAsMaps(),
    );
    if (defaults case Err<void>(:final Failure failure)) {
      state = AsyncValue<void>.error(failure, StackTrace.current);
      return Err<Tenant>(failure);
    }

    final Result<String> account = await ref
        .read(authRepositoryProvider)
        .createAuthAccount(email: adminEmail, password: adminPassword);

    if (account case Err<String>(:final Failure failure)) {
      state = AsyncValue<void>.error(failure, StackTrace.current);
      return Err<Tenant>(failure);
    }

    final Result<AppUser> admin = await ref
        .read(userRepositoryProvider)
        .createUser(
          AppUser(
            uid: (account as Ok<String>).value,
            email: adminEmail.trim().toLowerCase(),
            displayName: adminName.trim(),
            tenantId: tenant.id,
            role: UserRole.admin,
            status: UserStatus.active,
            createdAt: now,
            createdBy: ref.read(currentUserProvider)?.uid,
          ),
        );

    if (admin case Err<AppUser>(:final Failure failure)) {
      state = AsyncValue<void>.error(failure, StackTrace.current);
      return Err<Tenant>(failure);
    }

    state = const AsyncValue<void>.data(null);
    return Ok<Tenant>(tenant);
  }

  Future<Result<void>> updateSubscription({
    required String tenantId,
    required Subscription subscription,
    TenantStatus? status,
  }) async {
    state = const AsyncValue<void>.loading();
    final Result<void> result = await _tenants.updateSubscription(
      tenantId: tenantId,
      subscription: subscription,
      status: status,
    );
    _finish(result);
    return result;
  }

  Future<Result<void>> updateStatus({
    required String tenantId,
    required TenantStatus status,
  }) async {
    state = const AsyncValue<void>.loading();
    final Result<void> result = await _tenants.updateStatus(
      tenantId: tenantId,
      status: status,
    );
    _finish(result);
    return result;
  }

  /// Müşteriyi ve tüm verisini siler.
  ///
  /// Auth hesapları silinmez — istemci başkasının hesabını silemez. Kalan
  /// hesaplar giriş yapabilir ama Firestore kaydı olmadığı için oturum
  /// "hesabınız tanımlı değil" diyerek engellenir.
  Future<Result<void>> deleteTenant(String tenantId) async {
    state = const AsyncValue<void>.loading();
    final Result<void> result = await _tenants.deleteTenant(tenantId);
    _finish(result);
    return result;
  }

  /// Rol varsayılanlarını bugünkü izin kataloğuyla tazeler.
  ///
  /// İzin kataloğu genişlediğinde eski müşterilerin tablosunda yeni anahtar
  /// bulunmaz ve güvenlik kuralı onu "kapalı" sayar. Bu düğme farkı kapatır.
  Future<Result<void>> refreshRoleDefaults(String tenantId) async {
    state = const AsyncValue<void>.loading();
    final Result<void> result = await _tenants.writeRoleDefaults(
      tenantId: tenantId,
      defaults: RoleDefaults.allAsMaps(),
    );
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

final AsyncNotifierProvider<TenantController, void> tenantControllerProvider =
    AsyncNotifierProvider<TenantController, void>(TenantController.new);
