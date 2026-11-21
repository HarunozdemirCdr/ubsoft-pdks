import 'package:flutter/material.dart';
import 'package:ubsoft_pdks/core/extensions/context_x.dart';
import 'package:ubsoft_pdks/core/theme/app_colors.dart';
import 'package:ubsoft_pdks/core/theme/app_radius.dart';

/// UBS Elektronik ve Güvenlik Sistemleri resmi marka logosu.
class UbsLogo extends StatelessWidget {
  const UbsLogo({this.width = 92, super.key});

  /// Dar alan / çekmece başlığı için boyut.
  const UbsLogo.mark({this.width = 128, super.key});

  final double width;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      'assets/images/ubs_logo.png',
      width: width,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      semanticLabel: 'UBS Elektronik ve Güvenlik Sistemleri',
    );

    if (!context.isDark) return image;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: AppRadius.allSm,
      ),
      child: image,
    );
  }
}
