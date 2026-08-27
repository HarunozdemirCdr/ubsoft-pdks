import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ubsoft_pdks/core/theme/app_colors.dart';
import 'package:ubsoft_pdks/core/theme/app_radius.dart';
import 'package:ubsoft_pdks/core/theme/app_spacing.dart';
import 'package:ubsoft_pdks/core/theme/app_typography.dart';

/// Uygulama temaları.
///
/// Material 3 tabanı kullanılıyor ancak varsayılan Material görünümü
/// (dolgulu alanlar, büyük köşe yuvarlamaları, mor tonlar) bilinçli olarak
/// eziliyor. Amaç: nötr, sakin, kurumsal bir yüzey.
abstract final class AppTheme {
  static ThemeData get light => _build(isDark: false);
  static ThemeData get dark => _build(isDark: true);

  static ThemeData _build({required bool isDark}) {
    final Color surface = isDark ? AppColors.surfaceDark : AppColors.surface;
    final Color surfaceAlt = isDark
        ? AppColors.surfaceAltDark
        : AppColors.surfaceAlt;
    final Color border = isDark ? AppColors.borderDark : AppColors.border;
    final Color textPrimary = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimary;
    final Color textBody = isDark ? AppColors.textBodyDark : AppColors.textBody;
    final Color textMuted = isDark
        ? AppColors.textMutedDark
        : AppColors.textMuted;
    final Color accent = isDark ? AppColors.primaryOnDark : AppColors.primary;

    final ColorScheme scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: isDark ? Brightness.dark : Brightness.light,
        ).copyWith(
          primary: AppColors.primary,
          onPrimary: AppColors.white,
          primaryContainer: isDark
              ? AppColors.primarySurfaceDark
              : AppColors.primarySurface,
          onPrimaryContainer: accent,
          surface: surface,
          onSurface: textPrimary,
          surfaceContainerLowest: surface,
          surfaceContainerLow: surfaceAlt,
          surfaceContainer: surfaceAlt,
          surfaceContainerHigh: isDark
              ? AppColors.surfaceMutedDark
              : AppColors.surfaceMuted,
          surfaceContainerHighest: isDark
              ? AppColors.surfaceMutedDark
              : AppColors.surfaceMuted,
          onSurfaceVariant: textBody,
          outline: border,
          outlineVariant: border,
          error: isDark ? AppColors.dangerOnDark : AppColors.danger,
          onError: AppColors.white,
          shadow: AppColors.shadow,
          scrim: AppColors.scrim,
        );

