# Yurt Kontrol — satışa hazırlık değerlendirmesi

Bu belge kaynak kodu ve mevcut testlere dayanan bir ürün/mühendislik değerlendirmesidir. Bağımsız sızma testi, hukuki uygunluk onayı veya saha kabul tutanağı değildir.

## Karar

Arayüzü iyileştirilmiş, kontrollü bir yurt pilotuna uygun bir temel var. **Her ölçekte genel satışa hazır, eksiksiz ürün** iddiası için aşağıdaki yüksek öncelikli işler kapanmalı. Testlerin geçmesi bütün gerçek cihazların ve işletme senaryolarının doğrulandığı anlamına gelmez.

## Bu sürümde tamamlananlar

- Panelde dört eşit, ikonlu ve tıklanabilir kart: toplam öğrenci, içeride, dışarıda, dönüşü geciken.
- Dönüşü gecikenlerin dışarıdakilerin alt kümesi olduğu açıklanır. Başlangıç kaydı olmayan öğrenciler ayrı bilgilendirmede görünür; sıfırsa kart kaplamaz.
- Bulunma durumu ile inceleme filtresi ayrı seçimlerdir; arama ve sıfırlama tutarlıdır.
- Öğrenci araması Türkçe harfleri destekler; seçim penceresinde isim araması vardır.
- Rapor/geçmiş: öğrenci → gün → hareket açılımı. Her giriş yeşil, her çıkış kırmızı; gün özeti ilk giriş ve son çıkışı açıklar. Bir gündeki diğer hareketler açılımda korunur.
- Öğrenci ayrıntısı varsayılan olarak son 30 günü gösterir; tarih aralığı değiştirilebilir.
- İlk çizimde öğrenci kartları 30'ar gösterilir. Sadece açılan öğrencinin/günün hareket bileşenleri çizilir. Bu bir veritabanı sayfalama çözümü değildir.
- Panelin izin/uyarı eşleştirmeleri kullanıcıya göre indekslenir; aynı öğrencinin gecikme hesabı her sıralama karşılaştırmasında tekrarlanmaz.
- Yurt silme akışındaki eksik temizleme düzeltildi: yeni presence, presenceAudit, leaves ve leaveLocks alt koleksiyonları da kapsanır. Bu işlem testte sahte veritabanında doğrulanır; canlı yurt silinmez.

## Genel satış öncesi yüksek öncelik

| Alan | Mevcut sınır / somut risk | Tamamlanması gereken |
|---|---|---|
| Güvenilir iş kuralları | Hareket zamanı sunucudan gelir; geç/erken bilgisi ve konum değerlendirmesi istemcide hesaplanır. `firestore.rules` yön, üyelik, aktif QR ve durum eşleşmesini denetler; bütün uyarı alanlarını yeniden hesaplamaz. | Yetkili sunucu tarafında saat/izin/konum kuralı değerlendirmesi; manipülasyona karşı testler. GPS'in kendisinin de mutlak fiziksel geçiş kanıtı olmadığı ürün anlatımında açık kalmalı. |
| Eksik okutma operasyonu | Öğrenci çıkışı unuttuğunda kayıtlı durum gerçek durumdan ayrılabilir. Gerekçeli başlangıç belirleme ve yanlış hareketi geçersiz kılma var; bilinen bir durumu gerçek bir eksik geçiş için düzeltmenin iş akışı yetersiz. | Asıl hareketleri koruyan, gerekçeli yönetici durum doğrulaması; kim/ne zaman/neden kaydı ve yöneticiye görünür denetim geçmişi. |
| Rapor ölçeği | `DormRepository.watchEvents` seçili aralıktaki hareketlerin tümünü canlı dinler. Arayüzdeki 30'lu gösterim okunan belge sayısını azaltmaz. 1.000 öğrenci × günlük 4 hareket × 30 gün yaklaşık 120.000 hareket belgesidir. | Sunucudan sayfalama, rapor için tek seferlik okuma, günlük/aylık özetler; büyük PDF'ler için ayrı üretim süreci. Hedef yükle gecikme/bellek/okuma ölçümü. |
| Hesap oluşturma | Auth hesabı oluşturulduktan sonra Firestore profili yazılıyor; ikinci adım başarısızsa yarım hesap kalabilir. | Tekrar denenebilir sunucu işlemi, yarım işlemi tamamlama/geri alma ve yöneticiye açık hata/kurtarma adımı. |
| Plan limitleri | Kullanıcı/QR limitleri istemcide kontrol ediliyor; sayaçlar tek başına ticari limitin sunucuda uygulanması garantisi değil. | Limit ve sayaç tutarlılığının yetkili sunucuda doğrulanması; eşzamanlı oluşturma testleri. |
| Saha kabulü | Otomatik testler gerçek iPhone/Android kamera ve GPS izin davranışlarının tamamını sınamaz. Önceki canlı test betiğinin demo giriş bilgileri geçersizdi. | Yetkili test hesaplarıyla gerçek cihazlarda giriş, çıkış, izin, gece yarısı, zayıf ağ, çift cihaz, unutulan okutma ve uygulama güncellemesi kabul testi. |
| Üretim takibi ve geri dönüş | Hata çıktılarının çoğu debug modunda; yayın sorunlarını takip edecek merkezi hata/performans izleme yok. Alınan geçiş yedeği düzenli yedek/geri yükleme sürecinin yerine geçmez. | Üretim hata izleme, erişim kısıtlı günlükler, düzenli yedekler, denenmiş geri yükleme ve sürüm geri dönüş prosedürü. |

## Ürün kapsamı ve yönetim kararları

- Saatler kurum politikasıyla yazılı olarak eşleştirilmeli: hafta sonu, gece yarısı sonrası dönüş, izin bitişi, erken çıkış, tatil ve istisnai öğrenci durumları.
- İlk sürümde öğrenci başına tek aktif/gelecek izin vardır. Birden fazla gelecek izin ve öğrenci izin talebi/onay akışı kapsam kararıdır.
- Uyarılar açık panelde güncellenir. Uygulama kapalıyken görevliye bildirim/escalation süreci mevcut değildir; satışta varmış gibi anlatılmamalı.
- Yüksek öğrenci sayısında toplu öğrenci aktarımı ve dönem sonu devir/arşiv işlemi yönetim maliyetini azaltır; mevcut akış ağırlıklı olarak tekil kayıt üzerinedir.
- Yurtlar arası öğrenci taşıma, merkez yönetiminin birden fazla yurdu birlikte izlemesi, görevli vardiyaları ve ayrı belletmen/müdire yetkileri henüz ayrı ürün akışları değildir.
- Kurum; veri sorumlusu iletişimi, saklama/silme esasları, öğrenci bilgilendirmesi ve sözleşme kapsamını kendi süreçleriyle tamamlamalıdır. Mevcut bilgilendirme ekranı tek başına bütün bu süreçleri sağlamaz.

## Önerilen satış kapısı

1. Sunucu otoritesi, eksik okutma düzeltmesi ve hesap kurtarma akışlarını tamamla.
2. Gerçek kurum kuralları ve cihazlarla sınırlı pilot yap; günlük kayıtları görevli gözlemiyle karşılaştır.
3. Hedef kapasiteyi ölç ve rapor okumalarını sayfala; yedekten geri dönüşü dene.
4. Kritik açık senaryo kalmadığında destek, kurulum ve işletme sınırları açık bir ürün olarak satışa çık.

Bu aşamalar tamamlanmadan “mükemmel”, “hatasız” veya “her ölçekte hazır” ifadesi kullanmak doğru olmaz.
