import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubsoft_pdks/application/auth/session_provider.dart';
import 'package:ubsoft_pdks/application/providers.dart';
import 'package:ubsoft_pdks/core/error/failure.dart';
import 'package:ubsoft_pdks/core/result/result.dart';
import 'package:ubsoft_pdks/domain/entities/app_user.dart';
import 'package:ubsoft_pdks/domain/entities/checkpoint.dart';
import 'package:ubsoft_pdks/domain/entities/tenant.dart';
import 'package:ubsoft_pdks/domain/repositories/checkpoint_repository.dart';

/// Müşterinin tüm QR noktaları, sıraya göre.
final StreamProvider<List<Checkpoint>> checkpointsProvider =
    StreamProvider<List<Checkpoint>>(
      (ref) => ref
          .watch(checkpointRepositoryProvider)
          .watchCheckpoints(ref.watch(tenantIdProvider)),
    );

/// Yalnız etkin noktalar — okutma ve seçim listeleri için.
final Provider<List<Checkpoint>> activeCheckpointsProvider =
    Provider<List<Checkpoint>>(
      (ref) =>
          ref
              .watch(checkpointsProvider)
              .value
              ?.where((Checkpoint c) => c.active)
              .toList(growable: false) ??
          const <Checkpoint>[],
    );

/// Tek bir nokta — düzenleme ekranı için.
final checkpointProvider = StreamProvider.family<Checkpoint?, String>(
  (ref, id) => ref
      .watch(checkpointRepositoryProvider)
      .watchCheckpoint(ref.watch(tenantIdProvider), id),
);

/// Nokta oluşturma, düzenleme ve silme işlemleri.
class CheckpointController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  CheckpointRepository get _repository =>
      ref.read(checkpointRepositoryProvider);

  String get _tenantId => ref.read(tenantIdProvider);
  AppUser? get _actor => ref.read(currentUserProvider);

  Future<Result<Checkpoint>> create(Checkpoint checkpoint) async {
    state = const AsyncValue<void>.loading();

    // Abonelik limiti istemcide de kontrol edilir: kullanıcı formu doldurup
    // gönderdikten sonra reddedilmek yerine, düğmeye basmadan önce uyarılır.
    // Gerçek kapı yine güvenlik kurallarıdır.
    final Tenant? tenant = ref.read(currentTenantProvider);
    if (tenant != null && tenant.checkpointLimitReached) {
      final SubscriptionFailure failure = SubscriptionFailure(
        'Abonelik planınız en fazla ${tenant.subscription.maxCheckpoints} '
        'QR noktasına izin veriyor.',
        code: 'checkpoint-limit',
      );
      state = AsyncValue<void>.error(failure, StackTrace.current);
      return Err<Checkpoint>(failure);
    }

    final Result<Checkpoint> result = await _repository.createCheckpoint(
      tenantId: _tenantId,
      checkpoint: checkpoint,
      createdBy: _actor?.uid,
    );

    _finish(result);
    return result;
  }

  Future<Result<void>> save(Checkpoint checkpoint) async {
    state = const AsyncValue<void>.loading();
    final Result<void> result = await _repository.updateCheckpoint(
      tenantId: _tenantId,
      checkpoint: checkpoint,
    );
    _finish(result);
    return result;
  }

  Future<Result<void>> setActive(
    Checkpoint checkpoint, {
    required bool active,
  }) => save(checkpoint.copyWith(active: active));

  Future<Result<void>> delete(Checkpoint checkpoint) async {
    state = const AsyncValue<void>.loading();
    final Result<void> result = await _repository.deleteCheckpoint(
      tenantId: _tenantId,
      checkpoint: checkpoint,
    );
    _finish(result);
    return result;
  }

  Future<Result<void>> reorder(List<String> orderedIds) async {
    state = const AsyncValue<void>.loading();
    final Result<void> result = await _repository.reorder(
      tenantId: _tenantId,
      orderedIds: orderedIds,
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

final AsyncNotifierProvider<CheckpointController, void>
checkpointControllerProvider =
    AsyncNotifierProvider<CheckpointController, void>(CheckpointController.new);
