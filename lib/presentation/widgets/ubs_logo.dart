import 'package:flutter/material.dart';
import 'package:ubsoft_pdks/core/extensions/context_x.dart';
import 'package:ubsoft_pdks/core/theme/app_colors.dart';

/// UBS Elektronik ve Güvenlik Sistemleri resmi marka logosu (vektörel).
class UbsLogo extends StatelessWidget {
  const UbsLogo({
    this.showSubtitle = true,
    this.scale = 1.0,
    super.key,
  });

  /// Dar yan menü için alt yazı olmadan sade çift hilal + UBS görünümü.
  const UbsLogo.compact({this.scale = 0.85, super.key})
    : showSubtitle = false;

  final bool showSubtitle;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final Color ink = context.isDark ? AppColors.white : AppColors.gray900;
    final Color subInk = context.isDark
        ? AppColors.textBodyDark
        : AppColors.gray700;
    final double emblemW = 30 * scale;
    final double emblemH = 26 * scale;

    return Semantics(
      label: 'UBS Elektronik ve Güvenlik Sistemleri',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomPaint(
            size: Size(emblemW, emblemH),
            painter: const _UbsCrescentPainter(),
          ),
          SizedBox(width: 5 * scale),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'UBS',
                  maxLines: 1,
                  style: TextStyle(
                    color: ink,
                    fontSize: 20 * scale,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    height: 0.95,
                  ),
                ),
                if (showSubtitle) ...[
                  SizedBox(height: 2 * scale),
                  Text(
                    'Elektronik ve Güvenlik Sistemleri',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: subInk,
                      fontSize: 9.2 * scale,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.05,
                      height: 1.05,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UbsCrescentPainter extends CustomPainter {
  const _UbsCrescentPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.danger
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final w = size.width;
    final h = size.height;

    // Dış kırmızı kavis — sol üstten başlayıp alt sağa doğru incelerek kapanır.
    final outer = Path()
      ..moveTo(w * 0.45, h * 0.14)
      ..lineTo(w * 0.49, h * 0.30)
      ..cubicTo(w * 0.18, h * 0.35, w * 0.17, h * 0.78, w * 0.88, h * 0.96)
      ..cubicTo(w * 0.02, h * 0.92, -w * 0.05, h * 0.22, w * 0.45, h * 0.14)
      ..close();

    // İç kırmızı kavis — dış kavisin içinde eş merkezli ikinci hilal.
    final inner = Path()
      ..moveTo(w * 0.62, h * 0.35)
      ..lineTo(w * 0.65, h * 0.48)
      ..cubicTo(w * 0.39, h * 0.50, w * 0.38, h * 0.75, w * 0.78, h * 0.85)
      ..cubicTo(w * 0.25, h * 0.83, w * 0.22, h * 0.38, w * 0.62, h * 0.35)
      ..close();

    canvas
      ..drawPath(outer, paint)
      ..drawPath(inner, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
