# UBSoft Yurt Kontrol

Öğrenci yurtları için QR ve konum doğrulamalı giriş–çıkış kontrolü.
Flutter Web, Riverpod, GoRouter, Firebase Auth, Firestore ve Firebase Hosting kullanır.
Paket/Firebase proje kimliği (`ubsoft_pdks`, `ubsoft-pdks`) mevcut kurulumlarla uyumluluk için korunur.

## ESP32 turnike entegrasyonu — 2.2.0

**Yayın durumu:** 2.2.0 web sürümü, sekiz Cloud Functions işlevi, Firestore kuralları ve ayrı Avrupa RTDB kuralları 1 Kasım 2026 tarihinde yayımlandı. Canlıda geçersiz cihaz kaydı ve yetkisiz yönetim/veritabanı erişimi reddi doğrulandı. Gerçek kartın kurulumu ve fiziksel röle kabul testi henüz yapılmadı.

ESP32-WROOM kartı en fazla **8 aktif HIGH röle** destekler. Sırasıyla GPIO: **26, 27, 25, 32, 14, 12, 13, 15**.
Yurt yöneticisi **QR Noktaları → Turnike kartı** ekranında kart kimliğini kalıcı olarak yurda bağlar ve her röleye ayrı giriş/çıkış QR noktası atar. Kullanılmayan kanallar boş kalır; bir QR yalnız bir röleye atanır.

Kart Bluetooth LE üzerinden Wi-Fi kurulumu yapar, kendi rastgele kimliğiyle kaydolur ve yalnız kendi yurt atamasını dinler. Atamayı NVS'ye kaydettikten sonra doğrudan kendi RTDB komut yolunu dinler. Röle darbesi **1000 ms** süreyle kart içinde kapanır. Oturum, son kullanma ve kalıcı sıra kontrolü eski komutların tekrar açmasını engeller. Sunucu, yön ve konum politikası dahil mevcut kayıt koşullarını tekrar denetler; istemciler röle komutu yazamaz.

[Kurulum, Bluetooth alanları, pinler ve saha kontrolü](docs/ESP32_TURNIKE_KURULUM.md) · [Arduino kodu](firmware/ubsoft_turnstile/ubsoft_turnstile.ino)

QR hareket kaydı ile fiziksel geçiş aynı şey değildir. Röle yanıtı alınamazsa öğrenci görevliye yönlendirilir; geçiş sensörü olmadan fiziksel geçiş kanıtlanamaz. GPIO12/15 strapping davranışı özel üretim kartta ayrıca doğrulanmalıdır. Bu sürüm yurtta tek kart ve en fazla sekiz QR–röle eşlemesi içerir.

Backend: `functions/` (Node22), `database.rules.json`, `firebase.turnstile.emulator.json`. Avrupa RTDB `ubsoft-pdks-turnstile` mevcut varsayılan RTDB'den ayrıdır. Fonksiyonlar `europe-west1` bölgesindedir. Dağıtım: `firebase deploy --only functions:turnstile,database:turnstile,firestore:rules,hosting --project ubsoft-pdks`. Bluetooth kurulumu ayrı GATT istemcisiyle yapılır; Flutter web içinde doğrudan Bluetooth arayüzü bulunmaz.

### Turnike doğrulaması

- Mevcut 280 Flutter testi ve 3 yeni turnike testi geçti (360 px yerleşim, öğrenci erişimi, sınırlı bekleme/geciken yanıt).
- 5 sunucu mantık testi, 14 RTDB erişim kontrolü ve 18 Firestore güvenlik kontrolü geçti.
- Yerel emulator'da cihaz kaydı → yönetici ataması → röle1/röle8 komutu → kart yanıtı → komut temizliği ve çevrimdışı durum doğrulandı.
- ESP32 Dev Module / Huge APP, core3.3.12 ile derlendi: yaklaşık 1,84 MB flash, 69 KB statik RAM. Bu rakamlar TLS çalışma zamanı yığın tüketimi veya gerçek donanım testi değildir.
- Canlıya cihaz kimliği, Wi-Fi parolası veya test kartı ataması eklenmedi. Fiziksel kurulum kullanıcı tarafından yapılacak.

Yerel sunucu testi: `npm ci --prefix functions` ve `npm test --prefix functions`.
Erişim testi: `firebase emulators:exec --project demo-yurt-turnstile --config firebase.turnstile.emulator.json --only database "node functions/test/rules.cjs"`.
Uçtan uca test: aynı komutta `--only auth,firestore,database,functions "node functions/test/integration.cjs"`.

Canlı ekranın tarayıcı üzerinden görsel kontrolü, otomasyonun aktif adresi doğrulayamaması nedeniyle tamamlanamadı; 360 px yerleşim widget testinde doğrulandı. Sunucu etkinlik durumu ve Hosting derleme eşleşmesi ayrıca kontrol edildi.

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

### 2.1.1 boş hareket ve mobil yerleşim düzeltmesi

Geçmiş, rapor ve öğrencinin günlük hareketleri ortak canlı akış üzerinden yüklenir.
Boş liste geçerli sonuçtur ve kayıt yok görünümüne geçer. İlk dinleyici cevabı 4 saniye içinde gelmezse
sunucudan tek bir doğrulama okuması yapılır; bu istek 12 saniyede yanıt vermezse hata ve yeniden deneme sunulur.
Bağlantı veya yetki hatası kayıt yok gibi gösterilmez. Canlı dinleyici çalışmaya devam eder;
geciken ilk okuma daha yeni bir canlı sonucu ezmez ve normal hızlı yanıtta ek okuma yapılmaz.
Oturum hazır değilken veri sağlayıcıları değersiz kapanan akış yerine açık bir başlangıç değeri yayınlar;
ad veya son giriş zamanı değişmesi hareket sorgusunu gereksiz yere yeniden başlatmaz.
Tarih alanı etiketi kutunun dışında gösterilir. Mobil alt menüde daha fazla yükseklik,
yatay etiket boşluğu ve dar ekrana uygun yazı boyutu kullanılır.
Kılavuzdaki ekran görüntüleri alındıkları 2.1.0 sürümünü belgelemeye devam eder.

