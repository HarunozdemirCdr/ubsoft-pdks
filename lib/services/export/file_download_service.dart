/// Dosya indirme — ortama göre gerçek uygulama ya da karşılık seçilir.
///
/// Web derlemesinde `dart:js_interop` sürümü, testlerin koştuğu VM'de ise
/// hata fırlatan karşılık kullanılır. Tek bir web'e özel içe aktarma, onu
/// içeren tüm zinciri birim testlerinden dışarıda bırakıyordu: rapor
/// sağlayıcıları bu dosyayı kullandığı için rapor ekranı hiç test edilemiyordu.
library;

export 'file_download_service_stub.dart'
    if (dart.library.js_interop) 'file_download_service_web.dart';
