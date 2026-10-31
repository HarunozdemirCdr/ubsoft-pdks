# UBSoft Yurt Kontrol

Öğrenci yurtları için QR ve konum doğrulamalı giriş–çıkış kontrolü.
Flutter Web, Riverpod, GoRouter, Firebase Auth, Firestore ve Firebase Hosting kullanır.
Paket/Firebase proje kimliği (`ubsoft_pdks`, `ubsoft-pdks`) mevcut kurulumlarla uyumluluk için korunur.

## Roller ve ekranlar

- **Öğrenci:** kendi kalıcı durumunu, hareket geçmişini ve izinlerini görür; giriş ve çıkış için ayrı QR okutur.
- **Yurt yöneticisi:** öğrenci, oda, QR, saat kuralı ve izin yönetimi yapar; öğrenci hareketi oluşturmaz.
- **UBS süper admin:** yurt, yönetici hesabı ve abonelik yönetimi yapar.

Yurt Durumu paneli aktif öğrencilerden kurulur; yöneticiler öğrenci sayısına dahil edilmez.
İçeride/dışarıda/bilinmeyen durumları, izin ve uyarılardan ayrı değerlendirilir.

## İş kuralları

- Giriş ve çıkış QR kodları farklıdır. Eski `both` noktalar yeni okutma kabul etmez.
- Çoklu giriş–çıkış desteklenir. Son hareket kişinin durumunu belirler; durum gece yarısı sıfırlanmaz.
- İlk hareketi olmayan öğrenci içeride/dışarıda varsayılmaz. İlk QR veya gerekçeli yönetici başlangıç kaydı durumu belirler.
- Aynı yöndeki ikinci hareket ve 60 saniye içindeki tekrar okutma transaction içinde ve Firestore kurallarında engellenir.
- Tarih ve saat kuralları Türkiye (UTC+3) saatine göredir. Öncelik: özel tarih → hafta günü → genel.
- En erken çıkış, en geç dönüş, isteğe bağlı en erken giriş ve geç dönüş toleransı ayarlanır.
- Sabah açılışından önceki dönüş önceki akşama aittir: 22.30 sınırı için ertesi gün 00.15 girişi 105 dakika geçtir.
- Saat ihlali hareketi engellemez; gerçek giriş/çıkış kaydedilir ve uyarı eklenir.
- Son dönüşü geçmiş ve hâlâ dışarıda olan öğrenci "Dönüş yapmadı" görünür; ertesi sabah uyarı kaybolmaz.
- Yönetici izin tanımlar/iptal eder. Kişi başına tek aktif/gelecek izin vardır, geçmiş izinler korunur. İzin fiziksel durumu değiştirmez.
- Yanlış hareket silinmez; gerekçe, yönetici ve zamanıyla geçersiz kılınır. Son durum ve günlük özet yeniden kurulur.
- Yeni akışta mesai, çalışma süresi ve "Tamamlandı" ekranları bulunmaz.

Başlangıç saatleri 06.00/22.30 örnek değerlerdir, kurum politikası değildir. Yönetici yurdun kendi kurallarını ayarlamalıdır.

## Arayüz 2.1

Panel metrikleri eşit boyutludur; dışarıda ve dönüşü geciken sayıları toplanmaz, gecikenler dışarıdakilerin alt kümesidir.
Başlangıç kaydı olmayan öğrenciler ayrı açıklama ve inceleme bağlantısıyla gösterilir.
Durum/inceleme filtreleri, arama ve sıfırlama ayrı yönetilir. Öğrenci seçimi isimle aranabilir.
Rapor ve geçmişte öğrenci → gün → hareket açılımı vardır; giriş yeşil, çıkış kırmızıdır. Günlük özet yalnız ilk giriş/son çıkışı gösterir; diğer okutmalar açılımda korunur.
Satışa hazırlık bulguları ve yüksek öncelikli işler [SATISA_HAZIRLIK.md](SATISA_HAZIRLIK.md) belgesindedir.

## Veri modeli

```text
tenants/{yurtId}
  users/{uid}                  kimlik, staff/admin rolü, öğrenci no, oda
  roleDefaults/{role}          rol izinleri
  checkpoints/{id}             ayrı in/out QR noktaları
  qrIndex/{code}               kod tekilliği
  attendance/{eventId}         asıl hareket, uyarılar, kural anlık görüntüsü
  presence/{uid}               günlerden bağımsız durum ve revision
  presenceAudit/{id}          gerekçeli başlangıç kayıtları
  leaves/{id}                 izin geçmişi ve iptal bilgisi
  leaveLocks/{uid}            aktif/gelecek izin kilidi
  attendanceDays/{uid}_{day}  eski şemayla uyumlu günlük özet
```

Hareketin `at` alanı ve `presence.at` sunucu zamanıdır. Hareket ve durum atomik yazılır.
Yön/aktif QR, rol/yurt üyeliği, tekrar okutma ve eşlenmiş durum yazımı Firestore kurallarında da doğrulanır.
GPS ölçümü ve saat uyarısı hesabı istemci kaynaklıdır; tarayıcı GPS'i fiziksel geçiş garantisi değildir.
Eski şema geçmiş veri için korunur. Yeni ekranlar `application/dorm` ve `presentation/features/dorm` altındadır.

## Geliştirme ve doğrulama

```powershell
flutter pub get
flutter run -d chrome
flutter analyze
flutter test
flutter build web --release
```

Gerçek güvenlik kuralları sahte Firestore testlerinde çalışmaz. Java 21 ve Firebase CLI ile yerel doğrulama:

```powershell
firebase emulators:exec --config firebase.emulator.json --project demo-yurt-test --only auth,firestore "node tool/verify_dorm_rules.cjs"
```

Kontroller ayrı QR, eşzamanlı cihazlar, rol/yurt izolasyonu, kapalı hesap ve izin yetkilerini kapsar; canlıya yazmaz.

## Eski PDKS kurulumundan geçiş

```powershell
node tool/migrate_dorm.cjs          # salt okunur plan
node tool/migrate_dorm.cjs --apply  # yedek alıp uygula
```

Betik Firebase CLI hesabını kullanır; kimlik bilgilerini çıktı/yedeğe yazmaz.
Yedek `.local-backups/` altına yazılır ve Git tarafından dışlanır.
Eski hareketler silinmez; son geçerli hareket kalıcı duruma taşınır. Hareketi olmayan öğrenci bilinmeyen kalır.
Ortak QR'ın kodu giriş olarak korunur, yeni tekil kodla çıkış noktası oluşturulur.
**Yeni çıkış etiketi QR Noktaları ekranından yazdırılıp asılmalıdır.** Betik tekrar çalıştırılabilir; mevcut durumları ezmez.

## Yayın

```powershell
flutter build web --release
firebase deploy --project ubsoft-pdks --only firestore:rules,firestore:indexes,hosting --account harun123gimba@gmail.com
```

Geçiş sırası: test/derleme → güvenlik kuralları → veri geçişi → hosting. Eski istemciler yeni kurallar yayımlandığında yenilenmelidir.
Hosting uygulama dosyalarını her açılışta doğrular (`no-cache`).
