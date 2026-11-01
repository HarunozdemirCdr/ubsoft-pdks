import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:ubsoft_pdks/core/config/firebase_collections.dart';
import 'package:ubsoft_pdks/core/error/error_mapper.dart';
import 'package:ubsoft_pdks/core/error/failure.dart';
import 'package:ubsoft_pdks/core/result/result.dart';

/// Firestore repository'leri için ortak temel.
///
/// İki şeyi tek yerde çözer:
///  • **Hata dönüşümü** — her platform istisnası [Result] içinde bir
///    `Failure`'a çevrilir; çağıran taraf asla `FirebaseException` görmez.
///  • **Yol üretimi** — tenant altındaki koleksiyonlara erişim tek yerden
///    kurulur, böylece bir yerde yanlış yol yazılıp veri sızması olmaz.
abstract base class FirestoreRepositoryBase {
  const FirestoreRepositoryBase(this.firestore);

  @protected
  final FirebaseFirestore firestore;

  // ─────────────────────────── Yol üreticiler ───────────────────────────

  @protected
  CollectionReference<Map<String, dynamic>> get tenantsRef =>
      firestore.collection(FsPaths.tenants);

  /// Bir yurdun kullanıcıları: `tenants/{tenantId}/users`.
  @protected
  CollectionReference<Map<String, dynamic>> usersRef(String tenantId) =>
      subcollection(tenantId, FsPaths.users);

  /// Tüm yurtlardeki kullanıcılar üzerinde arama yapar.
  ///
  /// Giriş yapan kullanıcı hangi yurda ait olduğunu bilmediği için
  /// oturum çözümü bu sorguyla başlar.
  @protected
  Query<Map<String, dynamic>> get allUsersQuery =>
      firestore.collectionGroup(FsPaths.users);

  @protected
  DocumentReference<Map<String, dynamic>> tenantRef(String tenantId) =>
      tenantsRef.doc(tenantId);

  @protected
  CollectionReference<Map<String, dynamic>> subcollection(
    String tenantId,
    String name,
  ) => tenantRef(tenantId).collection(name);

  // ─────────────────────────── Hata sarmalayıcılar ───────────────────────

  /// Bir yazma/okuma işlemini çalıştırır ve hatayı [Result]'a çevirir.
  @protected
  Future<Result<T>> guard<T>(Future<T> Function() action) async {
    try {
      return Ok<T>(await action());
    } catch (error, stackTrace) {
      _log(error, stackTrace);
      return Err<T>(ErrorMapper.map(error, stackTrace));
    }
  }

  /// Değer döndürmeyen işlemler için kısayol.
  @protected
  Future<Result<void>> guardVoid(Future<void> Function() action) =>
      guard<void>(() async {
        await action();
      });

  /// Bir akışı dinlerken oluşan hataları günlüğe düşürür ve yeniden fırlatır.
  ///
  /// Akış hataları [Result]'a sarılmaz; Riverpod'un `AsyncError` mekanizması
  /// üzerinden arayüze taşınır ve `ErrorView` tarafından Türkçeye çevrilir.
  @protected
  Stream<T> guardStream<T>(Stream<T> source) {
    return source.handleError((Object error, StackTrace stackTrace) {
      _log(error, stackTrace);
      throw ErrorMapper.map(error, stackTrace);
    });
  }

  /// İlk dinleyici cevabı gelmezse sunucudan bir kez doğrular. Boş cevap da
  /// geçerli veridir; bağlantı sorunu hiçbir zaman boş listeye çevrilmez.
  /// Sonraki canlı değişiklikler dinlenmeye devam eder. Yeni canlı veri
  /// geldiyse geciken ilk okumanın eski sonucu ekranın üzerine yazılmaz.
  @protected
  Stream<T> guardLiveStream<T>(
    Stream<T> source, {
    required Future<T> Function() loadInitial,
    Duration initialWait = const Duration(seconds: 4),
    Duration requestTimeout = const Duration(seconds: 12),
  }) => guardStream(
    Stream<T>.multi((controller) {
      bool received = false;
      bool cancelled = false;
      Timer? timer;
      void add(T data) {
        if (cancelled) return;
        received = true;
        timer?.cancel();
        controller.add(data);
      }

      final subscription = source.listen(
        add,
        onError: (Object error, StackTrace stack) {
          if (cancelled) return;
          received = true;
          timer?.cancel();
          controller.addError(error, stack);
        },
        onDone: () {
          timer?.cancel();
          if (!received && !cancelled) {
            controller.addError(
              const NetworkFailure(
                message:
                    'Kayıtlar alınamadı. Bağlantınızı kontrol edip yeniden deneyin.',
              ),
            );
          }
          controller.close();
        },
      );
      timer = Timer(initialWait, () async {
        try {
          final data = await loadInitial().timeout(requestTimeout);
          if (!received && !cancelled) add(data);
        } catch (error, stack) {
          if (!received && !cancelled) {
            controller.addError(
              error is TimeoutException
                  ? const NetworkFailure(
                      message:
                          'Kayıtlar alınırken yanıt bekleniyor. Bağlantınızı kontrol edip yeniden deneyin.',
                      code: 'initial-read-timeout',
                    )
                  : error,
              stack,
            );
          }
        }
      });
      controller.onCancel = () {
        cancelled = true;
        timer?.cancel();
        return subscription.cancel();
      };
    }),
  );

  void _log(Object error, StackTrace stackTrace) {
    if (kDebugMode) {
      debugPrint('[${runtimeType.toString()}] $error');
    }
  }
}
