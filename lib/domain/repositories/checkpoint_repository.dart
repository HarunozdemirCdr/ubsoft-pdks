import 'package:ubsoft_pdks/core/result/result.dart';
import 'package:ubsoft_pdks/domain/entities/checkpoint.dart';

/// QR noktaları — `tenants/{tid}/checkpoints/{id}`.
abstract interface class CheckpointRepository {
  /// Müşterinin tüm noktaları, sıraya göre.
  Stream<List<Checkpoint>> watchCheckpoints(String tenantId);

  Stream<Checkpoint?> watchCheckpoint(String tenantId, String id);

  /// Okunan koda karşılık gelen noktayı bulur.
  ///
  /// Kod, `qrIndex` defteri üzerinden çözülür: tarama tek bir doküman
  /// okumasıyla biter, koleksiyon taranmaz.
  Future<Result<Checkpoint>> findByCode({
    required String tenantId,
    required String code,
  });

  /// Yeni nokta ekler ve kodunu `qrIndex` defterine yazar.
  ///
  /// Kod başka bir noktada kullanılıyorsa [ConflictFailure] döner — kontrol
  /// istemcide değil, işlem (transaction) içinde yapılır; iki yönetici aynı
  /// anda aynı numarayı verirse ikincisi reddedilir.
  Future<Result<Checkpoint>> createCheckpoint({
    required String tenantId,
    required Checkpoint checkpoint,
    String? createdBy,
  });

  /// Noktayı günceller; kod değiştiyse defteri de taşır.
  Future<Result<void>> updateCheckpoint({
    required String tenantId,
    required Checkpoint checkpoint,
  });

  Future<Result<void>> deleteCheckpoint({
    required String tenantId,
    required Checkpoint checkpoint,
  });

  /// Sıralamayı topluca yazar.
  Future<Result<void>> reorder({
    required String tenantId,
    required List<String> orderedIds,
  });
}
