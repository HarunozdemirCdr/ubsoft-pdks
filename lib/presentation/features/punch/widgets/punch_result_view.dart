import 'package:flutter/material.dart';
import 'package:ubsoft_pdks/application/attendance/punch_controller.dart';
import 'package:ubsoft_pdks/core/error/failure.dart';
import 'package:ubsoft_pdks/core/extensions/context_x.dart';
import 'package:ubsoft_pdks/core/theme/app_colors.dart';
import 'package:ubsoft_pdks/core/theme/app_radius.dart';
import 'package:ubsoft_pdks/core/theme/app_spacing.dart';
import 'package:ubsoft_pdks/core/theme/app_typography.dart';
import 'package:ubsoft_pdks/core/utils/geo.dart';
import 'package:ubsoft_pdks/domain/entities/attendance_event.dart';
import 'package:ubsoft_pdks/domain/enums/location_verdict.dart';
import 'package:ubsoft_pdks/presentation/formatters/enum_labels.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_button.dart';
import 'package:ubsoft_pdks/presentation/widgets/status_chip.dart';

/// Okutmanın sonucu — kameranın üstünde yükselen panel.
///
/// Başarıda saat ve nokta adı büyük yazılır: öğrenci telefonu cebine
/// koymadan önce kaydın gerçekten düştüğünü görmelidir.
class PunchResultView extends StatelessWidget {
  const PunchResultView({
    required this.state,
    required this.onAgain,
    required this.onClose,
    this.showLocation = true,
    super.key,
  });

  final PunchState state;

  /// Konum kararı ve noktaya uzaklık gösterilsin mi?
  ///
  /// Öğrencinin ekranında kapalıdır: kaydın düştüğünü görmesi yeter.
  /// **Reddedilen** okutmanın sebebi bundan bağımsızdır ve her zaman
  /// yazılır — aksi hâlde neden okutamadığını bilemezdi.
  final bool showLocation;

  /// Kameraya dön ve yeniden okut.
  final VoidCallback onAgain;

  /// Ekranı kapat.
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.surface,
      borderRadius: AppRadius.topXl,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: switch (state) {
            PunchSuccess(:final AttendanceEvent event) => _Success(
              event: event,
              showLocation: showLocation,
              onAgain: onAgain,
              onClose: onClose,
            ),
            PunchFailed(:final Failure failure) => _Failed(
              failure: failure,
              onAgain: onAgain,
              onClose: onClose,
            ),
            _ => const SizedBox.shrink(),
          },
        ),
      ),
    );
  }
}

class _Success extends StatelessWidget {
  const _Success({
    required this.event,
    required this.showLocation,
    required this.onAgain,
    required this.onClose,
  });

  final AttendanceEvent event;
  final bool showLocation;
  final VoidCallback onAgain;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Icon(
              Icons.check_circle_rounded,
              color: AppColors.success,
              size: 28,
            ),
            AppSpacing.hSm,
            Expanded(
              child: Text(
                event.type.isEntry ? 'Giriş yapıldı' : 'Çıkış yapıldı',
                style: AppTypography.h2(context.colors.onSurface),
              ),
            ),
            Text(
              event.timeLabel,
              style: AppTypography.metric(context.colors.onSurface),
            ),
          ],
        ),
        AppSpacing.vSm,
        Text(
          event.checkpointName,
          style: AppTypography.body(context.colors.onSurfaceVariant),
        ),
        AppSpacing.vMd,

        if (event.lateMinutes > 0 || event.earlyExit || event.earlyEntry)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (event.lateMinutes > 0)
                  StatusChip(
                    label: '${event.lateMinutes} dk geç giriş',
                    tone: StatusTone.warning,
                  ),
                if (event.earlyExit)
                  const StatusChip(
                    label: 'Erken çıkış',
                    tone: StatusTone.warning,
                  ),
                if (event.earlyEntry)
                  const StatusChip(
                    label: 'Erken giriş',
                    tone: StatusTone.warning,
                  ),
              ],
            ),
          ),

        if (showLocation) ...<Widget>[
          Row(
            children: <Widget>[
              StatusChip(
                label: event.verdict.label,
                tone: EnumLabels.toneOfVerdict(event.verdict),
                icon: EnumLabels.iconOfVerdict(event.verdict),
              ),
              if (event.distanceMeters case final double distance)
                if (event.verdict != LocationVerdict.unavailable) ...<Widget>[
                  AppSpacing.hXs,
                  Text(
                    'Noktaya ${Geo.formatDistance(distance)}',
                    style: AppTypography.small(context.colors.onSurfaceVariant),
                  ),
                ],
            ],
          ),
          if (event.verdict.needsAttention) ...<Widget>[
            AppSpacing.vXs,
            Text(
              _verdictNote(event.verdict),
              style: AppTypography.small(context.colors.onSurfaceVariant),
            ),
          ],
        ],

        AppSpacing.vLg,
        // Tek eylem: kapat.
        //
        // Burada bir "Yeniden okut" düğmesi vardı ve zararlıydı. Kayıt
        // düşmüşken okunacak bir şey kalmaz; düğme ise bir öneri gibi değil
        // **talimat** gibi okunuyordu ("yeniden okut"). Basan kişi kamerayı
        // hâlâ aynı etiketin önünde tutuyor oluyor, kod anında yeniden
        // gönderiliyor ve reddediliyordu — sonu gelmeyen bir döngü.
        AppButton.primaryWide(label: 'Tamam', onPressed: onClose),
      ],
    );
  }

  /// Kayıt tutuldu ama işaretlendi — öğrenci bunu bilmeli.
  ///
  /// Sessizce işaretlemek, sonradan yöneticiyle karşı karşıya gelindiğinde
  /// "bana kimse söylemedi" demeye yol açar.
  String _verdictNote(LocationVerdict verdict) => switch (verdict) {
    LocationVerdict.borderline =>
      'Kaydınız alındı ancak konumunuz noktanın sınırında ölçüldü. '
          'Yöneticiniz bu okutmayı işaretli görecek.',
    LocationVerdict.outside =>
      'Kaydınız alındı ancak konumunuz noktadan uzak ölçüldü. '
          'Yöneticiniz bu okutmayı işaretli görecek.',
    LocationVerdict.unavailable =>
      'Kaydınız konum bilgisi olmadan alındı. Konum iznini açarsanız '
          'okutmalarınız doğrulanmış olarak kaydedilir.',
    LocationVerdict.verified => '',
  };
}

class _Failed extends StatelessWidget {
  const _Failed({
    required this.failure,
    required this.onAgain,
    required this.onClose,
  });

  final Failure failure;
  final VoidCallback onAgain;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Icon(
              Icons.error_outline_rounded,
              color: AppColors.danger,
              size: 28,
            ),
            AppSpacing.hSm,
            Expanded(
              child: Text(
                'Okutma tamamlanmadı',
                style: AppTypography.h2(context.colors.onSurface),
              ),
            ),
          ],
        ),
        AppSpacing.vSm,
        Text(
          failure.message,
          style: AppTypography.body(context.colors.onSurfaceVariant),
        ),
        AppSpacing.vLg,
        AppButton.primaryWide(label: 'Tekrar dene', onPressed: onAgain),
        AppSpacing.vXs,
        AppButton(
          label: 'Vazgeç',
          variant: AppButtonVariant.text,
          expand: true,
          onPressed: onClose,
        ),
      ],
    );
  }
}
