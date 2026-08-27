import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ubsoft_pdks/application/auth/auth_controller.dart';
import 'package:ubsoft_pdks/application/auth/session_provider.dart';
import 'package:ubsoft_pdks/core/extensions/context_x.dart';
import 'package:ubsoft_pdks/core/theme/app_colors.dart';
import 'package:ubsoft_pdks/core/theme/app_radius.dart';
import 'package:ubsoft_pdks/core/theme/app_spacing.dart';
import 'package:ubsoft_pdks/core/theme/app_typography.dart';
import 'package:ubsoft_pdks/core/utils/date_x.dart';
import 'package:ubsoft_pdks/domain/entities/session.dart';
import 'package:ubsoft_pdks/domain/entities/tenant.dart';
import 'package:ubsoft_pdks/domain/permissions/permission_set.dart';
import 'package:ubsoft_pdks/presentation/shell/nav_destinations.dart';

/// Uygulama kabuğu.
///
/// Geniş ekranda kalıcı yan menü (NavigationRail), dar ekranda alt navigasyon
/// çizer. Sekme sayısı ikiden azsa navigasyon hiç gösterilmez.
///
/// Dar ekranda en fazla [_mobileTabLimit] sekme alt çubukta durur; kalanlar
/// soldan açılan bir menüde (Drawer) toplanır — böylece kaç modül olursa olsun
/// hepsi kaydırılabilir bir listede eksiksiz görünür.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({required this.child, super.key});

  /// Alt çubukta doğrudan görünen en fazla sekme sayısı ("Menü" dahil).
  static const int _mobileTabLimit = 5;

  final Widget child;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final Session session = ref.watch(currentSessionProvider);
    final PermissionSet permissions = ref.watch(permissionsProvider);

    final List<NavDestination> destinations = AppNavigation.visibleFor(
      permissions,
      isSuperAdmin: session is SessionSuperAdmin,
    );

    // Aboneliği bitmiş hesapta yönetici salt okunur devam eder; bandı her
    // düzende (dar, geniş, menüsüz) görmesi gerekir, bu yüzden içerik burada
    // bir kez sarılır.
    final Widget body = _ExpiredBanner.wrap(
      child: widget.child,
      tenant: session.tenantOrNull,
    );

    if (destinations.length < 2) return body;

    final String location = GoRouterState.of(context).matchedLocation;

    // Geniş ekran: hepsi yan menüde sığar.
    if (context.isWide) {
      final int index = _indexFor(destinations, location);
      return Scaffold(
        body: Row(
          children: <Widget>[
            _SideRail(
              destinations: destinations,
              selectedIndex: index,
              onSelect: (i) => context.go(destinations[i].path),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      );
    }

    // Dar ekran: fazlalık soldan açılan menüye (Drawer) iner.
    final bool overflows = destinations.length > AppShell._mobileTabLimit;
    final List<NavDestination> primary = overflows
        ? destinations.sublist(0, AppShell._mobileTabLimit - 1)
        : destinations;
    final List<NavDestination> overflow = overflows
        ? destinations.sublist(AppShell._mobileTabLimit - 1)
        : const <NavDestination>[];

    int index = _indexFor(primary, location);
    final bool inOverflow =
        overflows &&
        _matches(overflow, location) &&
        !_matches(primary, location);
    if (inOverflow) index = primary.length;

    return Scaffold(
      key: _scaffoldKey,
      drawer: overflows
          ? _NavDrawer(
              destinations: destinations,
              location: location,
              onSelect: (destination) {
                _scaffoldKey.currentState?.closeDrawer();
                context.go(destination.path);
              },
            )
          : null,
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) {
          if (overflows && i == primary.length) {
            _scaffoldKey.currentState?.openDrawer();
            return;
          }
          context.go(primary[i].path);
        },
        destinations: <Widget>[
          for (final NavDestination destination in primary)
            NavigationDestination(
              icon: Icon(destination.icon),
              selectedIcon: Icon(destination.selectedIcon),
              label: destination.label,
            ),
          if (overflows)
            NavigationDestination(
              icon: Icon(
                inOverflow ? Icons.menu_open_rounded : Icons.menu_rounded,
              ),
              selectedIcon: const Icon(Icons.menu_open_rounded),
              label: 'Menü',
            ),
        ],
      ),
    );
  }

  bool _matches(List<NavDestination> destinations, String location) =>
      destinations.any((d) => _isActive(d.path, location));

  static bool _isActive(String path, String location) => path == '/'
      ? location == '/'
      : location == path || location.startsWith('$path/');

  /// Geçerli adrese karşılık gelen sekme.
  ///
  /// Alt sayfalarda (ör. `/bolgeler/yeni`) üst sekme seçili kalır.
  int _indexFor(List<NavDestination> destinations, String location) {
    int best = 0;
    int bestLength = -1;

    for (int i = 0; i < destinations.length; i++) {
      final String path = destinations[i].path;
      if (_isActive(path, location) && path.length > bestLength) {
        best = i;
        bestLength = path.length;
      }
    }
    return best;
  }
}

