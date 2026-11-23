import 'package:flutter/widgets.dart';
import 'package:ubsoft_pdks/core/theme/app_colors.dart';

/// Gölge token'ları.
///
/// Tasarım ilkesi: kartlar temelde gölgesizdir; gölge yalnız hover/aktif
/// durumda ve tek bir yumuşak katman olarak görünür.
abstract final class AppShadows {
  static const List<BoxShadow> none = <BoxShadow>[];

  /// Kurumsal kartların sayfadan ayrışması için çok hafif derinlik.
  static const List<BoxShadow> subtle = <BoxShadow>[
    BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: Offset(0, 2)),
  ];

  /// Hover'da kartın yükselmesi.
  static const List<BoxShadow> card = <BoxShadow>[
    BoxShadow(color: AppColors.shadow, blurRadius: 16, offset: Offset(0, 4)),
  ];

  /// Açılır menü, popover.
  static const List<BoxShadow> overlay = <BoxShadow>[
    BoxShadow(
      color: AppColors.shadowStrong,
      blurRadius: 32,
      offset: Offset(0, 12),
    ),
  ];

  /// Alt navigasyon çubuğu — içeriğin altına girdiğini belli eden ince katman.
  static const List<BoxShadow> navBar = <BoxShadow>[
    BoxShadow(color: AppColors.shadow, blurRadius: 12, offset: Offset(0, -2)),
  ];
}