    final TextTheme textTheme = AppTypography.textTheme(
      primary: textPrimary,
      body: textBody,
      muted: textMuted,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: surface,
      canvasColor: surface,
      textTheme: textTheme,
      fontFamily: AppTypography.fontFamily,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,

      // Web'de sürükleyerek kaydırma (fare + dokunmatik) açık.
      scrollbarTheme: ScrollbarThemeData(
        thickness: WidgetStateProperty.all(6),
        radius: const Radius.circular(AppRadius.full),
        thumbColor: WidgetStateProperty.all(
          isDark ? AppColors.gray700 : AppColors.gray300,
        ),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.h2(textPrimary),
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),

      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),

      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.allLg,
          side: BorderSide(color: border),
        ),
      ),

      // ─────────── Butonlar: yumuşak dikdörtgen, 48px yükseklik ───────────
      //
      // Tam yuvarlak (pill) buton bilinçli olarak kullanılmıyor; ürünün geri
      // kalanı hizalı satırlardan oluşuyor ve pill butonlar o hizayı bozuyor.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
          disabledBackgroundColor: isDark
              ? AppColors.gray800
              : AppColors.gray200,
          disabledForegroundColor: AppColors.gray400,
          elevation: 0,
          minimumSize: const Size(0, AppSpacing.touchTarget),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.allMd),
          textStyle: AppTypography.label(AppColors.white),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          minimumSize: const Size(0, AppSpacing.touchTarget),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          side: BorderSide(
            color: isDark ? AppColors.borderStrongDark : AppColors.borderStrong,
          ),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.allMd),
          textStyle: AppTypography.label(textPrimary),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          minimumSize: const Size(0, AppSpacing.touchTarget),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.allSm),
          textStyle: AppTypography.label(accent),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: textBody,
          minimumSize: const Size(
            AppSpacing.touchTarget,
            AppSpacing.touchTarget,
          ),
        ),
      ),

      // ─────────────── Form alanları ───────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.surfaceAltDark : AppColors.surfaceAlt,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 2,
        ),
        hintStyle: AppTypography.body(AppColors.textPlaceholder),
        labelStyle: AppTypography.label(textBody),
        floatingLabelStyle: AppTypography.label(accent),
        errorStyle: AppTypography.small(
          isDark ? AppColors.dangerOnDark : AppColors.danger,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.allMd,
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.allMd,
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: AppRadius.allMd,
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.allMd,
          borderSide: BorderSide(
            color: isDark ? AppColors.dangerOnDark : AppColors.danger,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.allMd,
          borderSide: BorderSide(
            color: isDark ? AppColors.dangerOnDark : AppColors.danger,
            width: 1.5,
          ),
        ),
      ),

      // ─────────────── Yüzeyler ───────────────
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.allXl),
        titleTextStyle: AppTypography.h2(textPrimary),
        contentTextStyle: AppTypography.body(textBody),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        showDragHandle: true,
        dragHandleColor: isDark ? AppColors.gray700 : AppColors.gray300,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.topXl),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? AppColors.gray800 : AppColors.gray900,
        contentTextStyle: AppTypography.body(AppColors.white),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.allMd),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.allMd,
          side: BorderSide(color: border),
        ),
        textStyle: AppTypography.body(textBody),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? AppColors.gray800 : AppColors.gray900,
          borderRadius: AppRadius.allSm,
        ),
        textStyle: AppTypography.small(AppColors.white),
      ),

      // ─────────────── Navigasyon ───────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: isDark
            ? AppColors.primarySurfaceDark
            : AppColors.primarySurface,
        indicatorShape: const RoundedRectangleBorder(
          borderRadius: AppRadius.allMd,
        ),
        elevation: 0,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppTypography.caption(accent)
              : AppTypography.caption(textMuted),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 22,
            color: states.contains(WidgetState.selected) ? accent : textMuted,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surfaceAlt,
        indicatorColor: isDark
            ? AppColors.primarySurfaceDark
            : AppColors.primarySurface,
        indicatorShape: const RoundedRectangleBorder(
          borderRadius: AppRadius.allMd,
        ),
        elevation: 0,
        selectedLabelTextStyle: AppTypography.label(accent),
        unselectedLabelTextStyle: AppTypography.label(textMuted),
        selectedIconTheme: IconThemeData(color: accent, size: 22),
        unselectedIconTheme: IconThemeData(color: textMuted, size: 22),
      ),

      // ─────────────── Kontroller ───────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.white
              : (isDark ? AppColors.gray400 : AppColors.white),
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.primary
              : (isDark ? AppColors.gray700 : AppColors.gray300),
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.primary
              : Colors.transparent,
        ),
        side: BorderSide(
          color: isDark ? AppColors.borderStrongDark : AppColors.borderStrong,
          width: 1.5,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.primary
              : (isDark ? AppColors.borderStrongDark : AppColors.borderStrong),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark
            ? AppColors.surfaceMutedDark
            : AppColors.surfaceMuted,
        selectedColor: isDark
            ? AppColors.primarySurfaceDark
            : AppColors.primarySurface,
        side: BorderSide.none,
        labelStyle: AppTypography.caption(textBody),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xxs,
        ),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.allSm),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearMinHeight: 6,
        linearTrackColor: AppColors.gray200,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xxs,
        ),
        titleTextStyle: AppTypography.bodyStrong(textPrimary),
        subtitleTextStyle: AppTypography.small(textMuted),
        iconColor: textMuted,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.allMd),
      ),

      // Sayfa geçişi: her platformda sade fade (200ms).
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
