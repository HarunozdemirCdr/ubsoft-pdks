import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ubsoft_pdks/application/auth/session_provider.dart';
import 'package:ubsoft_pdks/application/dorm/dorm_providers.dart';
import 'package:ubsoft_pdks/core/extensions/context_x.dart';
import 'package:ubsoft_pdks/core/routing/app_routes.dart';
import 'package:ubsoft_pdks/core/theme/app_colors.dart';
import 'package:ubsoft_pdks/core/theme/app_radius.dart';
import 'package:ubsoft_pdks/core/theme/app_spacing.dart';
import 'package:ubsoft_pdks/core/theme/app_typography.dart';
import 'package:ubsoft_pdks/core/utils/date_x.dart';
import 'package:ubsoft_pdks/domain/entities/app_user.dart';
import 'package:ubsoft_pdks/domain/entities/attention_resolution.dart';
import 'package:ubsoft_pdks/domain/usecases/dorm/dorm_attention.dart';
import 'package:ubsoft_pdks/domain/usecases/dorm/dorm_duration.dart';
import 'package:ubsoft_pdks/presentation/features/dorm/widgets/dorm_ui.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_button.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_card.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_scaffold.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_text_field.dart';
import 'package:ubsoft_pdks/presentation/widgets/confirm_dialog.dart';
import 'package:ubsoft_pdks/presentation/widgets/status_chip.dart';
import 'package:ubsoft_pdks/services/notification/toast_service.dart';

/// Dikkat Edilmesi Gereken Durumlar modülü (`/uyarilar`).
///
/// Yurt Durumu ile birebir aynı üst kurumsal başlık bandı, metrik kartları ve
/// dairesel ikon rozetli öğrenci kartı dilini kullanır. Yönetici her durumu
/// zorunlu çözüm notuyla kapatabilir; kapanan kayıtlar aktif listeden düşer ve
/// öğrencinin geçmişi ile raporlarında kalıcı denetim notu olarak görünür.
class DormAttentionPage extends ConsumerStatefulWidget {
  const DormAttentionPage({super.key});

  @override
  ConsumerState<DormAttentionPage> createState() => _DormAttentionPageState();
}

