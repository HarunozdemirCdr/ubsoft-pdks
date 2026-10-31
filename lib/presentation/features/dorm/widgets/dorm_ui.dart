import 'package:flutter/material.dart';
import 'package:ubsoft_pdks/core/extensions/context_x.dart';
import 'package:ubsoft_pdks/core/theme/app_colors.dart';
import 'package:ubsoft_pdks/core/theme/app_radius.dart';
import 'package:ubsoft_pdks/core/theme/app_spacing.dart';
import 'package:ubsoft_pdks/core/theme/app_typography.dart';
import 'package:ubsoft_pdks/core/utils/date_x.dart';
import 'package:ubsoft_pdks/domain/entities/app_user.dart';
import 'package:ubsoft_pdks/domain/entities/attendance_event.dart';
import 'package:ubsoft_pdks/domain/entities/dormitory.dart';
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
    this.onTap,
  );
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final String caption;
  final VoidCallback onTap;
}

/// Boyutlar metin uzunluğuna göre değişmez; her satır eşit kolonlardan oluşur.
class DormMetricGrid extends StatelessWidget {
  const DormMetricGrid({required this.metrics, super.key});
  final List<DormMetric> metrics;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final columns = bounds.maxWidth >= 840 ? 4 : 2;
      const gap = AppSpacing.sm;
      final width = (bounds.maxWidth - gap * (columns - 1)) / columns;
      final scale = MediaQuery.textScalerOf(context).scale(1);
      final height =
          (width < 155 ? 164.0 : 150.0) + (scale > 1 ? 100 * (scale - 1) : 0);
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
                onTap: m.onTap,
                excludeSemantics: true,
                label: '${m.label}, ${m.value}. ${m.caption}',
                child: AppCard(
                  onTap: m.onTap,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: m.color.withValues(alpha: 0.09),
                              borderRadius: AppRadius.allMd,
                            ),
                            child: Icon(m.icon, size: 18, color: m.color),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.north_east_rounded,
                            size: 15,
                            color: context.colors.onSurfaceVariant.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        '${m.value}',
                        style: AppTypography.h1(context.colors.onSurface)
                            .copyWith(
                              fontSize: 28,
                              height: 1.1,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        m.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyStrong(
                          context.colors.onSurface,
                        ).copyWith(fontSize: 13),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        m.caption,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption(
                          context.colors.onSurfaceVariant,
                        ).copyWith(fontSize: 11),
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
            Text(
              'Görünümü düzenle',
              style: AppTypography.label(context.colors.onSurface),
            ),
            const Spacer(),
            if (onReset != null)
              TextButton(onPressed: onReset, child: const Text('Sıfırla')),
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
    final color = presence.inside == null
        ? AppColors.neutral
        : inside
        ? AppColors.entry
        : AppColors.exit;
    final elapsed = presence.at == null
        ? Duration.zero
        : now.difference(presence.at!);
    final subtitle = [
      if (user.studentNumber.isNotEmpty) 'No ${user.studentNumber}',
      if (user.room.isNotEmpty) 'Oda ${user.room}',
    ].join(' · ');
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primarySurface,
                foregroundColor: AppColors.primary,
                child: Text(
                  user.initials,
                  style: AppTypography.label(AppColors.primary),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyStrong(context.colors.onSurface),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: AppTypography.caption(
                          context.colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: context.colors.onSurfaceVariant,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              StatusChip(
                label: presence.inside == null
                    ? 'Başlangıç kaydı yok'
                    : presence.label,
                icon: presence.inside == null
                    ? Icons.help_outline_rounded
                    : inside
                    ? Icons.login_rounded
                    : Icons.logout_rounded,
                tone: presence.inside == null
                    ? StatusTone.neutral
                    : inside
                    ? StatusTone.success
                    : StatusTone.danger,
                compact: true,
              ),
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
                StatusChip(label: w, tone: StatusTone.warning, compact: true),
            ],
          ),
          const SizedBox(height: 12),
          if (presence.at != null)
            Row(
              children: [
                Icon(Icons.access_time_rounded, size: 15, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${presence.checkpoint == 'Başlangıç durumu'
                        ? 'Durum doğrulaması'
                        : inside
                        ? 'Son giriş'
                        : 'Son çıkış'} · ${AppDate.dateTime(presence.at!)}',
                    style: AppTypography.caption(
                      context.colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          if (presence.inside == false && elapsed > Duration.zero)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${AppDate.durationHuman(elapsed)} dışarıda',
                style: AppTypography.caption(context.colors.onSurfaceVariant),
              ),
            ),
          if (onInitialize != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onInitialize,
                icon: const Icon(Icons.edit_location_alt_outlined, size: 17),
                label: const Text('Başlangıç durumunu belirle'),
              ),
            ),
        ],
      ),
    );
  }
}

class DormMovementTile extends StatelessWidget {
  const DormMovementTile({
    required this.event,
    this.onVoid,
    this.showName = false,
    super.key,
  });
  final AttendanceEvent event;
  final VoidCallback? onVoid;
  final bool showName;
  @override
  Widget build(BuildContext context) {
    final color = event.type.isEntry ? AppColors.entry : AppColors.exit;
    final surface = event.type.isEntry
        ? AppColors.entrySurface
        : AppColors.exitSurface;
    return Container(
      key: ValueKey('movement-${event.id}'),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadius.allMd,
        border: Border.all(
          color: context.colors.outline.withValues(alpha: 0.65),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 3,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(10),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: surface,
                            borderRadius: AppRadius.allMd,
                          ),
                          child: Icon(
                            event.type.isEntry
                                ? Icons.login_rounded
                                : Icons.logout_rounded,
                            color: color,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
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
                            fontSize: 20,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        if (onVoid != null)
                          SizedBox(
                            width: 48,
                            height: 48,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              tooltip: 'Yanlış kaydı geçersiz kıl',
                              icon: Icon(
                                Icons.more_horiz_rounded,
                                size: 21,
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
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DormDaySummary extends StatelessWidget {
  const DormDaySummary({
    required this.events,
    required this.expanded,
    required this.onTap,
    super.key,
  });
  final List<AttendanceEvent> events;
  final bool expanded;
  final VoidCallback onTap;
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
