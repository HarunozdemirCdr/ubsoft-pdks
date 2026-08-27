import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ubsoft_pdks/core/config/firebase_collections.dart';
import 'package:ubsoft_pdks/core/error/failure.dart';
import 'package:ubsoft_pdks/core/result/result.dart';
import 'package:ubsoft_pdks/data/mappers/firestore_converters.dart';
import 'package:ubsoft_pdks/data/mappers/user_mapper.dart';
import 'package:ubsoft_pdks/data/repositories/firestore_repository_base.dart';
import 'package:ubsoft_pdks/domain/entities/app_user.dart';
import 'package:ubsoft_pdks/domain/enums/user_role.dart';
import 'package:ubsoft_pdks/domain/enums/user_status.dart';
import 'package:ubsoft_pdks/domain/repositories/user_repository.dart';

/// Firestore tabanlı kullanıcı kayıtları.
final class UserRepositoryImpl extends FirestoreRepositoryBase
    implements UserRepository {
  const UserRepositoryImpl(super.firestore);

  @override
  Future<Result<AppUser>> findByUid(String uid) => guard(() async {
    // Kullanıcı hangi müşteride olduğunu bilmez; koleksiyon grubu üzerinde
    // tek seferlik arama yapılır. Güvenlik kuralı bu sorguyu yalnız kişinin
    // KENDİ kaydı için açar.
    final QuerySnapshot<Map<String, dynamic>> snapshot = await allUsersQuery
        .where('uid', isEqualTo: uid)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      throw const NotFoundFailure(
        message: 'Hesabınız sistemde tanımlı değil.',
        code: 'user-profile-missing',
      );
    }
    return UserMapper.fromDoc(snapshot.docs.first);
  });

  @override
  Stream<AppUser?> watchUser(String tenantId, String uid) => guardStream(
    usersRef(tenantId)
        .doc(uid)
        .snapshots()
        .map(
          (DocumentSnapshot<Map<String, dynamic>> doc) =>
              doc.exists ? UserMapper.fromDoc(doc) : null,
        ),
  );

  @override
  Stream<List<AppUser>> watchUsers(String tenantId) => guardStream(
    usersRef(tenantId)
        .orderBy(FsFields.displayName)
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, dynamic>> snapshot) => snapshot.docs
              .map(UserMapper.fromDoc)
              .where((AppUser user) => user.status.isVisible)
              .toList(growable: false),
        ),
  );

  @override
  Future<Result<AppUser>> createUser(AppUser user) => guard(() async {
    final DocumentReference<Map<String, dynamic>> doc = usersRef(
      user.tenantId,
    ).doc(user.uid);

    // Kullanıcı kaydı ve sayaç aynı toplu yazmada gider: sayaç ayrı bir
    // çağrıda güncellenseydi, yarıda kalan bir işlem abonelik limitini
    // kalıcı olarak yanlış gösterirdi.
    final WriteBatch batch = firestore.batch()
      ..set(doc, UserMapper.toCreateMap(user))
      ..update(tenantRef(user.tenantId), <String, Object?>{
        'counters.userCount': FirestoreWrite.increment(1),
        'updatedAt': FirestoreWrite.serverTime,
      });

    await batch.commit();
    return user;
  });

  @override
  Future<Result<void>> updateProfile({
    required String tenantId,
    required String uid,
    required String displayName,
    String? phone,
    String? note,
  }) => guardVoid(
    () => usersRef(tenantId).doc(uid).update(<String, Object?>{
      'displayName': displayName.trim(),
      'phone': phone?.trim() ?? '',
      'note': note?.trim() ?? '',
      // Eski "Görev" alanı her kayıtta temizlenir. Eşleyici `note` boşken
      // `title`'a düşüyor; silinmeseydi kullanıcı açıklamayı boşalttığında
      // ekranda eski unvan yeniden belirirdi.
      'title': '',
      'updatedAt': FirestoreWrite.serverTime,
    }),
  );

  @override
  Future<Result<void>> updateRole({
    required String tenantId,
    required String uid,
    required UserRole role,
  }) => guardVoid(() {
    if (role.isSuperAdmin) {
      throw const PermissionFailure(
        message: 'Süper admin rolü arayüzden atanamaz.',
        code: 'role-not-assignable',
      );
    }
    return usersRef(tenantId).doc(uid).update(<String, Object?>{
      FsFields.role: role.key,
      'updatedAt': FirestoreWrite.serverTime,
    });
  });

  @override
  Future<Result<void>> updateStatus({
    required String tenantId,
    required String uid,
    required UserStatus status,
  }) => guardVoid(
    () => usersRef(tenantId).doc(uid).update(<String, Object?>{
      FsFields.status: status.key,
      'updatedAt': FirestoreWrite.serverTime,
    }),
  );

  @override
  Future<Result<void>> updatePermissions({
    required String tenantId,
    required String uid,
    required Map<String, bool> overrides,
  }) => guardVoid(
    () => usersRef(tenantId).doc(uid).update(<String, Object?>{
      FsFields.permissions: overrides,
      'updatedAt': FirestoreWrite.serverTime,
    }),
  );

  @override
  Future<Result<void>> softDelete({
    required String tenantId,
    required String uid,
  }) => guardVoid(() async {
    final WriteBatch batch = firestore.batch()
      ..update(usersRef(tenantId).doc(uid), <String, Object?>{
        FsFields.status: UserStatus.deleted.key,
        'deletedAt': FirestoreWrite.serverTime,
        'updatedAt': FirestoreWrite.serverTime,
      })
      ..update(tenantRef(tenantId), <String, Object?>{
        'counters.userCount': FirestoreWrite.increment(-1),
        'updatedAt': FirestoreWrite.serverTime,
      });

    await batch.commit();
  });

  @override
  Future<Result<void>> touchLastLogin({
    required String tenantId,
    required String uid,
  }) => guardVoid(
    () => usersRef(tenantId).doc(uid).update(<String, Object?>{
      FsFields.lastLoginAt: FirestoreWrite.serverTime,
    }),
  );

  /// Bu e-posta sistemde kayıtlı mı?
  ///
  /// Yalnız bir **kolaylıktır**: kullanıcı formu doldurup göndermeden önce
  /// "bu adres zaten kayıtlı" diyebilmek için. Güvenlik kuralları koleksiyon
  /// grubu üzerinde yalnız kişinin kendi kaydını açtığı için bu sorgu
  /// çoğu zaman reddedilir ve [Err] döner — çağıran taraf bunu "bilinmiyor"
  /// sayıp devam eder. Gerçek engel Firebase Auth'un kendisidir; aynı adres
  /// ikinci kez açılmak istendiğinde `email-already-in-use` verir.
  @override
  Future<Result<bool>> emailExists(String email) => guard(() async {
    final String normalized = email.trim().toLowerCase();
    final QuerySnapshot<Map<String, dynamic>> snapshot = await allUsersQuery
        .where(FsFields.email, isEqualTo: normalized)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  });
}
