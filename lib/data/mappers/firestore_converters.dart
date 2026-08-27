import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore ham verisinden güvenli okuma yardımcıları.
///
/// Firestore şemasız çalışır: bir alan eksik olabilir, beklenen tipte
/// olmayabilir ya da `null` gelebilir. Bu yardımcılar her durumda makul bir
/// varsayılan döner; böylece tek bozuk kayıt yüzünden liste ekranı çökmez.
extension FirestoreMapX on Map<String, dynamic> {
  String str(String key, {String fallback = ''}) {
    final Object? value = this[key];
    return value is String ? value : fallback;
  }

  String? strOrNull(String key) {
    final Object? value = this[key];
    if (value is! String) return null;
    return value.trim().isEmpty ? null : value;
  }

  int integer(String key, {int fallback = 0}) {
    final Object? value = this[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  int? integerOrNull(String key) {
    final Object? value = this[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }

  bool boolean(String key, {bool fallback = false}) {
    final Object? value = this[key];
    return value is bool ? value : fallback;
  }

  /// Zaman damgası.
  ///
  /// `serverTimestamp()` ile yazılan bir alan, sunucu onayı gelmeden önce
  /// yerel önbellekte `null` görünür. Bu durumda [fallback] (varsayılan:
  /// şu an) döner ve arayüz boş tarih göstermez.
  DateTime dateTime(String key, {DateTime? fallback}) {
    final Object? value = this[key];
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value) ?? _now(fallback);
    return _now(fallback);
  }

  DateTime? dateTimeOrNull(String key) {
    final Object? value = this[key];
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  List<String> stringList(String key) {
    final Object? value = this[key];
    if (value is! List) return const <String>[];
    return value.whereType<String>().toList(growable: false);
  }

  Map<String, bool> boolMap(String key) {
    final Object? value = this[key];
    if (value is! Map) return const <String, bool>{};
    final Map<String, bool> result = <String, bool>{};
    value.forEach((dynamic k, dynamic v) {
      if (k is String && v is bool) result[k] = v;
    });
    return result;
  }

  Map<String, dynamic> nested(String key) {
    final Object? value = this[key];
    if (value is Map) return Map<String, dynamic>.from(value);
    return const <String, dynamic>{};
  }

  static DateTime _now(DateTime? fallback) => fallback ?? DateTime.now();
}

/// Firestore'a yazarken kullanılan yardımcılar.
abstract final class FirestoreWrite {
  /// Sunucu zaman damgası.
  ///
  /// İstemci saati asla kullanılmaz: kullanıcının bilgisayarının saati yanlış
  /// olabilir ve güvenlik kuralları zaten sunucu saatini zorunlu tutar.
  static FieldValue get serverTime => FieldValue.serverTimestamp();

  static FieldValue increment(int by) => FieldValue.increment(by);

  static FieldValue arrayAdd(List<Object?> values) =>
      FieldValue.arrayUnion(values);

  static FieldValue arrayRemove(List<Object?> values) =>
      FieldValue.arrayRemove(values);

  static FieldValue get delete => FieldValue.delete();

  /// `null` değerleri temizler.
  ///
  /// Firestore'a `null` yazmak alanı `null` yapar; genellikle istenen şey
  /// alanı hiç yazmamaktır (mevcut değer korunsun diye).
  static Map<String, Object?> prune(Map<String, Object?> data) {
    final Map<String, Object?> result = <String, Object?>{};
    data.forEach((String key, Object? value) {
      if (value != null) result[key] = value;
    });
    return result;
  }

  /// Tarih değerini yazılabilir biçime çevirir.
  static Timestamp? timestamp(DateTime? value) =>
      value == null ? null : Timestamp.fromDate(value);
}
