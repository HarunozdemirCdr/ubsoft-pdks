import 'package:go_router/go_router.dart';
import 'package:ubsoft_pdks/core/routing/app_routes.dart';
import 'package:ubsoft_pdks/domain/entities/session.dart';
import 'package:ubsoft_pdks/domain/permissions/app_permission.dart';

/// Yönlendirme kararları.
///
/// Tek sorumluluğu: verilen oturum durumu ve hedef adres için kullanıcının
/// nereye gitmesi gerektiğini söylemek. Saf bir fonksiyondur — `BuildContext`
/// ya da Firebase bilmez, bu yüzden her kural birim testiyle doğrulanabilir.
abstract final class RouteGuard {
  /// Oturum açılmadan erişilebilen adresler.
  ///
  /// Bunlar oturum **açıkken** erişilemez: giriş yapmış bir kullanıcı giriş
  /// ekranına gitmeye çalışırsa kendi ana sayfasına döner.
  static const Set<String> publicRoutes = <String>{
    AppRoutes.login,
    AppRoutes.forgotPassword,
  };

  /// Oturum durumundan **bağımsız** olarak her zaman açık adresler.
  ///
  /// KVKK aydınlatma metninin hem giriş ekranından hem uygulamanın içinden
  /// okunabilmesi gerekir; erişimi engellemek metnin varlık sebebine aykırıdır.
  static const Set<String> alwaysOpenRoutes = <String>{AppRoutes.privacy};

  /// Bir bölümü açabilmek için gereken izinler — **en az biri** yeterlidir.
  ///
  /// Menüden gizlemek yetmez: kullanıcı adresi elle yazarak da girebilir.
  /// O durumda sayfa açılır, sorgular güvenlik kuralınca reddedilir ve
  /// kullanıcı boş bir hata ekranıyla kalırdı. Burada baştan kendi ana
  /// sayfasına döndürülür. Bu yine yalnız arayüz önlemidir; verinin gerçek
  /// kapısı `firestore.rules`'tur.
  static const Map<String, List<AppPermission>> _required =
      <String, List<AppPermission>>{
        AppRoutes.punch: <AppPermission>[AppPermission.punchCreate],
        AppRoutes.history: <AppPermission>[
          AppPermission.attendanceViewOwn,
          AppPermission.attendanceViewAll,
        ],
        AppRoutes.checkpoints: <AppPermission>[AppPermission.checkpointView],
        AppRoutes.users: <AppPermission>[AppPermission.userView],
        AppRoutes.reports: <AppPermission>[AppPermission.reportView],
        AppRoutes.settings: <AppPermission>[AppPermission.settingsView],
        AppRoutes.leaves: <AppPermission>[
          AppPermission.attendanceViewOwn,
          AppPermission.attendanceViewAll,
        ],
      };

  /// Bir bölümü açabilmek için gereken izinler — **hepsi** gereklidir.
  ///
  /// Günlük panel iki şeyi birden ister: paneli görme yetkisi ve panelin
  /// gösterdiği verinin (tüm öğrencinin kayıtları) okuma yetkisi. Yalnız
  /// birine bakmak, ekranı açıp veriyi getiremeyen bir kullanıcı yaratırdı.
  static const Map<String, List<AppPermission>> _requiredAll =
      <String, List<AppPermission>>{
        AppRoutes.today: <AppPermission>[
          AppPermission.dashboardView,
          AppPermission.attendanceViewAll,
        ],
      };

  static List<AppPermission>? _matchIn(
    Map<String, List<AppPermission>> source,
    String location,
  ) {
    for (final MapEntry<String, List<AppPermission>> entry in source.entries) {
      if (location == entry.key || location.startsWith('${entry.key}/')) {
        return entry.value;
      }
    }
    return null;
  }

  /// [location] için gereken izinler (en az biri). Alt sayfalar üst bölümün
  /// iznine tabidir (`/kullanicilar/abc/yetkiler` → `/kullanicilar`).
  static List<AppPermission>? requirementFor(String location) =>
      _matchIn(_required, location);

  /// [location] için gereken izinler (hepsi).
  static List<AppPermission>? allRequirementFor(String location) =>
      _matchIn(_requiredAll, location);