class _DormAttentionPageState extends ConsumerState<DormAttentionPage> {
  final TextEditingController _search = TextEditingController();
  String _filter = 'all'; // all | leaveExpired | curfew | other | resolved
  bool _busy = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _resolve(DormAttentionItem item) async {
    final String? note = await showDialog<String>(
      context: context,
      builder: (BuildContext c) => _ResolveAttentionDialog(item: item),
    );
    if (note == null || !mounted) return;
    final AppUser? me = ref.read(currentUserProvider);
    if (me == null) return;
    setState(() => _busy = true);
    final res = await ref
        .read(dormRepositoryProvider)
        .resolveAttentionItem(
          tid: me.tenantId,
          item: item,
          resolutionNote: note,
          resolvedBy: me.uid,
          resolvedByName: me.displayName,
        );
    Toast.result(
      res,
      successMessage:
          'Durum çözüldü olarak kapatıldı ve öğrenci geçmişine kaydedildi.',
    );
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _reopen(AttentionResolution log) async {
    final bool ok = await ConfirmDialog.show(
      context,
      title: 'Uyarı tekrar açılsın mı?',
      message:
          '“${log.userName}” için kaydedilen bu çözüm notu kaldırılır ve durum hâlâ sürüyorsa açık uyarı listesine geri döner.',
      confirmLabel: 'Tekrar aç',
    );
    if (!ok || !mounted) return;
    final AppUser? me = ref.read(currentUserProvider);
    if (me == null) return;
    setState(() => _busy = true);
    final res = await ref
        .read(dormRepositoryProvider)
        .reopenAttentionLog(me.tenantId, log.id);
    Toast.result(res, successMessage: 'Çözüm kaydı kaldırıldı.');
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final DateTime now = ref.watch(dormNowProvider);
    final List<DormAttentionItem> all = ref.watch(dormAttentionItemsProvider);
    final List<AttentionResolution> logs =
        ref.watch(attentionLogsProvider).value ?? const <AttentionResolution>[];

    final int leaveExpiredCount = all
        .where((i) => i.kind == DormAttentionKind.leaveExpiredStillOutside)
        .length;
    final int curfewCount = all
        .where((i) => i.kind == DormAttentionKind.curfewOverdue)
        .length;
    final int otherCount = all
        .where(
          (i) =>
              i.kind == DormAttentionKind.scanWarning ||
              i.kind == DormAttentionKind.uninitialized,
        )
        .length;

    final String q = dormSearchKey(_search.text);
    final bool showingResolved = _filter == 'resolved';

    final List<DormAttentionItem> filteredOpen = all.where((item) {
      final bool kindMatch = switch (_filter) {
        'leaveExpired' =>
          item.kind == DormAttentionKind.leaveExpiredStillOutside,
        'curfew' => item.kind == DormAttentionKind.curfewOverdue,
        'other' =>
          item.kind == DormAttentionKind.scanWarning ||
              item.kind == DormAttentionKind.uninitialized,
        _ => true,
      };
      if (!kindMatch) return false;
      if (q.isEmpty) return true;
      final String hay = <String>[
        item.user.displayName,
        item.user.room,
        item.user.studentNumber,
        item.title,
        item.relatedLeave?.contactName ?? '',
        item.relatedLeave?.destination ?? '',
      ].join(' ');
      return dormSearchKey(hay).contains(q);
    }).toList();

    final List<AttentionResolution> filteredLogs = logs.where((log) {
      if (q.isEmpty) return true;
      final String hay = <String>[
        log.userName,
        log.room,
        log.title,
        log.summary,
        log.resolutionNote,
        log.resolvedByName,
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
          DormPageBanner(
            eyebrow: 'TAKİP VE MÜDAHALE MERKEZİ',
            title: 'Dikkat Edilmesi Gerekenler',
            subtitle:
                '${AppDate.date(now)} · ${AppDate.dayName(now)} · Çözülen durumlar notuyla geçmişe aktarılır',
            statLabel: 'TAKİP ÖZETİ',
            statValue: '${all.length} açık · ${logs.length} çözüldü',
          ),
          const SizedBox(height: 16),
          DormMetricGrid(
            metrics: [
              DormMetric(
                'Açık uyarı',
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
                'Çözülen kayıt',
                logs.length,
                Icons.fact_check_outlined,
                AppColors.entry,
                'Notlu denetim arşivi',
                () => setState(
                  () => _filter = _filter == 'resolved' ? 'all' : 'resolved',
                ),
                selected: _filter == 'resolved',
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText:
                  'Öğrenci adı, oda no, çözüm notu veya iletişim bilgisi ara...',
              prefixIcon: const Icon(Icons.search_rounded),
              isDense: true,
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
            options: [
              DormSegmentedOption('all', 'Açık (${all.length})'),
              const DormSegmentedOption(
                'leaveExpired',
                'İzni Biten',
                dotColor: AppColors.exit,
              ),
              const DormSegmentedOption(
                'curfew',
                'Geciken',
                dotColor: AppColors.warning,
              ),
              DormSegmentedOption(
                'other',
                'Diğer ($otherCount)',
                dotColor: AppColors.neutral,
              ),
              DormSegmentedOption(
                'resolved',
                'Çözülenler (${logs.length})',
                dotColor: AppColors.entry,
              ),
            ],
            onChanged: (v) => setState(() => _filter = v),
          ),
          const SizedBox(height: 14),
          if (showingResolved) ...[
            if (filteredLogs.isEmpty)
              DormEmpty(
                title: logs.isEmpty
                    ? 'Henüz çözülmüş uyarı kaydı yok'
                    : 'Bu aramaya uyan çözüm kaydı bulunamadı',
                message: logs.isEmpty
                    ? 'Bir uyarıyı not ekleyerek "Çözüldü" olarak kapattığınızda burada ve öğrencinin geçmişinde görünür.'
                    : 'Arama metnini temizleyip tekrar deneyin.',
                onReset: _search.text.isNotEmpty
                    ? () {
                        _search.clear();
                        setState(() {});
                      }
                    : null,
              )
            else
              for (final log in filteredLogs)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ResolvedLogCard(
                    log: log,
                    busy: _busy,
                    onOpenHistory: () =>
                        context.push(AppRoutes.personHistoryPath(log.userId)),
                    onReopen: () => _reopen(log),
                  ),
                ),
          ] else if (filteredOpen.isEmpty) ...[
            DormEmpty(
              title: all.isEmpty
                  ? 'Açık dikkat gerektiren durum yok'
                  : 'Bu filtreye uygun kayıt bulunamadı',
              message: all.isEmpty
                  ? 'Tüm öğrenciler beklenen saatler içinde veya mevcut uyarılar çözüldü.'
                  : 'Arama metnini veya filtreyi değiştirebilirsiniz.',
              onReset: (_search.text.isNotEmpty || _filter != 'all')
                  ? () {
                      _search.clear();
                      setState(() => _filter = 'all');
                    }
                  : null,
            ),
          ] else ...[
            for (final item in filteredOpen)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _AttentionCard(
                  item: item,
                  busy: _busy,
                  onResolve: () => _resolve(item),
                  onOpenHistory: () =>
                      context.push(AppRoutes.personHistoryPath(item.user.uid)),
                  onOpenDetail: () =>
                      context.push(AppRoutes.userEditPath(item.user.uid)),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Yurt Durumu'ndaki `DormStudentCard` ile birebir aynı görsel mimariyi taşıyan
/// açık uyarı kartı.
class _AttentionCard extends StatelessWidget {
  const _AttentionCard({
    required this.item,
    required this.busy,
    required this.onResolve,
    required this.onOpenHistory,
    required this.onOpenDetail,
  });

  final DormAttentionItem item;
  final bool busy;
  final VoidCallback onResolve;
  final VoidCallback onOpenHistory;
  final VoidCallback onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final Color color = switch (item.kind) {
      DormAttentionKind.leaveExpiredStillOutside => AppColors.exit,
      DormAttentionKind.curfewOverdue => AppColors.warning,
      DormAttentionKind.scanWarning => AppColors.primary,
      DormAttentionKind.uninitialized => AppColors.neutral,
    };
    final Color surface = switch (item.kind) {
      DormAttentionKind.leaveExpiredStillOutside => AppColors.exitSurface,
      DormAttentionKind.curfewOverdue => AppColors.warningSurface,
      DormAttentionKind.scanWarning => AppColors.primarySurface,
      DormAttentionKind.uninitialized => AppColors.neutral.withValues(
        alpha: 0.1,
      ),
    };
    final IconData icon = switch (item.kind) {
      DormAttentionKind.leaveExpiredStillOutside => Icons.event_busy_outlined,
      DormAttentionKind.curfewOverdue => Icons.schedule_rounded,
      DormAttentionKind.scanWarning => Icons.error_outline_rounded,
      DormAttentionKind.uninitialized => Icons.help_outline_rounded,
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
        : <String>[
            if (leave.contactName.isNotEmpty) leave.contactName,
            if (leave.contactRelation.isNotEmpty) '(${leave.contactRelation})',
            if (leave.contactPhone.isNotEmpty) leave.contactPhone,
          ].join(' ');

    final String metaLine = <String>[
      if (item.user.room.isNotEmpty) 'Oda ${item.user.room}',
      if (item.user.studentNumber.isNotEmpty) 'No ${item.user.studentNumber}',
      if (item.outsideFor != null)
        '${DormDurationCalculator.formatDuration(item.outsideFor!)} dışarıda',
    ].join(' · ');

    return AppCard(
      onTap: onOpenHistory,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              DormCircleBadge(
                icon: icon,
                color: color,
                surface: surface,
                tooltip: item.title,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.user.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyStrong(
                        context.colors.onSurface,
                      ).copyWith(fontSize: 13.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      metaLine.isEmpty ? item.summary : metaLine,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption(
                        context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (item.presence.at != null)
                Text(
                  AppDate.time(item.presence.at!),
                  style: AppTypography.bodyStrong(color).copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusChip(label: item.title, tone: tone, compact: true),
              if (item.overdueBy != null)
                StatusChip(
                  label:
                      '${DormDurationCalculator.formatDuration(item.overdueBy!)} gecikti',
                  icon: Icons.timer_outlined,
                  tone: tone,
                  compact: true,
                ),
              if ((item.user.phone ?? '').isNotEmpty)
                StatusChip(
                  label: item.user.phone!,
                  icon: Icons.phone_outlined,
                  tone: StatusTone.neutral,
                  compact: true,
                ),
            ],
          ),
          if (item.detailLine.isNotEmpty ||
              contactLine.isNotEmpty ||
              (leave?.destination ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              <String>[
                if (item.detailLine.isNotEmpty) item.detailLine,
                if ((leave?.destination ?? '').isNotEmpty)
                  'Yer: ${leave!.destination}',
                if (contactLine.isNotEmpty) 'Yakın: $contactLine',
              ].join(' · '),
              style: AppTypography.caption(
                context.colors.onSurfaceVariant,
              ).copyWith(height: 1.4),
            ),
          ],
          const Divider(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Wrap(
                spacing: 4,
                children: [
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                    ),
                    onPressed: onOpenHistory,
                    icon: const Icon(Icons.history_rounded, size: 16),
                    label: const Text('Geçmiş'),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                    ),
                    onPressed: onOpenDetail,
                    icon: const Icon(Icons.badge_outlined, size: 16),
                    label: const Text('Detay'),
                  ),
                ],
              ),
              AppButton(
                key: ValueKey('resolve-${item.user.uid}'),
                label: 'Çözüldü',
                icon: Icons.task_alt_rounded,
                size: AppButtonSize.small,
                onPressed: busy ? null : onResolve,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResolvedLogCard extends StatelessWidget {
  const _ResolvedLogCard({
    required this.log,
    required this.busy,
    required this.onOpenHistory,
    required this.onReopen,
  });

  final AttentionResolution log;
  final bool busy;
  final VoidCallback onOpenHistory;
  final VoidCallback onReopen;

  @override
  Widget build(BuildContext context) {
    final String meta = <String>[
      if (log.room.isNotEmpty) 'Oda ${log.room}',
      log.title,
      AppDate.dateTime(log.resolvedAt),
    ].join(' · ');

    return AppCard(
      onTap: onOpenHistory,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const DormCircleBadge(
                icon: Icons.check_circle_outline_rounded,
                color: AppColors.entry,
                surface: AppColors.entrySurface,
                tooltip: 'Çözüldü',
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      log.userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyStrong(
                        context.colors.onSurface,
                      ).copyWith(fontSize: 13.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      meta,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption(
                        context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const StatusChip(
                label: 'Çözüldü',
                tone: StatusTone.success,
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
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
                if (log.summary.isNotEmpty) ...[
                  Text(
                    log.summary,
                    style: AppTypography.caption(
                      context.colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  log.resolutionNote,
                  style: AppTypography.small(context.colors.onSurface),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Çözen: ${log.resolvedByName.isEmpty ? 'Yönetici' : log.resolvedByName}',
                  style: AppTypography.caption(
                    context.colors.onSurfaceVariant,
                  ),
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: onOpenHistory,
                child: const Text('Geçmiş'),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: context.colors.onSurfaceVariant,
                ),
                onPressed: busy ? null : onReopen,
                child: const Text('Tekrar aç'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResolveAttentionDialog extends StatefulWidget {
  const _ResolveAttentionDialog({required this.item});

  final DormAttentionItem item;

  @override
  State<_ResolveAttentionDialog> createState() =>
      _ResolveAttentionDialogState();
}

class _ResolveAttentionDialogState extends State<_ResolveAttentionDialog> {
  static const List<String> _templates = <String>[
    'Veli ile görüşüldü, bilgisi dahilinde olduğu teyit edildi.',
    'Öğrenci ile iletişime geçildi, dönüş saati teyit edildi.',
    'İzin süresi yönetici onayıyla uzatıldı.',
    'Yurda dönüş yaptığı gözlemlendi, QR kaydı eksikti.',
  ];

  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Durumu çözüldü olarak kapat'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${widget.item.user.displayName}'
                  '${widget.item.user.room.isEmpty ? '' : ' · Oda ${widget.item.user.room}'}',
                  style: AppTypography.bodyStrong(context.colors.onSurface),
                ),
                const SizedBox(height: 2),
                Text(
                  '${widget.item.title} — ${widget.item.detailLine}',
                  style: AppTypography.caption(
                    context.colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Hızlı şablonlar',
                  style: AppTypography.caption(
                    context.colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final t in _templates)
                      ActionChip(
                        label: Text(
                          t,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onPressed: () {
                          setState(() => _note.text = t);
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                AppTextField(
                  key: const ValueKey('resolve-note-field'),
                  label: 'Çözüm notu (zorunlu)',
                  controller: _note,
                  isRequired: true,
                  maxLines: 3,
                  maxLength: 1000,
                  hint:
                      'Durumun nasıl doğrulandığını ve çözüldüğünü yazın (öğrenci geçmişinde saklanır)...',
                  validator: (String? v) {
                    final String trimmed = (v ?? '').trim();
                    if (trimmed.isEmpty) return 'Çözüm notu girmek zorunludur.';
                    if (trimmed.length < 5) {
                      return 'Lütfen en az 5 karakterlik kısa bir açıklama girin.';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          key: const ValueKey('resolve-confirm-btn'),
          onPressed: () {
            if (!_form.currentState!.validate()) return;
            Navigator.pop(context, _note.text.trim());
          },
          child: const Text('Çözüldü olarak kaydet'),
        ),
      ],
    );
  }
}
