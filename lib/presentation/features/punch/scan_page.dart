import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:ubsoft_pdks/application/attendance/attendance_providers.dart';
import 'package:ubsoft_pdks/application/attendance/punch_controller.dart';
import 'package:ubsoft_pdks/core/config/app_config.dart';
import 'package:ubsoft_pdks/core/theme/app_colors.dart';
import 'package:ubsoft_pdks/core/theme/app_radius.dart';
import 'package:ubsoft_pdks/core/theme/app_spacing.dart';
import 'package:ubsoft_pdks/core/theme/app_typography.dart';
import 'package:ubsoft_pdks/presentation/features/punch/widgets/punch_result_view.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_button.dart';
import 'package:ubsoft_pdks/services/location/location_service.dart';
import 'package:ubsoft_pdks/services/qr/qr_scanner_service.dart';

/// QR okutma ekranı.
///
/// Tam ekran kamera; üstte ne yapılacağını söyleyen tek satır, ortada
/// hizalama çerçevesi. Sonuç geldiğinde kamera durur ve yerini sonuç
/// görünümüne bırakır — kullanıcı "okudu mu, okumadı mı" diye beklemez.
///
/// **Elle kod girişi yoktur.** Öğrencinin yurtta olduğu yalnız QR ile
/// kanıtlanır; klavyeden girilebilen bir kod, konum doğrulamasıyla birlikte
/// tüm denetimi anlamsız kılardı.
class ScanPage extends ConsumerStatefulWidget {
  const ScanPage({super.key});

  @override
  ConsumerState<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends ConsumerState<ScanPage> {
  /// Bu ekranda en son gönderilen kod ve gönderilme anı.
  ///
  /// Kamera saniyede birkaç kare üretir ve etiket önündeyken **aynı kodu**
  /// durmadan bildirir. Sonuç paneli kapandığı anda (ya da "Tekrar dene"ye
  /// basıldığında) telefon hâlâ etikete bakıyor olduğu için kod anında
  /// yeniden gönderiliyor, aynı cevabı alıyor ve kullanıcı çıkamadığı bir
  /// döngüye giriyordu. Aynı kodun yeniden işlenmesi için kısa bir süre
  /// geçmesi ya da başka bir koda bakılması gerekir.
  String? _lastCode;
  DateTime? _lastCodeAt;

  /// Bu kod şu an yok sayılmalı mı?
  bool _isRepeat(String code) {
    if (_lastCode != code) return false;
    final DateTime? at = _lastCodeAt;
    if (at == null) return false;
    return DateTime.now().difference(at) < AppConfig.scanDebounce;
  }

  void _remember(String code) {
    _lastCode = code;
    _lastCodeAt = DateTime.now();
  }

  void _retryScan() {
    _lastCode = null;
    _lastCodeAt = null;
    ref.read(punchControllerProvider.notifier).reset();
  }

  @override
  void initState() {
    super.initState();

    // Konum izni kamera açılır açılmaz istenir. Sonraya bırakılsaydı
    // kullanıcı QR'ı okuttuktan sonra ikinci bir istemle karşılaşır ve
    // okutma yarıda kalırdı.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(locationServiceProvider).ensurePermission();
      ref.read(punchControllerProvider.notifier).reset();
    });
  }

  void _onDetect(BarcodeCapture capture) {
    final PunchState state = ref.read(punchControllerProvider);
    if (state.isBusy || state.isResolved) return;

    final String? code = QrCodeReader.extract(capture);
    if (code != null && _isRepeat(code)) return;
    if (code != null) _remember(code);
    if (code == null) {
      // Okundu ama bizim biçimimizde değil: kullanıcıya "kamera çalışmıyor"
      // dedirtmemek için ham içerik de kural motoruna gönderilir, hata
      // mesajını orası verir.
      final String? raw = QrCodeReader.rawOf(capture);
      if (raw == null) return;
      ref.read(punchControllerProvider.notifier).submit(raw);
      return;
    }

    ref.read(punchControllerProvider.notifier).submit(code);
  }

  @override
  Widget build(BuildContext context) {
    final PunchState state = ref.watch(punchControllerProvider);
    final MobileScannerController controller = ref.watch(qrControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.gray950,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.white,
        title: const Text('QR Okut'),
        titleTextStyle: AppTypography.h2(AppColors.white),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          MobileScanner(
            controller: controller,
            onDetect: _onDetect,
            errorBuilder:
                (BuildContext context, MobileScannerException error) =>
                    _CameraError(error: error),
          ),

          // Hizalama çerçevesi — kullanıcı QR'ı nereye tutacağını bilsin.
          const IgnorePointer(child: _ScanFrame()),

          if (state.isBusy) const _BusyOverlay(),

          if (state.isResolved)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: PunchResultView(
                state: state,
                autoRetryAfter: const Duration(seconds: 5),
                showLocation: ref.watch(attendanceDetailVisibleProvider),
                onAgain: _retryScan,
                onClose: () => context.pop(),
              ),
            ),
        ],
      ),
    );
  }
}

/// Kameranın ortasındaki hizalama çerçevesi.
class _ScanFrame extends StatelessWidget {
  const _ScanFrame();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              borderRadius: AppRadius.allXl,
              border: Border.all(color: AppColors.white, width: 3),
            ),
          ),
          AppSpacing.vLg,
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            decoration: const BoxDecoration(
              color: AppColors.scrim,
              borderRadius: BorderRadius.all(Radius.circular(AppRadius.full)),
            ),
            child: Text(
              'QR kodu çerçevenin içine getirin',
              style: AppTypography.small(AppColors.white),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kayıt yazılırken kamerayı kapatan katman.
class _BusyOverlay extends ConsumerWidget {
  const _BusyOverlay();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PunchState state = ref.watch(punchControllerProvider);
    final String message = state is PunchWorking ? state.message : 'İşleniyor…';

    return ColoredBox(
      color: AppColors.scrim,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const CircularProgressIndicator(color: AppColors.white),
            AppSpacing.vMd,
            Text(message, style: AppTypography.bodyStrong(AppColors.white)),
          ],
        ),
      ),
    );
  }
}

/// Kamera açılamadığında gösterilen açıklama.
///
/// Tarayıcıda kamera erişimi HTTPS ve kullanıcı izni ister; en sık görülen
/// hata budur ve kullanıcıya ne yapacağı söylenir.
class _CameraError extends StatelessWidget {
  const _CameraError({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.gray950,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.videocam_off_outlined,
                size: 48,
                color: AppColors.gray400,
              ),
              AppSpacing.vMd,
              Text(
                'Kamera açılamadı',
                style: AppTypography.h3(AppColors.white),
              ),
              AppSpacing.vXs,
              Text(
                'Tarayıcınızın bu siteye kamera izni verdiğinden emin olun. '
                'İzni reddettiyseniz adres çubuğundaki kilit simgesinden '
                'yeniden verebilirsiniz.',
                textAlign: TextAlign.center,
                style: AppTypography.small(AppColors.gray400),
              ),
              AppSpacing.vLg,
              AppButton(
                label: 'Geri dön',
                variant: AppButtonVariant.outline,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
