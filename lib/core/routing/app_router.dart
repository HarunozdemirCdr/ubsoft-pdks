import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ubsoft_pdks/application/auth/session_provider.dart';
import 'package:ubsoft_pdks/core/routing/app_routes.dart';
import 'package:ubsoft_pdks/core/routing/route_guard.dart';
import 'package:ubsoft_pdks/domain/entities/session.dart';
import 'package:ubsoft_pdks/presentation/features/admin/tenant_detail_page.dart';
import 'package:ubsoft_pdks/presentation/features/admin/tenant_form_page.dart';
import 'package:ubsoft_pdks/presentation/features/admin/tenant_list_page.dart';
import 'package:ubsoft_pdks/presentation/features/auth/blocked_page.dart';
import 'package:ubsoft_pdks/presentation/features/auth/forgot_password_page.dart';
import 'package:ubsoft_pdks/presentation/features/auth/login_page.dart';
import 'package:ubsoft_pdks/presentation/features/checkpoints/checkpoint_form_page.dart';
import 'package:ubsoft_pdks/presentation/features/checkpoints/checkpoint_list_page.dart';
import 'package:ubsoft_pdks/presentation/features/checkpoints/checkpoint_qr_page.dart';
import 'package:ubsoft_pdks/presentation/features/dorm/dorm_pages.dart';
import 'package:ubsoft_pdks/presentation/features/dorm/dorm_settings_page.dart';
import 'package:ubsoft_pdks/presentation/features/legal/privacy_page.dart';
import 'package:ubsoft_pdks/presentation/features/misc/not_found_page.dart';
import 'package:ubsoft_pdks/presentation/features/misc/splash_page.dart';
import 'package:ubsoft_pdks/presentation/features/profile/change_password_page.dart';
import 'package:ubsoft_pdks/presentation/features/profile/profile_page.dart';
import 'package:ubsoft_pdks/presentation/features/punch/scan_page.dart';
import 'package:ubsoft_pdks/presentation/features/turnstile/turnstile_page.dart';
import 'package:ubsoft_pdks/presentation/features/users/user_form_page.dart';
import 'package:ubsoft_pdks/presentation/features/users/user_list_page.dart';
import 'package:ubsoft_pdks/presentation/shell/app_shell.dart';

