import 'package:flutter/material.dart';
import 'package:ubsoft_pdks/core/extensions/context_x.dart';
import 'package:ubsoft_pdks/core/theme/app_colors.dart';
import 'package:ubsoft_pdks/core/theme/app_radius.dart';
import 'package:ubsoft_pdks/core/theme/app_spacing.dart';
import 'package:ubsoft_pdks/core/theme/app_typography.dart';
import 'package:ubsoft_pdks/core/utils/date_x.dart';
import 'package:ubsoft_pdks/domain/entities/app_user.dart';
import 'package:ubsoft_pdks/domain/entities/attendance_event.dart';
import 'package:ubsoft_pdks/domain/entities/attention_resolution.dart';
import 'package:ubsoft_pdks/domain/entities/dormitory.dart';
import 'package:ubsoft_pdks/domain/usecases/dorm/dorm_duration.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_card.dart';
import 'package:ubsoft_pdks/presentation/widgets/punch_time.dart';
import 'package:ubsoft_pdks/presentation/widgets/status_chip.dart';

String dormSearchKey(String text) {
  const letters = {
    'ı': 'i',
    'İ': 'i',
    'ş': 's',
    'ğ': 'g',
    'ü': 'u',
    'ö': 'o',
    'ç': 'c',
  };
  var result = text.toLowerCase();
  letters.forEach((a, b) => result = result.replaceAll(a, b));
  return result.trim();
}

class DormMetric {
  const DormMetric(
    this.label,
    this.value,
    this.icon,
    this.color,
    this.caption,
    this.onTap, {
    this.selected = false,
  });
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final String caption;
  final VoidCallback onTap;
  final bool selected;
}

/// Boyutlar metin uzunluğuna göre değişmez; her satır eşit kolonlardan oluşur.
class DormMetricGrid extends StatelessWidget {
  const DormMetricGrid({
    required this.metrics,
    this.forceTwoColumns = false,
    super.key,
  });
  final List<DormMetric> metrics;
  final bool forceTwoColumns;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final columns = !forceTwoColumns && bounds.maxWidth >= 840
          ? (metrics.length == 6 ? 3 : 4)
          : 2;
      const gap = AppSpacing.sm;
      final width = (bounds.maxWidth - gap * (columns - 1)) / columns;
      final scale = MediaQuery.textScalerOf(context).scale(1);
      final height =
          (width < 155 ? 108.0 : 94.0) + (scale > 1 ? 82 * (scale - 1) : 0);
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final m in metrics)
            SizedBox(
              key: ValueKey('metric-${m.label}'),
              width: width,
              height: height,
              child: Semantics(
                button: true,
                selected: m.selected,
                onTap: m.onTap,
                excludeSemantics: true,
                label: '${m.label}, ${m.value}. ${m.caption}',
                child: AppCard(
                  onTap: m.onTap,
                  borderColor: m.selected ? m.color : null,
                  background: m.selected
                      ? m.color.withValues(alpha: 0.04)
                      : null,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm + 4,
                    vertical: AppSpacing.sm + 2,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: m.color.withValues(alpha: 0.09),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(m.icon, size: 17, color: m.color),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '${m.value}',
                                  style:
                                      AppTypography.h1(
                                        context.colors.onSurface,
                                      ).copyWith(
                                        fontSize: 21,
                                        height: 1.05,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                ),
                                const Spacer(),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  size: 16,
                                  color: context.colors.onSurfaceVariant
                                      .withValues(alpha: 0.55),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              m.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.bodyStrong(
                                context.colors.onSurface,
                              ).copyWith(fontSize: 12.5, height: 1.15),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              m.caption,
                              maxLines: width < 155 ? 2 : 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.caption(
                                context.colors.onSurfaceVariant,
                              ).copyWith(fontSize: 10.5, height: 1.15),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}

class DormOption<T> {
  const DormOption(this.value, this.label, this.icon);
  final T value;
  final String label;
  final IconData icon;
}

class DormSelect<T> extends StatelessWidget {
  const DormSelect({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    super.key,
  });
  final String label;
  final T value;
  final List<DormOption<T>> options;
  final ValueChanged<T> onChanged;
  @override
  Widget build(BuildContext context) => DropdownButtonFormField<T>(
    key: ValueKey('$label-$value'),
    initialValue: value,
    isExpanded: true,
    selectedItemBuilder: (context) => [
      for (final option in options)
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            option.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
    ],
    icon: const Icon(Icons.expand_more_rounded, size: 20),
    style: AppTypography.small(context.colors.onSurface),
    decoration: InputDecoration(
      labelText: label,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    ),
    items: [
      for (final o in options)
        DropdownMenuItem(
          value: o.value,
          child: Row(
            children: [
              Icon(o.icon, size: 17, color: context.colors.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  o.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
    ],
    onChanged: (v) {
      if (v != null) onChanged(v);
    },
  );
}

class DormFilterPanel extends StatelessWidget {
  const DormFilterPanel({required this.children, this.onReset, super.key});
  final List<Widget> children;
  final VoidCallback? onReset;
  @override
  Widget build(BuildContext context) => AppCard(
    background: context.colors.surfaceContainerLowest,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.tune_rounded, size: 18, color: context.colors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Görünümü düzenle',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.label(context.colors.onSurface),
              ),
            ),
            if (onReset != null) ...[
              const SizedBox(width: 8),
              TextButton(onPressed: onReset, child: const Text('Sıfırla')),
            ],
          ],
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    ),
  );
}

class DormEmpty extends StatelessWidget {
  const DormEmpty({
    required this.title,
    required this.message,
    this.onReset,
    super.key,
  });
  final String title;
  final String message;
  final VoidCallback? onReset;
  @override
  Widget build(BuildContext context) => AppCard(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 32,
            color: context.colors.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.bodyStrong(context.colors.onSurface),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTypography.small(context.colors.onSurfaceVariant),
          ),
          if (onReset != null)
            TextButton(
              onPressed: onReset,
              child: const Text('Filtreleri temizle'),
            ),
        ],
      ),
    ),
  );
}

