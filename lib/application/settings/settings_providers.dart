import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubsoft_pdks/application/auth/session_provider.dart';
import 'package:ubsoft_pdks/application/providers.dart';
import 'package:ubsoft_pdks/core/error/failure.dart';
import 'package:ubsoft_pdks/core/result/result.dart';
import 'package:ubsoft_pdks/domain/entities/tenant.dart';

/// Yurt bilgileri ve devam ayarları.
class SettingsController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<Result<void>> save({
    required String name,
    required TenantSettings settings,
  }) async {
    state = const AsyncValue<void>.loading();

    final Result<void> result = await ref
        .read(tenantRepositoryProvider)
        .updateSettings(
          tenantId: ref.read(tenantIdProvider),
          name: name,
          settings: settings,
        );

    state = switch (result) {
      Ok<void>() => const AsyncValue<void>.data(null),
      Err<void>(:final Failure failure) => AsyncValue<void>.error(
        failure,
        StackTrace.current,
      ),
    };
    return result;
  }
}

final AsyncNotifierProvider<SettingsController, void>
settingsControllerProvider = AsyncNotifierProvider<SettingsController, void>(
  SettingsController.new,
);
