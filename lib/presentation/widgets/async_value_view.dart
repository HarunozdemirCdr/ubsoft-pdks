import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubsoft_pdks/presentation/widgets/error_view.dart';
import 'package:ubsoft_pdks/presentation/widgets/loading_view.dart';

/// [AsyncValue]'yu ekrana çeviren tek yol.
///
/// Her sayfada `when(data:, loading:, error:)` yazmak yerine bu bileşen
/// kullanılır. Böylece yükleme ve hata görünümleri uygulamanın tamamında
/// aynıdır ve bir ekranda unutulmuş hata durumu kalmaz.
///
/// Yenileme (refresh) sırasında eski veri korunur: kullanıcı boş ekrana
/// düşmez, içerik yerinde kalırken üstte ince bir ilerleme çizgisi belirir.
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    required this.value,
    required this.builder,
    this.onRetry,
    this.loading,
    this.compact = false,
    this.skipLoadingOnRefresh = true,
    super.key,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final VoidCallback? onRetry;

  /// Özel yükleme görünümü (iskelet listesi gibi).
  final Widget? loading;

  final bool compact;

  /// Yenileme sırasında mevcut veriyi ekranda tutar.
  final bool skipLoadingOnRefresh;

  @override
  Widget build(BuildContext context) {
    return value.when(
      skipLoadingOnRefresh: skipLoadingOnRefresh,
      skipLoadingOnReload: skipLoadingOnRefresh,
      data: builder,
      loading: () => loading ?? LoadingView(compact: compact),
      error: (error, _) =>
          ErrorView(error: error, onRetry: onRetry, compact: compact),
    );
  }
}

/// Kaydırılabilir sayfalarda kullanılan sliver karşılığı.
class SliverAsyncValueView<T> extends StatelessWidget {
  const SliverAsyncValueView({
    required this.value,
    required this.builder,
    this.onRetry,
    this.loading,
    super.key,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final VoidCallback? onRetry;
  final Widget? loading;

  @override
  Widget build(BuildContext context) {
    return value.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      data: builder,
      loading: () => SliverFillRemaining(
        hasScrollBody: false,
        child: loading ?? const LoadingView(),
      ),
      error: (error, _) => SliverFillRemaining(
        hasScrollBody: false,
        child: ErrorView(error: error, onRetry: onRetry),
      ),
    );
  }
}
