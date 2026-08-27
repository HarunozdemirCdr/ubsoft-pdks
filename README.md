# UBSoft PDKS

QR kodlu, **konum doğrulamalı** personel devam kontrol sistemi. Çok kiracılı
(multi-tenant) Flutter Web uygulaması; Firebase üzerinde çalışır.

Personel işe geldiğinde giriş QR'ını, çıkarken çıkış QR'ını okutur. Okutma
anında cihazın konumu ölçülür ve QR noktasının koordinatıyla karşılaştırılır —
böylece "etiketin fotoğrafını çekip evden okuttu" ile "gerçekten kapıda okuttu"
birbirinden ayrılır.

---

## İçindekiler

- [Ne yapar](#ne-yapar)
- [Konum doğrulaması nasıl çalışır](#konum-doğrulaması-nasıl-çalışır)
- [Geçmiş mi, Raporlar mı?](#geçmiş-mi-raporlar-mı)
- [Görünüm](#görünüm)
- [Roller ve yetkiler](#roller-ve-yetkiler)
- [Veri modeli](#veri-modeli)
- [Mimari](#mimari)
- [Kurulum](#kurulum)
- [Geliştirme](#geliştirme)
- [Testler](#testler)
- [Dağıtım](#dağıtım)

---

## Ne yapar

| Ekran | Kim görür | Ne işe yarar |
|---|---|---|
| **Okut** | Personel + yönetici | Tek düğme: içerideyse "çıkış için okut", değilse "giriş için okut". Altında günün okutmaları. |
| **Bugün** | Yönetici | Kim içeride, kim tamamladı, kim gelmedi, hangi okutma dikkat istiyor. |
| **Geçmiş** | Yönetici (personel yalnız kendisi) | Bir günün tüm kadrosu tek tabloda: solda ad, sağda giriş ve çıkış saatleri. Hızlı gözlem içindir. |
| **QR Noktaları** | Yönetici | Nokta oluştur, konumunu gir, yarıçapını ayarla, yazdırılabilir QR etiketini al. |
| **Personel** | Yönetici | Hesap aç, rol ve yetki ata, şifre sıfırlama gönder, pasifleştir. |
| **Raporlar** | Yönetici | İki tarih arası, kişiye dokununca gün gün giriş–çıkış dökümü. Geç giriş / çıkış yok / konum uyarısı / gelmediği gün süzgeçleri. Aynı döküm PDF olarak indirilir. |
| **Ayarlar** | Yönetici | Mesai saatleri, geç giriş toleransı, konum kuralları. |
| **Müşteriler** | Süper admin | Müşteri açar, abonelik uzatır, askıya alır. |

Bildirim **yoktur** ve bilinçli olarak eklenmemiştir; Cloud Functions'a da
ihtiyaç duymaz. Uygulama tarayıcıda çalışır, veriyi doğrudan Firestore'a yazar
ve güvenlik kurallarıyla korunur.

---

## Konum doğrulaması nasıl çalışır

Telefon GPS'i tek bir nokta değil, bir **daire** bildirir: "gerçek konum
şuranın 40 metre çevresinde bir yerde". Kapalı alanda ya da tarayıcı Wi-Fi
tabanlı konum kullandığında bu hata payı yüzlerce metreye çıkar. Ham mesafeyi
yarıçapla karşılaştırmak, kapının önünde duran personeli düzenli olarak
"uzakta" damgalardı.

Bu yüzden üç bölge vardır:

```
 |<--- yarıçap --->|<--- hata payı --->|
 ●─────────────────┼───────────────────┼────────────>
 nokta    doğrulandı        sınırda        nokta dışında
```

- **Yarıçap** nokta bazında ayarlanır (varsayılan **75 m**). 10 m ilk bakışta
  doğru görünür ama şehir içi GPS hatasının altındadır.
- **Hata payı** cihazın bildirdiği hassasiyettir, en fazla **150 m** ile
  sınırlanır. Sınırsız bırakılsaydı, tarayıcının IP tabanlı kilometrelerce
  hatalı ölçümü evden yapılan okutmayı da "sınırda" saydırırdı.

Sonuç dört değerden biridir: `doğrulandı`, `sınırda`, `nokta dışında`,
`konum yok`.

**Uzaktan okutma varsayılan olarak REDDEDİLMEZ, işaretlenir.** Reddetmek daha
sıkı görünür; ama hatalı bir GPS ölçümü yüzünden reddedilen giriş, personeli o
gün hiç gelmemiş gösterir — bu, uzaktan okutmadan daha büyük bir hatadır.
Kararı insan verir. Ayarlardan katı moda geçilebilir.

Kural motoru saf bir fonksiyondur (`VerifyLocation`, `ResolvePunch`) ve her
sınır durumu birim testiyle kilitlenmiştir.

---

## Geçmiş mi, Raporlar mı?

İki ekran da geçmiş veriye bakar ama soruları farklıdır ve bilinçli olarak
birbirinin kopyası değildir.

| | Geçmiş | Raporlar |
|---|---|---|
| Soru | "Dün kim kaçta geldi?" | "Ahmet son iki haftada ne yaptı?" |
| Kapsam | Bir gün, tüm kadro | Bir tarih aralığı, seçilen kişiler |
| Biçim | Hizalı tablo: ad, giriş, çıkış | Kişi satırı → dokununca gün gün döküm |
| Süzgeç | Yok (gün seçilir) | Personel + geç giriş / çıkış yok / konum uyarısı / gelmediği gün |
| Çıktı | Yok | PDF |

Geçmiş ekranında bir satıra dokunmak o günün okutmalarını **yerinde** açar;
kişinin başka günlerine geçmez. Bir personeli günler boyunca izlemek
Raporlar'ın işidir. Aynı işi iki yerde yapan iki ekran, ikisini de
zayıflatırdı.

Giriş ve çıkış saatleri her iki ekranda da renklidir: **giriş yeşil, çıkış
kırmızı**, okutulmamış saat soluk gri bir tire. Kırmızı burada "hata" demek
değildir; yön çiftinin bir bakışta ayrılması içindir. Aynı renkler PDF'e de
geçer.

Gün süzgeci **gün** seviyesinde çalışır: "geç giriş" seçildiğinde geç gelen
kişilerin tüm günleri değil, tam olarak geç gelinen günler listelenir.
Kişinin başlığındaki toplamlar ise aralığın tamamından hesaplanır — süzgeç
açıkken bile gerçek toplam süre görünür.

"Gelmediği gün" süzgeci özeldir: gelmeme bir kayıt değildir, Firestore'da
öyle bir belge bulunmaz. O günler yalnız bu süzgeç seçildiğinde kadro ve
tarih aralığından üretilir; aksi hâlde her rapor hafta sonlarıyla dolardı.

---

## Görünüm

Bu ürün, aynı kurumun devriye uygulamasıyla **mimarisini** paylaşır ama
görünümünü paylaşmaz; iki uygulamayı yan yana gören biri tek bir ürünün iki
kopyasına baktığını düşünmemelidir.

| | Devriye | PDKS |
|---|---|---|
| Vurgu rengi | Mavi `#2563EB` | Mor `#6D28D9` |
| Nötr skala | Soğuk gri | Sıcak taş (stone) |
| Font | Manrope | Plus Jakarta Sans |
| Köşe ölçeği | 8 / 12 / 16 / 24 | 6 / 10 / 14 / 20 |
| Buton | Tam yuvarlak (pill) | Yumuşak dikdörtgen |
| Rozet | Hap | Yumuşak dikdörtgen |

Renk seçimi rastgele değil: vurgu mavi kalsaydı, giriş–çıkış için kullanılan
yeşil–kırmızı ikilisiyle birlikte ekranda üç doygun renk yarışırdı. Mor,
durum renklerinin hiçbiriyle karışmaz. Köşelerin sıkılaşması ve butonların
düzleşmesi de aynı gerekçeden gelir: bu ürün gün gün saat okunan bir
tabloya bakar, tamamen yuvarlak bir dil o hizayı bulanıklaştırıyordu.

Renk, boşluk, köşe ve gölge değerleri yalnız `lib/core/theme` altındaki
token'lardan gelir; hiçbir widget dosyasında ham renk yazılmaz. Palet
değiştirmek tek dosyaya dokunmaktır.

PDF raporu ekrandaki paletin aynısını kullanır ve fontu `assets/fonts`
altında gömülü taşır — PDF'in yerleşik Helvetica'sında Türkçe harfler
(ş, ğ, İ, ı) yoktur.

---

## Roller ve yetkiler

| Rol | Kapsam |
|---|---|
| `superAdmin` | Müşteri açar/kapatır, abonelik yönetir. Bir müşteriye ait değildir; `tenants/_system` altında yaşar. |
| `admin` (Yönetici) | Kendi şirketinde **koşulsuz** tüm yetkilere sahiptir. |
| `staff` (Personel) | QR okutur, kendi kayıtlarını görür. Yetkileri kişi bazında açılıp kapatılabilir. |

İzin sistemi **yalnız personel içindir**. Yöneticiye izin açıp kapatmak
anlamsızdır; o zaten admindir. Bu kural iki yerde uygulanır ve ikisi senkron
olmalıdır: `PermissionSet.can()` ve `firestore.rules` içindeki `can()`.

Etkin izin şöyle çözülür:

```
kullanıcı override'ı  →  yoksa rol varsayılanı  →  yoksa kapalı
```

Rol varsayılanları Firestore'da `tenants/{tid}/roleDefaults/{role}` altında
durur ve güvenlik kuralları da oradan okur.

---

## Veri modeli

Tek kök koleksiyon; her şey bir müşterinin altında yaşar.

```
tenants/{tenantId}
  ├─ users/{uid}                       kimlik + rol + açıklama + izin override'ları
  ├─ roleDefaults/{role}               rol varsayılan izinleri
  ├─ checkpoints/{id}                  QR noktası: kod, konum, yarıçap, tür
  ├─ qrIndex/{code}                    kod tekilliği defteri
  ├─ attendance/{eventId}              TEK okutma — doğruluk kaynağı
  └─ attendanceDays/{uid}_{dateKey}    gün özeti — okutmalardan türetilir
```

İki kural bu modeli ayakta tutar:

1. **Okutma asla güncellenmez.** Düzeltilebilen bir devam kaydı, devam kaydı
   olmaktan çıkar. Yanlış kayıt silinir, personel yeniden okutur.
2. **Gün özeti türetilmiş veridir.** Okutmayla aynı işlemde (transaction)
   güncellenir; bir kayıt silindiğinde kalan okutmalardan sıfırdan kurulur.
   İki yolun aynı sonucu verdiği testle kilitlidir.

Okutmanın `at` alanı **sunucu saatidir**; güvenlik kuralı da bunu şart koşar.
Telefonun saatini geri alarak erken giriş yazdırmak aksi hâlde mümkün olurdu.

---

## Mimari

```
lib/
  core/          tema, yönlendirme, hata tipleri, saf yardımcılar (Geo, QrCode)
  domain/        varlıklar, enum'lar, izinler, kural motorları (saf Dart)
  data/          Firestore eşleyicileri ve depo uygulamaları
  application/   Riverpod sağlayıcıları ve denetleyiciler
  presentation/  ekranlar, kabuk, paylaşılan bileşenler
  services/      konum, kamera, PDF, bildirim (toast)
```

Kurallar:

- `domain` hiçbir şey bilmez — Firebase de, Flutter da. Bu yüzden kural
  motorlarının tamamı gerçek bir GPS ya da ağ olmadan test edilebilir.
- `data` katmanındaki her istisna `Result<T>`'ye çevrilir; `presentation`
  hiçbir zaman `FirebaseException` görmez.
- Ekranlar yönlendirme yapmaz; oturum değişir, `RouteGuard` karar verir.
- Renk, boşluk ve köşe değerleri yalnız `core/theme` token'larından gelir.

---

## Kurulum

Gereksinimler: Flutter 3.41+, Firebase CLI, `ubsoft-pdks` projesine erişim.

```bash
flutter pub get

# Firestore kurallarını ve indekslerini yükle (ilk kurulumda şart)
firebase deploy --only firestore:rules,firestore:indexes
```

### İlk süper admini oluştur

```bash
# Erişim jetonu
gcloud auth print-access-token

# Yalnız süper admin
dart run tool/seed.dart --token=<jeton> --only-super-admin

# Süper admin + örnek müşteri, personel, QR noktaları ve on günlük devam kaydı
dart run tool/seed.dart --token=<jeton>
```

Betik yeniden çalıştırılabilir; sabit kimlikler kullandığı için kayıtları
çoğaltmaz. Oluşturduğu hesaplar ekrana yazılır.

### Firebase Console'da açılması gerekenler

- **Authentication → Sign-in method → E-posta/Şifre**: etkin.
- **Firestore**: veritabanı oluşturulmuş (konum `eur3` önerilir).
- **Hosting**: `firebase deploy --only hosting` ile ilk yayın.

---

## Geliştirme

```bash
flutter run -d chrome

# Emulator ile
firebase emulators:start
flutter run -d chrome --dart-define=USE_EMULATOR=true
```

Kamera ve konum tarayıcıda **HTTPS ya da localhost** ister. `flutter run -d
chrome` localhost kullandığı için ikisi de çalışır.

---

## Testler

```bash
flutter analyze
flutter test
```

175 test dört katmanda:

| Dosya | Neyi korur |
|---|---|
| `test/domain/verify_location_test.dart` | Konum doğrulamasının her sınır durumu. |
| `test/domain/resolve_punch_test.dart` | Yön çözümü, üst üste okutma, konum kuralları. |
| `test/domain/summarize_day_test.dart` | Süre hesabı; artımlı ve sıfırdan hesabın eşitliği. |
| `test/domain/permissions_test.dart` | Rol varsayılanları ve izin çözümü. |
| `test/core/geo_and_qr_test.dart` | Haversine, koordinat doğrulama, kod biçimi. |
| `test/core/route_guard_test.dart` | Yönlendirme; menüde görünen her bölümün açılabilirliği. |
| `test/application/report_and_roster_test.dart` | Rapor toplamları, gün süzgeçleri, kadro tabanlı günlük tablo. |
| `test/services/pdf_report_test.dart` | PDF gerçekten üretiliyor mu; gömülü fontlar yerinde mi. |
| `test/e2e/punch_flow_test.dart` | Uçtan uca okutma: kural + depo + işlem + gün özeti. |
| `test/presentation/all_screens_smoke_test.dart` | Her ekranın gerçek veriyle çizilmesi. |
| `test/presentation/interaction_test.dart` | Form doğrulama, konum alma, ayar ve yetki kaydı, geçmiş tablosu ve rapor dökümü. |

Windows'ta `flutter test` bazen `build\unit_test_assets` dizinini silemediği
için patlar. Öncesinde:

```powershell
Remove-Item -Recurse -Force build\unit_test_assets -ErrorAction SilentlyContinue
```

---

## Dağıtım

```bash
flutter build web --release
firebase deploy --only hosting

# Kurallar ya da indeksler değiştiyse
firebase deploy --only firestore:rules,firestore:indexes
```

Sürüm numarası iki yerde tutulur ve birlikte artırılır: `pubspec.yaml`
(`version`) ve `lib/core/config/app_config.dart` (`appVersion`). Giriş
ekranında görünen pazarlama sürümü ayrıdır:
`lib/core/config/company_info.dart` → `displayVersion`.

**Yeni bir web eklentisi eklendiğinde `flutter clean` şart.** Artımlı derleme
`web_plugin_registrant.dart` dosyasını eski hâliyle yeniden kullanır ve yeni
eklentinin kaydı hiç yapılmaz; hata tarayıcıda izin sorunu gibi görünür ama
tümüyle derleme kaynaklıdır.
