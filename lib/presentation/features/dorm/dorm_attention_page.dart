import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ubsoft_pdks/application/dorm/dorm_providers.dart';
import 'package:ubsoft_pdks/core/extensions/context_x.dart';
import 'package:ubsoft_pdks/core/routing/app_routes.dart';
import 'package:ubsoft_pdks/core/theme/app_colors.dart';
import 'package:ubsoft_pdks/core/theme/app_radius.dart';
import 'package:ubsoft_pdks/core/theme/app_spacing.dart';
import 'package:ubsoft_pdks/core/theme/app_typography.dart';
import 'package:ubsoft_pdks/core/utils/date_x.dart';
import 'package:ubsoft_pdks/domain/usecases/dorm/dorm_attention.dart';
import 'package:ubsoft_pdks/domain/usecases/dorm/dorm_duration.dart';
import 'package:ubsoft_pdks/presentation/features/dorm/widgets/dorm_ui.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_button.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_card.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_scaffold.dart';
import 'package:ubsoft_pdks/presentation/widgets/section_header.dart';
import 'package:ubsoft_pdks/presentation/widgets/status_chip.dart';

/// Dikkat Edilmesi Gereken Durumlar modülü (`/uyarilar`).
///
/// İzni bitip hâlâ dönmeyen, izinsiz dönüş saatini geçiren, son okutmasında
/// saat/konum uyarısı bulunan veya başlangıç kaydı olmayan öğrencileri tek
/// merkezde listeler.
class DormAttentionPage extends ConsumerStatefulWidget {
  const DormAttentionPage({super.key});

  @override
  ConsumerState<DormAttentionPage> createState() => _DormAttentionPageState();
}

class _DormAttentionPageState extends ConsumerState<DormAttentionPage> {
  final TextEditingController _search = TextEditingController();
  String _filter = 'all';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<DormAttentionItem> all = ref.watch(dormAttentionItemsProvider);
    final int leaveExpiredCount = all
        .where((i) => i.kind == DormAttentionKind.leaveExpiredStillOutside)
        .length;
    final int curfewCount = all
        .where((i) => i.kind == DormAttentionKind.curfewOverdue)
        .length;
    final int warningCount = all
        .where((i) => i.kind == DormAttentionKind.scanWarning)
        .length;
    final int uninitCount = all
        .where((i) => i.kind == DormAttentionKind.uninitialized)
        .length;

    final String q = dormSearchKey(_search.text);
    final List<DormAttentionItem> filtered = all.where((item) {
      final bool kindMatch = switch (_filter) {
        'leaveExpired' =>
          item.kind == DormAttentionKind.leaveExpiredStillOutside,
        'curfew' => item.kind == DormAttentionKind.curfewOverdue,
        'warning' => item.kind == DormAttentionKind.scanWarning,
        'uninit' => item.kind == DormAttentionKind.uninitialized,
        _ => true,
      };
      if (!kindMatch) return false;
      if (q.isEmpty) return true;
      final String hay = [
        item.user.displayName,
        item.user.room,
        item.user.studentNumber,
        item.title,
        item.relatedLeave?.contactName ?? '',
        item.relatedLeave?.destination ?? '',
      ].join(' ');
      return dormSearchKey(hay).contains(q);
    }).toList();