/// Abonelik süresi dolmuş hesapta içeriğin üstünde duran uyarı.
///
/// Yalnız yönetici görür: personelin oturumu bu durumda hiç açılmaz, doğrudan
/// engelleme ekranına düşer.
///
/// **Kapatma düğmesi bilinçli olarak yoktur.** Kapatılabilen bir uyarı ilk gün
/// kapatılır ve hesabın neden hiçbir kaydı kabul etmediği bir daha görünmez;
/// bu da doğrudan "uygulama bozuk" telefonuna dönüşür.
class _ExpiredBanner extends StatelessWidget {
  const _ExpiredBanner({required this.expiresAt});

  final DateTime expiresAt;

  /// Süre dolmamışsa [child]'ı olduğu gibi döndürür — normal durumda bu widget
  /// ağaca hiç girmez.
  static Widget wrap({required Widget child, required Tenant? tenant}) {
    if (tenant == null || !tenant.subscription.isExpired) return child;
    return Column(
      children: <Widget>[
        _ExpiredBanner(expiresAt: tenant.subscription.expiresAt),
        Expanded(child: child),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool dark = context.isDark;
    final Color foreground = dark ? AppColors.dangerOnDark : AppColors.danger;

    return Material(
      color: dark
          ? AppColors.danger.withValues(alpha: 0.18)
          : AppColors.dangerSurface,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(Icons.event_busy_outlined, size: 18, color: foreground),
              AppSpacing.hSm,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Abonelik süresi ${AppDate.date(expiresAt)} '
                      'tarihinde doldu',
                      style: AppTypography.bodyStrong(foreground),
                    ),
                    Text(
                      'Uygulama salt okunur. Personel giriş yapamaz, yeni '
                      'okutma kaydedilemez. Geçmiş verileriniz duruyor.',
                      style: AppTypography.small(foreground),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dar ekranda soldan açılan menü — tüm bölümler ve çıkış.
///
/// Liste `ListView` olduğu için kaç öğe olursa olsun kaydırılır; hiçbir madde
/// ekranın altında kesilip kalmaz.
class _NavDrawer extends ConsumerWidget {
  const _NavDrawer({
    required this.destinations,
    required this.location,
    required this.onSelect,
  });

  final List<NavDestination> destinations;
  final String location;
  final ValueChanged<NavDestination> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String tenantName =
        ref.watch(currentTenantProvider)?.name ?? 'UBSoft PDKS';

    return Drawer(
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.rightXl),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: context.colors.primaryContainer,
                      borderRadius: AppRadius.allMd,
                    ),
                    child: Icon(
                      Icons.badge_outlined,
                      color: context.colors.primary,
                      size: 22,
                    ),
                  ),
                  AppSpacing.hSm,
                  Expanded(
                    child: Text(
                      tenantName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.h3(context.colors.onSurface),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.sm,
                ),
                children: <Widget>[
                  for (final NavDestination destination in destinations)
                    _DrawerTile(
                      destination: destination,
                      selected: _AppShellState._isActive(
                        destination.path,
                        location,
                      ),
                      onTap: () => onSelect(destination),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: ListTile(
                leading: const Icon(Icons.logout_rounded),
                title: const Text('Çıkış Yap'),
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadius.allMd,
                ),
                onTap: () async {
                  Scaffold.of(context).closeDrawer();
                  await ref.read(authControllerProvider.notifier).signOut();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Menüdeki tek satır — seçili bölüm vurgulanır.
class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final NavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = selected
        ? context.colors.primary
        : context.colors.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
      child: Material(
        color: selected ? context.colors.primaryContainer : Colors.transparent,
        borderRadius: AppRadius.allMd,
        child: InkWell(
          borderRadius: AppRadius.allMd,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  selected ? destination.selectedIcon : destination.icon,
                  size: 22,
                  color: color,
                ),
                AppSpacing.hSm,
                Text(
                  destination.label,
                  style: selected
                      ? AppTypography.bodyStrong(color)
                      : AppTypography.body(color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Geniş ekranlarda görünen yan menü.
class _SideRail extends ConsumerWidget {
  const _SideRail({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<NavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String tenantName =
        ref.watch(currentTenantProvider)?.name ?? 'UBSoft PDKS';

    return SingleChildScrollView(
      child: IntrinsicHeight(
        child: NavigationRail(
          selectedIndex: selectedIndex,
          onDestinationSelected: onSelect,
          labelType: NavigationRailLabelType.all,
          leading: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.lg,
            ),
            child: SizedBox(
              width: 64,
              child: Text(
                tenantName,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption(context.colors.onSurfaceVariant),
              ),
            ),
          ),
          destinations: destinations
              .map(
                (destination) => NavigationRailDestination(
                  icon: Icon(destination.icon),
                  selectedIcon: Icon(destination.selectedIcon),
                  label: Text(destination.label),
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
  }
}
