import 'package:flutter/material.dart';
import 'package:ubsoft_pdks/core/extensions/context_x.dart';
import 'package:ubsoft_pdks/core/theme/app_colors.dart';
import 'package:ubsoft_pdks/core/theme/app_radius.dart';
import 'package:ubsoft_pdks/core/theme/app_spacing.dart';
import 'package:ubsoft_pdks/core/theme/app_typography.dart';
import 'package:ubsoft_pdks/domain/entities/attendance_day.dart';
import 'package:ubsoft_pdks/domain/enums/day_status.dart';
import 'package:ubsoft_pdks/presentation/features/history/widgets/day_punch_list.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_card.dart';
import 'package:ubsoft_pdks/presentation/widgets/punch_time.dart';
import 'package:ubsoft_pdks/presentation/widgets/status_chip.dart';

/// Bir günün kadro tablosu: solda personel, sağda giriş ve çıkış saatleri.
///
/// Kart yığını yerine tek bir tablo kullanılır. Otuz kişilik bir kadroda
/// otuz ayrı kart, aranan şeyi (bir saatin olup olmadığını) her satırda
/// farklı bir yere taşır; hizalı kolonlarda ise göz tek bir dikey çizgiyi
/// tarar ve boşluklar hemen görünür.
///
/// Soldaki ince şerit günün durumunu taşır: yeşil tamamlandı, mavi hâlâ
/// içeride, turuncu çıkışı eksik, gri gelmedi. Renk körlüğüne karşı aynı
/// bilgi satırın sağındaki rozetle de yazılır.
class DayRosterTable extends StatelessWidget {
  const DayRosterTable({
    required this.days,
    required this.dateKey,
    required this.expandedUserId,
    required this.onToggle,
    super.key,
  });

  final List<AttendanceDay> days;
  final String dateKey;

  /// Okutmaları açılmış personel; `null` ise hepsi kapalı.
  final String? expandedUserId;

  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const _TableHeader(),
          for (final AttendanceDay day in days) ...<Widget>[
            Divider(height: 1, color: context.colors.outline),
            _RosterRow(
              day: day,
              expanded: expandedUserId == day.userId,
              onTap: day.isEmpty ? null : () => onToggle(day.userId),
            ),
            // 160 ms: satırın açıldığı fark edilir ama gün gün gezinirken
            // beklenmez.
            AnimatedSize(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: expandedUserId == day.userId && !day.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.sm,
                        0,
                        AppSpacing.sm,
                        AppSpacing.sm,
                      ),
                      child: DayPunchList(
                        userId: day.userId,
                        dateKey: dateKey,
                        padding: EdgeInsets.zero,
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ],
      ),
    );
  }
}

/// Kolon başlıkları — hangi saatin giriş hangisinin çıkış olduğunu bir kez
/// yazar; satırlarda yalnız renk ve ikon kalır.
class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    final TextStyle style = AppTypography.eyebrow(
      context.colors.onSurfaceVariant,
    ).copyWith(fontSize: 10);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Row(
        children: <Widget>[
          Expanded(child: Text('PERSONEL', style: style)),
          SizedBox(
            width: _RosterRow.columnWidth,
            child: Text('GİRİŞ', style: style),
          ),
          SizedBox(
            width: _RosterRow.columnWidth,
            child: Text('ÇIKIŞ', style: style),
          ),
          const SizedBox(width: _RosterRow.trailingWidth),
        ],
      ),
    );
  }
}

class _RosterRow extends StatelessWidget {
  const _RosterRow({
    required this.day,
    required this.expanded,
    required this.onTap,
  });

  static const double columnWidth = 72;
  static const double trailingWidth = 20;

  final AttendanceDay day;
  final bool expanded;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final DayStatus status = day.statusAt(DateTime.now());
    final bool flagged = !day.isEmpty && day.worstVerdict.needsAttention;
    final bool dark = context.isDark;

    final Color railColor = switch (status) {
      DayStatus.present => context.colors.primary,
      DayStatus.completed => dark ? AppColors.entryOnDark : AppColors.entry,
      DayStatus.missingExit =>
        dark ? AppColors.warningOnDark : AppColors.warning,
      DayStatus.absent => context.colors.outline,
    };

    final Widget row = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 3,
            height: 26,
            decoration: BoxDecoration(
              color: railColor,
              borderRadius: AppRadius.allXs,
            ),
          ),
          AppSpacing.hSm,
          Expanded(
            child: Row(
              children: <Widget>[
                Flexible(
                  child: Text(
                    day.userName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyStrong(
                      status.isAbsent
                          ? context.colors.onSurfaceVariant
                          : context.colors.onSurface,
                    ),
                  ),
                ),
                if (day.late || flagged) ...<Widget>[
                  AppSpacing.hXs,
                  StatusChip(
                    label: day.late ? 'Geç' : 'Konum',
                    tone: day.late ? StatusTone.warning : StatusTone.danger,
                    compact: true,
                  ),
                ],
              ],
            ),
          ),
          SizedBox(
            width: columnWidth,
            child: PunchTime(at: day.firstEntryAt, isEntry: true, dense: true),
          ),
          SizedBox(
            width: columnWidth,
            child: PunchTime(at: day.lastExitAt, isEntry: false, dense: true),
          ),
          SizedBox(
            width: trailingWidth,
            child: onTap == null
                ? null
                : Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: context.colors.onSurfaceVariant,
                  ),
          ),
        ],
      ),
    );

    if (onTap == null) return row;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: AppColors.primary.withValues(alpha: 0.06),
        highlightColor: AppColors.primary.withValues(alpha: 0.04),
        child: row,
      ),
    );
  }
}
