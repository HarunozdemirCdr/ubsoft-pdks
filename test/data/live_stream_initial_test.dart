import 'dart:async';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubsoft_pdks/core/error/failure.dart';
import 'package:ubsoft_pdks/data/repositories/firestore_repository_base.dart';

final class _Repository extends FirestoreRepositoryBase {
  _Repository() : super(FakeFirebaseFirestore());
  Stream<List<int>> watch(
    Stream<List<int>> source,
    Future<List<int>> Function() initial,
  ) => guardLiveStream(
    source,
    loadInitial: initial,
    initialWait: const Duration(milliseconds: 100),
    requestTimeout: const Duration(milliseconds: 200),
  );
}

void main() {
  test('ilk boş snapshot yüklemeyi bitirir ve fazladan okuma yapmaz', () async {
    final source = StreamController<List<int>>();
    final values = <List<int>>[];
    int reads = 0;
    final sub = _Repository()
        .watch(source.stream, () async {
          reads++;
          return [];
        })
        .listen(values.add);
    source.add([]);
    await Future<void>.delayed(const Duration(seconds: 1));
    expect(values, [<int>[]]);
    expect(reads, 0);
    await sub.cancel();
    await source.close();
  });
  test(
    'sessiz ilk dinleyici sunucu okumasıyla boş sonucu tamamlar ve canlı kalır',
    () async {
      final source = StreamController<List<int>>();
      final values = <List<int>>[];
      final sub = _Repository()
          .watch(source.stream, () async => [])
          .listen(values.add);
      await Future<void>.delayed(const Duration(milliseconds: 101));
      await Future<void>.delayed(Duration.zero);
      expect(values, [<int>[]]);
      source.add([1]);
      await Future<void>.delayed(Duration.zero);
      expect(values, [
        <int>[],
        [1],
      ]);
      await sub.cancel();
      await source.close();
    },
  );
  test('geciken ilk okuma daha yeni canlı veriyi ezmez', () async {
    final source = StreamController<List<int>>();
    final initial = Completer<List<int>>();
    final values = <List<int>>[];
    final sub = _Repository()
        .watch(source.stream, () => initial.future)
        .listen(values.add);
    await Future<void>.delayed(const Duration(milliseconds: 101));
    source.add([2]);
    await Future<void>.delayed(Duration.zero);
    initial.complete([]);
    await Future<void>.delayed(Duration.zero);
    expect(values, [
      [2],
    ]);
    await sub.cancel();
    await source.close();
  });
  test(
    'bağlantı yanıtsızken sonsuz yükleme yerine hata verir sonra canlı toparlanır',
    () async {
      final source = StreamController<List<int>>();
      final values = <List<int>>[];
      final errors = <Object>[];
      final initial = Completer<List<int>>();
      final sub = _Repository()
          .watch(source.stream, () => initial.future)
          .listen(values.add, onError: errors.add);
      await Future<void>.delayed(const Duration(milliseconds: 101));
      await Future<void>.delayed(const Duration(milliseconds: 201));
      await Future<void>.delayed(Duration.zero);
      expect(values, isEmpty);
      expect(errors.single, isA<NetworkFailure>());
      source.add([]);
      await Future<void>.delayed(Duration.zero);
      expect(values, [<int>[]]);
      initial.complete([]);
      await sub.cancel();
      await source.close();
    },
  );
  test('yetki hatası boş kayıt gibi gösterilmez', () async {
    final source = StreamController<List<int>>();
    final values = <List<int>>[];
    final errors = <Object>[];
    int reads = 0;
    final sub = _Repository()
        .watch(source.stream, () async {
          reads++;
          return [];
        })
        .listen(values.add, onError: errors.add);
    source.addError(const PermissionFailure());
    await Future<void>.delayed(const Duration(seconds: 1));
    expect(values, isEmpty);
    expect(errors.single, isA<PermissionFailure>());
    expect(reads, 0);
    await sub.cancel();
    await source.close();
  });
  test('ekrandan ayrılınca bekleyen ilk okuma ve dinleyici durur', () async {
    final source = StreamController<List<int>>();
    int reads = 0;
    final sub = _Repository()
        .watch(source.stream, () async {
          reads++;
          return [];
        })
        .listen((_) {});
    await sub.cancel();
    await Future<void>.delayed(const Duration(seconds: 1));
    expect(reads, 0);
    expect(source.hasListener, isFalse);
    await source.close();
  });
}
