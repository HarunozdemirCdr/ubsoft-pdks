import 'package:ubsoft_pdks/core/config/app_config.dart';

/// QR nokta kodu yardımcıları.
///
/// Kod, yöneticinin işyerine özel elle girdiği **basit sayısal** bir
/// numaradır (1, 2, 3…); URL ya da sabit uzunlukta bir dize değildir.
/// Uygulama QR görselini üretir ve yazdırılabilir hâlde sunar; okuma
/// tarafında görevi okunan içeriği normalize edip doğrulamaktır.
///
/// Çok kiracılı olduğu için aynı numara farklı şirketlerde bulunabilir;
/// tekillik yalnız tenant içinde aranır.
abstract final class QrCode {
  /// Okunan ham QR içeriğini normalize eder.
  ///
  /// Bazı okuyucular kodun etrafına boşluk, satır sonu veya ayırıcı ekler.
  /// Sayısal olmayan her karakter temizlenir.
  static String normalize(String raw) =>
      raw.replaceAll(RegExp(r'[^0-9]'), '').trim();

  /// Normalize edilmiş kodun geçerli biçimde olup olmadığını söyler.
  ///
  /// Kural `firestore.rules` içindeki `^[0-9]{1,10}$` ile birebir aynıdır;
  /// ikisi birlikte değiştirilmelidir.
  static bool isValid(String code) =>
      code.isNotEmpty &&
      code.length <= AppConfig.qrCodeMaxLength &&
      RegExp(r'^[0-9]+$').hasMatch(code);

  /// Görüntüleme biçimi. Basit numaralar olduğu gibi gösterilir.
  static String format(String code) => code;
}
