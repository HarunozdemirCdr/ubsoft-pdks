import 'package:flutter/material.dart';
import 'package:ubsoft_pdks/core/extensions/context_x.dart';
import 'package:ubsoft_pdks/core/theme/app_colors.dart';
import 'package:ubsoft_pdks/core/theme/app_radius.dart';
import 'package:ubsoft_pdks/core/theme/app_spacing.dart';

/// Ortalanmış yükleme göstergesi.
class LoadingView extends StatelessWidget {
  const LoadingView({this.compact = false, super.key});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: compact ? AppSpacing.lg : AppSpacing.xxl,
        ),
        child: const SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
    );
  }
}

/// İçeriğin yerini tutan iskelet (skeleton) blok.
///
/// Yükleme sırasında sayfanın zıplamasını önler: gerçek içerikle aynı
/// yüksekliği kaplar ve yumuşak bir parlama animasyonu ile beklendiğini
/// hissettirir.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    this.height = 16,
    this.width,
    this.borderRadius = AppRadius.allSm,
    super.key,
  });

  final double height;
  final double? width;
  final BorderRadius borderRadius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool dark = context.isDark;
    final Color base = dark ? AppColors.surfaceMutedDark : AppColors.gray100;
    final Color highlight = dark ? AppColors.gray700 : AppColors.gray200;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Container(
        height: widget.height,
        width: widget.width,
        decoration: BoxDecoration(
          color: Color.lerp(base, highlight, _controller.value),
          borderRadius: widget.borderRadius,
        ),
      ),
    );
  }
}

/// Liste yüklenirken gösterilen kart iskeletleri.
class SkeletonList extends StatelessWidget {
  const SkeletonList({this.itemCount = 4, this.itemHeight = 76, super.key});

  final int itemCount;
  final double itemHeight;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List<Widget>.generate(
        itemCount,
        (index) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: SkeletonBox(height: itemHeight, borderRadius: AppRadius.allLg),
        ),
      ),
    );
  }
}
