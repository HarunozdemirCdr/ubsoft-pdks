import 'package:flutter/material.dart';
import 'package:ubsoft_pdks/core/theme/app_spacing.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_button.dart';

/// Yıkıcı ve geri alınamaz işlemler için tek tip onay penceresi.
///
/// ```dart
/// final approved = await ConfirmDialog.show(
///   context,
///   title: 'Bölgeyi sil',
///   message: '"Havuz" bölgesi silinecek. Bu işlem geri alınamaz.',
///   confirmLabel: 'Sil',
///   isDestructive: true,
/// );
/// if (!approved) return;
/// ```
class ConfirmDialog extends StatelessWidget {
  const ConfirmDialog({
    required this.title,
    required this.message,
    this.confirmLabel,
    this.cancelLabel,
    this.isDestructive = false,
    super.key,
  });

  final String title;
  final String message;
  final String? confirmLabel;
  final String? cancelLabel;

  /// `true` ise onay butonu kırmızı olur.
  final bool isDestructive;

  /// Pencereyi açar; kullanıcı onaylarsa `true` döner.
  ///
  /// Pencere dışına dokunularak kapatılırsa `false` döner — yani varsayılan
  /// her zaman "işlemi yapma" yönündedir.
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String? confirmLabel,
    String? cancelLabel,
    bool isDestructive = false,
  }) async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        isDestructive: isDestructive,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Text(message),
      contentPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      actions: <Widget>[
        AppButton(
          label: cancelLabel ?? 'Vazgeç',
          onPressed: () => Navigator.of(context).pop(false),
          variant: AppButtonVariant.text,
        ),
        AppButton(
          label: confirmLabel ?? 'Onayla',
          onPressed: () => Navigator.of(context).pop(true),
          variant: isDestructive
              ? AppButtonVariant.danger
              : AppButtonVariant.primary,
        ),
      ],
    );
  }
}
