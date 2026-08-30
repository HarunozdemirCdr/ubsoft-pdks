/// Uygulamadaki tüm yol (path) ve rota adları.
///
/// Kural: `context.go('/noktalar')` gibi düz metin yol yazılmaz. Yol değişimi
/// tek dosyadan yönetilir ve yazım hatası derleme zamanında yakalanır.
///
/// Yollar Türkçedir çünkü tarayıcı adres çubuğunda kullanıcıya görünür; rota
/// **adları** ise kodun bir parçası olduğu için İngilizcedir.
abstract final class AppRoutes {
  // ─────────────────────────── Kimlik doğrulama ───────────────────────────
  static const String login = '/giris';
  static const String loginName = 'login';

  static const String forgotPassword = '/sifremi-unuttum';
  static const String forgotPasswordName = 'forgotPassword';

  static const String blocked = '/erisim-yok';
  static const String blockedName = 'blocked';

  // ─────────────────────────── Ana bölümler ───────────────────────────
  /// Kök adres — oturum çözülene kadar açılış ekranı, sonra yönlendirilir.
  static const String root = '/';
  static const String rootName = 'root';

  /// Personelin okutma ekranı.
  static const String punch = '/okut';
  static const String punchName = 'punch';

  /// Kamera ekranı.
  static const String scan = 'tara';
  static const String scanName = 'scan';
  static const String scanPath = '/okut/tara';

  /// Yöneticinin günlük paneli — bugün kim içeride.
  static const String today = '/bugun';
  static const String todayName = 'today';

  /// Geçmiş — gün seç, personel listesi.
  static const String history = '/gecmis';
  static const String historyName = 'history';

  /// Bir personelin geçmişi.
  static const String personHistory = ':userId';
  static const String personHistoryName = 'personHistory';

  // ─────────────────────────── Yönetim ───────────────────────────
  static const String checkpoints = '/noktalar';
  static const String checkpointsName = 'checkpoints';

  static const String checkpointNew = 'yeni';
  static const String checkpointNewName = 'checkpointNew';
  static const String checkpointNewPath = '/noktalar/yeni';

  static const String checkpointEdit = ':checkpointId';
  static const String checkpointEditName = 'checkpointEdit';

  /// Yazdırılabilir QR görseli.
  static const String checkpointQr = 'qr';
  static const String checkpointQrName = 'checkpointQr';

  static const String users = '/kullanicilar';
  static const String usersName = 'users';

  static const String userNew = 'yeni';
  static const String userNewName = 'userNew';
  static const String userNewPath = '/kullanicilar/yeni';

  static const String userEdit = ':userId';
  static const String userEditName = 'userEdit';

  static const String reports = '/raporlar';
  static const String reportsName = 'reports';

  static const String settings = '/ayarlar';
  static const String settingsName = 'settings';

  static const String profile = '/profil';
  static const String profileName = 'profile';

  static const String changePassword = 'sifre';
  static const String changePasswordName = 'changePassword';
  static const String changePasswordPath = '/profil/sifre';

  // ─────────────────────────── Süper admin ───────────────────────────
  static const String tenants = '/admin';
  static const String tenantsName = 'tenants';

  static const String tenantNew = 'musteriler/yeni';
  static const String tenantNewName = 'tenantNew';
  static const String tenantNewPath = '/admin/musteriler/yeni';

  static const String tenantDetail = 'musteriler/:tenantId';
  static const String tenantDetailName = 'tenantDetail';

  // ─────────────────────────── Yasal ───────────────────────────
  /// KVKK aydınlatma metni. Oturumdan bağımsız olarak her zaman açıktır.
  ///
  /// Konum verisi işlendiği için bu metin bir süs değil, yasal zorunluluktur.
  static const String privacy = '/kvkk';
  static const String privacyName = 'privacy';

  // ─────────────────────────── Diğer ───────────────────────────
  static const String notFound = '/404';
  static const String notFoundName = 'notFound';

  // ─────────────────────────── Yol üreticiler ───────────────────────────
  static String personHistoryPath(String userId) => '/gecmis/$userId';
  static String checkpointEditPath(String id) => '/noktalar/$id';
  static String checkpointQrPath(String id) => '/noktalar/$id/qr';
  static String userEditPath(String userId) => '/kullanicilar/$userId';
  static String tenantDetailPath(String tenantId) =>
      '/admin/musteriler/$tenantId';

  /// Giriş sonrası geri dönülecek adresi taşıyan sorgu parametresi.
  static const String redirectQueryParam = 'next';

  static String loginWithRedirect(String location) =>
      '$login?$redirectQueryParam=${Uri.encodeComponent(location)}';
}
