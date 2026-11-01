# ESP32 turnike kartı — kurulum ve kullanım

Bu sürüm bir yurda kalıcı bağlanan tek ESP32-WROOM kartını ve kart üzerindeki en fazla sekiz röleyi destekler. Her röle giriş veya çıkış olarak kullanılabilir. Yön, uygulamadaki QR noktasından gelir. Kullanılmayan rölelere QR atanmaz.

| Röle | GPIO |
| --- | --- |
| 1 | 26 |
| 2 | 27 |
| 3 | 25 |
| 4 | 32 |
| 5 | 14 |
| 6 | 12 |
| 7 | 13 |
| 8 | 15 |

Röleler HIGH ile çalışır. Geçerli yeni komutta yalnız ilgili GPIO yaklaşık 1 saniye HIGH olur; kart kendi zamanlayıcısıyla LOW yapar. Buluttan kapatma emri beklemez. Yazılım zamanlayıcısı mutlak donanım zaman garantisi değildir. Turnike girişinin kuru kontak ve darbe beklentisini kendi kartınızla doğrulayın.

## 1. Kodu karta yükleme

Firebase sunucu hizmetleri ve 2.2.0 web sürümü yayımlandı. Kartınızın kimliği henüz gerçek bir yurda atanmadı; aşağıdaki adımlarla kendi kartınızı bağlayabilirsiniz. Kart kayıt yanıtını alamazsa kimliğini koruyarak 30 saniye arayla yeniden dener.

`firmware/ubsoft_turnstile/ubsoft_turnstile.ino` dosyasını Arduino IDE ile açın. Aynı klasördeki `trusted_roots.h` dosyası da gereklidir.

Kurulumda kullanılan sürümler:

- ESP32 by Espressif Systems: **3.3.12**
- FirebaseClient by Mobizt: **2.2.9**
- ArduinoJson by Benoit Blanchon: **7.4.3**
- Kart: **ESP32 Dev Module**; Partition Scheme: **Huge APP (3MB No OTA/1MB SPIFFS)**, en az 4 MB flash.
- Seri port: **115200 baud**.

Firebase API anahtarı ve adresler proje için hazırdır; yönetici parolası veya servis hesabı anahtarı girilmez. TLS sertifika doğrulaması açıktır. Firebase uçlarının sertifika zinciri değişirse kök sertifikalar bakımdan geçirilmelidir.

GPIO12 ve GPIO15 açılışta özel anlamı olan strapping pinleridir. Özellikle GPIO12'nin reset anında yanlış seviyeye çekilmesi flash besleme seçimini etkileyebilir. Röle sürücüsü/pull dirençleri kartınızın açılışını ve rölelerin reset boyunca kapalı kalmasını sağlamalıdır. Yazılım ancak işlemci başladıktan sonra pin seviyesini belirleyebilir. İlk yüklemeyi turnike yükleri ayrıyken yapıp sekiz çıkışın güç verme/reset davranışını ölçün. [Espressif veri sayfası](https://www.espressif.com/sites/default/files/documentation/esp32_datasheet_en.pdf).

## 2. Bluetooth ile ilk Wi-Fi kurulumu

Kart ilk açılışta rastgele 32 karakterli kimlik ve ayrı bir gizli cihaz parolası üretir. Kimlik, parola ve sonraki yurt ataması ESP32'nin Preferences/NVS kalıcı belleğinde tutulur. Normal yeniden başlatma veya Wi-Fi değişikliği kimliği değiştirmez.

1. Seri monitörü 115200 ile açın. `Kart kimligi` ve altı haneli `Bluetooth PIN` satırlarını alın. PIN'i kartın kurulum etiketi olarak saklayın. Gizli Firebase cihaz parolası gösterilmez.
2. Telefonda Bluetooth LE GATT istemcisiyle (örneğin nRF Connect) `UBSoft-xxxxxxxx` cihazına bağlanın. Bu aşama web uygulamasının dışında yapılır; web uygulamasında doğrudan Bluetooth kurulum ekranı yoktur.
3. Aşağıdaki servisi açın. Kimlik okuma veya ayar yazma sırasında Bluetooth güvenli eşleştirme istediğinde kartın PIN'ini girin. Şifresiz yazma kabul edilmez.
4. SSID ve parola alanlarına **UTF-8 metin** yazın. Uzun parola için istemcide MTU 247 veya uzun yazma seçeneğini kullanın. Wi-Fi 2,4 GHz olmalıdır.
5. Kaydet alanına büyük harfle `SAVE` yazın. Kart bilgileri kaydedip yeniden başlar. İnternete bağlanınca cihaz kaydını oluşturur; henüz yurt atanmamışsa yalnız kendi atama yolunu dinler.