/// Uygulama yönlendiricisi.
///
/// Oturum değiştikçe kendini yeniler ([GoRouter.refreshListenable]) ve
/// yönlendirme kararını [RouteGuard]'a sorar. Sayfaların kendisi yönlendirme
/// yapmaz — "giriş yaptı ama ekran değişmedi" gibi durumlar bu yüzden oluşmaz.
final Provider<GoRouter> routerProvider = Provider<GoRouter>((ref) {
  final _SessionNotifier notifier = _SessionNotifier();

  ref
    ..listen<Session>(routingSessionProvider, (
      Session? previous,
      Session next,
    ) {
      notifier.value = next;
    }, fireImmediately: true)
    ..onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: AppRoutes.root,
    refreshListenable: notifier,
    debugLogDiagnostics: kDebugMode,
    errorBuilder: (BuildContext context, GoRouterState state) =>
        const NotFoundPage(),
    redirect: (BuildContext context, GoRouterState state) =>
        RouteGuard.resolve(notifier.value, state),
    routes: <RouteBase>[
      // ─────────────── Oturum açmadan erişilebilir ───────────────
      GoRoute(
        path: AppRoutes.login,
        name: AppRoutes.loginName,
        pageBuilder: (context, state) => _fade(state, const LoginPage()),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        name: AppRoutes.forgotPasswordName,
        pageBuilder: (context, state) =>
            _fade(state, const ForgotPasswordPage()),
      ),
      GoRoute(
        path: AppRoutes.blocked,
        name: AppRoutes.blockedName,
        pageBuilder: (context, state) => _fade(state, const BlockedPage()),
      ),
      // KVKK metni kabuğun **dışındadır**: oturum açılmadan da açılabilmesi
      // gerekir ve kabuk (menü) oturuma bağlıdır. Geri düğmesiyle çıkılır.
      GoRoute(
        path: AppRoutes.privacy,
        name: AppRoutes.privacyName,
        pageBuilder: (context, state) => _fade(state, const PrivacyPage()),
      ),

      // Kamera ekranı kabuğun DIŞINDADIR: alt menü, tam ekran kameranın
      // üzerinde yer kaplar ve okutma alanını küçültürdü.
      GoRoute(
        path: AppRoutes.scanPath,
        name: AppRoutes.scanName,
        pageBuilder: (context, state) => _fade(state, const ScanPage()),
      ),

      // ─────────────── Uygulama kabuğu ───────────────
      ShellRoute(
        builder: (BuildContext context, GoRouterState state, Widget child) =>
            AppShell(child: child),
        routes: <RouteBase>[
          // `/` bir giriş kapısıdır: oturum çözülene kadar açılış ekranını
          // gösterir, çözülünce RouteGuard kullanıcıyı ana sayfasına taşır.
          GoRoute(
            path: AppRoutes.root,
            name: AppRoutes.rootName,
            pageBuilder: (context, state) => _fade(state, const SplashPage()),
          ),
          GoRoute(
            path: AppRoutes.punch,
            name: AppRoutes.punchName,
            pageBuilder: (context, state) =>
                _fade(state, const StudentHomePage()),
          ),
          GoRoute(
            path: AppRoutes.today,
            name: AppRoutes.todayName,
            pageBuilder: (context, state) =>
                _fade(state, const DormDashboardPage()),
          ),
          GoRoute(
            path: AppRoutes.history,
            name: AppRoutes.historyName,
            pageBuilder: (context, state) =>
                _fade(state, const DormHistoryPage()),
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.personHistory,
                name: AppRoutes.personHistoryName,
                pageBuilder: (context, state) => _fade(
                  state,
                  DormHistoryPage(userId: state.pathParameters['userId'] ?? ''),
                ),
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.checkpoints,
            name: AppRoutes.checkpointsName,
            pageBuilder: (context, state) =>
                _fade(state, const CheckpointListPage()),
            routes: <RouteBase>[
              GoRoute(
                path: 'turnike',
                pageBuilder: (context, state) =>
                    _fade(state, const TurnstilePage()),
              ),
              GoRoute(
                path: AppRoutes.checkpointNew,
                name: AppRoutes.checkpointNewName,
                pageBuilder: (context, state) =>
                    _fade(state, const CheckpointFormPage()),
              ),
              GoRoute(
                path: AppRoutes.checkpointEdit,
                name: AppRoutes.checkpointEditName,
                pageBuilder: (context, state) => _fade(
                  state,
                  CheckpointFormPage(
                    checkpointId: state.pathParameters['checkpointId'],
                  ),
                ),
                routes: <RouteBase>[
                  GoRoute(
                    path: AppRoutes.checkpointQr,
                    name: AppRoutes.checkpointQrName,
                    pageBuilder: (context, state) => _fade(
                      state,
                      CheckpointQrPage(
                        checkpointId:
                            state.pathParameters['checkpointId'] ?? '',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.users,
            name: AppRoutes.usersName,
            pageBuilder: (context, state) => _fade(state, const UserListPage()),
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.userNew,
                name: AppRoutes.userNewName,
                pageBuilder: (context, state) =>
                    _fade(state, const UserFormPage()),
              ),
              GoRoute(
                path: AppRoutes.userEdit,
                name: AppRoutes.userEditName,
                pageBuilder: (context, state) => _fade(
                  state,
                  UserFormPage(userId: state.pathParameters['userId']),
                ),
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.leaves,
            builder: (context, state) => const DormLeavePage(),
          ),
          GoRoute(
            path: AppRoutes.reports,
            name: AppRoutes.reportsName,
            pageBuilder: (context, state) =>
                _fade(state, const DormReportPage()),
          ),
          GoRoute(
            path: AppRoutes.settings,
            name: AppRoutes.settingsName,
            pageBuilder: (context, state) =>
                _fade(state, const DormSettingsPage()),
          ),
          GoRoute(
            path: AppRoutes.profile,
            name: AppRoutes.profileName,
            pageBuilder: (context, state) => _fade(state, const ProfilePage()),
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.changePassword,
                name: AppRoutes.changePasswordName,
                pageBuilder: (context, state) =>
                    _fade(state, const ChangePasswordPage()),
              ),
            ],
          ),

          // ─────────────── Süper admin ───────────────
          GoRoute(
            path: AppRoutes.tenants,
            name: AppRoutes.tenantsName,
            pageBuilder: (context, state) =>
                _fade(state, const TenantListPage()),
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.tenantNew,
                name: AppRoutes.tenantNewName,
                pageBuilder: (context, state) =>
                    _fade(state, const TenantFormPage()),
              ),
              GoRoute(
                path: AppRoutes.tenantDetail,
                name: AppRoutes.tenantDetailName,
                pageBuilder: (context, state) => _fade(
                  state,
                  TenantDetailPage(
                    tenantId: state.pathParameters['tenantId'] ?? '',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),

      GoRoute(
        path: AppRoutes.notFound,
        name: AppRoutes.notFoundName,
        pageBuilder: (context, state) => _fade(state, const NotFoundPage()),
      ),
    ],
  );
});

/// Sayfa geçişi — 200 ms sade solma.
///
/// Mobil tarayıcıda kaydırmalı geçişler takılıyor; solma hem daha hızlı
/// hem de fark edilmeden çalışıyor.
CustomTransitionPage<void> _fade(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    transitionDuration: const Duration(milliseconds: 200),
    reverseTransitionDuration: const Duration(milliseconds: 150),
    transitionsBuilder:
        (
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
          Widget child,
        ) => FadeTransition(opacity: animation, child: child),
    child: child,
  );
}

/// Oturum değişimini GoRouter'a bildiren köprü.
class _SessionNotifier extends ValueNotifier<Session> {
  _SessionNotifier() : super(const Session.unknown());
}
