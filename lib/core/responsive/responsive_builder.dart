import 'package:flutter/widgets.dart';
import 'package:ubsoft_pdks/core/responsive/breakpoints.dart';

/// Ekran boyutuna göre farklı yerleşim kuran yardımcı.
///
/// ```dart
/// ResponsiveBuilder(
///   mobile: (_) => const _MobileLayout(),
///   desktop: (_) => const _DesktopLayout(),
/// )
/// ```
/// Verilmeyen boyut bir alt kademeye düşer (desktop → tablet → mobile).
class ResponsiveBuilder extends StatelessWidget {
  const ResponsiveBuilder({
    required this.mobile,
    this.tablet,
    this.desktop,
    super.key,
  });

  final WidgetBuilder mobile;
  final WidgetBuilder? tablet;
  final WidgetBuilder? desktop;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final ScreenSize size = Breakpoints.of(constraints.maxWidth);
        return switch (size) {
          ScreenSize.desktop => (desktop ?? tablet ?? mobile)(context),
          ScreenSize.tablet => (tablet ?? mobile)(context),
          ScreenSize.mobile => mobile(context),
        };
      },
    );
  }
}

/// İçeriği ortalar ve maksimum genişlikle sınırlar.
///
/// Web'de içerik 2000px'e yayılmaz; okunabilirlik için daraltılır.
class ContentContainer extends StatelessWidget {
  const ContentContainer({
    required this.child,
    this.maxWidth = 720,
    this.padding,
    this.fillHeight = true,
    super.key,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  /// Kullanılabilir yüksekliğin tamamı kaplansın mı?
  ///
  /// Sayfa gövdesinde `true` olmalı: içindeki `Expanded`'lar ancak o zaman
  /// çalışır. Alt eylem çubuğu gibi **kendi boyunca kadar** yer kaplaması
  /// gereken yerlerde `false` verilmelidir — aksi hâlde `Center`, Scaffold'un
  /// verdiği "0 ile tam ekran arası" boşluğu sonuna kadar doldurur ve çubuk
  /// tüm sayfayı yutar.
  final bool fillHeight;

  @override
  Widget build(BuildContext context) {
    return Align(
      heightFactor: fillHeight ? null : 1.0,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
      ),
    );
  }
}
