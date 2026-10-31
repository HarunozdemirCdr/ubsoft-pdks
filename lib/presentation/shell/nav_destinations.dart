import 'package:flutter/material.dart';
import 'package:ubsoft_pdks/core/routing/app_routes.dart';
import 'package:ubsoft_pdks/domain/permissions/app_permission.dart';
import 'package:ubsoft_pdks/domain/permissions/permission_set.dart';

/// Alt navigasyon / yan menü öğesi.
class NavDestination {
  const NavDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.path,
    this.requires = const <AppPermission>[],
    this.requiresAll = const <AppPermission>[],
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String path;

  /// Bu öğenin görünmesi için gereken izinler — **en az biri** yeterlidir.
  /// Boşsa herkese görünür.
  final List<AppPermission> requires;

  /// Bu öğenin görünmesi için gereken izinler — **hepsi** gereklidir.
  ///
  /// Günlük panel iki ayrı şeyi birden ister: paneli görme yetkisi ve
  /// panelin gösterdiği verinin okuma yetkisi. Yalnız birine bakmak, ekranı
  /// açıp veriyi getiremeyen bir kullanıcı yaratırdı.
  final List<AppPermission> requiresAll;

  bool isVisibleTo(PermissionSet permissions) {
    if (requiresAll.isNotEmpty && !permissions.canAll(requiresAll)) {
      return false;
    }
    return requires.isEmpty || permissions.canAny(requires);
  }
}

/// Navigasyon öğeleri.
///
/// Öğrenci yalnız "Okut" ve "Profil" ekranlarını görür. Yönetici okutma
/// yapmaz; öğrencilerin kayıtlarını yönetim ekranlarından izler.
abstract final class AppNavigation {
  static const List<NavDestination> all = <NavDestination>[
    NavDestination(
      label: 'Yurt Durumu',
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard_rounded,
      path: AppRoutes.today,
      requiresAll: <AppPermission>[
        AppPermission.dashboardView,
        AppPermission.attendanceViewAll,
      ],
    ),
    NavDestination(
      label: 'Okut',
      icon: Icons.qr_code_scanner_outlined,
      selectedIcon: Icons.qr_code_scanner_rounded,
      path: AppRoutes.punch,
      requires: <AppPermission>[AppPermission.punchCreate],
    ),
    NavDestination(
      label: 'Geçmiş',
      icon: Icons.history_rounded,
      selectedIcon: Icons.history_rounded,
      path: AppRoutes.history,
      requires: <AppPermission>[
        AppPermission.attendanceViewOwn,
        AppPermission.attendanceViewAll,
      ],
    ),
    NavDestination(
      label: 'Noktalar',
      icon: Icons.qr_code_2_outlined,
      selectedIcon: Icons.qr_code_2_rounded,
      path: AppRoutes.checkpoints,
      requires: <AppPermission>[AppPermission.checkpointView],
    ),
    NavDestination(
      label: 'İzinler',
      icon: Icons.event_available_outlined,
      selectedIcon: Icons.event_available,
      path: AppRoutes.leaves,
      requires: <AppPermission>[
        AppPermission.attendanceViewOwn,
        AppPermission.attendanceViewAll,
      ],
    ),
    NavDestination(
      label: 'Raporlar',
      icon: Icons.bar_chart_rounded,
      selectedIcon: Icons.bar_chart_rounded,
      path: AppRoutes.reports,
      requires: <AppPermission>[AppPermission.reportView],
    ),
    NavDestination(
      label: 'Öğrenciler',
      icon: Icons.people_outline_rounded,
      selectedIcon: Icons.people_rounded,
      path: AppRoutes.users,
      requires: <AppPermission>[AppPermission.userView],
    ),
    NavDestination(
      label: 'Ayarlar',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings_rounded,
      path: AppRoutes.settings,
      requires: <AppPermission>[AppPermission.settingsView],
    ),
    NavDestination(
      label: 'Profil',
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
      path: AppRoutes.profile,
    ),
  ];

  /// Süper admin için ayrı menü — yurt yönetimi.
  static const List<NavDestination> superAdmin = <NavDestination>[
    NavDestination(
      label: 'Yurtlar',
      icon: Icons.business_outlined,
      selectedIcon: Icons.business_rounded,
      path: AppRoutes.tenants,
    ),
    NavDestination(
      label: 'Profil',
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
      path: AppRoutes.profile,
    ),
  ];

  /// [permissions] için görünür öğeler.
  static List<NavDestination> visibleFor(
    PermissionSet permissions, {
    required bool isSuperAdmin,
  }) {
    final List<NavDestination> source = isSuperAdmin ? superAdmin : all;
    return source
        .where(
          (NavDestination destination) => destination.isVisibleTo(permissions),
        )
        .toList(growable: false);
  }
}
