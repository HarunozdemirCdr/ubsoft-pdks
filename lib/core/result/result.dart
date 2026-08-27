import 'package:ubsoft_pdks/core/error/failure.dart';

/// İşlem sonucu — ya başarı ([Ok]) ya da hata ([Err]).
///
/// Repository ve use case katmanları istisna fırlatmaz; sonucu bu tiple döner.
/// Böylece çağıran taraf hata durumunu ele almayı **unutamaz** — `switch`
/// üzerinde derleyici zorunlu tutar.
///
/// ```dart
/// final result = await repo.startPatrol(...);
/// switch (result) {
///   case Ok(:final value): _goToPatrol(value);
///   case Err(:final failure): _showError(failure.message);
/// }
/// ```
sealed class Result<T> {
  const Result();

  /// Başarılıysa değeri, değilse `null`.
  T? get valueOrNull => switch (this) {
    Ok<T>(:final T value) => value,
    Err<T>() => null,
  };

  /// Hata varsa [Failure], yoksa `null`.
  Failure? get failureOrNull => switch (this) {
    Ok<T>() => null,
    Err<T>(:final Failure failure) => failure,
  };

  bool get isOk => this is Ok<T>;
  bool get isErr => this is Err<T>;

  /// Başarı değerini dönüştürür, hatayı olduğu gibi taşır.
  Result<R> map<R>(R Function(T value) transform) => switch (this) {
    Ok<T>(:final T value) => Ok<R>(transform(value)),
    Err<T>(:final Failure failure) => Err<R>(failure),
  };

  /// Zincirleme: başarılıysa bir sonraki işlemi çalıştırır.
  Result<R> flatMap<R>(Result<R> Function(T value) transform) => switch (this) {
    Ok<T>(:final T value) => transform(value),
    Err<T>(:final Failure failure) => Err<R>(failure),
  };

  /// İki dalı da ele alarak tek bir değere indirger.
  R fold<R>(R Function(T value) onOk, R Function(Failure failure) onErr) =>
      switch (this) {
        Ok<T>(:final T value) => onOk(value),
        Err<T>(:final Failure failure) => onErr(failure),
      };
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;

  @override
  String toString() => 'Ok($value)';
}

final class Err<T> extends Result<T> {
  const Err(this.failure);
  final Failure failure;

  @override
  String toString() => 'Err($failure)';
}

/// Değer taşımayan başarı durumu için kısayol.
typedef VoidResult = Result<void>;

const VoidResult okVoid = Ok<void>(null);
