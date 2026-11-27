import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubsoft_pdks/application/auth/session_provider.dart';
import 'package:ubsoft_pdks/application/dorm/dorm_providers.dart';
import 'package:ubsoft_pdks/core/extensions/context_x.dart';
import 'package:ubsoft_pdks/core/theme/app_colors.dart';
import 'package:ubsoft_pdks/core/theme/app_radius.dart';
import 'package:ubsoft_pdks/core/theme/app_spacing.dart';
import 'package:ubsoft_pdks/core/theme/app_typography.dart';
import 'package:ubsoft_pdks/core/utils/date_x.dart';
import 'package:ubsoft_pdks/domain/entities/announcement.dart';
import 'package:ubsoft_pdks/domain/entities/app_user.dart';
import 'package:ubsoft_pdks/presentation/features/dorm/widgets/dorm_ui.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_button.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_card.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_scaffold.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_text_field.dart';
import 'package:ubsoft_pdks/presentation/widgets/async_value_view.dart';
import 'package:ubsoft_pdks/presentation/widgets/confirm_dialog.dart';
import 'package:ubsoft_pdks/presentation/widgets/status_chip.dart';
import 'package:ubsoft_pdks/services/notification/toast_service.dart';
import 'package:ubsoft_pdks/services/notification/web_notification_service.dart';

/// Duyurular modülü (`/duyurular`).
///
/// Yurt Durumu ile birebir aynı üst kurumsal başlık bandı, metrik kartları ve
/// dairesel ikon rozetli kart mimarisini kullanır.
class DormAnnouncementsPage extends ConsumerStatefulWidget {
  const DormAnnouncementsPage({super.key});

  @override
  ConsumerState<DormAnnouncementsPage> createState() =>
      _DormAnnouncementsPageState();
}

class _DormAnnouncementsPageState extends ConsumerState<DormAnnouncementsPage> {
  final TextEditingController _search = TextEditingController();
  String _filter = 'all';
  bool _busy = false;
  String _notifPermission = WebNotificationService.permission;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _requestBrowserPermission() async {
    final String status = await WebNotificationService.requestPermission();
    if (!mounted) return;
    setState(() => _notifPermission = status);
    if (status == 'granted') {
      Toast.success('Duyuru bildirimleri etkinleştirildi.');
    } else if (status == 'denied') {
      Toast.error(
        'Tarayıcı bildirim izni reddedildi. Tarayıcı ayarlarından açabilirsiniz.',
      );
    }
  }

