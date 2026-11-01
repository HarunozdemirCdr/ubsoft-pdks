import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubsoft_pdks/application/auth/session_provider.dart';
import 'package:ubsoft_pdks/application/providers.dart';
import 'package:ubsoft_pdks/core/config/app_config.dart';
import 'package:ubsoft_pdks/data/repositories/firestore_repository_base.dart';

const relayPins = [26, 27, 25, 32, 14, 12, 13, 15];
final turnstileFunctionsProvider = Provider<FirebaseFunctions>((ref) {
  final functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
  if (AppConfig.useEmulator) {
    functions.useFunctionsEmulator(AppConfig.emulatorHost, 5001);
  }
  return functions;
});
final turnstileStateProvider = StreamProvider<Map<String, dynamic>>((ref) {
  final tid = ref.watch(tenantIdProvider);
  if (tid.isEmpty || tid == '_system') return Stream.value({});
  return TurnstileRepository(ref.watch(firestoreProvider)).watchState(tid);
});
Future<Map<String, dynamic>> turnstileCall(
  WidgetRef ref,
  String name, [
  Map<String, dynamic> data = const {},
]) async {
  final result = await ref
      .read(turnstileFunctionsProvider)
      .httpsCallable(
        name,
        options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
      )
      .call<Object?>({'tenantId': ref.read(tenantIdProvider), ...data});
  return Map<String, dynamic>.from(result.data! as Map);
}

final class TurnstileRepository extends FirestoreRepositoryBase {
  const TurnstileRepository(super.firestore);
  Stream<Map<String, dynamic>> watchState(String tid) {
    final doc = firestore.doc('tenants/$tid/turnstileState/controller');
    return guardLiveStream(
      doc
          .snapshots(includeMetadataChanges: true)
          .map((s) => s.data() ?? <String, dynamic>{}),
      loadInitial: () async =>
          (await doc.get(const GetOptions(source: Source.server))).data() ??
          <String, dynamic>{},
    );
  }
}
