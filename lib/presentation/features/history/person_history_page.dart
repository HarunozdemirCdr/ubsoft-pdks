import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubsoft_pdks/application/attendance/attendance_providers.dart';
import 'package:ubsoft_pdks/application/auth/session_provider.dart';
import 'package:ubsoft_pdks/application/user/user_providers.dart';
import 'package:ubsoft_pdks/core/extensions/context_x.dart';
import 'package:ubsoft_pdks/core/theme/app_spacing.dart';
import 'package:ubsoft_pdks/core/theme/app_typography.dart';
import 'package:ubsoft_pdks/core/utils/date_x.dart';
import 'package:ubsoft_pdks/domain/entities/app_user.dart';
import 'package:ubsoft_pdks/domain/entities/attendance_day.dart';
import 'package:ubsoft_pdks/domain/entities/report_filter.dart';
import 'package:ubsoft_pdks/presentation/features/history/widgets/day_punch_list.dart';
import 'package:ubsoft_pdks/presentation/features/today/widgets/attendance_day_tile.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_card.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_scaffold.dart';
import 'package:ubsoft_pdks/presentation/widgets/async_value_view.dart';
import 'package:ubsoft_pdks/presentation/widgets/empty_state.dart';
import 'package:ubsoft_pdks/presentation/widgets/section_header.dart';

/// Bir öğrencinin kendi geçmişi — gün gün, açılabilir satırlarla.
///
/// Yalnız **kendi** kayıtlarını görebilen öğrenci içindir; yönetici aynı
/// bilgiye Raporlar ekranından, tarih aralığı seçerek ve yazdırılabilir
/// hâliyle ulaşır.
///
/// Bir güne dokunulduğunda o günün okutmaları **yerinde** açılır; ayrı bir
/// sayfaya gitmek, "dün kaçta girdim, önceki gün kaçta" karşılaştırmasını
/// yapan kişiyi sürekli ileri geri gezdirirdi.
class PersonHistoryPage extends ConsumerStatefulWidget {
  const PersonHistoryPage({required this.userId, super.key});

  final String userId;

  @override
  ConsumerState<PersonHistoryPage> createState() => _PersonHistoryPageState();
}

class _PersonHistoryPageState extends ConsumerState<PersonHistoryPage> {
  ReportFilter _filter = ReportFilter.lastDays(14);
  String? _expandedDay;

  @override
  Widget build(BuildContext context) {
    final AppUser? user = ref.watch(userProvider(widget.userId));
    final AppUser? me = ref.watch(currentUserProvider);
    final bool isSelf = me?.uid == widget.userId;
    final String name = user?.displayName ?? me?.displayName ?? 'Öğrenci';

    return AppScaffold(
      title: isSelf ? 'Geçmişim' : name,
      showBackButton: !isSelf,
      maxContentWidth: AppWidths.wide,
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppSpacing.vSm,
          _RangeChips(
            selected: _filter,
            onChanged: (ReportFilter value) => setState(() => _filter = value),
          ),
          AppSpacing.vLg,

          AsyncValueView<List<AttendanceDay>>(
            value: ref.watch(
              personDaysProvider((userId: widget.userId, filter: _filter)),
            ),
            builder: (List<AttendanceDay> days) => _DayList(
              days: days,
              filter: _filter,
              userId: widget.userId,
              showFlags: ref.watch(attendanceDetailVisibleProvider),
              expandedDay: _expandedDay,
              onToggle: (String dateKey) => setState(
                () => _expandedDay = _expandedDay == dateKey ? null : dateKey,
              ),
            ),
          ),
          AppSpacing.vXl,
        ],
      ),
    );
  }
}

/// Hazır aralıklar. Serbest tarih seçimi rapor ekranındadır; burada hızlı
/// bakış yeterlidir.
class _RangeChips extends StatelessWidget {
  const _RangeChips({required this.selected, required this.onChanged});

  final ReportFilter selected;
  final ValueChanged<ReportFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final List<(String, ReportFilter)> options = <(String, ReportFilter)>[
      ('Son 7 gün', ReportFilter.lastDays(7)),
      ('Son 14 gün', ReportFilter.lastDays(14)),
      ('Son 30 gün', ReportFilter.lastDays(30)),
      ('Bu ay', ReportFilter.thisMonth()),
    ];

    return Wrap(
      spacing: AppSpacing.xs,
      children: <Widget>[
        for (final (String label, ReportFilter filter) in options)
          ChoiceChip(
            label: Text(label),
            selected:
                selected.fromKey == filter.fromKey &&
                selected.toKey == filter.toKey,
            onSelected: (_) => onChanged(filter),
          ),
      ],
    );
  }
}

/// Aralıktaki günler — kayıt olmayan günler de satırını korur.
class _DayList extends ConsumerWidget {
  const _DayList({
    required this.days,
    required this.filter,
    required this.userId,
    required this.showFlags,
    required this.expandedDay,
    required this.onToggle,
  });

  final List<AttendanceDay> days;
  final ReportFilter filter;
  final String userId;

  /// Geç giriş ve konum rozetleri — öğrencinin kendi geçmişinde kapalı.
  final bool showFlags;
  final String? expandedDay;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (days.isEmpty) {
      return const EmptyState(
        icon: Icons.event_busy_outlined,
        title: 'Bu aralıkta kayıt yok',
        description: 'Daha geniş bir aralık seçmeyi deneyin.',
        compact: true,
      );
    }

    final int workedMinutes = days.fold(
      0,
      (int sum, AttendanceDay day) => sum + day.workedMinutes,
    );
    final int presentDays = days
        .where((AttendanceDay day) => !day.isEmpty)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppCard(
          child: Row(
            children: <Widget>[
              Expanded(
                child: _Summary(label: 'Gelinen gün', value: '$presentDays'),
              ),
              Expanded(
                child: _Summary(
                  label: 'Toplam süre',
                  value: AppDate.durationHuman(
                    Duration(minutes: workedMinutes),
                  ),
                ),
              ),
              Expanded(
                child: _Summary(
                  label: 'Günlük ortalama',
                  value: presentDays == 0
                      ? '—'
                      : AppDate.durationHuman(
                          Duration(
                            minutes: (workedMinutes / presentDays).round(),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
        AppSpacing.vLg,
        SectionHeader(title: filter.label, dense: true),
        AppSpacing.vSm,

        for (final AttendanceDay day in days) ...<Widget>[
          AttendanceDayTile(
            day: day,
            showName: false,
            showDate: true,
            showFlags: showFlags,
            onTap: day.isEmpty ? null : () => onToggle(day.dateKey),
          ),
          // 180 ms: fark edilir ama beklenmez. Ağır geçişler bu ekranda
          // gün gün gezinmeyi yavaşlatırdı.
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: expandedDay == day.dateKey
                ? DayPunchList(userId: userId, dateKey: day.dateKey)
                : const SizedBox(width: double.infinity),
          ),
          AppSpacing.vXs,
        ],
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.label, required this.value});

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