  Future<void> _openCreateDialog(List<AppUser> students) async {
    final Set<String> rooms = students
        .map((s) => s.room.trim())
        .where((r) => r.isNotEmpty)
        .toSet();
    final Set<String> floors = rooms
        .map(DormAnnouncement.floorOfRoom)
        .where((f) => f.isNotEmpty)
        .toSet();

    final _NewAnnouncementInput? input =
        await showDialog<_NewAnnouncementInput>(
          context: context,
          builder: (c) => _AnnouncementDialog(
            floors: floors.toList()..sort(),
            rooms: rooms.toList()..sort(),
          ),
        );
    if (input == null || !mounted) return;
    final AppUser? me = ref.read(currentUserProvider);
    if (me == null) return;
    setState(() => _busy = true);
    final res = await ref
        .read(dormRepositoryProvider)
        .createAnnouncement(
          tid: me.tenantId,
          title: input.title,
          body: input.body,
          targetType: input.targetType,
          targetValue: input.targetValue,
          priority: input.priority,
          createdBy: me.uid,
          createdByName: me.displayName,
        );
    Toast.result(res, successMessage: 'Duyuru yayınlandı.');
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _deleteAnnouncement(DormAnnouncement a) async {
    final bool ok = await ConfirmDialog.show(
      context,
      title: 'Duyuru silinsin mi?',
      message: '“${a.title}” duyurusu tüm öğrencilerden kaldırılır.',
      confirmLabel: 'Sil',
      isDestructive: true,
    );
    if (!ok || !mounted) return;
    final AppUser? me = ref.read(currentUserProvider);
    if (me == null) return;
    setState(() => _busy = true);
    final res = await ref
        .read(dormRepositoryProvider)
        .deleteAnnouncement(me.tenantId, a.id);
    Toast.result(res, successMessage: 'Duyuru silindi.');
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _markRead(Iterable<String> ids) async {
    final AppUser? me = ref.read(currentUserProvider);
    if (me == null || !me.role.isStaff) return;
    await ref
        .read(dormRepositoryProvider)
        .markAnnouncementsRead(me.tenantId, me.uid, ids);
  }

  @override
  Widget build(BuildContext context) {
    final AppUser? user = ref.watch(currentUserProvider);
    if (user == null) {
      return const AppScaffold(
        title: 'Duyurular',
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final bool isAdmin = user.role.isAdmin;
    final List<AppUser> students = ref.watch(studentsProvider);
    final Set<String> readIds =
        ref.watch(myAnnouncementReadsProvider).value ?? const <String>{};

    return AppScaffold(
      title: 'Duyurular',
      maxContentWidth: AppWidths.page,
      scrollable: true,
      body: AsyncValueView<List<DormAnnouncement>>(
        value: ref.watch(dormAnnouncementsProvider),
        builder: (all) {
          final List<DormAnnouncement> applicable = all
              .where((a) => a.appliesTo(user))
              .toList();
          final int generalCount = applicable
              .where((a) => a.targetType == 'all')
              .length;
          final int floorCount = applicable
              .where((a) => a.targetType == 'floor')
              .length;
          final int roomCount = applicable
              .where((a) => a.targetType == 'room')
              .length;
          final int urgentCount = applicable.where((a) => a.isUrgent).length;
          final int unreadTotal = isAdmin
              ? 0
              : applicable.where((a) => !readIds.contains(a.id)).length;

          final String q = dormSearchKey(_search.text);
          final List<DormAnnouncement> visible = applicable.where((a) {
            final bool typeMatch = switch (_filter) {
              'general' => a.targetType == 'all',
              'floor' => a.targetType == 'floor',
              'room' => a.targetType == 'room',
              'urgent' => a.isUrgent,
              _ => true,
            };
            if (!typeMatch) return false;
            if (q.isEmpty) return true;
            return dormSearchKey(
              '${a.title} ${a.body} ${a.targetLabel} ${a.createdByName}',
            ).contains(q);
          }).toList();

          final List<String> unreadVisibleIds = !isAdmin
              ? visible
                    .where((a) => !readIds.contains(a.id))
                    .map((a) => a.id)
                    .toList()
              : const <String>[];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DormPageBanner(
                eyebrow: 'YURT İLETİŞİM MERKEZİ',
                title: 'Duyurular',
                subtitle: isAdmin
                    ? 'Tüm yurda, belirli bir kata veya odaya anlık kurumsal duyuru yayınlayın'
                    : 'Yönetim tarafından yayınlanan genel, kat ve oda duyuruları',
                statLabel: isAdmin ? 'YAYINDAKİ DUYURU' : 'OKUNMAMIŞ',
                statValue: isAdmin
                    ? '${applicable.length} duyuru · $urgentCount acil'
                    : '$unreadTotal / ${applicable.length} duyuru',
                action: isAdmin
                    ? ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.white,
                          foregroundColor: AppColors.navy,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          shape: const RoundedRectangleBorder(
                            borderRadius: AppRadius.allSm,
                          ),
                          textStyle: AppTypography.label(AppColors.navy),
                        ),
                        onPressed: _busy
                            ? null
                            : () => _openCreateDialog(students),
                        icon: const Icon(Icons.campaign_outlined, size: 18),
                        label: const Text('Yeni duyuru'),
                      )
                    : null,
              ),
              const SizedBox(height: 16),
              DormMetricGrid(
                metrics: [
                  DormMetric(
                    'Toplam duyuru',
                    applicable.length,
                    Icons.campaign_outlined,
                    AppColors.primary,
                    'Yayındaki duyurular',
                    () => setState(() => _filter = 'all'),
                    selected: _filter == 'all',
                  ),
                  DormMetric(
                    'Acil / Önemli',
                    urgentCount,
                    Icons.priority_high_rounded,
                    AppColors.exit,
                    'Öncelikli bildirimler',
                    () => setState(
                      () => _filter = _filter == 'urgent' ? 'all' : 'urgent',
                    ),
                    selected: _filter == 'urgent',
                  ),
                  DormMetric(
                    'Genel duyuru',
                    generalCount,
                    Icons.public_rounded,
                    AppColors.entry,
                    'Tüm yurt kapsamı',
                    () => setState(
                      () => _filter = _filter == 'general' ? 'all' : 'general',
                    ),
                    selected: _filter == 'general',
                  ),
                  DormMetric(
                    'Kat & Oda özel',
                    floorCount + roomCount,
                    Icons.meeting_room_outlined,
                    AppColors.warning,
                    '$floorCount kat · $roomCount oda',
                    () => setState(
                      () => _filter = _filter == 'floor' ? 'all' : 'floor',
                    ),
                    selected: _filter == 'floor' || _filter == 'room',
                  ),
                ],
              ),
              if (!isAdmin &&
                  WebNotificationService.isSupported &&
                  _notifPermission == 'default') ...[
                const SizedBox(height: 12),
                AppCard(
                  background: AppColors.primarySurface.withValues(alpha: 0.45),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      const DormCircleBadge(
                        icon: Icons.notifications_active_outlined,
                        color: AppColors.primary,
                        surface: AppColors.primarySurface,
                        size: 34,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Yeni duyurular yayınlandığında tarayıcı bildirimi almak ister misiniz?',
                          style: AppTypography.small(context.colors.onSurface),
                        ),
                      ),
                      const SizedBox(width: 8),
                      AppButton(
                        label: 'İzin ver',
                        size: AppButtonSize.small,
                        onPressed: _requestBrowserPermission,
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Duyuru başlığı, metni, kat veya oda ara...',
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
                options: const [
                  DormSegmentedOption('all', 'Tümü'),
                  DormSegmentedOption(
                    'general',
                    'Genel',
                    dotColor: AppColors.primary,
                  ),
                  DormSegmentedOption(
                    'floor',
                    'Kat Bazlı',
                    dotColor: AppColors.entry,
                  ),
                  DormSegmentedOption(
                    'room',
                    'Oda Bazlı',
                    dotColor: AppColors.warning,
                  ),
                ],
                onChanged: (v) => setState(() => _filter = v),
              ),
              const SizedBox(height: 14),
              if (unreadVisibleIds.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _markRead(unreadVisibleIds),
                      icon: const Icon(Icons.done_all_rounded, size: 18),
                      label: Text(
                        'Tümünü okundu işaretle (${unreadVisibleIds.length})',
                      ),
                    ),
                  ),
                ),
              if (visible.isEmpty)
                DormEmpty(
                  title: applicable.isEmpty
                      ? 'Henüz duyuru yok'
                      : 'Bu filtreye uygun duyuru bulunamadı',
                  message: applicable.isEmpty
                      ? 'Yurt yönetimi yeni bir duyuru yayınladığında burada görünür.'
                      : 'Arama metnini veya filtreyi temizleyebilirsiniz.',
                  onReset: (_search.text.isNotEmpty || _filter != 'all')
                      ? () {
                          _search.clear();
                          setState(() => _filter = 'all');
                        }
                      : null,
                )
              else
                for (final a in visible)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _AnnouncementCard(
                      announcement: a,
                      isAdmin: isAdmin,
                      unread: !isAdmin && !readIds.contains(a.id),
                      onMarkRead: () => _markRead([a.id]),
                      onDelete: () => _deleteAnnouncement(a),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

/// Yurt Durumu'ndaki `DormStudentCard` ile birebir aynı tasarım dilini taşıyan
/// duyuru kartı.
class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({
    required this.announcement,
    required this.isAdmin,
    required this.unread,
    required this.onMarkRead,
    required this.onDelete,
  });

  final DormAnnouncement announcement;
  final bool isAdmin;
  final bool unread;
  final VoidCallback onMarkRead;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final Color color = announcement.isUrgent
        ? AppColors.exit
        : switch (announcement.targetType) {
            'floor' => AppColors.entry,
            'room' => AppColors.warning,
            _ => AppColors.primary,
          };
    final Color surface = announcement.isUrgent
        ? AppColors.exitSurface
        : switch (announcement.targetType) {
            'floor' => AppColors.entrySurface,
            'room' => AppColors.warningSurface,
            _ => AppColors.primarySurface,
          };
    final IconData icon = announcement.isUrgent
        ? Icons.priority_high_rounded
        : switch (announcement.targetType) {
            'floor' => Icons.layers_outlined,
            'room' => Icons.meeting_room_outlined,
            _ => Icons.campaign_outlined,
          };

    final String metaLine = <String>[
      announcement.targetLabel,
      if (announcement.createdByName.isNotEmpty) announcement.createdByName,
      AppDate.dateTime(announcement.createdAt),
    ].join(' · ');

    return AppCard(
      onTap: unread ? onMarkRead : null,
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
                tooltip: announcement.targetLabel,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      announcement.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyStrong(
                        context.colors.onSurface,
                      ).copyWith(fontSize: 13.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      metaLine,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption(
                        context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (isAdmin)
                IconButton(
                  tooltip: 'Duyuruyu sil',
                  visualDensity: VisualDensity.compact,
                  onPressed: onDelete,
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    size: 19,
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              StatusChip(
                label: announcement.targetLabel,
                tone: announcement.targetType == 'floor'
                    ? StatusTone.success
                    : announcement.targetType == 'room'
                    ? StatusTone.warning
                    : StatusTone.info,
                compact: true,
              ),
              if (announcement.isUrgent)
                const StatusChip(
                  label: 'Acil',
                  icon: Icons.priority_high_rounded,
                  tone: StatusTone.danger,
                  compact: true,
                ),
              if (unread)
                const StatusChip(
                  label: 'Yeni',
                  tone: StatusTone.danger,
                  compact: true,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            announcement.body,
            style: AppTypography.small(
              context.colors.onSurface,
            ).copyWith(height: 1.48),
          ),
          if (unread) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: onMarkRead,
                icon: const Icon(Icons.check_rounded, size: 16),
                label: const Text('Okundu işaretle'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NewAnnouncementInput {
  const _NewAnnouncementInput({
    required this.title,
    required this.body,
    required this.targetType,
    required this.targetValue,
    required this.priority,
  });

  final String title;
  final String body;
  final String targetType;
  final String targetValue;
  final String priority;
}

class _AnnouncementDialog extends StatefulWidget {
  const _AnnouncementDialog({required this.floors, required this.rooms});

  final List<String> floors;
  final List<String> rooms;

  @override
  State<_AnnouncementDialog> createState() => _AnnouncementDialogState();
}

class _AnnouncementDialogState extends State<_AnnouncementDialog> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _body = TextEditingController();
  final TextEditingController _customTarget = TextEditingController();
  String _targetType = 'all';
  String? _selectedTarget;
  String _priority = 'normal';

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _customTarget.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<String> choices = _targetType == 'floor'
        ? widget.floors
        : _targetType == 'room'
        ? widget.rooms
        : const <String>[];

    return AlertDialog(
      title: const Text('Yeni duyuru'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  label: 'Duyuru başlığı',
                  controller: _title,
                  isRequired: true,
                  maxLength: 160,
                  hint: 'Örn: Su kesintisi / Kat toplantısı',
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Başlık girin.' : null,
                ),
                const SizedBox(height: 12),
                Text(
                  'Hedef kitle',
                  style: AppTypography.label(context.colors.onSurfaceVariant),
                ),
                const SizedBox(height: 6),
                DormSegmentedBar<String>(
                  value: _targetType,
                  options: const [
                    DormSegmentedOption('all', 'Genel'),
                    DormSegmentedOption('floor', 'Kat Bazlı'),
                    DormSegmentedOption('room', 'Oda Bazlı'),
                  ],
                  onChanged: (v) => setState(() {
                    _targetType = v;
                    _selectedTarget = null;
                    _customTarget.clear();
                  }),
                ),
                if (_targetType != 'all') ...[
                  const SizedBox(height: 12),
                  if (choices.isNotEmpty)
                    DropdownButtonFormField<String>(
                      initialValue: _selectedTarget,
                      decoration: InputDecoration(
                        labelText: _targetType == 'floor'
                            ? 'Kat seçin'
                            : 'Oda seçin',
                      ),
                      items: [
                        for (final c in choices)
                          DropdownMenuItem(
                            value: c,
                            child: Text(
                              _targetType == 'floor' ? '$c. Kat' : 'Oda $c',
                            ),
                          ),
                      ],
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Hedef seçin.'
                          : null,
                      onChanged: (v) => setState(() => _selectedTarget = v),
                    )
                  else
                    AppTextField(
                      label: _targetType == 'floor'
                          ? 'Kat numarası'
                          : 'Oda numarası',
                      controller: _customTarget,
                      isRequired: true,
                      hint: _targetType == 'floor' ? 'Örn: 2' : 'Örn: 201',
                      validator: (v) =>
                          (v ?? '').trim().isEmpty ? 'Hedef girin.' : null,
                    ),
                ],
                const SizedBox(height: 12),
                Text(
                  'Öncelik',
                  style: AppTypography.label(context.colors.onSurfaceVariant),
                ),
                const SizedBox(height: 6),
                DormSegmentedBar<String>(
                  value: _priority,
                  options: const [
                    DormSegmentedOption(
                      'normal',
                      'Normal',
                      dotColor: AppColors.primary,
                    ),
                    DormSegmentedOption(
                      'urgent',
                      'Acil / Önemli',
                      dotColor: AppColors.exit,
                    ),
                  ],
                  onChanged: (v) => setState(() => _priority = v),
                ),
                const SizedBox(height: 12),
                AppTextField(
                  label: 'Duyuru metni',
                  controller: _body,
                  isRequired: true,
                  maxLines: 4,
                  maxLength: 2000,
                  hint: 'Öğrencilere iletilecek ayrıntıları yazın...',
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Duyuru metni girin.' : null,
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
          onPressed: () {
            if (!_form.currentState!.validate()) return;
            final String targetVal = _targetType == 'all'
                ? ''
                : (_selectedTarget ?? _customTarget.text.trim());
            Navigator.pop(
              context,
              _NewAnnouncementInput(
                title: _title.text.trim(),
                body: _body.text.trim(),
                targetType: _targetType,
                targetValue: targetVal,
                priority: _priority,
              ),
            );
          },
          child: const Text('Yayınla'),
        ),
      ],
    );
  }
}
