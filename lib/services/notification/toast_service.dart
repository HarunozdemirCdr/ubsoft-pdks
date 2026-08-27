import 'package:flutter/material.dart';
import 'package:ubsoft_pdks/core/error/error_mapper.dart';
import 'package:ubsoft_pdks/core/error/failure.dart';
import 'package:ubsoft_pdks/core/result/result.dart';
import 'package:ubsoft_pdks/core/theme/app_colors.dart';
import 'package:ubsoft_pdks/core/theme/app_radius.dart';
import 'package:ubsoft_pdks/core/theme/app_spacing.dart';
import 'package:ubsoft_pdks/core/theme/app_typography.dart';

/// Kısa bildirim mesajları.
///
/// `ScaffoldMessenger` doğrudan çağrılmaz; tüm bildirimlerin görünümü ve süresi
/// burada standarttır. Böylece bir ekranda kırmızı, diğerinde gri bir hata
/// mesajı çıkmaz.
abstract final class Toast {
  /// Bildirimleri sayfa bağlamına ihtiyaç duymadan gösterebilmek için
  /// `MaterialApp.scaffoldMessengerKey` ile bağlanır.
  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static void success(String message) => _show(
    message,
    icon: Icons.check_circle_outline_rounded,
    tone: _Tone.success,
  );

  static void info(String message) =>
      _show(message, icon: Icons.info_outline_rounded, tone: _Tone.info);

  static void warning(String message) =>
      _show(message, icon: Icons.warning_amber_rounded, tone: _Tone.warning);

  static void error(String message) => _show(
    message,
    icon: Icons.error_outline_rounded,
    tone: _Tone.error,
    duration: const Duration(seconds: 5),
  );

  /// Ham hata nesnesini Türkçe mesaja çevirerek gösterir.
  static void failure(Object error) {
    final Failure mapped = ErrorMapper.map(error);
    Toast.error(mapped.message);
  }

  /// Bir [Result]'ı tek satırda bildirime çevirir.
  ///
  /// Her ekranda `switch (result) { Ok() => …, Err() => … }` yazmak yerine
  /// kullanılır; başarı ve hata mesajlarının biçimi böylece her yerde aynı
  /// kalır.
  static void result(Result<Object?> value, {required String successMessage}) {
    switch (value) {
      case Ok<Object?>():
        Toast.success(successMessage);
      case Err<Object?>(:final Failure failure):
        Toast.error(failure.message);
    }
  }

  static void dismiss() => messengerKey.currentState?.hideCurrentSnackBar();

  static void _show(
    String message, {
    required IconData icon,
    required _Tone tone,
    Duration duration = const Duration(seconds: 3),
  }) {
    final ScaffoldMessengerState? messenger = messengerKey.currentState;
    if (messenger == null) return;

    final Color accent = switch (tone) {
      _Tone.success => AppColors.successOnDark,
      _Tone.info => AppColors.primaryOnDark,
      _Tone.warning => AppColors.warningOnDark,
      _Tone.error => AppColors.dangerOnDark,
    };

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: duration,
          backgroundColor: AppColors.gray900,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(AppSpacing.md),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.allMd),
          content: Row(
            children: <Widget>[
              Icon(icon, size: 20, color: accent),
              AppSpacing.hSm,
              Expanded(
                child: Text(
                  message,
                  style: AppTypography.body(AppColors.white),
                ),
              ),
            ],
          ),
        ),
      );
  }
}

enum _Tone { success, info, warning, error }
