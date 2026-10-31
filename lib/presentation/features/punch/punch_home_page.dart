import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ubsoft_pdks/application/attendance/attendance_providers.dart';
import 'package:ubsoft_pdks/application/auth/session_provider.dart';
import 'package:ubsoft_pdks/core/extensions/context_x.dart';
import 'package:ubsoft_pdks/core/routing/app_routes.dart';
import 'package:ubsoft_pdks/core/theme/app_spacing.dart';
import 'package:ubsoft_pdks/core/theme/app_typography.dart';
import 'package:ubsoft_pdks/core/utils/date_x.dart';
import 'package:ubsoft_pdks/domain/entities/app_user.dart';
import 'package:ubsoft_pdks/domain/entities/attendance_day.dart';
import 'package:ubsoft_pdks/domain/permissions/app_permission.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_button.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_card.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_scaffold.dart';
import 'package:ubsoft_pdks/presentation/widgets/async_value_view.dart';
import 'package:ubsoft_pdks/presentation/widgets/section_header.dart';
import 'package:ubsoft_pdks/presentation/widgets/status_chip.dart';

/// Öğrencinin ana ekranı.
///
/// Tek bir soruya cevap verir: **şimdi ne yapmalıyım?** Giriş yapılmamışsa
/// "Giriş için okut", yapılmışsa "Çıkış için okut" der. Saat ayrıntıları
/// yalnız yurt yönetiminde görünür.
class PunchHomePage extends ConsumerWidget {
  const PunchHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppUser? user = ref.watch(currentUserProvider);
    final bool canPunch = ref.watch(canProvider(AppPermission.punchCreate));

    return AppScaffold(
      title: AppDate.date(DateTime.now()),
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppSpacing.vSm,
          SectionHeader(
            eyebrow: AppDate.dayName(DateTime.now()),
            title: 'Merhaba${user == null ? '' : ', ${user.displayName}'}',
            description: 'Giriş ve çıkışta yurttaki QR kodunu okutun.',
          ),
          AppSpacing.vLg,

          AsyncValueView<AttendanceDay>(
            value: ref.watch(myTodayProvider),
            builder: (AttendanceDay day) => _TodayCard(
              day: day,
              canPunch: canPunch,

              onScan: () => context.push(AppRoutes.scanPath),
            ),
          ),

          AppSpacing.vXl,
        ],
      ),
    );
  }
}

/// Günün durumunu ve tek büyük eylemi taşıyan kart.
class _TodayCard extends StatefulWidget {
  const _TodayCard({
    required this.day,
    required this.canPunch,

    required this.onScan,
  });

  final AttendanceDay day;
  final bool canPunch;

  final VoidCallback onScan;

  @override
  State<_TodayCard> createState() => _TodayCardState();
}

class _TodayCardState extends State<_TodayCard> {
  @override
  Widget build(BuildContext context) {
    final AttendanceDay day = widget.day;
    final bool inside = day.open;

    return AppCard(
      spacious: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              StatusChip(
                label: inside ? 'İçeridesiniz' : 'Dışarıdasınız',
                tone: inside ? StatusTone.success : StatusTone.neutral,
                icon: inside ? Icons.login_rounded : Icons.logout_rounded,
              ),
              const Spacer(),
            ],
          ),
          AppSpacing.vMd,

          Text(
            'Giriş ve çıkış saatlerinizi yalnız yurt yönetimi görüntüler.',
            style: AppTypography.small(context.colors.onSurfaceVariant),
          ),

          AppSpacing.vLg,
          AppButton.primaryWide(
            label: inside ? 'Çıkış için QR okut' : 'Giriş için QR okut',
            icon: Icons.qr_code_scanner_rounded,
            onPressed: widget.canPunch ? widget.onScan : null,
          ),
          if (!widget.canPunch) ...<Widget>[
            AppSpacing.vXs,
            Text(
              'QR okutma yetkiniz kapalı. Yöneticinizle görüşün.',
              textAlign: TextAlign.center,
              style: AppTypography.small(context.colors.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}
