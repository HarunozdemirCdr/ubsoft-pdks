import 'package:ubsoft_pdks/core/result/result.dart';
import 'package:ubsoft_pdks/domain/entities/tenant.dart';
import 'package:ubsoft_pdks/domain/enums/tenant_status.dart';

/// Yurt kayıtları — `tenants/{tid}`.
///
/// Yazma işlemlerinin çoğu yalnız süper adminindir; yurt yöneticisi
/// yalnız kendi yurt bilgilerini ve devam ayarlarını değiştirebilir.
abstract interface class TenantRepository {
  Stream<Tenant?> watchTenant(String tenantId);

  /// Tüm yurtlar — süper admin listesi.
  Stream<List<Tenant>> watchTenants();

  Future<Result<Tenant>> getTenant(String tenantId);

  /// Yeni yurt açar; rol varsayılanlarını da kurar.
  Future<Result<Tenant>> createTenant({
    required Tenant tenant,
    String? createdBy,
  });

  /// Yurt bilgileri ve devam ayarları — yönetici de yapabilir.
  Future<Result<void>> updateSettings({
    required String tenantId,
    required String name,
    required TenantSettings settings,
    String? timezone,
  });

  /// Abonelik ve durum — yalnız süper admin.
  Future<Result<void>> updateSubscription({
    required String tenantId,
    required Subscription subscription,
    TenantStatus? status,
  });

  Future<Result<void>> updateStatus({
    required String tenantId,
    required TenantStatus status,
  });

  Future<Result<void>> deleteTenant(String tenantId);

  /// Rol varsayılanları: `{ 'admin': {'user.view': true, …}, … }`.
  Future<Result<Map<String, Map<String, bool>>>> getRoleDefaults(
    String tenantId,
  );

  /// Rol varsayılanlarını yazar — kurulum ve izin kataloğu genişlemesi için.
  Future<Result<void>> writeRoleDefaults({
    required String tenantId,
    required Map<String, Map<String, bool>> defaults,
  });
}
