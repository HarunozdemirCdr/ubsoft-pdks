import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ubsoft_pdks/data/mappers/firestore_converters.dart';
import 'package:ubsoft_pdks/domain/entities/app_user.dart';
import 'package:ubsoft_pdks/domain/enums/user_role.dart';
import 'package:ubsoft_pdks/domain/enums/user_status.dart';

/// `tenants/{tid}/users/{uid}` ↔ [AppUser].
abstract final class UserMapper {
  static AppUser fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};
    return fromMap(data, id: doc.id, tenantId: _tenantIdOf(doc.reference));
  }

  static AppUser fromMap(
    Map<String, dynamic> data, {
    required String id,
    required String tenantId,
  }) => AppUser(
    uid: data.str('uid', fallback: id),
    email: data.str('email'),
    displayName: data.str('displayName'),
    phone: data.strOrNull('phone'),
    // `title` eski alan adıdır (v1.0 "Görev"); okunmaya devam edilir ki
    // kayıtlı metin bir sürüm yükseltmesiyle kaybolmasın.
    note: data.strOrNull('note') ?? data.strOrNull('title'),
    tenantId: data.str('tenantId', fallback: tenantId),
    role: UserRole.fromKey(data.strOrNull('role')),
    permissionOverrides: data.boolMap('permissions'),
    status: UserStatus.fromKey(data.strOrNull('status')),
    createdAt: data.dateTime('createdAt'),
    updatedAt: data.dateTimeOrNull('updatedAt'),
    lastLoginAt: data.dateTimeOrNull('lastLoginAt'),
    deletedAt: data.dateTimeOrNull('deletedAt'),
    createdBy: data.strOrNull('createdBy'),
  );

  /// Yeni kayıt için tam gövde.
  ///
  /// `uid` alanı doküman kimliğiyle aynı olsa da açıkça yazılır: oturum
  /// çözümündeki koleksiyon-grubu sorgusu (`where('uid','==',auth.uid)`)
  /// ancak bir **alan** üzerinden çalışabilir, doküman kimliğiyle değil.
  static Map<String, Object?> toCreateMap(AppUser user) => <String, Object?>{
    'uid': user.uid,
    'email': user.email.trim().toLowerCase(),
    'displayName': user.displayName.trim(),
    if ((user.phone ?? '').isNotEmpty) 'phone': user.phone!.trim(),
    if ((user.note ?? '').isNotEmpty) 'note': user.note!.trim(),
    'tenantId': user.tenantId,
    'role': user.role.key,
    'permissions': user.permissionOverrides,
    'status': user.status.key,
    'createdAt': FirestoreWrite.serverTime,
    'updatedAt': FirestoreWrite.serverTime,
    if (user.createdBy != null) 'createdBy': user.createdBy,
  };

  /// Doküman yolundan tenant kimliğini çıkarır: `tenants/{tid}/users/{uid}`.
  static String _tenantIdOf(DocumentReference<Object?> reference) {
    final DocumentReference<Object?>? tenantDoc = reference.parent.parent;
    return tenantDoc?.id ?? '';
  }
}
