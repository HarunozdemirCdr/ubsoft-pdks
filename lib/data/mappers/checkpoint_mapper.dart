import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ubsoft_pdks/core/config/app_config.dart';
import 'package:ubsoft_pdks/data/mappers/firestore_converters.dart';
import 'package:ubsoft_pdks/domain/entities/checkpoint.dart';
import 'package:ubsoft_pdks/domain/enums/punch_type.dart';

/// `tenants/{tid}/checkpoints/{id}` ↔ [Checkpoint].
abstract final class CheckpointMapper {
  static Checkpoint fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      fromMap(doc.data() ?? <String, dynamic>{}, id: doc.id);

  static Checkpoint fromMap(Map<String, dynamic> data, {required String id}) =>
      Checkpoint(
        id: id,
        code: data.str('code'),
        name: data.str('name'),
        description: data.strOrNull('description'),
        kind: CheckpointKind.fromKey(data.strOrNull('kind')),
        latitude: _double(data['latitude']),
        longitude: _double(data['longitude']),
        radiusMeters: data.integer(
          'radiusMeters',
          fallback: AppConfig.defaultRadiusMeters,
        ),
        active: data.boolean('active', fallback: true),
        order: data.integer('order'),
        createdAt: data.dateTime('createdAt'),
        updatedAt: data.dateTimeOrNull('updatedAt'),
        createdBy: data.strOrNull('createdBy'),
      );

  static Map<String, Object?> toCreateMap(Checkpoint value) =>
      <String, Object?>{
        ...toUpdateMap(value),
        'createdAt': FirestoreWrite.serverTime,
        if (value.createdBy != null) 'createdBy': value.createdBy,
      };

  static Map<String, Object?> toUpdateMap(Checkpoint value) =>
      <String, Object?>{
        'code': value.code.trim(),
        'name': value.name.trim(),
        'description': value.description?.trim() ?? '',
        'kind': value.kind.key,
        'latitude': value.latitude,
        'longitude': value.longitude,
        'radiusMeters': value.radiusMeters,
        'active': value.active,
        'order': value.order,
        'updatedAt': FirestoreWrite.serverTime,
      };

  /// Firestore sayıları `int` ya da `double` olarak döndürebilir; koordinat
  /// tam sayı yazıldığında (ör. 41) `int` gelir ve doğrudan cast çökerdi.
  static double _double(Object? value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.replaceAll(',', '.')) ?? 0;
    }
    return 0;
  }
}