  /// Kullanıcı bu adresi açabilir mi?
  static bool canOpen(Session session, String location) {
    final List<AppPermission>? all = allRequirementFor(location);
    if (all != null && !session.permissionsOrNone.canAll(all)) return false;

    final List<AppPermission>? any = requirementFor(location);
    if (any != null && !session.permissionsOrNone.canAny(any)) return false;

    return true;
  }

  /// `null` dönerse yönlendirme yapılmaz.
  static String? resolve(Session session, GoRouterState state) {
    final String location = state.matchedLocation;

    // Yasal metinler her durumda okunabilir — oturum yoksa da, varsa da.
    if (alwaysOpenRoutes.contains(location)) return null;

    final bool isPublic = publicRoutes.contains(location);
    final bool isBlockedPage = location == AppRoutes.blocked;

    switch (session) {
      // Oturum henüz çözülmedi: uygulama açılıyor. Yönlendirme yapılmaz,
      // aksi hâlde kullanıcı bir an giriş ekranına düşer ve geri zıplar.
      case SessionUnknown():
        return null;

      case SessionSignedOut():
        if (isPublic) return null;
        return AppRoutes.loginWithRedirect(location);

      case SessionBlocked():
        return isBlockedPage ? null : AppRoutes.blocked;

      case SessionSuperAdmin():
        // Süper admin bir tenant'a bağlı değildir; yurt ekranları ona
        // anlamsız gelir.
        if (isPublic || isBlockedPage) return AppRoutes.tenants;
        if (location == AppRoutes.root) return AppRoutes.tenants;
        if (location != AppRoutes.profile &&
            !location.startsWith(AppRoutes.tenants)) {
          return AppRoutes.tenants;
        }
        return null;

      case SessionActive():
        if (isPublic || isBlockedPage) return homeFor(session);
        // `/` yalnız bir giriş kapısıdır: oturum çözülene kadar açılış
        // ekranını gösterir, çözülünce kullanıcı kendi ana sayfasına gider.
        if (location == AppRoutes.root) return homeFor(session);
        if (location.startsWith(AppRoutes.tenants)) return homeFor(session);

        // Adres elle yazılmış olabilir: yetkisi olmayan bölüm açılmaz.
        if (!canOpen(session, location)) return homeFor(session);
        return null;
    }
  }

  /// Giriş sonrası açılacak sayfa.
  ///
  /// Öğrencinin işi okutmaktır; onu doğrudan okutma ekranına götürmek bir
  /// dokunuş tasarruf ettirir. Yöneticiler günlük panele düşer.
  ///
  /// Tercih edilen sayfanın izni kapatılmış olabilir (ör. öğrenciden "QR
  /// okut" alınmış). O sayfaya yönlendirmek sonsuz döngü olurdu: yönlendir →
  /// izin yok → yeniden yönlendir. Bu yüzden erişilebilir ilk bölüm seçilir;
  /// hiçbiri yoksa izin gerektirmeyen Profil'e düşülür.
  static String homeFor(SessionActive session) {
    final String preferred = session.user.role.isStaff
        ? AppRoutes.punch
        : AppRoutes.today;

    for (final String candidate in <String>[
      preferred,
      AppRoutes.punch,
      AppRoutes.history,
      AppRoutes.checkpoints,
      AppRoutes.reports,
    ]) {
      if (canOpen(session, candidate)) return candidate;
    }
    return AppRoutes.profile;
  }

  /// Giriş ekranındaki `next` parametresini çözer.
  ///
  /// Kullanıcı doğrudan bir alt sayfaya girip oturumu olmadığı için giriş
  /// ekranına yönlendirildiyse, giriş sonrası oraya geri döner.
  static String? redirectTarget(GoRouterState state) {
    final String? next =
        state.uri.queryParameters[AppRoutes.redirectQueryParam];
    if (next == null || next.isEmpty) return null;
    if (publicRoutes.contains(next) || next == AppRoutes.blocked) return null;
    // Giriş sonrası kullanıcıyı yasal metne düşürmek anlamsız olur.
    if (alwaysOpenRoutes.contains(next)) return null;
    return next;
  }
}
