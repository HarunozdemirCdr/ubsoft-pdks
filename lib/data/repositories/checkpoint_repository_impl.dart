import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ubsoft_pdks/core/config/app_config.dart';
import 'package:ubsoft_pdks/core/config/firebase_collections.dart';
import 'package:ubsoft_pdks/core/error/failure.dart';
import 'package:ubsoft_pdks/core/result/result.dart';
import 'package:ubsoft_pdks/data/mappers/checkpoint_mapper.dart';
import 'package:ubsoft_pdks/data/mappers/firestore_converters.dart';
import 'package:ubsoft_pdks/data/repositories/firestore_repository_base.dart';
import 'package:ubsoft_pdks/domain/entities/checkpoint.dart';
import 'package:ubsoft_pdks/domain/repositories/checkpoint_repository.dart';

/// Firestore tabanlı QR noktaları.
///
/// Kod tekilliği ayrı bir defterle (`qrIndex`) korunur: Firestore'da "şu
/// alan benzersiz olsun" diye bir kısıt yoktur, tekillik ancak doküman
/// kimliğiyle kurulur. Defter kaydı ile noktanın kendisi **aynı işlemde**
/// yazılır; ikisi ayrılırsa ya sahipsiz bir kod rezervasyonu ya da iki
/// noktaya verilmiş tek bir numara kalırdı.
final class CheckpointRepositoryImpl extends FirestoreRepositoryBase
    implements CheckpointRepository {
  const CheckpointRepositoryImpl(super.firestore);

  CollectionReference<Map<String, dynamic>> _checkpoints(String tenantId) =>
      subcollection(tenantId, FsPaths.checkpoints);

  CollectionReference<Map<String, dynamic>> _index(String tenantId) =>
      subcollection(tenantId, FsPaths.qrIndex);

  @override
  Stream<List<Checkpoint>> watchCheckpoints(String tenantId) => guardStream(
    _checkpoints(tenantId)
        .orderBy(FsFields.order)
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, dynamic>> snapshot) => snapshot.docs
              .map(CheckpointMapper.fromDoc)
              .toList(growable: false),
        ),
  );

  @override
  Stream<Checkpoint?> watchCheckpoint(String tenantId, String id) =>
      guardStream(
        _checkpoints(tenantId)
            .doc(id)
            .snapshots()
            .map(
              (DocumentSnapshot<Map<String, dynamic>> doc) =>
                  doc.exists ? CheckpointMapper.fromDoc(doc) : null,
            ),
      );

  /// Belgeyi önce sunucudan, süre dolarsa önbellekten okur.
  ///
  /// Okutma akışının ortasında süresiz beklemek kabul edilemez: kullanıcı
  /// dönen bir göstergeye bakar ve okutmanın olup olmadığını bilemez.
  /// Önbelleğe düşmek doğru karşılıktır — nokta bilgisi seyrek değişir ve
  /// bir önceki okutmadan zaten yereldedir; taze olmayan bir ad, hiç
  /// çalışmayan bir okutmadan iyidir.
  Future<DocumentSnapshot<Map<String, dynamic>>> _read(
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    try {
      return await ref.get().timeout(AppConfig.lookupTimeout);
    } on TimeoutException {
      try {
        return await ref.get(const GetOptions(source: Source.cache));
      } on FirebaseException {
        // Önbellekte de yok: gerçekten bağlantı sorunu. Kullanıcıya
        // "kod tanımsız" demek yanıltıcı olurdu.
        throw const NetworkFailure(
          message:
              'Bağlantı çok yavaş; kod okunamadı. Bağlantınızı kontrol edip '
              'tekrar deneyin.',
          code: 'lookup-timeout',
        );
      }
    }
  }

  @override
  Future<Result<Checkpoint>> findByCode({
    required String tenantId,
    required String code,
  }) => guard(() async {
    final DocumentSnapshot<Map<String, dynamic>> entry = await _read(
      _index(tenantId).doc(code),
    );

    if (!entry.exists) {
      throw PunchFailure(
        'Bu QR kodu ($code) sisteme tanımlı değil.',
        code: 'unknown-code',
      );
    }

    final String checkpointId = (entry.data() ?? <String, dynamic>{}).str(
      FsFields.checkpointId,
    );
    final DocumentSnapshot<Map<String, dynamic>> doc = await _read(
      _checkpoints(tenantId).doc(checkpointId),
    );

    if (!doc.exists) {
      // Defter kaydı duruyor ama nokta silinmiş: veri tutarsızlığı. Kullanıcı
      // suçlanmaz, kod "tanımsız" sayılır.
      throw PunchFailure(
        'Bu QR kodu ($code) sisteme tanımlı değil.',
        code: 'dangling-code',
      );
    }

    return CheckpointMapper.fromDoc(doc);
  });

  @override
  Future<Result<Checkpoint>> createCheckpoint({
    required String tenantId,
    required Checkpoint checkpoint,
    String? createdBy,
  }) => guard(() async {
    final DocumentReference<Map<String, dynamic>> doc = _checkpoints(
      tenantId,
    ).doc();
    final String code = checkpoint.code.trim();
    final DocumentReference<Map<String, dynamic>> indexDoc = _index(
      tenantId,
    ).doc(code);

    final Checkpoint created = Checkpoint(
      id: doc.id,
      code: code,
      name: checkpoint.name,
      description: checkpoint.description,
      kind: checkpoint.kind,
      latitude: checkpoint.latitude,
      longitude: checkpoint.longitude,
      radiusMeters: checkpoint.radiusMeters,
      active: checkpoint.active,
      order: checkpoint.order,
      createdAt: checkpoint.createdAt,
      createdBy: createdBy,
    );

    await firestore.runTransaction((Transaction transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> existing = await transaction
          .get(indexDoc);
      if (existing.exists) {
        throw ConflictFailure(
          '$code kodu başka bir noktada kullanılıyor.',
          code: 'code-taken',
        );
      }

      transaction
        ..set(doc, CheckpointMapper.toCreateMap(created))
        ..set(indexDoc, <String, Object?>{
          FsFields.checkpointId: doc.id,
          'createdAt': FirestoreWrite.serverTime,
        })
        ..update(tenantRef(tenantId), <String, Object?>{
          'counters.checkpointCount': FirestoreWrite.increment(1),
          'updatedAt': FirestoreWrite.serverTime,
        });
    });

    return created;
  });

  @override
  Future<Result<void>> updateCheckpoint({
    required String tenantId,
    required Checkpoint checkpoint,
  }) => guardVoid(() async {
    final DocumentReference<Map<String, dynamic>> doc = _checkpoints(
      tenantId,
    ).doc(checkpoint.id);
    final String code = checkpoint.code.trim();

    await firestore.runTransaction((Transaction transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> current = await transaction
          .get(doc);
      if (!current.exists) {
        throw const NotFoundFailure(message: 'Nokta bulunamadı.');
      }

      final String previousCode = (current.data() ?? <String, dynamic>{}).str(
        FsFields.code,
      );

      if (previousCode != code) {
        final DocumentReference<Map<String, dynamic>> nextIndex = _index(
          tenantId,
        ).doc(code);
        final DocumentSnapshot<Map<String, dynamic>> taken = await transaction
            .get(nextIndex);

        if (taken.exists &&
            (taken.data() ?? <String, dynamic>{}).str(FsFields.checkpointId) !=
                checkpoint.id) {
          throw ConflictFailure(
            '$code kodu başka bir noktada kullanılıyor.',
            code: 'code-taken',
          );
        }

        transaction
          ..set(nextIndex, <String, Object?>{
            FsFields.checkpointId: checkpoint.id,
            'createdAt': FirestoreWrite.serverTime,
          })
          ..delete(_index(tenantId).doc(previousCode));
      }

      transaction.update(doc, CheckpointMapper.toUpdateMap(checkpoint));
    });
  });

  @override
  Future<Result<void>> deleteCheckpoint({
    required String tenantId,
    required Checkpoint checkpoint,
  }) => guardVoid(() async {
    final WriteBatch batch = firestore.batch()
      ..delete(_checkpoints(tenantId).doc(checkpoint.id))
      ..delete(_index(tenantId).doc(checkpoint.code))
      ..update(tenantRef(tenantId), <String, Object?>{
        'counters.checkpointCount': FirestoreWrite.increment(-1),
        'updatedAt': FirestoreWrite.serverTime,
      });

    await batch.commit();
  });

  @override
  Future<Result<void>> reorder({
    required String tenantId,
    required List<String> orderedIds,
  }) => guardVoid(() async {
    final WriteBatch batch = firestore.batch();
    for (int i = 0; i < orderedIds.length; i++) {
      batch.update(_checkpoints(tenantId).doc(orderedIds[i]), <String, Object?>{
        FsFields.order: i,
        'updatedAt': FirestoreWrite.serverTime,
      });
    }
    await batch.commit();
  });
}
