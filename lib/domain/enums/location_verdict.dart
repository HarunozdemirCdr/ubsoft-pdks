/// Okutmanın konum doğrulaması.
///
/// Amaç, "noktanın yanında mı okuttu yoksa etiketin fotoğrafını çekip evden
/// mi okuttu" sorusuna cevap vermektir. Doğrulama okutmayı **engellemek**
/// için değil, **işaretlemek** için kullanılır (yönetici ayarla engellemeyi
/// açabilir): GPS yanılabilir ve yanlışlıkla reddedilen bir giriş, personelin
/// o gün hiç çalışmamış görünmesine yol açardı.
enum LocationVerdict {
  /// Noktanın yarıçapı içinde.
  verified('verified', 'Konum doğrulandı'),

  /// Yarıçap dışında ama cihazın bildirdiği ölçüm hatası payı içinde.
  ///
  /// Kesin bir suçlama değildir: kapalı alanda ya da zayıf sinyalde telefon
  /// gerçek konumu 100 metre kaydırabilir.
  borderline('borderline', 'Sınırda'),

  /// Ölçüm hatası payı hesaba katıldıktan sonra bile açıkça uzakta.
  outside('outside', 'Nokta dışında'),

  /// Konum alınamadı — izin verilmedi, cihaz kapalı ya da sinyal yok.
  unavailable('unavailable', 'Konum yok');

  const LocationVerdict(this.key, this.label);

  final String key;
  final String label;

  static LocationVerdict fromKey(String? key) => switch (key) {
    'verified' => LocationVerdict.verified,
    'borderline' => LocationVerdict.borderline,
    'outside' => LocationVerdict.outside,
    _ => LocationVerdict.unavailable,
  };

  bool get isVerified => this == LocationVerdict.verified;
  bool get isOutside => this == LocationVerdict.outside;

  /// Yöneticinin bakması gereken bir durum mu?
  bool get needsAttention => this != LocationVerdict.verified;

  /// Kötüden iyiye sıralama ağırlığı — bir günün "en kötü" okutmasını
  /// bulmak için kullanılır.
  int get severity => switch (this) {
    LocationVerdict.verified => 0,
    LocationVerdict.unavailable => 1,
    LocationVerdict.borderline => 2,
    LocationVerdict.outside => 3,
  };

  /// İkisinden daha kötü olanı.
  LocationVerdict worst(LocationVerdict other) =>
      other.severity > severity ? other : this;
}
