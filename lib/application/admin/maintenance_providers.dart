import 'package:cloud_functions/cloud_functions.dart' hide Result;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubsoft_pdks/application/auth/session_provider.dart';
import 'package:ubsoft_pdks/core/config/app_config.dart';
import 'package:ubsoft_pdks/core/error/error_mapper.dart';
import 'package:ubsoft_pdks/core/result/result.dart';

final maintenanceFunctionsProvider = Provider<FirebaseFunctions>((ref) {
  final functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
  if (AppConfig.useEmulator) {
    functions.useFunctionsEmulator(AppConfig.emulatorHost, 5001);
  }
  return functions;
});

final maintenanceServiceProvider = Provider<MaintenanceService>(
  (ref) => MaintenanceService(
    ref.watch(maintenanceFunctionsProvider),
    ref.watch(tenantIdProvider),
  ),
);

final class MaintenanceService {
  const MaintenanceService(this._functions, this._tenantId);

  final FirebaseFunctions _functions;
  final String _tenantId;

  Future<Result<void>> clearAttendanceHistory() =>
      _call('clearAttendanceHistory');

  Future<Result<void>> deleteUserAndData(String uid) =>
      _call('deleteUserAndData', <String, Object?>{'uid': uid});

  Future<Result<void>> _call(
    String name, [
    Map<String, Object?> data = const <String, Object?>{},
  ]) async {
    try {
      await _functions
          .httpsCallable(
            name,
            options: HttpsCallableOptions(
              timeout: const Duration(seconds: 120),
            ),
          )
          .call<Object?>(<String, Object?>{'tenantId': _tenantId, ...data});
      return okVoid;
    } catch (error, stack) {
      return Err<void>(ErrorMapper.map(error, stack));
    }
  }
}
