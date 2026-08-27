import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ubsoft_pdks/application/attendance/attendance_providers.dart';
import 'package:ubsoft_pdks/core/routing/app_routes.dart';
import 'package:ubsoft_pdks/core/theme/app_spacing.dart';
import 'package:ubsoft_pdks/core/utils/date_x.dart';
import 'package:ubsoft_pdks/domain/entities/attendance_day.dart';
import 'package:ubsoft_pdks/presentation/features/today/widgets/attendance_day_tile.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_scaffold.dart';
import 'package:ubsoft_pdks/presentation/widgets/empty_state.dart';
import 'package:ubsoft_pdks/presentation/widgets/section_header.dart';
import 'package:ubsoft_pdks/presentation/widgets/stat_card.dart';
import 'package:ubsoft_pdks/presentation/widgets/status_chip.dart';

/// Yöneticinin günlük paneli — **yalnız bugün**.
///
/// Tek soruya cevap verir: şu anda kim içeride, kim gelmedi, hangi okutma
/// dikkat istiyor. Geçmiş buraya karışmaz; onun kendi ekranı var.
class TodayPage extends ConsumerWidget {
  const TodayPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String dateKey = AppDate.todayKey();
    final DayOverview overview = ref.watch(dayOverviewProvider(dateKey));
    final List<AttendanceDay> rows = ref.watch(dayRosterProvider(dateKey));

    return AppScaffold(
      title: 'Bugün',
      maxContentWidth: AppWidths.wide,
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppSpacing.vSm,
          SectionHeader(
            eyebrow: AppDate.dayName(DateTime.now()),
            title: AppDate.date(DateTime.now()),
            description:
                '${overview.total} kişilik kadro üzerinden hesaplanıyor.',
          ),
          AppSpacing.vLg,

          _StatGrid(overview: overview),

          AppSpacing.vXl,
          SectionHeader(
            title: 'Personel',
            dense: true,
            trailing: StatusChip(
              label: '${overview.inside} içeride',
              tone: StatusTone.info,
              compact: true,
            ),
          ),
          AppSpacing.vSm,

          if (rows.isEmpty)
            const EmptyState(
              icon: Icons.people_outline_rounded,
              title: 'Kadroda personel yok',
              description:
                  'Personel ekledikten sonra günlük devam tablosu burada '
                  'oluşur.',
              compact: true,
            )
          else
            for (final AttendanceDay day in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: AttendanceDayTile(
                  day: day,
                  onTap: () =>
                      context.go(AppRoutes.personHistoryPath(day.userId)),
                ),
              ),
          AppSpacing.vXl,
        ],
      ),
    );
  }
}

/// Dört sayı: içeride, tamamlandı, gelmedi, işaretli.
///
/// **Kişi denklemi:** her sayı bir personeli bir kez sayar; toplamları kadro
/// sayısını verir. Geç girişler ayrı bir kutu değildir — satırında rozetiyle
/// görünür, ekranda iki kez sayılmaz.
class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.overview});

  final DayOverview overview;

  @override
  Widget build(BuildContext context) {
    final List<Widget> cards = <Widget>[
      StatCard(
        label: 'İçeride',
        value: '${overview.inside}',
        icon: Icons.login_rounded,
      ),
      StatCard(
        label: 'Tamamlandı',
        value: '${overview.completed}',
        icon: Icons.check_circle_outline_rounded,
        tone: StatusTone.success,
      ),
      StatCard(
        label: 'Gelmedi',
        value: '${overview.absent}',
        icon: Icons.remove_circle_outline_rounded,
        tone: StatusTone.neutral,
      ),
      StatCard(
        label: 'Dikkat isteyen',
        value: '${overview.flagged}',
        icon: Icons.error_outline_rounded,
        tone: StatusTone.warning,
        caption: overview.late > 0 ? '${overview.late} geç giriş' : null,
      ),
    ];

    // Sabit en-boy oranlı bir ızgara (GridView childAspectRatio) bilinçli
    // olarak kullanılmıyor: kutunun yüksekliğini oran belirlediğinde, altına
    // bir açıklama satırı eklenmesi ya da yalnızca yazı tipinin değişmesi
    // içeriği birkaç piksel taşırıyor. Burada yüksekliği **içerik** belirler;
    // IntrinsicHeight aynı satırdaki kutuları en uzununa eşitler.
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = constraints.maxWidth >= 720 ? 4 : 2;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (int start = 0; start < cards.length; start += columns)
              Padding(
                padding: EdgeInsets.only(
                  bottom: start + columns < cards.length ? AppSpacing.sm : 0,
                ),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      for (int i = start; i < start + columns; i++) ...<Widget>[
                        if (i > start) AppSpacing.hSm,
                        Expanded(
                          child: i < cards.length
                              ? cards[i]
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