    return AppScaffold(
      title: 'Dikkat Edilmesi Gerekenler',
      maxContentWidth: AppWidths.page,
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(
            eyebrow: 'TAKİP VE MÜDAHALE MERKEZİ',
            title: 'Dikkat Edilmesi Gereken Durumlar',
            description:
                'İzin süresi dolduğu hâlde dönmeyenler, dönüş saatini aşanlar ve uyarı üreten son hareketler otomatik olarak burada toplanır.',
          ),
          const SizedBox(height: 16),
          DormMetricGrid(
            metrics: [
              DormMetric(
                'Toplam takip',
                all.length,
                Icons.notifications_active_outlined,
                AppColors.primary,
                'Kontrol bekleyen durum',
                () => setState(() => _filter = 'all'),
                selected: _filter == 'all',
              ),
              DormMetric(
                'İzni bitti · Dönmedi',
                leaveExpiredCount,
                Icons.event_busy_outlined,
                AppColors.exit,
                'Kritik izin aşımı',
                () => setState(
                  () => _filter = _filter == 'leaveExpired'
                      ? 'all'
                      : 'leaveExpired',
                ),
                selected: _filter == 'leaveExpired',
              ),
              DormMetric(
                'Dönüşü geciken',
                curfewCount,
                Icons.schedule_rounded,
                AppColors.warning,
                'İzinsiz saat aşımı',
                () => setState(
                  () => _filter = _filter == 'curfew' ? 'all' : 'curfew',
                ),
                selected: _filter == 'curfew',
              ),
              DormMetric(
                'Uyarı / Kayıtsız',
                warningCount + uninitCount,
                Icons.info_outline_rounded,
                AppColors.neutral,
                '$warningCount uyarı · $uninitCount kayıtsız',
                () => setState(
                  () => _filter = _filter == 'warning' ? 'all' : 'warning',
                ),
                selected: _filter == 'warning' || _filter == 'uninit',
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Öğrenci adı, oda no, öğrenci no veya iletişim ara...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Temizle',
                      onPressed: () {
                        _search.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          DormSegmentedBar<String>(
            value: _filter,
            options: const [
              DormSegmentedOption('all', 'Tümü'),
              DormSegmentedOption(
                'leaveExpired',
                'İzni Biten',
                dotColor: AppColors.exit,
              ),
              DormSegmentedOption(
                'curfew',
                'Dönüşü Geciken',
                dotColor: AppColors.warning,
              ),
              DormSegmentedOption(
                'warning',
                'Saat / Konum',
                dotColor: AppColors.primary,
              ),
              DormSegmentedOption(
                'uninit',
                'Kayıtsız',
                dotColor: AppColors.neutral,
              ),
            ],
            onChanged: (v) => setState(() => _filter = v),
          ),
          const SizedBox(height: 16),
          if (filtered.isEmpty)
            DormEmpty(
              title: all.isEmpty
                  ? 'Dikkat gerektiren durum yok'
                  : 'Bu filtreye uygun kayıt bulunamadı',
              message: all.isEmpty
                  ? 'Tüm öğrenciler beklenen saatler ve izin sınırları içinde.'
                  : 'Arama metnini veya filtreyi değiştirin.',
              onReset: (_search.text.isNotEmpty || _filter != 'all')
                  ? () {
                      _search.clear();
                      setState(() => _filter = 'all');
                    }
                  : null,
            )
          else
            for (final item in filtered)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _AttentionCard(item: item),
              ),
        ],
      ),
    );
  }
}

class _AttentionCard extends StatelessWidget {
  const _AttentionCard({required this.item});

  final DormAttentionItem item;

