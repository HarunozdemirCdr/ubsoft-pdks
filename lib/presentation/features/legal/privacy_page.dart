import 'package:flutter/material.dart';
import 'package:ubsoft_pdks/core/config/company_info.dart';
import 'package:ubsoft_pdks/core/extensions/context_x.dart';
import 'package:ubsoft_pdks/core/theme/app_spacing.dart';
import 'package:ubsoft_pdks/core/theme/app_typography.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_card.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_scaffold.dart';
import 'package:ubsoft_pdks/presentation/widgets/section_header.dart';

// Madde metinleri liste dışında, tek tek sabit olarak durur: çok satırlı bir
// dizeyi doğrudan liste literaline yazmak, arada unutulmuş bir virgülü
// görünmez kılar ve iki madde sessizce birleşir.
const String _dataIdentity =
    'Kimlik: ad soyad, e-posta, telefon, öğrenci numarası, oda ve açıklama notu.';
const String _dataAttendance =
    'Devam kaydı: her giriş ve çıkış okutmasının tarihi, saati ve okutulan '
    'QR noktası.';
const String _dataLocation =
    'Konum: okutma yapıldığı an, cihazın bildirdiği koordinat ve ölçüm '
    'hassasiyeti.';
const String _dataSession = 'Oturum: son giriş zamanı.';
const String _dataLeave =
    'İzinler: izin aralığı, dönüş zamanı ve izin açıklaması; kayıt düzeltmelerinin gerekçesi ve işlemi yapan yönetici.';

const List<String> _collectedData = <String>[
  _dataIdentity,
  _dataAttendance,
  _dataLocation,
  _dataSession,
  _dataLeave,
];

const String _locationPurpose =
    'Amaç: okutmanın gerçekten yurtta yapıldığını doğrulamak — etiketin '
    'fotoğrafını çekip başka bir yerden okutmayı ayırt etmek.';
const String _locationMeasure =
    'Ölçüm, QR noktasının koordinatına olan uzaklık hesaplanarak '
    'değerlendirilir; ham koordinat kaydın içinde kalır.';
const String _locationConsent =
    'Konum izni verilmezse okutma yapılamayabilir (yurt ayarına bağlıdır); '
    'bu durumda yöneticinize başvurun.';

const List<String> _locationNotes = <String>[
  _locationPurpose,
  _locationMeasure,
  _locationConsent,
];

/// KVKK aydınlatma metni.
///
/// Bu ekran bir süs değildir: uygulama **konum verisi** işler ve 6698 sayılı
/// kanun bunu açıkça bildirmeyi zorunlu kılar. Metin oturumdan bağımsız
/// olarak her zaman açıktır — giriş yapamayan bir öğrenci de neyin
/// toplandığını okuyabilmelidir.
class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'KVKK Aydınlatma Metni',
      showBackButton: true,
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppSpacing.vSm,
          const SectionHeader(
            eyebrow: 'Kişisel verilerin korunması',
            title: 'Hangi veriler, neden işleniyor?',
            description:
                'Bu uygulama öğrenci devam kontrolü için gerekli en az '
                'veriyi toplar.',
          ),
          AppSpacing.vLg,

          const _Section(
            title: '1. Veri sorumlusu',
            body:
                'Uygulamayı işleten yurt yönetimi veri sorumlusudur. Yazılımı '
                'geliştiren ${CompanyInfo.legalName} yalnız teknik hizmet '
                'sağlar ve verilerinizi kendi amaçları için kullanmaz.',
          ),

          const _Section(title: '2. İşlenen veriler', bullets: _collectedData),

          const _Section(
            title: '3. Konum verisi hakkında',
            body:
                'Konum yalnız QR okutulduğu anda, bir kez ölçülür ve o '
                'okutma kaydının parçası olarak saklanır. Uygulama arka '
                'planda çalışmaz, öğrenciyi sürekli izlemez ve iki okutma '
                'arasında hiçbir konum bilgisi toplamaz.',
            bullets: _locationNotes,
          ),

          const _Section(
            title: '4. İşleme amacı',
            body:
                'Veriler; öğrencilerin yurda giriş ve çıkışlarının kaydı, '
                'yurtta bulunma durumunun ve izinli dönüşlerin takibi amacıyla '
                'kullanılır. Kurumun veri işleme esasları hakkında yurt '
                'yönetiminden bilgi alabilirsiniz.',
          ),

          const _Section(
            title: '5. Aktarım',
            body:
                'Veriler yalnız barındırma hizmeti için Google Firebase '
                'altyapısında saklanır. Üçüncü kişilere pazarlama ya da '
                'benzeri amaçlarla aktarılmaz.',
          ),

          const _Section(
            title: '6. Saklama süresi',
            body:
                'Öğrenci hesabı listeden kaldırıldığında geçmiş giriş–çıkış '
                'kayıtları otomatik silinmez. Saklama süreleri ve silme '
                'talepleri için yurt yönetimine başvurun.',
          ),

          const _Section(
            title: '7. Haklarınız',
            body:
                '6698 sayılı Kanun\'un 11. maddesi uyarınca; verilerinizin '
                'işlenip işlenmediğini öğrenme, düzeltilmesini veya '
                'silinmesini isteme ve işlemeye itiraz etme haklarına '
                'sahipsiniz. Başvurularınızı yurt yönetimine iletebilirsiniz.',
          ),

          AppSpacing.vLg,
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Yazılım sağlayıcı',
                  style: AppTypography.label(context.colors.onSurfaceVariant),
                ),
                AppSpacing.vXxs,
                Text(
                  CompanyInfo.legalName,
                  style: AppTypography.bodyStrong(context.colors.onSurface),
                ),
                AppSpacing.vXxs,
                Text(
                  '${CompanyInfo.phone} · ${CompanyInfo.email}',
                  style: AppTypography.small(context.colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          AppSpacing.vXl,
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    this.body,
    this.bullets = const <String>[],
  });

  final String title;
  final String? body;
  final List<String> bullets;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: AppTypography.h3(context.colors.onSurface)),
          if (body case final String value) ...<Widget>[
            AppSpacing.vXs,
            Text(
              value,
              style: AppTypography.body(context.colors.onSurfaceVariant),
            ),
          ],
          for (final String bullet in bullets) ...<Widget>[
            AppSpacing.vXs,
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '• ',
                  style: AppTypography.body(context.colors.onSurfaceVariant),
                ),
                Expanded(
                  child: Text(
                    bullet,
                    style: AppTypography.body(context.colors.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