Servis UUID: `87df1000-1677-4e78-99d1-224e0c852200`

| Alan | UUID son bölümü öncesindeki numara | Tam UUID |
| --- | --- | --- |
| Kart kimliği — oku | 1001 | `87df1001-1677-4e78-99d1-224e0c852200` |
| Wi-Fi SSID — yaz | 1002 | `87df1002-1677-4e78-99d1-224e0c852200` |
| Wi-Fi parolası — yaz | 1003 | `87df1003-1677-4e78-99d1-224e0c852200` |
| Kaydet — `SAVE` yaz | 1004 | `87df1004-1677-4e78-99d1-224e0c852200` |

Kurulum tamamlandığında Bluetooth kapalıdır; normal çalışma belleği Wi-Fi/Firebase için ayrılır. Wi-Fi hatalıysa veya ağ değişirse USB seri monitörden satır sonuyla `WIFI_RESET` gönderin. Yalnız Wi-Fi bilgileri temizlenir, kart kimliği/yurt/sıra sayaçları korunur. Bluetooth kurulumu yeniden açılır. `ID` komutu kart kimliğini gösterir. NVS'yi tamamen silmeyin; silme cihaz kimliğini kaybettirir ve aynı donanımın yeniden kaydı sunucuda engellenir. Kurtarma bakım işlemi gerektirir.

## 3. Uygulamada yurda bağlama

1. Yurt yöneticisi olarak giriş yapın.
2. **QR Noktaları → Turnike kartı · 8 röle** bölümüne girin.
3. Kartın 32 karakterli kimliğini girip **Bu yurda bağla** seçin. Önce kart internete bağlanmış olmalıdır. Kimliği kontrol edin: atama kalıcıdır. Bu sürüm bir yurtta tek kart destekler.
4. Kart atamayı alır, yurt kimliğini NVS'ye yazar ve yeniden başlar. Sonraki açılışlarda Firebase'i taramaz; doğrudan kayıtlı yurdun kendi komut yoluna gider.
5. Giriş ve çıkış için ayrı QR noktaları oluşturun. Her kullanılan röleye bir QR seçin. Bir QR iki röleye bağlanamaz. Örneğin röle1 giriş, röle2 çıkış olabilir; kalan altısı boş kalabilir. İsterseniz sekizini de kullanabilirsiniz.
6. **Eşlemeyi kaydet** ve **Bağlantıyı kontrol et** seçenekleriyle kurulumu kontrol edin. Etkin anahtarı kapalıysa hareket kaydı devam eder fakat röle tetiklenmez.

## 4. QR okutulunca ne olur?

Öğrencinin hareket kaydı kurallara uygun oluşturulur. Sunucu etkin yurt/öğrenci/QR, QR yönü, kayıt yaşı, mevcut konum politikası ve kart bağlantısını denetler. Uygulama doğrudan RTDB röle komutu yazamaz. 2.2.3 kartında kayıtlı oturum kimliğine doğru röle komutu gönderilir. Periyodik bağlantı bildirimi aranmaz; yanıt gelmezse arayüzde süreli bekleme sonunda uyarı çıkar. Süresi dolmuş komut sonradan açma yapmaz.

Kart yeni komutun sıra numarasını kalıcı belleğe **açmadan önce** kaydeder. Komutun bu açılışa ait oturumunu ve 10 saniyelik süresini denetler. Eski, yinelenen veya yanlış oturumlu komut röleyi açmaz. Aynı rölede komutlar sıraya alınır; iki darbe arasında kısa LOW aralığı vardır. Sıra dolarsa veya süre geçerse açma yapılmaz. Firebase tekrar göndermeleri aynı hareketi yeniden etkinleştiremez.

