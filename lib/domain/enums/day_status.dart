/// Bir personelin bir gündeki devam durumu.
enum DayStatus {
  /// Giriş yapıldı, henüz çıkış okutulmadı — hâlâ içeride.
  present('present', 'İçeride'),

  /// Giriş ve çıkış tamam.
  completed('completed', 'Tamamlandı'),

  /// Giriş var ama gün bitmiş, çıkış hiç okutulmamış.
  ///
  /// Ayrı bir durumdur: uygulama personelin ne zaman çıktığını bilemez ve
  /// bir saat uydurmaz. Yönetici bunu görüp kendisi sorar.
  missingExit('missingExit', 'Çıkış yok'),

  /// O gün hiç okutma yok.
  absent('absent', 'Gelmedi');

  const DayStatus(this.key, this.label);

  final String key;
  final String label;

  static DayStatus fromKey(String? key) => switch (key) {
    'present' => DayStatus.present,
    'completed' => DayStatus.completed,
    'missingExit' => DayStatus.missingExit,
    _ => DayStatus.absent,
  };

  /// Personelin **kendi** ekranında görünen ad.
  ///
  /// Yöneticinin listesinde "Gelmedi" doğru özettir; kişinin kendi
  /// geçmişinde ise uygulamanın bildiği tek şey okutma olmadığıdır.
  String get selfLabel => this == DayStatus.absent ? 'Giriş yok' : label;

  bool get isPresent => this == DayStatus.present;
  bool get isAbsent => this == DayStatus.absent;
}
