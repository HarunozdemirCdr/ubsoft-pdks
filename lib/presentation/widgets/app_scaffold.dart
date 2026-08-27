import 'package:flutter/material.dart';
import 'package:ubsoft_pdks/core/extensions/context_x.dart';
import 'package:ubsoft_pdks/core/responsive/responsive_builder.dart';
import 'package:ubsoft_pdks/core/theme/app_spacing.dart';
import 'package:ubsoft_pdks/core/theme/app_typography.dart';

/// Sayfa iskeleti.
///
/// Başlık çubuğu, içerik genişliği sınırı ve kenar boşluklarını tek yerde
/// yönetir. Her ekran doğrudan `Scaffold` yerine bunu kullanır; böylece sayfa
/// genişlikleri ve boşluklar uygulamanın tamamında tutarlı kalır.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    required this.body,
    this.title,
    this.titleWidget,
    this.actions,
    this.leading,
    this.showBackButton = false,
    this.maxContentWidth = AppWidths.content,
    this.bottomBar,
    this.floatingActionButton,
    this.padded = true,
    this.scrollable = false,
    this.backgroundColor,
    super.key,
  });

  final Widget body;
  final String? title;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final Widget? leading;

  /// Alt sayfalarda geri okunu gösterir.
  final bool showBackButton;

  final double maxContentWidth;

  /// Sayfanın altına sabitlenen eylem çubuğu (ör. "Kaydet").
  final Widget? bottomBar;

  final Widget? floatingActionButton;

  /// `false` ise yatay kenar boşluğu uygulanmaz — tam genişlik listeler için.
  final bool padded;

  /// `true` ise gövde kaydırılabilir hale gelir.
  final bool scrollable;

  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final bool hasAppBar =
        title != null || titleWidget != null || showBackButton;

    Widget content = ContentContainer(
      maxWidth: maxContentWidth,
      padding: padded ? context.pagePadding : EdgeInsets.zero,
      child: body,
    );

    if (scrollable) {
      content = SingleChildScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        child: content,
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: hasAppBar
          ? AppBar(
              automaticallyImplyLeading: showBackButton,
              leading: leading,
              title:
                  titleWidget ??
                  (title == null
                      ? null
                      : Text(
                          title!,
                          style: AppTypography.h2(context.colors.onSurface),
                        )),
              actions: <Widget>[
                ...?actions,
                SizedBox(
                  width: context.isMobile ? AppSpacing.xs : AppSpacing.md,
                ),
              ],
            )
          : null,
      body: SafeArea(child: content),
      bottomNavigationBar: bottomBar == null
          ? null
          : _BottomActionBar(child: bottomBar!),
      floatingActionButton: floatingActionButton,
    );
  }
}

/// Sayfa altına sabitlenen eylem alanı.
///
/// Klavye açıldığında yukarı iter ve içeriğin altında kalmaz.
class _BottomActionBar extends StatelessWidget {
  const _BottomActionBar({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(top: BorderSide(color: context.colors.outline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.sm + context.keyboardInset,
          ),
          child: ContentContainer(fillHeight: false, child: child),
        ),
      ),
    );
  }
}