QR hiç algılanmadığında kamera taramayı sürdürür. Yanlış kod ve yeniden denenebilir hatalarda sonuç paneli
5 saniyelik sayaçtan sonra aynı ekranda taramaya döner; `Tekrar dene` beklemeden yeniden taramayı açar.
Aynı kodun kamera tarafındaki 1,5 saniyelik filtrelemesi ile başarılı kaydın sunucu tarafındaki 1 dakikalık
çift kayıt koruması birbirinden ayrıdır. Hata sonrası elle tekrar deneme eski kod filtresini temizler.
İşlem sürerken ve başarı panelinde otomatik yeni kayıt gönderilmez. Oturum/yetki/abonelik hataları ile
`too-soon` uyarısı otomatik tekrarlanmaz; kullanıcı açıklamayı okur ve gerekli işlemi yapar.
Kamera yeniden denemesi yazılım testlerinde sınanmıştır; gerçek telefon, kamera ve GPS kabulü ayrıca yapılmalıdır.

Panel metrikleri eşit boyutludur; dışarıda ve dönüşü geciken sayıları toplanmaz, gecikenler dışarıdakilerin alt kümesidir.
Başlangıç kaydı olmayan öğrenciler ayrı açıklama ve inceleme bağlantısıyla gösterilir.
Durum/inceleme filtreleri, arama ve sıfırlama ayrı yönetilir. Öğrenci seçimi isimle aranabilir.
Rapor ve geçmişte öğrenci → gün → hareket açılımı vardır; giriş yeşil, çıkış kırmızıdır. Günlük özet yalnız ilk giriş/son çıkışı gösterir; diğer okutmalar açılımda korunur.
Satışa hazırlık bulguları ve yüksek öncelikli işler [SATISA_HAZIRLIK.md](SATISA_HAZIRLIK.md) belgesindedir.

## Sunum demosu ve görselli kullanım kılavuzu

[Word kullanım kılavuzu](docs/UBSoft_Yurt_Kontrol_Kullanim_Kilavuzu.docx), yönetici ve öğrenci ekranlarını sade adımlarla açıklar.
30 sayfalık belgede 28 konu ve çalışan uygulamadan alınmış 29 mobil ekran görüntüsü bulunur.
Ekranlar 390 × 844 boyutunda, yayımlanmış 2.1.0 sürümünün TÜRGEV Demo oturumlarından alınmıştır; taslak arayüz veya widget testi görüntüsü değildir.
QR tarama görüntüsü kamera açılamadı yardım durumunu gösterir; gerçek telefonla başarılı QR/GPS kabul testi yapıldığının kanıtı değildir.

31 Ekim 2026 sunum hazırlığında yalnız `turgev-demo` yurduna 27 kurgusal öğrenci eklendi.
Doğrulanan toplamlar: **30 öğrenci, 2 yönetici, 1.050 hareket belgesi, 403 günlük özet ve 5 izin**.
Hareket belgelerinden biri gerekçeli geçersiz kayıt senaryosudur; normal hareket listesinde gösterilmez.
Yeni verilerde 128 öğrenci gününde birden çok giriş bulunur; geç giriş, erken giriş/çıkış, gece yarısı dönüşü,
geciken dönüş, aktif/geçmiş/gelecek/iptal izin ve başlangıç kaydı olmayan öğrenci senaryoları vardır.
Eski 32 hareket korunmuştur. Kurgu senaryoların bulunması, tüm saha senaryolarının test edildiği anlamına gelmez.
Demo saat kuralı: en erken çıkış 06:00, en erken giriş 07:00, son dönüş 22:30 ve 10 dakika tolerans.
Bu saatler bir kurumun resmî uygulamasını temsil etmez. Tarihli kayıtlar otomatik olarak her gün yeniden üretilmez.

```powershell
node tool/prepare_presentation_demo.cjs           # yalnız demo planı ve yerel yedek
node tool/prepare_presentation_demo.cjs --apply   # yalnız demo yurduna kurgusal kayıt ekler
node tool/prepare_presentation_demo.cjs --verify  # hareket sırası, durum ve eski kayıtları doğrular
```

Betik yalnız `turgev-demo` ve `TÜRGEV Demo` hedefini kabul eder. Daha önce eklenmiş sunum verilerini yeniden yazmaz.
Firebase CLI'ın yetkili oturumunu kullanır. İşlem öncesi yedekler ve yeni kurgusal hesapların rastgele şifreleri
Git dışında tutulan `.local-backups/` altında kalır; şifreler kılavuza veya terminal çıktısına yazılmaz.
`--verify` özgün hareketleri karşılaştırmak için aynı makinedeki işlem öncesi yedeği kullanır.

Kılavuz kaynak görüntüleri `docs/kilavuz/ekranlar/`, üretim betiği `tool/build_user_manual.py` altındadır.
Betik `python-docx` ile çalışır; belge değiştiğinde Word/uygun belge işleyicisiyle bütün sayfalar görsel olarak yeniden kontrol edilmelidir.
Bu çalışma uygulama kodunu veya güvenlik kurallarını değiştirmez; mevcut 2.1.0 yayını geçerlidir.

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
