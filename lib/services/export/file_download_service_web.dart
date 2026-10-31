import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

/// Tarayıcıda dosya indirme.
///
/// Sunucuya yükleme yapılmaz: bayt dizisi bellekte bir nesne URL'ine
/// dönüştürülür, gizli bir bağlantı tıklanır ve URL hemen serbest bırakılır.
abstract final class FileDownloadService {
  static const String pdfMimeType = 'application/pdf';

  static void download({
    required Uint8List bytes,
    required String fileName,
    String mimeType = pdfMimeType,
  }) {
    final web.Blob blob = web.Blob(
      <JSUint8Array>[bytes.toJS].toJS,
      web.BlobPropertyBag(type: mimeType),
    );

    final String url = web.URL.createObjectURL(blob);

    final web.HTMLAnchorElement anchor =
        web.document.createElement('a') as web.HTMLAnchorElement
          ..href = url
          ..download = fileName;
    anchor.style.display = 'none';

    web.document.body?.appendChild(anchor);
    anchor
      ..click()
      ..remove();

    // Nesne URL'i serbest bırakılmazsa bayt dizisi sekme kapanana kadar
    // bellekte kalır.
    web.URL.revokeObjectURL(url);
  }
}
