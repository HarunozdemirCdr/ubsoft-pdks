import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ubsoft_pdks/core/config/firebase_collections.dart';
import 'package:ubsoft_pdks/core/error/failure.dart';
import 'package:ubsoft_pdks/core/result/result.dart';
import 'package:ubsoft_pdks/data/mappers/firestore_converters.dart';
import 'package:ubsoft_pdks/data/mappers/tenant_mapper.dart';
import 'package:ubsoft_pdks/data/repositories/firestore_repository_base.dart';
import 'package:ubsoft_pdks/domain/entities/tenant.dart';
import 'package:ubsoft_pdks/domain/enums/tenant_status.dart';
import 'package:ubsoft_pdks/domain/repositories/tenant_repository.dart';

/// Firestore tabanlı müşteri kayıtları.
final class TenantRepositoryImpl extends FirestoreRepositoryBase
    implements TenantRepository {
  const TenantRepositoryImpl(super.firestore);

  @override
  Stream<Tenant?> watchTenant(String tenantId) => guardStream(
    tenantRef(tenantId).snapshots().map(
      (DocumentSnapshot<Map<String, dynamic>> doc) =>
          doc.exists ? TenantMapper.fromDoc(doc) : null,
    ),
  );

  @override
  Stream<List<Tenant>> watchTenants() => guardStream(
    tenantsRef
        .orderBy(FsFields.name)
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, dynamic>> snapshot) => snapshot.docs
              // Sistem müşterisi süper adminlerin barınağıdır, gerçek bir
              // müşteri değildir; listede yer almaz.
              .where((doc) => doc.id != FsPaths.systemTenantId)
              .map(TenantMapper.fromDoc)
              .toList(growable: false),
        ),
  );

  @override
  Future<Result<Tenant>> getTenant(String tenantId) => guard(() async {
    final DocumentSnapshot<Map<String, dynamic>> doc = await tenantRef(
      tenantId,
    ).get();
    if (!doc.exists) {
      throw const NotFoundFailure(message: 'Müşteri kaydı bulunamadı.');
    }
    return TenantMapper.fromDoc(doc);
  });

  @override
  Future<Result<Tenant>> createTenant({
    required Tenant tenant,
    String? createdBy,
  }) => guard(() async {
    final DocumentReference<Map<String, dynamic>> doc = tenant.id.isEmpty
        ? tenantsRef.doc()
        : tenantsRef.doc(tenant.id);

    final Tenant created = Tenant(
      id: doc.id,
      name: tenant.name,
      slug: tenant.slug,
      status: tenant.status,
      subscription: tenant.subscription,
      settings: tenant.settings,
      counters: tenant.counters,
      createdAt: tenant.createdAt,
      timezone: tenant.timezone,
      locale: tenant.locale,
      createdBy: tenant.createdBy ?? createdBy,
    );

    await doc.set(TenantMapper.toCreateMap(created));
    return created;
  });

  @override
  Future<Result<void>> updateSettings({
    required String tenantId,
    required String name,
    required TenantSettings settings,
    String? timezone,
  }) => guardVoid(
    () => tenantRef(tenantId).update(<String, Object?>{
      FsFields.name: name.trim(),
      'settings': TenantMapper.settingsMap(settings),
      'timezone': ?timezone,
      'updatedAt': FirestoreWrite.serverTime,
    }),
  );

  @override
  Future<Result<void>> updateSubscription({
    required String tenantId,
    required Subscription subscription,
    TenantStatus? status,
  }) => guardVoid(
    () => tenantRef(tenantId).update(<String, Object?>{
      'subscription': TenantMapper.subscriptionMap(subscription),
      FsFields.status: ?status?.key,
      'updatedAt': FirestoreWrite.serverTime,
    }),
  );

  @override
  Future<Result<void>> updateStatus({
    required String tenantId,
    required TenantStatus status,
  }) => guardVoid(
    () => tenantRef(tenantId).update(<String, Object?>{
      FsFields.status: status.key,
      'updatedAt': FirestoreWrite.serverTime,
    }),
  );

  @override
  Future<Result<void>> deleteTenant(String tenantId) => guardVoid(() async {
    if (tenantId == FsPaths.systemTenantId) {
      throw const PermissionFailure(
        message: 'Sistem müşterisi silinemez.',
        code: 'system-tenant',
      );
    }

    // Alt koleksiyonlar tek tek boşaltılır: Firestore bir dokümanı silince
    // altındakileri silmez, onlar "yetim" olarak erişilebilir kalır ve
    // fatura üretmeye devam eder.
    for (final String collection in <String>[
      FsPaths.users,
      FsPaths.roleDefaults,
      FsPaths.checkpoints,
      FsPaths.qrIndex,
      FsPaths.attendance,
      FsPaths.attendanceDays,
    ]) {
      await _deleteCollection(subcollection(tenantId, collection));
    }

    await tenantRef(tenantId).delete();
  });

  @override
  Future<Result<Map<String, Map<String, bool>>>> getRoleDefaults(
    String tenantId,
  ) => guard(() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await subcollection(
      tenantId,
      FsPaths.roleDefaults,
    ).get();

    return <String, Map<String, bool>>{
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in snapshot.docs)
        doc.id: doc.data().boolMap(FsFields.permissions),
    };
  });

  @override
  Future<Result<void>> writeRoleDefaults({
    required String tenantId,
    required Map<String, Map<String, bool>> defaults,
  }) => guardVoid(() async {
    final WriteBatch batch = firestore.batch();
    defaults.forEach((String role, Map<String, bool> permissions) {
      batch.set(
        subcollection(tenantId, FsPaths.roleDefaults).doc(role),
        <String, Object?>{
          FsFields.permissions: permissions,
          'updatedAt': FirestoreWrite.serverTime,
        },
      );
    });
    await batch.commit();
  });

  /// Bir koleksiyonu sayfa sayfa boşaltır.
  ///
  /// Toplu yazma sınırı 500'dür; devam kayıtları binlerce dokümana ulaşabilir.
  Future<void> _deleteCollection(
    CollectionReference<Map<String, dynamic>> reference,
  ) async {
    while (true) {
      final QuerySnapshot<Map<String, dynamic>> page = await reference
          .limit(300)
          .get();
      if (page.docs.isEmpty) return;

      final WriteBatch batch = firestore.batch();
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in page.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      if (page.docs.length < 300) return;
    }
  }
}