  @override
  Widget build(BuildContext context) {
    final Color stripeColor = switch (item.kind) {
      DormAttentionKind.leaveExpiredStillOutside => AppColors.exit,
      DormAttentionKind.curfewOverdue => AppColors.warning,
      DormAttentionKind.scanWarning => AppColors.primary,
      DormAttentionKind.uninitialized => AppColors.neutral,
    };
    final StatusTone tone = switch (item.kind) {
      DormAttentionKind.leaveExpiredStillOutside => StatusTone.danger,
      DormAttentionKind.curfewOverdue => StatusTone.warning,
      DormAttentionKind.scanWarning => StatusTone.info,
      DormAttentionKind.uninitialized => StatusTone.neutral,
    };
    final leave = item.relatedLeave;
    final String contactLine = leave == null
        ? ''
        : [
            if (leave.contactName.isNotEmpty) leave.contactName,
            if (leave.contactRelation.isNotEmpty) '(${leave.contactRelation})',
            if (leave.contactPhone.isNotEmpty) leave.contactPhone,
          ].join(' ');

    return AppCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: AppRadius.allMd,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 5, color: stripeColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: stripeColor.withValues(alpha: 0.1),
                              borderRadius: AppRadius.allSm,
                            ),
                            child: Icon(
                              Icons.person_outline_rounded,
                              size: 22,
                              color: stripeColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.user.displayName,
                                  style: AppTypography.bodyStrong(
                                    context.colors.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  [
                                    if (item.user.room.isNotEmpty)
                                      'Oda ${item.user.room}',
                                    if (item.user.studentNumber.isNotEmpty)
                                      'No ${item.user.studentNumber}',
                                    if ((item.user.phone ?? '').isNotEmpty)
                                      item.user.phone!,
                                  ].join(' · '),
                                  style: AppTypography.caption(
                                    context.colors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          StatusChip(
                            label: item.title,
                            tone: tone,
                            compact: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: context.isDark
                              ? AppColors.surfaceAltDark
                              : AppColors.surfaceAlt,
                          borderRadius: AppRadius.allSm,
                          border: Border.all(color: context.colors.outline),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (item.kind ==
                                    DormAttentionKind
                                        .leaveExpiredStillOutside &&
                                item.expectedReturnAt != null) ...[
                              Text(
                                'İzin bitişi: ${AppDate.dateTime(item.expectedReturnAt!)}'
                                '${item.overdueBy == null ? '' : ' · ${DormDurationCalculator.formatDuration(item.overdueBy!)} gecikti'}',
                                style: AppTypography.bodyStrong(
                                  AppColors.exit,
                                ).copyWith(fontSize: 13),
                              ),
                              if (item.presence.at != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 3),
                                  child: Text(
                                    'Son çıkış: ${AppDate.dateTime(item.presence.at!)}'
                                    '${item.outsideFor == null ? '' : ' (${DormDurationCalculator.formatDuration(item.outsideFor!)} süredir dışarıda)'}',
                                    style: AppTypography.caption(
                                      context.colors.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              if (contactLine.isNotEmpty ||
                                  (leave?.destination ?? '').isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Wrap(
                                    spacing: 14,
                                    runSpacing: 4,
                                    children: [
                                      if ((leave?.destination ?? '').isNotEmpty)
                                        Text(
                                          'Gittiği yer: ${leave!.destination}',
                                          style: AppTypography.caption(
                                            context.colors.onSurface,
                                          ),
                                        ),
                                      if (contactLine.isNotEmpty)
                                        Text(
                                          'Yakın iletişim: $contactLine',
                                          style: AppTypography.caption(
                                            context.colors.onSurface,
                                          ).copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                            ] else if (item.kind ==
                                    DormAttentionKind.curfewOverdue &&
                                item.expectedReturnAt != null) ...[
                              Text(
                                'Beklenen dönüş: ${AppDate.dateTime(item.expectedReturnAt!)}'
                                '${item.overdueBy == null ? '' : ' · ${DormDurationCalculator.formatDuration(item.overdueBy!)} gecikti'}',
                                style: AppTypography.bodyStrong(
                                  AppColors.warning,
                                ).copyWith(fontSize: 13),
                              ),
                              if (item.presence.at != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 3),
                                  child: Text(
                                    'Son çıkış: ${AppDate.dateTime(item.presence.at!)}'
                                    '${item.outsideFor == null ? '' : ' (${DormDurationCalculator.formatDuration(item.outsideFor!)} süredir dışarıda)'}',
                                    style: AppTypography.caption(
                                      context.colors.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                            ] else ...[
                              Text(
                                item.summary,
                                style: AppTypography.small(
                                  context.colors.onSurface,
                                ),
                              ),
                              if (item.presence.at != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 3),
                                  child: Text(
                                    'Son okutma: ${AppDate.dateTime(item.presence.at!)}',
                                    style: AppTypography.caption(
                                      context.colors.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.end,
                        children: [
                          AppButton(
                            label: 'Öğrenci Detayı',
                            icon: Icons.badge_outlined,
                            variant: AppButtonVariant.outline,
                            size: AppButtonSize.small,
                            onPressed: () => context.push(
                              AppRoutes.userEditPath(item.user.uid),
                            ),
                          ),
                          AppButton(
                            label: 'Geçmişi Aç',
                            icon: Icons.history_rounded,
                            size: AppButtonSize.small,
                            onPressed: () => context.push(
                              AppRoutes.personHistoryPath(item.user.uid),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