/// Tüm yurt modüllerinin ortak derin lacivert üst kurumsal başlık bandı.
///
/// Yurt Durumu, Dikkat Edilmesi Gerekenler ve Duyurular ekranlarında birebir
/// aynı hiyerarşiyi, gölgeyi ve özet kutusunu üretir.
class DormPageBanner extends StatelessWidget {
  const DormPageBanner({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.statLabel,
    this.statValue,
    this.action,
    super.key,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final String? statLabel;
  final String? statValue;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: const BoxDecoration(
        color: AppColors.navy,
        borderRadius: AppRadius.allMd,
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 12,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: AppTypography.eyebrow(
                  AppColors.white.withValues(alpha: 0.72),
                ),
              ),
              const SizedBox(height: 4),
              Text(title, style: AppTypography.h2(AppColors.white)),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppTypography.small(
                  AppColors.white.withValues(alpha: 0.78),
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (statLabel != null && statValue != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.1),
                    borderRadius: AppRadius.allSm,
                    border: Border.all(
                      color: AppColors.white.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        statLabel!,
                        style: AppTypography.eyebrow(
                          AppColors.white.withValues(alpha: 0.72),
                        ).copyWith(fontSize: 10),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        statValue!,
                        style: AppTypography.bodyStrong(AppColors.white)
                            .copyWith(
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                      ),
                    ],
                  ),
                ),
              ?action,
            ],
          ),
        ],
      ),
    );
  }
}

/// Yurt Durumu kartlarındaki dairesel ikon rozeti — tüm liste kartlarında
/// ortak tasarım dili sağlar.
class DormCircleBadge extends StatelessWidget {
  const DormCircleBadge({
    required this.icon,
    required this.color,
    this.surface,
    this.tooltip,
    this.size = 36,
    this.borderAlpha = 0.25,
    super.key,
  });

  final IconData icon;
  final Color color;
  final Color? surface;
  final String? tooltip;
  final double size;
  final double borderAlpha;

  @override
  Widget build(BuildContext context) {
    final Widget badge = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: surface ?? color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: borderAlpha)),
      ),
      child: Icon(icon, size: 17, color: color),
    );
    if (tooltip == null || tooltip!.isEmpty) return badge;
    return Tooltip(message: tooltip!, child: badge);
  }
}

class _DirectionBadge extends StatelessWidget {
  const _DirectionBadge({
    required this.icon,
    required this.color,
    required this.surface,
    required this.tooltip,
    this.size = 36,
    this.borderAlpha = 0.25,
  });
  final IconData icon;
  final Color color;
  final Color surface;
  final String tooltip;
  final double size;
  final double borderAlpha;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: surface,
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: borderAlpha)),
      ),
      child: Icon(icon, size: 17, color: color),
    ),
  );
}

