import 'dart:async';

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
import 'package:ubsoft_pdks/domain/entities/attendance_event.dart';
import 'package:ubsoft_pdks/domain/permissions/app_permission.dart';
import 'package:ubsoft_pdks/presentation/features/punch/widgets/punch_event_tile.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_button.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_card.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_scaffold.dart';
import 'package:ubsoft_pdks/presentation/widgets/async_value_view.dart';
import 'package:ubsoft_pdks/presentation/widgets/empty_state.dart';
import 'package:ubsoft_pdks/presentation/widgets/section_header.dart';
import 'package:ubsoft_pdks/presentation/widgets/status_chip.dart';

/// Personelin ana ekranı.
///
/// Tek bir soruya cevap verir: **şimdi ne yapmalıyım?** Giriş yapılmamışsa
/// "Giriş için okut", yapılmışsa "Çıkış için okut" der. Bunun altında günün
/// okutmaları saat saat durur.
class PunchHomePage extends ConsumerWidget {
  const PunchHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppUser? user = ref.watch(currentUserProvider);
    final bool canPunch = ref.watch(canProvider(AppPermission.punchCreate));
    final bool showDetail = ref.watch(attendanceDetailVisibleProvider);

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
            description: 'Giriş ve çıkışta işyerindeki QR kodunu okutun.',
          ),
          AppSpacing.vLg,

          AsyncValueView<AttendanceDay>(
            value: ref.watch(myTodayProvider),
            builder: (AttendanceDay day) => _TodayCard(
              day: day,
              canPunch: canPunch,
              showDetail: showDetail,
              onScan: () => context.push(AppRoutes.scanPath),
            ),
          ),

          AppSpacing.vXl,
          const SectionHeader(title: 'Bugünkü okutmalarım', dense: true),
          AppSpacing.vSm,

          AsyncValueView<List<AttendanceEvent>>(
            value: ref.watch(myTodayEventsProvider),
            compact: true,
            builder: (List<AttendanceEvent> events) => events.isEmpty
                ? const EmptyState(
                    icon: Icons.qr_code_scanner_outlined,
                    title: 'Bugün henüz okutma yok',
                    description: 'Giriş kodunu okuttuğunuzda burada görünecek.',
                    compact: true,
                  )
                : Column(
                    children: <Widget>[
                      for (final AttendanceEvent event in events)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                          child: PunchEventTile(
                            event: event,
                            showLocation: showDetail,
                          ),
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

/// Günün durumunu ve tek büyük eylemi taşıyan kart.
class _TodayCard extends StatefulWidget {
  const _TodayCard({
    required this.day,
    required this.canPunch,
    required this.showDetail,
    required this.onScan,
  });

  final AttendanceDay day;
  final bool canPunch;

  /// Geç giriş işareti gösterilsin mi? Personelin kendi kartında kapalıdır.
  final bool showDetail;

  final VoidCallback onScan;

  @override
  State<_TodayCard> createState() => _TodayCardState();
}

class _TodayCardState extends State<_TodayCard> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant _TodayCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTicker();
  }

  /// Süre sayacı yalnız personel **içerideyken** çalışır.
  ///
  /// Sürekli dönen bir zamanlayıcı, gün kapandıktan sonra hiçbir şeyi
  /// değiştirmeden ekranı dakikada bir yeniden çizerdi.
  void _syncTicker() {
    if (widget.day.open && _ticker == null) {
      _ticker = Timer.periodic(
        const Duration(seconds: 30),
        (_) => setState(() {}),
      );
    } else if (!widget.day.open) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AttendanceDay day = widget.day;
    final bool inside = day.open;
    final Duration worked = Duration(
      minutes: day.workedMinutesAt(DateTime.now()),
    );

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
              if (widget.showDetail && day.late)
                const StatusChip(
                  label: 'Geç giriş',
                  tone: StatusTone.warning,
                  compact: true,
                ),
            ],
          ),
          AppSpacing.vMd,

          Row(
            children: <Widget>[
              Expanded(
                child: _Metric(label: 'Giriş', value: day.entryLabel),
              ),
              Expanded(
                child: _Metric(label: 'Çıkış', value: day.exitLabel),
              ),
              Expanded(
                child: _Metric(
                  label: inside ? 'Süre (devam ediyor)' : 'Toplam süre',
                  value: day.isEmpty ? '—' : AppDate.durationHuman(worked),
                ),
              ),
            ],
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

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          style: AppTypography.small(context.colors.onSurfaceVariant),
        ),
        AppSpacing.vXxs,
        Text(value, style: AppTypography.h3(context.colors.onSurface)),
      ],
    );
  }
}
