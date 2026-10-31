import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:ubsoft_pdks/core/config/app_config.dart';
import 'package:ubsoft_pdks/core/utils/qr_code.dart';

/// Kamera denetleyicisi.
///
/// Tarayıcıda kamera erişimi HTTPS ve kullanıcı izni gerektirir. İzin
/// reddedildiğinde okutma yapılamaz — elle kod girişi bilinçli olarak
/// **yoktur**: öğrencinin yurtta olduğu yalnız QR ile kanıtlanır,
/// elle girilebilen bir kod bu kanıtı ortadan kaldırırdı.
final qrControllerProvider = Provider.autoDispose<MobileScannerController>((
  ref,
) {
  final MobileScannerController controller = MobileScannerController(
    formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
    // Aynı kodun arka arkaya okunmasını engeller: kullanıcı kamerayı
    // etiketten çekene kadar tek okuma sayılır.
    detectionTimeoutMs: AppConfig.scanDebounce.inMilliseconds,
  );

  ref.onDispose(controller.dispose);
  return controller;
});

/// Okunan barkodlardan geçerli nokta kodunu çıkarır.
///
/// QR içeriği URL değil, sayısal bir dizedir. Bazı okuyucular kodun etrafına
/// boşluk veya satır sonu ekler; normalize edilir.
abstract final class QrCodeReader {
  /// Barkod listesinden ilk geçerli kodu döner; yoksa `null`.
  static String? extract(BarcodeCapture capture) {
    for (final Barcode barcode in capture.barcodes) {
      final String? raw = barcode.rawValue;
      if (raw == null || raw.isEmpty) continue;

      final String normalized = QrCode.normalize(raw);
      if (QrCode.isValid(normalized)) return normalized;
    }
    return null;
  }

  /// Okunan ama geçersiz olan ham içerik — kullanıcıya "bu bizim kodumuz
  /// değil" demek için kullanılır.
  static String? rawOf(BarcodeCapture capture) {
    for (final Barcode barcode in capture.barcodes) {
      final String? raw = barcode.rawValue;
      if (raw != null && raw.isNotEmpty) return raw;
    }
    return null;
  }
}
