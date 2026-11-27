import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ubsoft_pdks/application/auth/auth_controller.dart';
import 'package:ubsoft_pdks/application/auth/session_provider.dart';
import 'package:ubsoft_pdks/application/dorm/dorm_providers.dart';
import 'package:ubsoft_pdks/core/extensions/context_x.dart';
import 'package:ubsoft_pdks/core/routing/app_routes.dart';
import 'package:ubsoft_pdks/core/theme/app_colors.dart';
import 'package:ubsoft_pdks/core/theme/app_radius.dart';
import 'package:ubsoft_pdks/core/theme/app_shadows.dart';
import 'package:ubsoft_pdks/core/theme/app_spacing.dart';
import 'package:ubsoft_pdks/core/theme/app_typography.dart';
import 'package:ubsoft_pdks/core/utils/date_x.dart';
import 'package:ubsoft_pdks/domain/entities/announcement.dart';
import 'package:ubsoft_pdks/domain/entities/session.dart';
import 'package:ubsoft_pdks/domain/entities/tenant.dart';
import 'package:ubsoft_pdks/domain/permissions/permission_set.dart';
import 'package:ubsoft_pdks/presentation/shell/nav_destinations.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_button.dart';
import 'package:ubsoft_pdks/presentation/widgets/ubs_logo.dart';
import 'package:ubsoft_pdks/services/location/location_service.dart';
import 'package:ubsoft_pdks/services/notification/web_notification_service.dart';

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
  final Set<String> _notifiedAnnouncementIds = <String>{};
  bool _announcementsPrimed = false;

  @override
  Widget build(BuildContext context) {
    final Session session = ref.watch(currentSessionProvider);
    final PermissionSet permissions = ref.watch(permissionsProvider);

    final List<NavDestination> destinations = AppNavigation.visibleFor(
      permissions,
      isSuperAdmin: session is SessionSuperAdmin,
    );

    final bool isStaff = session is SessionActive && session.user.role.isStaff;
    final bool isAdmin = session is SessionActive && session.user.role.isAdmin;

    final int unreadAnnouncements = isStaff
        ? ref.watch(unreadAnnouncementsCountProvider)
        : 0;
    final int attentionCount = isAdmin
        ? ref.watch(dormAttentionCountProvider)
        : 0;

    // Öğrenciye yeni duyuru düştüğünde (ve bildirim izni açıksa) anlık bildirim gönder.
    if (isStaff) {
      ref.listen<List<DormAnnouncement>>(visibleAnnouncementsProvider, (
        List<DormAnnouncement>? prev,
        List<DormAnnouncement> next,
      ) {
        if (!_announcementsPrimed) {
          _announcementsPrimed = true;
          _notifiedAnnouncementIds.addAll(next.map((a) => a.id));
          return;
        }
        final Set<String> readIds =
            ref.read(myAnnouncementReadsProvider).value ?? const <String>{};
        for (final DormAnnouncement a in next) {
          if (_notifiedAnnouncementIds.add(a.id) && !readIds.contains(a.id)) {
            WebNotificationService.show(
              title: '${a.targetLabel}: ${a.title}',
              body: a.body,
            );
          }
        }
      });
    }

    int? badgeFor(String path) {
      if (path == AppRoutes.announcements && isStaff && unreadAnnouncements > 0) {
        return unreadAnnouncements;
      }
      if (path == AppRoutes.attention && isAdmin) {
        return attentionCount;
      }
      return null;
    }

    // Aboneliği bitmiş hesapta yönetici salt okunur devam eder; bandı her
    // düzende (dar, geniş, menüsüz) görmesi gerekir, bu yüzden içerik burada
    // bir kez sarılır.
    final Widget body = _LocationGate.wrap(
      requireMandatory: isStaff,
      child: _ExpiredBanner.wrap(
        child: widget.child,
        tenant: session.tenantOrNull,
      ),
    );

    if (destinations.length < 2) return body;

    final String location = GoRouterState.of(context).matchedLocation;

    // Geniş ekran: tek kurumsal sol menü (ikon + metin, çift bar yok).
    if (context.isWide) {
      return Scaffold(
        body: Row(
          children: <Widget>[
            _CorporateSidebar(
              destinations: destinations,
              location: location,
              badgeFor: badgeFor,
              onSelect: (destination) => context.go(destination.path),
            ),
            Expanded(child: body),
          ],
        ),
      );
    }

    // Dar ekran: soldan ekstra yan bar açılmaz; yalnızca temiz alt navigasyon
    // ve sığmayan modüller için tek dokunuşluk İşlemler alt penceresi kullanılır.
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
      drawerEnableOpenDragGesture: false,
      drawer: overflows
          ? Drawer(
              width: 276,
              backgroundColor: context.colors.surface,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.horizontal(
                  right: Radius.circular(14),
                ),
              ),
              child: _CorporateSidebarContent(
                destinations: destinations,
                location: location,
                badgeFor: badgeFor,
                onSelect: (destination) {
                  _scaffoldKey.currentState?.closeDrawer();
                  context.go(destination.path);
                },
                onBeforeSignOut: () =>
                    _scaffoldKey.currentState?.closeDrawer(),
              ),
            )
          : null,
      body: body,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          border: Border(top: BorderSide(color: context.colors.outline)),
          boxShadow: context.isDark ? null : AppShadows.navBar,
        ),
        child: DefaultTextStyle.merge(
          textAlign: TextAlign.center,
          child: NavigationBar(
            height: 80,
            labelPadding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
            labelTextStyle: WidgetStateProperty.resolveWith(
              (states) => AppTypography.caption(
                states.contains(WidgetState.selected)
                    ? context.colors.primary
                    : context.colors.onSurfaceVariant,
              ).copyWith(fontSize: 11, height: 1.3),
            ),
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
                  icon: _NavBadgeIcon(
                    icon: destination.icon,
                    count: badgeFor(destination.path),
                  ),
                  selectedIcon: _NavBadgeIcon(
                    icon: destination.selectedIcon,
                    count: badgeFor(destination.path),
                  ),
                  label: destination.label,
                ),
              if (overflows)
                NavigationDestination(
                  icon: Icon(
                    inOverflow ? Icons.menu_open_rounded : Icons.menu_rounded,
                  ),
                  selectedIcon: const Icon(Icons.menu_open_rounded),
                  label: 'İşlemler',
                ),
            ],
          ),
        ),
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
/// Yalnız yönetici görür: öğrencinin oturumu bu durumda hiç açılmaz, doğrudan
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
                      'Uygulama salt okunur. Öğrenci giriş yapamaz, yeni '
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

