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
- [Çıkış okutulmazsa ne olur?](#çıkış-okutulmazsa-ne-olur)
- [Kim neyi görür?](#kim-neyi-görür)
- [Roller ve yetkiler](#roller-ve-yetkiler)
- [Veri modeli](#veri-modeli)
- [Mimari](#mimari)
- [Kurulum](#kurulum)
- [Geliştirme](#geliştirme)
- [Testler](#testler)
- [Okuma maliyeti](#okuma-maliyeti)
- [Dağıtım](#dağıtım)

---

## Ne yapar

| Ekran | Kim görür | Ne işe yarar |
|---|---|---|
| **Okut** | Personel + yönetici | Tek düğme: içerideyse "çıkış için okut", değilse "giriş için okut". Altında günün okutmaları. Personel burada konum kararını ve geç giriş işaretini görmez. |
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
| Vurgu rengi | Canlı mavi `#2563EB` | Lacivert `#1E3A8A` |
| Nötr skala | Soğuk gri | Sıcak taş (stone) |
| Font | Manrope | Plus Jakarta Sans |
| Köşe ölçeği | 8 / 12 / 16 / 24 | 6 / 10 / 14 / 20 |
| Buton | Tam yuvarlak (pill) | Yumuşak dikdörtgen |
| Rozet | Hap | Yumuşak dikdörtgen |

Lacivert, devam kontrol yazılımlarının alıştırdığı renktir; kurumsal durur
ve doygunluğu düşük olduğu için giriş–çıkış'ın yeşil–kırmızı ikilisiyle
yarışmaz. Devriye ürünü de mavi kullandığından ayrım tek renge
bırakılmamıştır: ton (lacivert, canlı maviden belirgin biçimde koyu), nötr
skala ve font birlikte ayırır. Köşelerin sıkılaşması ve butonların
düzleşmesi de aynı gerekçeden gelir: bu ürün gün gün saat okunan bir
tabloya bakar, tamamen yuvarlak bir dil o hizayı bulanıklaştırıyordu.

Renk, boşluk, köşe ve gölge değerleri yalnız `lib/core/theme` altındaki
token'lardan gelir; hiçbir widget dosyasında ham renk yazılmaz. Palet
değiştirmek tek dosyaya dokunmaktır.

PDF raporu ekrandaki paletin aynısını kullanır ve fontu `assets/fonts`
altında gömülü taşır — PDF'in yerleşik Helvetica'sında Türkçe harfler
(ş, ğ, İ, ı) yoktur.

---

## Çıkış okutulmazsa ne olur?

En sık yaşanan durum: personel akşam çıkarken okutmayı unutur, gün biter,
ertesi sabah normal şekilde işe gelir. Sistem bunu **karıştırmaz**, çünkü
her gün kendi belgesindedir (`attendanceDays/{uid}_{gün}`) ve bir okutma
hangi güne düşerse o günün hanesine yazılır.

Sırayla ne olur:

| Zaman | Ne olur |
|---|---|
| Salı 08:30 | Giriş okutulur. Gün "İçeride" olur. |
| Salı 18:00 | Çıkış okutulmaz. Gün açık kalır. |
| Salı 24:00 | Hiçbir şey olmaz; gün kendiliğinden kapanmaz. |
| Çarşamba 00:30 | Girişin üstünden 16 saat geçti: Salı artık **"Çıkış yok"**. Çalışma süresi sayacı **durur**. |
| Çarşamba 08:30 | Giriş okutulur. **Çarşamba'nın kendi belgesi** açılır ve sıfırdan başlar. |

Üç sonucu ayrıca söylemek gerek:

1. **Ertesi günün girişi engellenmez.** "Zaten giriş yapmışsınız" uyarısı
   yalnız *aynı gün* içinde çalışır; Salı'nın açık kalması Çarşamba'yı
   etkilemez.
2. **Salı'nın çalışma süresi 0 kalır**, "eksik" olarak. Uygulama bir çıkış
   saati uydurmaz — ne 18:00 yazar ne de gece yarısında keser. Kaç saat
   çalışıldığını yalnız orada olan insanlar bilir.
3. **Sayaç sonsuza kadar büyümez.** 16 saat dolduktan sonra süre donar;
   aksi hâlde üç gün önce unutulmuş bir çıkış ekranda "78 saat" olarak
   görünürdü.

Yönetici bunu iki yerde görür: Geçmiş tablosunda o satırın çıkış kolonu
boştur ve durumu "Çıkış yok"tur; Raporlar'da **"Çıkış yok"** süzgeci tam
olarak bu günleri listeler ve PDF'e döker. Düzeltme yolu yoktur, olması da
istenmedi: bir devam kaydının saati elle değiştirilebiliyorsa o kayıt kanıt
olmaktan çıkar. Yanlış bir okutma **silinebilir** (gün özeti kalan
okutmalardan yeniden hesaplanır), ama olmayan bir okutma sonradan
yazılamaz.

**Gece vardiyası desteklenmez.** 20:00'de girip ertesi gün 05:00'te çıkan
biri iki ayrı güne düşer: ilk gün "çıkış yok", ikinci gün "girişi olmayan
çıkış" olarak görünür ve hiçbirinde süre hesaplanmaz. Böyle bir vardiya
gerekirse gün sınırının mesai başlangıcına kaydırılması gerekir; bu bugün
yok.

---

## Kullanım kılavuzu

Müşteriye verilecek sade kılavuz depoda hazır durur:
[`Kullanim-Kilavuzu.docx`](Kullanim-Kilavuzu.docx). İçinde teknik ayrıntı
yoktur; personel ve yönetici için ne yapılacağını ve sık sorulanları anlatır.

Metni değiştirmek gerekirse Word'de değil `tool/kullanim_kilavuzu.py`
içinde değiştirilir ve belge yeniden üretilir:

```bash
pip install python-docx
python tool/kullanim_kilavuzu.py
```

---

## Kim neyi görür?

Konum kanıtı ve geç giriş işareti **yöneticinin** bilgisidir. Personel kendi
ekranında yalnız ne olduğunu görür:

| | Personel (kendi kaydı) | Yönetici |
|---|---|---|
| Giriş / çıkış saati | ✓ | ✓ |
| Gün durumu (İçeride / Tamamlandı / Çıkış yok / Giriş yok) | ✓ | ✓ |
| Çalışma süresi | ✓ | ✓ |
| Konum kararı (doğrulandı / sınırda / nokta dışında) | — | ✓ |
| Noktaya uzaklık | — | ✓ |
| Geç giriş işareti | — | ✓ |

Sebep: bunlar bir **konuşmanın malzemesidir**, personelin her gün karşısına
çıkan bir yargı değil. Ölçüt `attendance.viewAll` iznidir — başkalarının
kaydını görebilen kişi zaten yöneticidir.

Bunun bir bedeli var ve bilinerek ödeniyor: uzaktan okutma yapan personel,
kaydının işaretlendiğini o an görmez. Okutması **reddedildiğinde** (katı mod
açıksa) sebebi yine görür; aksi hâlde neden okutamadığını bilemezdi.

---

## Roller ve yetkiler

| Rol | Kapsam |
|---|---|
| `superAdmin` | Müşteri açar/kapatır, abonelik yönetir. Bir müşteriye ait değildir; `tenants/_system` altında yaşar. |
| `admin` (Yönetici) | Kendi şirketinde **koşulsuz** tüm yetkilere sahiptir. |
| `staff` (Personel) | QR okutur, kendi kayıtlarını görür. |

İzin sistemi **yalnız personel içindir**. Yöneticiye izin açıp kapatmak
anlamsızdır; o zaten admindir. Bu kural iki yerde uygulanır ve ikisi senkron
olmalıdır: `PermissionSet.can()` ve `firestore.rules` içindeki `can()`.

Etkin izin şöyle çözülür:

```
kullanıcı override'ı  →  yoksa rol varsayılanı  →  yoksa kapalı
```

Rol varsayılanları Firestore'da `tenants/{tid}/roleDefaults/{role}` altında
durur ve güvenlik kuralları da oradan okur.

### Kişiye özel izin ekranı neden yok

Altyapı override'ı destekler ama **arayüzden erişilemez**: kişi bazlı izin
düzenleme sayfası bilerek kaldırıldı. Müşterinin isteği açıktı — iki rolün
izin kümesi standarttır ve "yanlışlıkla bile olsa" değişmemelidir. Bir
personelin sayfası artık tek sayfadır: bilgiler ve işlemler.

Zincirin ortasındaki override basamağı yerinde duruyor: rol varsayılanları
Firestore'dan okunduğu için ileride gerekirse tek bir belge yazmakla
açılabilir, kod değişikliği gerekmez. Kapalı olan yalnız arayüz — kazara
değişimin tek gerçekçi yolu buydu.

Karar [`test/presentation/interaction_test.dart`](test/presentation/interaction_test.dart)
içindeki "Yetkiler ekrandan değiştirilemez" grubuyla kilitlidir.

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

# Süper admin + örnek müşteri: bir yönetici, on iki personel, üç QR noktası
# ve son bir buçuk aylık devam kaydı
dart run tool/seed.dart --token=<jeton>
```

Betik yeniden çalıştırılabilir; sabit kimlikler kullandığı için kayıtları
çoğaltmaz. Devam kayıtlarını yazmadan **önce siler**: belge kimliği değişen
bir okutma yanında kalsaydı, gün özeti "bir giriş" derken listede iki giriş
görünürdü.

Örnek kadronun her üyesinin bir davranış profili vardır (`_Profile`) —
sürekli geç gelen, çıkışını unutan, konumu doğrulanamayan, öğle arası çıkıp
dönen, yarı zamanlı, hafta sonu nöbetçisi ve işten ayrılmış bir personel.
Amaç dolu görünen bir veritabanı değil, arayüzün **her durumunu** gerçek
veriyle görebilmek: geç gelen biri yoksa geç giriş rozeti hiç denenemez.

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

229 test beş katmanda:

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
| `test/presentation/layout_stress_test.dart` | On iki kişilik kadro ve uzun adlarla üç genişlikte (360 / 768 / 1440) ve karanlık temada taşma denetimi. |
| `test/presentation/interaction_test.dart` | Form doğrulama, konum alma, ayar ve yetki kaydı, geçmiş tablosu ve rapor dökümü. |

Windows'ta `flutter test` bazen `build\unit_test_assets` dizinini silemediği
için patlar. Öncesinde:

```powershell
Remove-Item -Recurse -Force build\unit_test_assets -ErrorAction SilentlyContinue
```

### Güvenlik kuralları: canlı doğrulama

`flutter test`, `fake_cloud_firestore` üzerinde çalışır ve o sahte Firestore
**güvenlik kurallarını hiç çalıştırmaz**. Yani 221 testin tamamı yeşilken
yayındaki kurallar bozuk olabilir — nitekim oldu (aşağıdaki tuzağa bakınız).

O katmanı `tool/verify_live.py` sınar: gerçek hesaplarla giriş yapar ve
Firestore'a o kullanıcının kimliğiyle sorar.

```bash
python tool/verify_live.py     # 15 kontrol; yalnız okur, veri değiştirmez
```

Kurallara her dokunuşta **deploy'dan sonra** çalıştırın. Kontroller iki yönlü:
personelin görebilmesi gerekenler görünüyor mu *ve* görmemesi gerekenler
kapalı mı. İkincisi olmadan bir kural gevşetmesi fark edilmezdi.

---

## Okuma maliyeti

Firestore faturası okunan **belge sayısıyla** ölçülür, sorgu sayısıyla değil.
Bu yüzden ekranların ne kadar okuduğu tasarımın parçasıdır:

| Ekran | Okuma |
|---|---|
| Okut | Kişinin bugünkü özeti + okutmaları — canlı, tek dinleyici |
| Bugün / Geçmiş | Seçili günün özetleri (kadro kadar belge) — canlı, tek dinleyici; iki ekran aynı günü seçtiğinde aynı dinleyiciyi paylaşır |
| Raporlar | Aralıktaki özetler — **tek seferlik** okuma, oturum boyunca önbellekte |
| Oturum açılışı | Bir kullanıcı + bir müşteri + rol varsayılanları |

Üç karar bunu ucuz tutuyor:

1. **Gün özeti ayrı bir belgedir.** "Bu ay kim kaç saat çalıştı" sorusu
   binlerce okutma yerine otuz özet okunarak cevaplanır.
2. **Rapor canlı dinlemez.** Rapor bir fotoğraftır; açık kalan bir ekran her
   yeni okutmada yeniden belge okumaz.
3. **Gün süzgeci ağa çıkmaz.** "Geç giriş", "çıkış yok", "gelmediği gün"
   süzgeçleri istemcide çalışır ve okuma anahtarı yalnız tarih aralığı +
   personelden oluşur (`ReportQuery`). Çipler arasında gezinmek sıfır okuma
   maliyetlidir.

Ölçek örneği: 12 kişilik bir kadroda otuz günlük rapor ≈ 360 belge okur ve
o aralığa geri dönüldüğünde yeniden okumaz. Günlük panelde bir gün ≈ 12
belgedir.

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

---

## Tuzak: kuralda olmayan belgenin alanına bakmak

Bir güvenlik kuralı `resource.data.<alan>` yazdığında **belgenin var olduğunu
varsayar**. Belge yoksa `resource` boştur, değerlendirme hata verir ve
Firestore erişimi reddeder — kullanıcıya `permission-denied` döner, yani
uygulamada "Bu işlem için yetkiniz yok".

Bu, `attendanceDays` üzerinde gerçekten yaşandı ve en kötü yerde vurdu: gün
özeti ancak **ilk okutmayla** oluştuğu için, personel sabah uygulamayı
açtığında kendi okutma ekranında yetki hatası görüyordu — tam okutma yapacağı
anda. Yöneticide görünmüyordu, çünkü onda `attendance.viewAll` şartı daha
önce doğru dönüp kısa devre yapıyordu. `flutter test` de yakalamıyordu:
kurallar orada hiç çalışmıyor.

Çözüm, belgeyi okumadan sahibini bilmek. Doküman kimliği `{uid}_{gün}`
biçimindedir, dolayısıyla `get` için kimlik yeter; `list` için ise alana
bakmak hem güvenli (her aday belge vardır) hem zorunludur:

```
allow get:  if dayId.split('_')[0] == request.auth.uid ||
               can(tid, 'attendance.viewAll');

allow list: if request.auth.uid == resource.data.userId ||
               can(tid, 'attendance.viewAll');
```

**Genel kural:** `get` ile `list`'i aynı satırda birleştirmeden önce
"bu belge hiç var olmayabilir mi?" diye sorun. Cevap evetse ikisi ayrılmalı.
Gerileme koruması `tool/verify_live.py` içindedir.
