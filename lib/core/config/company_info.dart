/// Yazılımı geliştiren firmanın sabit iletişim bilgileri.
///
/// Bu değerler yurda göre değişmez — hangi villada, hangi hesapta olursa
/// olsun aynıdır. Bu yüzden Firestore'da değil kodda durur: yurt başına
/// saklamak hem gereksiz okuma hem yanlışlıkla değiştirilebilir bir alan
/// demekti.
abstract final class CompanyInfo {
  static const String legalName = 'UBS Elektronik ve Güvenlik Sistemleri';

  static const String contactName = 'Mustafa Özdemir';

  /// Görünen biçim — arama bağlantısı için [phoneDial] kullanılır.
  static const String phone = '0535 812 85 36';
  static const String phoneDial = '+905358128536';

  static const String email = 'info@ubselektronik.com';
  static const String website = 'www.ubselektronik.com';
  static const String websiteUrl = 'https://www.ubselektronik.com';

  /// YALNIZ giriş ekranında gösterilen sürüm.
  ///
  /// Teknik sürümden (`AppConfig.appVersion`) ayrıdır: yurda gösterilen
  /// pazarlama sürümü ile geliştirme sürümü aynı hızda ilerlemez. Uygulamanın
  /// içinde sürüm numarası **hiçbir yerde** görünmez — bekçinin ya da site
  /// yöneticisinin işine yaramaz, yalnız ekranı kalabalıklaştırır. Bir hatayı
  /// ararken gereken gerçek sürüm, hata raporlarında zaten
  /// `AppConfig.appVersion` olarak gider.
  static const String displayVersion = 'v2.2.1';
}
