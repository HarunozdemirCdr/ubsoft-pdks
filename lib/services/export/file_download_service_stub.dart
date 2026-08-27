import 'dart:typed_data';

/// Tarayıcı dışı ortamlar için karşılık.
///
/// Uygulama yalnız web'de çalışıyor; bu dosyanın var olma sebebi **testler**.
/// Gerçek indirme `dart:js_interop` kullanır ve VM'de derlenmez; tek bir web'e
/// özel dosya, onu içeren tüm zinciri (rapor sağlayıcıları → rapor ekranı)
/// birim testinden tümüyle dışarıda bırakıyordu. Koşullu içe aktarma sayesinde
/// rapor ekranı artık VM üzerinde de çizilip sınanabiliyor.
abstract final class FileDownloadService {
  static const String pdfMimeType = 'application/pdf';

  static void download({
    required Uint8List bytes,
    required String fileName,
    String mimeType = pdfMimeType,
  }) {
    throw UnsupportedError(
      'Dosya indirme yalnız tarayıcıda çalışır. Bu çağrı web dışı bir '
      'ortamdan geldi (büyük ihtimalle bir test).',
    );
  }
}