Kart röleyi başlattığını bildirir; öğrenci ekranında **Röle tetiklendi** görünür. Bağlantı/yanıt yoksa en geç 12 saniyede görevliye başvurma mesajı gösterilir. Belirsiz bir sonuç için otomatik ikinci hareket veya açma komutu üretilmez. Kartın kapanması buluttaki `false` değerine bağlı değildir. İşlenen komutlar kaldırılır, eski komutlar da düzenli temizlenir.

**Fiziksel geçiş sınırı:** Röle yanıtı, kişinin gerçekten turnikeden geçtiğini kanıtlamaz. Hareket kaydı açma yanıtından önce oluşturulur; kart çevrimdışı olsa da kayıt mevcut olabilir. Geçilemeyen durumda görevli kontrol eder, gerektiğinde gerekçeli kayıt düzeltmesi yapar. Fiziksel doğrulama için turnike geçiş sensörü entegrasyonu ayrıca gerekir.

## 5. Firebase yapısı ve işletim

Ayrı Avrupa RTDB örneği: `ubsoft-pdks-turnstile`.

- `bindings/{deviceId}`: cihazın yalnız kendi okuyabildiği kalıcı yurt ataması.
- `registry/{deviceId}`: sunucunun yönettiği kimlik/yurt/etkinlik denetimi; istemci yazamaz.
- `turnstiles/{tenantId}/{deviceId}/control/commands/{eventId}`: sunucu komutları; kart yalnız kendi yolunu okur.
- Aynı kökte `status`: yalnız açılış/yeni oturumda bir bildirim ve yönetici istediğinde tek yanıt; `acks`: kartın QR komutuna eşleşen gerekli yanıtı. 2.2.3 kartında düzenli durum yazımı yoktur.
- Firestore `tenants/{tenantId}/turnstileConfig/controller`: yöneticiye açık, sunucudan yazılan eşleme.
- Firestore `turnstileState/controller`: öğrencinin sonuç ekranı için sınırlı durum/eşleme; gizli parola içermez.
- Global cihaz kayıtları yalnız sunucuya açıktır. Kullanıcının gerçek hareketine `turnstile.status` sunucu tarafından eklenir.

TLS ve cihaz Firebase Auth hesabı kullanılır. MAC adresi tek başına kimlik doğrulama değildir; rastgele gizli parola kullanılır. Açık cihaz kayıt uç noktası donanımın üretici onayını kanıtlamaz. Ürünleşmede üretimden gelen cihaz envanteri/aktivasyon anahtarı, kayıt hız sınırı ve fiziksel cihaz anahtarı koruması ayrıca değerlendirilmelidir. Standart NVS fiziksel flash erişimine karşı şifreli kasa değildir.

Blaze gerekir. Cloud Functions, RTDB, Firestore ve zamanlanmış temizleme tüketim bazlıdır. 2.2.3 kartında ne RTDB'ye ne Firestore'a periyodik durum yazılır. Kart yalnız kendi komut akışını dinler. Komutlar için kısa son kullanma süresi vardır; sürekli veri tabanı taraması yapılmaz. Bu sürüm bağımsız çevrimdışı geçiş sağlamaz. İnternet kesintisinde kurumun görevli/acil geçiş prosedürü uygulanır.

## 6. Sahada kabul kontrolü

Her kullanılan röle için doğru giriş/çıkış QR'ını deneyin. Diğer yedi röle kapalı kalmalı, ilgili röle yaklaşık 1 saniye sonra internet olmasa bile kapanmalıdır. Aynı komutun tekrar gönderilmesi, bağlantı kopup gelmesi ve kartın yeniden başlatılması eski bir açmayı tekrarlamamalıdır. Yanlış/kapalı QR, devre dışı kart, yetkisiz kullanıcı, bağlantı yokluğu ve boş röle eşlemesini deneyin. Bir röle açıkken Wi-Fi'yi kesin, beslemeyi ayrı test edin. GPIO12/15 boot seviyesi ile sekiz kanalın reset davranışını ölçün.

Derleme ve yazılım testleri gerçek kart, röle sürücüsü ve turnike kabul testinin yerine geçmez. Fiziksel kart bu çalışma ortamına bağlı olmadığından tezgâh testi yapılmış sayılmaz.

## Kart tanı sürümü 2.2.2

