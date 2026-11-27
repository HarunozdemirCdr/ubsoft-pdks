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
import 'package:ubsoft_pdks/presentation/widgets/section_header.dart';
import 'package:ubsoft_pdks/presentation/widgets/status_chip.dart';
import 'package:ubsoft_pdks/services/notification/toast_service.dart';
import 'package:ubsoft_pdks/services/notification/web_notification_service.dart';

/// Duyurular modülü (`/duyurular`).
///
/// Yönetici genel, kat bazlı veya oda bazlı duyuru yayınlar; öğrenci yalnızca
/// kendisini ilgilendiren duyuruları görür, tarayıcı bildirim iznini açabilir
/// ve okunmamış duyuruları okundu olarak işaretler.
class DormAnnouncementsPage extends ConsumerStatefulWidget {
  const DormAnnouncementsPage({super.key});

  @override
  ConsumerState<DormAnnouncementsPage> createState() =>
      _DormAnnouncementsPageState();
}

class _DormAnnouncementsPageState extends ConsumerState<DormAnnouncementsPage> {
  String _filter = 'all';
  bool _busy = false;
  String _notifPermission = WebNotificationService.permission;

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
      maxContentWidth: AppWidths.wide,
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, bounds) {
              final header = SectionHeader(
                eyebrow: 'YURT İLETİŞİM MERKEZİ',
                title: 'Duyurular',
                description: isAdmin
                    ? 'Tüm yurda, belirli bir kata veya belirli bir odaya anlık duyuru yayınlayın.'
                    : 'Yönetim tarafından yayınlanan genel, kat ve oda duyuruları.',
              );
              if (!isAdmin) return header;
              final btn = AppButton(
                label: 'Yeni duyuru yayınla',
                icon: Icons.campaign_outlined,
                size: bounds.maxWidth >= 600
                    ? AppButtonSize.small
                    : AppButtonSize.medium,
                isLoading: _busy,
                onPressed: () => _openCreateDialog(students),
              );
              if (bounds.maxWidth >= 600) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: header),
                    const SizedBox(width: 16),
                    btn,
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [header, const SizedBox(height: 12), btn],
              );
            },
          ),
          if (!isAdmin &&
              WebNotificationService.isSupported &&
              _notifPermission == 'default') ...[
            const SizedBox(height: 14),
            AppCard(
              background: AppColors.primarySurface,
              borderColor: AppColors.primary.withValues(alpha: 0.25),
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(
                    Icons.notifications_active_outlined,
                    color: AppColors.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Anlık duyuru bildirimlerini açın',
                          style: AppTypography.bodyStrong(
                            context.colors.onSurface,
                          ),
                        ),
                        Text(
                          'Yönetim yeni bir duyuru paylaştığında cihazınıza bildirim düşsün.',
                          style: AppTypography.caption(
                            context.colors.onSurfaceVariant,
                          ),
                        ),
                      ],
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
          const SizedBox(height: 14),
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
          const SizedBox(height: 16),
          AsyncValueView<List<DormAnnouncement>>(
            value: ref.watch(dormAnnouncementsProvider),
            builder: (all) {
              final List<DormAnnouncement> visible = all
                  .where((a) => a.appliesTo(user))
                  .where((a) {
                    return switch (_filter) {
                      'general' => a.targetType == 'all',
                      'floor' => a.targetType == 'floor',
                      'room' => a.targetType == 'room',
                      _ => true,
                    };
                  })
                  .toList();

              final List<String> unreadVisibleIds = !isAdmin
                  ? visible
                        .where((a) => !readIds.contains(a.id))
                        .map((a) => a.id)
                        .toList()
                  : const <String>[];

              if (visible.isEmpty) {
                return const DormEmpty(
                  title: 'Henüz duyuru yok',
                  message:
                      'Yurt yönetimi yeni bir duyuru yayınladığında burada görünür.',
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (unreadVisibleIds.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
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
                  for (final a in visible)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
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
        ],
      ),
    );
  }
}

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
    final Color accent = announcement.isUrgent
        ? AppColors.exit
        : switch (announcement.targetType) {
            'floor' => AppColors.entry,
            'room' => AppColors.warning,
            _ => AppColors.primary,
          };

    return AppCard(
      onTap: unread ? onMarkRead : null,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: AppRadius.allMd,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 5, color: accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                StatusChip(
                                  label: announcement.targetLabel,
                                  tone: switch (announcement.targetType) {
                                    'floor' => StatusTone.success,
                                    'room' => StatusTone.warning,
                                    _ => StatusTone.info,
                                  },
                                  compact: true,
                                ),
                                if (announcement.isUrgent)
                                  const StatusChip(
                                    label: 'Acil',
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
                          ),
                          Text(
                            AppDate.dateTime(announcement.createdAt),
                            style: AppTypography.caption(
                              context.colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        announcement.title,
                        style: AppTypography.h3(context.colors.onSurface),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        announcement.body,
                        style: AppTypography.body(context.colors.onSurface),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              announcement.createdByName.isEmpty
                                  ? 'Yurt Yönetimi'
                                  : announcement.createdByName,
                              style: AppTypography.caption(
                                context.colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                          if (unread)
                            TextButton.icon(
                              onPressed: onMarkRead,
                              icon: const Icon(Icons.check_rounded, size: 17),
                              label: const Text('Okudum'),
                            ),
                          if (isAdmin)
                            TextButton.icon(
                              onPressed: onDelete,
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.danger,
                              ),
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                size: 17,
                              ),
                              label: const Text('Sil'),
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
