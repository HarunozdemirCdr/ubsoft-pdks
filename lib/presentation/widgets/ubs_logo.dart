import 'package:flutter/material.dart';
import 'package:ubsoft_pdks/core/extensions/context_x.dart';
import 'package:ubsoft_pdks/core/theme/app_colors.dart';
import 'package:ubsoft_pdks/core/theme/app_radius.dart';

/// UBS Elektronik marka logosu — yan menü ve çekmecenin sol üstünde görünür.
class UbsLogo extends StatelessWidget {
  const UbsLogo({this.compact = false, super.key});

  /// Sadece simge rozeti (ör. mobil çekmece başlığı).
  const UbsLogo.mark({super.key}) : compact = true;

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryHover],
        ),
        borderRadius: AppRadius.allMd,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.22),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _UbsSignalPainter()),
          ),
          const Text(
            'UBS',
            style: TextStyle(
              color: AppColors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              height: 1,
            ),
          ),
        ],
      ),
    );

    if (compact) return badge;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        badge,
        const SizedBox(height: 5),
        Text(
          'UBS',
          maxLines: 1,
          style: TextStyle(
            color: context.colors.primary,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.9,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          'ELEKTRONİK',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: context.colors.onSurfaceVariant,
            fontSize: 7.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}

class _UbsSignalPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.white.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    // Köşe devre vurguları — UBS Elektronik teknik kimliği.
    const inset = 5.5;
    const len = 6.0;
    canvas.drawPath(
      Path()
        ..moveTo(inset, inset + len)
        ..lineTo(inset, inset)
        ..lineTo(inset + len, inset)
        ..moveTo(size.width - inset - len, size.height - inset)
        ..lineTo(size.width - inset, size.height - inset)
        ..lineTo(size.width - inset, size.height - inset - len),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