Yurt ataması ve bağlantı bildirimi doğrulanmasına rağmen komutun `queued` durumunda kalması için tanı çıktıları eklendi. Kesin fiziksel röle arızası veya komut reddinin nedeni henüz belirlenmiş değildir.

Normal Wi-Fi açılışında kullanılmayan Bluetooth controller/host belleği, TLS ve JSON işlemlerine ayrılmak üzere serbest bırakılır. Wi-Fi kurulum açılışında BLE kullanılmaya devam eder; `WIFI_RESET` yeniden başlattığı için sonraki kurulum korunur. [Espressif bellek API'si](https://docs.espressif.com/projects/esp-idf/en/stable/esp32/api-reference/bluetooth/controller_vhci.html#_CPPv418esp_bt_mem_release13esp_bt_mode_t).

Seri Monitör: 115200 baud ve New Line. `STATUS` gönderildiğinde Wi-Fi/Firebase durumu, UTC saati, boş RAM, son akış zamanı ve röle sıra sayaçları yazdırılır. Parola veya cihaz gizli anahtarı yazdırılmaz. Okutma sırasında `Akis`, `Komut alindi`, reddetme nedeni veya `ROLE TETIKLENDI` satırları görünür. `ROLE TETIKLENDI` yalnız GPIO yazma işlemini bildirir; röle kontağının fiziksel durumunu ölçmez.

Yüklemede **Huge APP** ve **Erase All Flash Before Sketch Upload: Disabled** seçilmelidir. NVS kimliği, yurt, Wi-Fi ve sıra sayaçlarının silinmesi gerekmez. Sadece bu sürümün derlenmesi, kart üzerinde röle sorununun çözüldüğü anlamına gelmez; yeni log ile saha doğrulaması gerekir.

## 2.2.3 — yalnız istendiğinde bağlantı kontrolü

Her 5 saniyelik `status` yazımı kaldırıldı. Kart açılışta/yeni oturumda bir kez kimlik/oturum kaydı yazar; sonrasında yalnız yöneticinin **Bağlantıyı kontrol et** isteğine karşılık durum yanıtı yazar. Yönetici isteği röle komutu değildir; hiçbir GPIO tetiklemez. Her kontrolün benzersiz istek kimliği ve kısa süresi vardır. Eski bir yanıt çevrimiçi kabul edilmez. En fazla 8 saniye yanıt beklenir, kontrol isteği temizlenir ve dinleyici kapatılır. Kullanıcı arayüzü son kontrol sonucunu gösterir; arka planda yenilemez.

QR anında komut ve gerekli açma yanıtı yazımları devam eder. Yerel `STATUS` seri komutu sadece cihaz bilgisini yazdırır, Firebase yazımı yapmaz. Periyodik yazımın gerçek kartta bitmesi için **2.2.3 kart yazılımı yüklenmelidir**. Sunucu eski kartlarla geçiş uyumluluğunu korur; eski kart yazılımı yüklenmiş kalırsa eski 5 saniyelik davranış devam eder. NVS yurt ve Wi-Fi bilgileri korunur. Rölenin önceki saha sorunu bu değişiklikle çözülmüş varsayılmaz.

## Kart 2.2.4 — komut çözümleme düzeltmesi

SSE `put /` içinde hareket kimliğine göre sarılan komutlar yanlış `is<JsonObject>()` kontrolü nedeniyle atlanıyordu. Salt okunur değerler `is<JsonObjectConst>()` ile kontrol edilerek komut işleyicisine aktarılır. [ArduinoJson tür kontrolü açıklaması](https://arduinojson.org/v7/api/jsonvariantconst/is/).

Yükleme sonrası açılışta **Surum=2.2.4** görünmelidir. Uygulamanın kabul ettiği yeni QR hareketinde `Komut alindi` ve ardından `ROLE TETIKLENDI` beklenir. Son gözlenen çıkış komutu röle6/GPIO12 içindi; uygulamadaki güncel eşleme hangi fiziksel çıkışın çalışacağını belirler. Yeni sürüm periyodik `status` yazmaz, aynı kimlik/yurt/Wi-Fi bilgilerini kullanır. Yükleme ayarları Huge APP ve tam flash silme Disabled olarak korunmalıdır.