/// Geniş ekranda tek kurumsal sol menü — banka / telekom portalları gibi
/// net hiyerarşi: UBS marka başlığı, yatay ikon+etiket satırları ve oturum
/// özeti.
class _CorporateSidebar extends StatelessWidget {
  const _CorporateSidebar({
    required this.destinations,
    required this.location,
    required this.onSelect,
    this.badgeFor,
  });

  final List<NavDestination> destinations;
  final String location;
  final ValueChanged<NavDestination> onSelect;
  final int? Function(String path)? badgeFor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 242,
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(right: BorderSide(color: context.colors.outline)),
      ),
      child: _CorporateSidebarContent(
        destinations: destinations,
        location: location,
        badgeFor: badgeFor,
        onSelect: onSelect,
      ),
    );
  }
}

class _CorporateSidebarContent extends ConsumerWidget {
  const _CorporateSidebarContent({
    required this.destinations,
    required this.location,
    required this.onSelect,
    this.badgeFor,
    this.onBeforeSignOut,
  });

  final List<NavDestination> destinations;
  final String location;
  final ValueChanged<NavDestination> onSelect;
  final int? Function(String path)? badgeFor;
  final VoidCallback? onBeforeSignOut;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Session session = ref.watch(currentSessionProvider);
    final String tenantName = session.tenantOrNull?.name ?? '';
    final String userName = session is SessionActive
        ? session.user.displayName
        : '';

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const UbsLogo.mark(width: 128),
                if (tenantName.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    tenantName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption(
                      context.colors.onSurfaceVariant,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 2,
                      color: AppColors.brandAccent,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Container(
                        height: 1,
                        color: context.colors.outline,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              children: <Widget>[
                for (final NavDestination destination in destinations)
                  _SidebarTile(
                    destination: destination,
                    selected: _AppShellState._isActive(
                      destination.path,
                      location,
                    ),
                    badgeCount: badgeFor?.call(destination.path),
                    onTap: () => onSelect(destination),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (userName.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 2, 10, 6),
                    child: Row(
                      children: [
                        Icon(
                          Icons.person_outline_rounded,
                          size: 16,
                          color: context.colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            userName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption(
                              context.colors.onSurfaceVariant,
                            ).copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                InkWell(
                  borderRadius: AppRadius.allSm,
                  onTap: () {
                    onBeforeSignOut?.call();
                    ref.read(authControllerProvider.notifier).signOut();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.logout_rounded,
                          size: 18,
                          color: context.colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Çıkış Yap',
                          style: AppTypography.small(
                            context.colors.onSurfaceVariant,
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({
    required this.destination,
    required this.selected,
    required this.onTap,
    this.badgeCount,
  });

  final NavDestination destination;
  final bool selected;
  final VoidCallback onTap;
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    final bool dark = context.isDark;
    final Color activeBg = dark
        ? AppColors.primarySurfaceDark
        : AppColors.primarySurface;
    final Color fg = selected
        ? (dark ? AppColors.primaryOnDark : AppColors.navy)
        : context.colors.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Material(
        color: selected ? activeBg : Colors.transparent,
        borderRadius: AppRadius.allSm,
        child: InkWell(
          borderRadius: AppRadius.allSm,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: <Widget>[
                Icon(
                  selected ? destination.selectedIcon : destination.icon,
                  size: 20,
                  color: fg,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    destination.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: (selected
                            ? AppTypography.bodyStrong(fg)
                            : AppTypography.body(fg))
                        .copyWith(fontSize: 13.5),
                  ),
                ),
                if (badgeCount case final int count) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: count > 0
                          ? AppColors.danger
                          : (dark
                                ? AppColors.surfaceMutedDark
                                : AppColors.gray200),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      count > 99 ? '99+' : '$count',
                      style: AppTypography.caption(
                        count > 0
                            ? AppColors.white
                            : context.colors.onSurfaceVariant,
                      ).copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavBadgeIcon extends StatelessWidget {
  const _NavBadgeIcon({required this.icon, this.count});

  final IconData icon;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final int? c = count;
    if (c == null) return Icon(icon);
    return Badge(
      backgroundColor: c > 0 ? AppColors.danger : AppColors.gray400,
      textColor: AppColors.white,
      label: Text(
        c > 99 ? '99+' : '$c',
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
      ),
      child: Icon(icon),
    );
  }
}

/// Uygulama seviyesinde konum zorunluluğu ve arka planda konum ısıtma kapısı.
///
/// Öğrenci sisteme girdiğinde konumu önden doğrular ve bellekte sıcak tutar.
/// Böylece QR okutma ekranı açıldığında GPS uydusu beklenmez (0 ms).
class _LocationGate extends ConsumerStatefulWidget {
  const _LocationGate({
    required this.child,
    required this.requireMandatory,
  });

  final Widget child;
  final bool requireMandatory;

  static Widget wrap({
    required Widget child,
    required bool requireMandatory,
  }) {
    return _LocationGate(
      requireMandatory: requireMandatory,
      child: child,
    );
  }

  @override
  ConsumerState<_LocationGate> createState() => _LocationGateState();
}

class _LocationGateState extends ConsumerState<_LocationGate>
    with WidgetsBindingObserver {
  bool _checking = true;
  bool _hasPermission = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initLocation());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _initLocation();
    }
  }

  Future<void> _initLocation() async {
    final LocationService service = ref.read(locationServiceProvider);
    final bool granted = await service.ensurePermission();
    if (!mounted) return;

    setState(() {
      _hasPermission = granted;
      _checking = false;
    });

    if (granted) {
      // Arka planda konumu anında ısıtıp belleğe alır
      service.warmUp().ignore();
      _startPeriodicRefresh();
    }
  }

  void _startPeriodicRefresh() {
    _refreshTimer?.cancel();
    // Uygulama açıkken her 90 saniyede bir konumu sessizce tazeler
    _refreshTimer = Timer.periodic(const Duration(seconds: 90), (_) {
      if (mounted) {
        ref.read(locationServiceProvider).warmUp(force: true).ignore();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Sadece öğrenci (staff) için konum zorunludur. Yönetici masaüstünden girebilir.
    if (!widget.requireMandatory) {
      return widget.child;
    }

    if (_checking) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_hasPermission) {
      final Color color = context.colors.primary;
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: context.colors.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.location_on_rounded,
                      size: 36,
                      color: color,
                    ),
                  ),
                  AppSpacing.vLg,
                  Text(
                    'Konum Erişimi Zorunludur',
                    textAlign: TextAlign.center,
                    style: AppTypography.h2(context.colors.onSurface),
                  ),
                  AppSpacing.vSm,
                  Text(
                    'UBS Yurt Yönetim Sistemi üzerinden turnike giriş-çıkışlarınızı '
                    'gerçekleştirebilmek için cihazınızın konum servisinin açık olması ve '
                    'tarayıcınıza izin vermeniz gerekmektedir.',
                    textAlign: TextAlign.center,
                    style: AppTypography.body(context.colors.onSurfaceVariant),
                  ),
                  AppSpacing.vXl,
                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      label: 'Konum İznini Aç ve Devam Et',
                      onPressed: () async {
                        setState(() => _checking = true);
                        await _initLocation();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return widget.child;
  }
}