class DormStudentCard extends StatelessWidget {
  const DormStudentCard({
    required this.user,
    required this.presence,
    required this.overdue,
    required this.permitted,
    required this.now,
    required this.onTap,
    this.onInitialize,
    super.key,
  });
  final AppUser user;
  final Presence presence;
  final bool overdue;
  final bool permitted;
  final DateTime now;
  final VoidCallback onTap;
  final VoidCallback? onInitialize;
  @override
  Widget build(BuildContext context) {
    final inside = presence.inside == true;
    final hasState = presence.inside != null;
    final color = !hasState
        ? AppColors.neutral
        : inside
        ? AppColors.entry
        : AppColors.exit;
    final surface = !hasState
        ? AppColors.neutral.withValues(alpha: 0.1)
        : inside
        ? AppColors.entrySurface
        : AppColors.exitSurface;
    final Duration? elapsed = DormDurationCalculator.ongoingDuration(
      presence,
      now,
    );
    final String? durationText = elapsed == null
        ? null
        : inside
        ? '${DormDurationCalculator.formatDuration(elapsed)} içeride'
        : '${DormDurationCalculator.formatDuration(elapsed)} dışarıda';
    final meta = [
      if (user.room.isNotEmpty) 'Oda ${user.room}',
      if (user.studentNumber.isNotEmpty) 'No ${user.studentNumber}',
      ?durationText,
    ].join(' · ');
    final detail = presence.at == null
        ? [if (meta.isNotEmpty) meta, 'İlk okutma bekleniyor'].join(' · ')
        : meta.isNotEmpty
        ? meta
        : (presence.checkpoint.isNotEmpty
              ? presence.checkpoint
              : presence.label);
    final hasBadges =
        overdue || (permitted && !inside) || presence.warnings.isNotEmpty;
    return Semantics(
      label: '${user.displayName}, ${presence.label}',
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _DirectionBadge(
                  tooltip: presence.label,
                  icon: !hasState
                      ? Icons.help_outline_rounded
                      : inside
                      ? Icons.login_rounded
                      : Icons.logout_rounded,
                  color: color,
                  surface: surface,
                  borderAlpha: hasState ? 0.25 : 0.18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyStrong(
                          context.colors.onSurface,
                        ).copyWith(fontSize: 13.5),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        detail,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption(
                          context.colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (presence.at != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    AppDate.time(presence.at!),
                    style: AppTypography.bodyStrong(color).copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ],
            ),
            if (hasBadges) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (overdue)
                    const StatusChip(
                      label: 'Dönüşü gecikti',
                      icon: Icons.schedule_rounded,
                      tone: StatusTone.warning,
                      compact: true,
                    ),
                  if (permitted && !inside)
                    const StatusChip(
                      label: 'İzinli',
                      icon: Icons.event_available_outlined,
                      tone: StatusTone.info,
                      compact: true,
                    ),
                  for (final w in presence.warnings)
                    StatusChip(
                      label: w,
                      tone: StatusTone.warning,
                      compact: true,
                    ),
                ],
              ),
            ],
            if (onInitialize != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onInitialize,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                  ),
                  icon: const Icon(Icons.edit_location_alt_outlined, size: 16),
                  label: const Text(
                    'Başlangıç durumunu belirle',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Sol paneldeki Son Hareketler akışı için kompakt log kartı.
class DormRecentMovementCard extends StatelessWidget {
  const DormRecentMovementCard({
    required this.event,
    required this.onTap,
    super.key,
  });
  final AttendanceEvent event;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final isEntry = event.type.isEntry;
    final color = isEntry ? AppColors.entry : AppColors.exit;
    final surface = isEntry ? AppColors.entrySurface : AppColors.exitSurface;
    final hasAlert =
        event.lateMinutes > 0 ||
        event.earlyExit ||
        event.earlyEntry ||
        event.permitted ||
        event.verdict.needsAttention;
    return Semantics(
      label:
          '${event.userName}, ${event.type.label}, ${AppDate.dateTime(event.at)}',
      child: AppCard(
        key: ValueKey('recent-log-${event.id}'),
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _DirectionBadge(
                  tooltip: event.type.label,
                  icon: isEntry ? Icons.login_rounded : Icons.logout_rounded,
                  color: color,
                  surface: surface,
                  size: 34,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyStrong(
                          context.colors.onSurface,
                        ).copyWith(fontSize: 13.5),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${event.checkpointName} · ${AppDate.date(event.at)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption(
                          context.colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  AppDate.time(event.at),
                  style: AppTypography.bodyStrong(color).copyWith(
                    fontSize: 14,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: context.colors.onSurfaceVariant,
                ),
              ],
            ),
            if (hasAlert) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 5,
                runSpacing: 4,
                children: [
                  if (event.lateMinutes > 0)
                    StatusChip(
                      label: '${event.lateMinutes} dk geç giriş',
                      tone: StatusTone.warning,
                      compact: true,
                    ),
                  if (event.earlyExit)
                    const StatusChip(
                      label: 'Erken çıkış',
                      tone: StatusTone.warning,
                      compact: true,
                    ),
                  if (event.earlyEntry)
                    const StatusChip(
                      label: 'Erken giriş',
                      tone: StatusTone.warning,
                      compact: true,
                    ),
                  if (event.permitted)
                    const StatusChip(
                      label: 'İzinli',
                      tone: StatusTone.info,
                      compact: true,
                    ),
                  if (event.verdict.needsAttention)
                    StatusChip(
                      label: event.verdict.label,
                      tone: StatusTone.warning,
                      compact: true,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class DormMovementTile extends StatelessWidget {
  const DormMovementTile({
    required this.event,
    this.onVoid,
    this.showName = false,
    this.resolutionLogs = const <AttentionResolution>[],
    super.key,
  });
  final AttendanceEvent event;
  final VoidCallback? onVoid;
  final bool showName;
  final List<AttentionResolution> resolutionLogs;
  @override
  Widget build(BuildContext context) {
    final color = event.type.isEntry ? AppColors.entry : AppColors.exit;
    final surface = event.type.isEntry
        ? AppColors.entrySurface
        : AppColors.exitSurface;
    return Container(
      key: ValueKey('movement-${event.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadius.allMd,
        border: Border.all(color: context.colors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: surface,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  event.type.isEntry
                      ? Icons.login_rounded
                      : Icons.logout_rounded,
                  color: color,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.type.label,
                      style: AppTypography.label(color),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      event.checkpointName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption(
                        context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                AppDate.time(event.at),
                style: AppTypography.h2(color).copyWith(
                  fontSize: 18,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (onVoid != null)
                SizedBox(
                  width: 44,
                  height: 44,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    tooltip: 'Yanlış kaydı geçersiz kıl',
                    icon: Icon(
                      Icons.more_horiz_rounded,
                      size: 20,
                      color: context.colors.onSurfaceVariant,
                    ),
                    onPressed: onVoid,
                  ),
                ),
            ],
          ),
          if (showName)
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Text(
                event.userName,
                style: AppTypography.small(context.colors.onSurface),
              ),
            ),
          if (event.lateMinutes > 0 ||
              event.earlyExit ||
              event.earlyEntry ||
              event.permitted ||
              event.verdict.needsAttention)
            Padding(
              padding: const EdgeInsets.only(top: 9),
              child: Wrap(
                spacing: 5,
                runSpacing: 5,
                children: [
                  if (event.lateMinutes > 0)
                    StatusChip(
                      label: '${event.lateMinutes} dk geç giriş',
                      tone: StatusTone.warning,
                      compact: true,
                    ),
                  if (event.earlyExit)
                    const StatusChip(
                      label: 'Erken çıkış',
                      tone: StatusTone.warning,
                      compact: true,
                    ),
                  if (event.earlyEntry)
                    const StatusChip(
                      label: 'Erken giriş',
                      tone: StatusTone.warning,
                      compact: true,
                    ),
                  if (event.permitted)
                    const StatusChip(
                      label: 'İzinli',
                      tone: StatusTone.info,
                      compact: true,
                    ),
                  if (onVoid != null && event.verdict.needsAttention)
                    StatusChip(
                      label: event.verdict.label,
                      tone: StatusTone.warning,
                      compact: true,
                    ),
                ],
              ),
            ),
          if (resolutionLogs.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final log in resolutionLogs)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: context.isDark
                        ? AppColors.primarySurfaceDark
                        : AppColors.primarySurface,
                    borderRadius: AppRadius.allSm,
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.fact_check_outlined,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Uyarı çözüm notu · ${log.title}',
                              style: AppTypography.caption(
                                AppColors.primary,
                              ).copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              log.resolutionNote,
                              style: AppTypography.small(
                                context.colors.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${log.resolvedByName.isEmpty ? 'Yönetici' : log.resolvedByName} · ${AppDate.dateTime(log.resolvedAt)}',
                              style: AppTypography.caption(
                                context.colors.onSurfaceVariant,
                              ).copyWith(fontSize: 10.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class DormDaySummary extends StatelessWidget {
  const DormDaySummary({
    required this.events,
    required this.expanded,
    required this.onTap,
    this.hasResolutionNote = false,
    super.key,
  });
  final List<AttendanceEvent> events;
  final bool expanded;
  final VoidCallback onTap;
  final bool hasResolutionNote;
  @override
  Widget build(BuildContext context) {
    final sorted = [...events]..sort((a, b) => a.at.compareTo(b.at));
    final entries = sorted.where((e) => e.type.isEntry).toList();
    final exits = sorted.where((e) => e.type.isExit).toList();
    final alert = events.any(
      (e) => e.lateMinutes > 0 || e.earlyExit || e.earlyEntry,
    );
    return Semantics(
      button: true,
      expanded: expanded,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.allMd,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 15,
                    color: context.colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      AppDate.date(sorted.first.at),
                      style: AppTypography.bodyStrong(
                        context.colors.onSurface,
                      ).copyWith(fontSize: 13),
                    ),
                  ),
                  if (hasResolutionNote)
                    const Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: Tooltip(
                        message: 'Bu güne ait yönetici çözüm notu var',
                        child: Icon(
                          Icons.fact_check_outlined,
                          size: 16,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  if (alert)
                    const Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: Icon(
                        Icons.error_outline_rounded,
                        size: 16,
                        color: AppColors.warning,
                      ),
                    ),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: context.colors.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 14,
                      runSpacing: 6,
                      children: [
                        PunchTime(
                          at: entries.isEmpty ? null : entries.first.at,
                          isEntry: true,
                          dense: true,
                        ),
                        PunchTime(
                          at: exits.isEmpty ? null : exits.last.at,
                          isEntry: false,
                          dense: true,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${entries.length} giriş · ${exits.length} çıkış',
                    style: AppTypography.caption(
                      context.colors.onSurfaceVariant,
                    ).copyWith(fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Etiketi kutunun dışında tutar; kaydırma alanının üst sınırında kesilmez.
class DormActionField extends StatelessWidget {
  const DormActionField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    super.key,
  });
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '$label $value',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 12, bottom: 6),
          child: Text(
            label,
            style: AppTypography.caption(context.colors.onSurfaceVariant),
          ),
        ),
        InkWell(
          borderRadius: AppRadius.allMd,
          onTap: onTap,
          child: InputDecorator(
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 14,
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: context.colors.primary),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.small(context.colors.onSurface),
                  ),
                ),
                const Icon(Icons.expand_more_rounded, size: 20),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class DormStudentPicker extends StatelessWidget {
  const DormStudentPicker({
    required this.names,
    required this.value,
    required this.onChanged,
    super.key,
  });
  final Map<String, String> names;
  final String? value;
  final ValueChanged<String?> onChanged;
  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: AppRadius.allMd,
    onTap: () async {
      final result = await showDialog<String>(
        context: context,
        builder: (c) => _StudentDialog(names: names, value: value),
      );
      if (result != null) onChanged(result.isEmpty ? null : result);
    },
    child: InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Öğrenci',
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      child: Row(
        children: [
          Icon(
            Icons.person_outline_rounded,
            size: 18,
            color: context.colors.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value == null
                  ? 'Tüm öğrenciler'
                  : names[value] ?? 'Seçili öğrenci',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.small(context.colors.onSurface),
            ),
          ),
          const Icon(Icons.expand_more_rounded, size: 20),
        ],
      ),
    ),
  );
}

class _StudentDialog extends StatefulWidget {
  const _StudentDialog({required this.names, this.value});
  final Map<String, String> names;
  final String? value;
  @override
  State<_StudentDialog> createState() => _StudentDialogState();
}

class _StudentDialogState extends State<_StudentDialog> {
  String _search = '';
  @override
  Widget build(BuildContext context) {
    final items =
        widget.names.entries
            .where(
              (e) => dormSearchKey(e.value).contains(dormSearchKey(_search)),
            )
            .toList()
          ..sort((a, b) => a.value.compareTo(b.value));
    return AlertDialog(
      title: const Text('Öğrenci seçin'),
      content: SizedBox(
        width: 430,
        height: 400,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Ad soyad ara',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: items.length + 1,
                itemBuilder: (context, index) {
                  final id = index == 0 ? '' : items[index - 1].key;
                  final title = index == 0
                      ? 'Tüm öğrenciler'
                      : items[index - 1].value;
                  return ListTile(
                    title: Text(title),
                    selected: (widget.value ?? '') == id,
                    trailing: (widget.value ?? '') == id
                        ? const Icon(Icons.check_rounded)
                        : null,
                    onTap: () => Navigator.pop(context, id),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Vazgeç'),
        ),
      ],
    );
  }
}

class DormSegmentedOption<T> {
  const DormSegmentedOption(this.value, this.label, {this.icon, this.dotColor});

  final T value;
  final String label;
  final IconData? icon;
  final Color? dotColor;
}

/// Kurumsal segmente sekme / filtre çubuğu.
///
/// Öğeleri mevcut genişliğe eşit aralıklarla tam sığdırır; dar ekranda eşit
/// sütunlu ızgaraya bölünerek sağda boşluk veya düzensiz taşma bırakmaz.
class DormSegmentedBar<T> extends StatelessWidget {
  const DormSegmentedBar({
    required this.value,
    required this.options,
    required this.onChanged,
    super.key,
  });

  final T value;
  final List<DormSegmentedOption<T>> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final bool dark = context.isDark;
    final Color barBg = dark ? AppColors.surfaceAltDark : AppColors.gray50;
    final Color barBorder = dark ? AppColors.borderDark : AppColors.border;
    final Color activeBg = dark ? AppColors.surfaceDark : AppColors.white;
    final Color activeBorder = dark
        ? AppColors.borderStrongDark
        : AppColors.borderStrong;
    final Color activeFg = dark ? AppColors.primaryOnDark : AppColors.primary;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: barBg,
        borderRadius: AppRadius.allMd,
        border: Border.all(color: barBorder),
      ),
      child: LayoutBuilder(
        builder: (context, bounds) {
          const double gap = 4;
          final bool hasLongLabel = options.any((o) => o.label.length >= 15);
          final double minPerItem = hasLongLabel ? 156 : 94;
          final bool singleRow =
              bounds.maxWidth.isFinite &&
              bounds.maxWidth >=
                  options.length * minPerItem + gap * (options.length - 1);

          Widget buildTile(DormSegmentedOption<T> opt) => _SegmentedItem<T>(
            option: opt,
            selected: opt.value == value,
            activeBg: activeBg,
            activeBorder: activeBorder,
            activeFg: activeFg,
            inactiveFg: context.colors.onSurfaceVariant,
            onTap: () => onChanged(opt.value),
          );

          if (singleRow) {
            return Row(
              children: [
                for (int i = 0; i < options.length; i++) ...[
                  Expanded(child: buildTile(options[i])),
                  if (i < options.length - 1) const SizedBox(width: gap),
                ],
              ],
            );
          }

          final int cols = options.length == 4
              ? 2
              : (bounds.maxWidth >= 340 && !hasLongLabel ? 3 : 2);
          final double cellW =
              (bounds.maxWidth - gap * (cols - 1)).clamp(60, 2000) / cols;

          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final opt in options)
                SizedBox(width: cellW, child: buildTile(opt)),
            ],
          );
        },
      ),
    );
  }
}

class _SegmentedItem<T> extends StatelessWidget {
  const _SegmentedItem({
    required this.option,
    required this.selected,
    required this.activeBg,
    required this.activeBorder,
    required this.activeFg,
    required this.inactiveFg,
    required this.onTap,
  });

  final DormSegmentedOption<T> option;
  final bool selected;
  final Color activeBg;
  final Color activeBorder;
  final Color activeFg;
  final Color inactiveFg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: Material(
      color: selected ? activeBg : Colors.transparent,
      borderRadius: AppRadius.allSm,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.allSm,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: AppRadius.allSm,
            border: Border.all(
              color: selected ? activeBorder : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (option.dotColor != null) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: option.dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              if (option.icon != null) ...[
                Icon(
                  option.icon,
                  size: 15,
                  color: option.dotColor ?? (selected ? activeFg : inactiveFg),
                ),
                const SizedBox(width: 5),
              ],
              Flexible(
                child: Text(
                  option.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style:
                      (selected
                              ? AppTypography.label(activeFg)
                              : AppTypography.small(inactiveFg))
                          .copyWith(fontSize: 12.5),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
