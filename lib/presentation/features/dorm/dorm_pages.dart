import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ubsoft_pdks/application/auth/session_provider.dart';
import 'package:ubsoft_pdks/application/dorm/dorm_providers.dart';
import 'package:ubsoft_pdks/application/user/user_providers.dart';
import 'package:ubsoft_pdks/core/routing/app_routes.dart';
import 'package:ubsoft_pdks/core/utils/date_x.dart';
import 'package:ubsoft_pdks/domain/entities/app_user.dart';
import 'package:ubsoft_pdks/domain/entities/attendance_event.dart';
import 'package:ubsoft_pdks/domain/entities/dormitory.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_button.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_card.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_scaffold.dart';
import 'package:ubsoft_pdks/presentation/widgets/async_value_view.dart';
import 'package:ubsoft_pdks/presentation/widgets/confirm_dialog.dart';
import 'package:ubsoft_pdks/presentation/widgets/status_chip.dart';
import 'package:ubsoft_pdks/services/export/dorm_pdf_service.dart';
import 'package:ubsoft_pdks/services/export/file_download_service.dart';
import 'package:ubsoft_pdks/services/notification/toast_service.dart';

class DormDashboardPage extends ConsumerStatefulWidget {
  const DormDashboardPage({super.key});
  @override
  ConsumerState<DormDashboardPage> createState() => _DormDashboardState();
}

class _DormDashboardState extends ConsumerState<DormDashboardPage> {
  String _filter = 'Tümü';
  String _search = '';
  @override
  Widget build(BuildContext context) {
    final now = ref.watch(dormNowProvider);
    final students = ref.watch(studentsProvider);
    final tenant = ref.watch(currentTenantProvider);
    if (tenant == null) {
      return const AppScaffold(
        title: 'Yurt Durumu',
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final policy = tenant.settings.dormPolicy;
    return AppScaffold(
      title: 'Yurt Durumu',
      scrollable: true,
      body: AsyncValueView(
        value: ref.watch(usersProvider),
        builder: (_) => AsyncValueView<List<Presence>>(
          value: ref.watch(residentsProvider),
          builder: (states) => AsyncValueView<List<StudentLeave>>(
            value: ref.watch(dormLeavesProvider),
            builder: (leaves) {
              final byId = {for (final p in states) p.userId: p};
              Presence state(AppUser u) =>
                  byId[u.uid] ?? Presence(userId: u.uid);
              bool overdue(AppUser u) => policy.overdue(
                state(u),
                now,
                relevantLeave(leaves, state(u), now),
              );
              bool matches(AppUser u) => switch (_filter) {
                'İçeride' => state(u).inside == true,
                'Dışarıda' => state(u).inside == false,
                'Dönüş yapmadı' => overdue(u),
                'İzinli' =>
                  state(u).inside == false &&
                      leaveAt(leaves, u.uid, now) != null,
                'Uyarılar' => overdue(u) || state(u).warnings.isNotEmpty,
                'Bilinmiyor' => state(u).inside == null,
                _ => true,
              };
              final visible = students
                  .where(
                    (u) =>
                        matches(u) &&
                        '${u.displayName} ${u.room} ${u.studentNumber}'
                            .toLowerCase()
                            .contains(_search.toLowerCase()),
                  )
                  .toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('${tenant.name} · ${AppDate.dateTime(now)}'),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _count('Toplam öğrenci', students.length),
                      _count(
                        'İçeride',
                        students.where((u) => state(u).inside == true).length,
                      ),
                      _count(
                        'Dışarıda',
                        students.where((u) => state(u).inside == false).length,
                      ),
                      _count('Dönüş yapmadı', students.where(overdue).length),
                      _count(
                        'İzinli dışarıda',
                        students
                            .where(
                              (u) =>
                                  state(u).inside == false &&
                                  leaveAt(leaves, u.uid, now) != null,
                            )
                            .length,
                      ),
                      _count(
                        'Durumu bilinmiyor',
                        students.where((u) => state(u).inside == null).length,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Öğrenci, numara veya oda ara',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (v) => setState(() => _search = v),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      for (final f in [
                        'Tümü',
                        'İçeride',
                        'Dışarıda',
                        'Dönüş yapmadı',
                        'İzinli',
                        'Uyarılar',
                        'Bilinmiyor',
                      ])
                        ChoiceChip(
                          label: Text(f),
                          selected: _filter == f,
                          onSelected: (_) => setState(() => _filter = f),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (students.isEmpty)
                    const Text(
                      'Henüz aktif öğrenci yok. Öğrenciler bölümünden kayıt ekleyin.',
                    ),
                  if (students.isNotEmpty && visible.isEmpty)
                    const Text('Bu seçime uyan öğrenci yok.'),
                  for (final u in visible)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(u.displayName),
                              subtitle: Text(
                                [
                                  if (u.studentNumber.isNotEmpty)
                                    'No: ${u.studentNumber}',
                                  if (u.room.isNotEmpty) 'Oda: ${u.room}',
                                  state(u).at == null
                                      ? 'Başlangıç durumu belirlenmedi'
                                      : 'Son hareket: ${AppDate.dateTime(state(u).at!)}',
                                  if (state(u).inside == false &&
                                      state(u).at != null)
                                    '${AppDate.durationHuman(now.difference(state(u).at!))} dışarıda',
                                ].join('\n'),
                              ),
                              onTap: () => context.push(
                                AppRoutes.personHistoryPath(u.uid),
                              ),
                            ),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                StatusChip(
                                  label: state(u).label,
                                  tone: state(u).inside == true
                                      ? StatusTone.success
                                      : StatusTone.neutral,
                                ),
                                if (overdue(u))
                                  const StatusChip(
                                    label: 'Dönüş yapmadı',
                                    tone: StatusTone.danger,
                                  ),
                                if (leaveAt(leaves, u.uid, now) != null)
                                  const StatusChip(
                                    label: 'İzinli',
                                    tone: StatusTone.info,
                                  ),
                                for (final w in state(u).warnings)
                                  StatusChip(
                                    label: w,
                                    tone: StatusTone.warning,
                                  ),
                              ],
                            ),
                            if (state(u).inside == null)
                              TextButton.icon(
                                icon: const Icon(
                                  Icons.edit_location_alt_outlined,
                                ),
                                label: const Text('Başlangıç durumunu belirle'),
                                onPressed: () => _initialize(u),
                              ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  const Text(
                    'Durumlar kayıtlı QR hareketlerine dayanır. İzin kaydı fiziksel durumu değiştirmez.',
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _count(String label, int count) => SizedBox(
    width: 155,
    child: AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$count', style: Theme.of(context).textTheme.headlineMedium),
          Text(label),
        ],
      ),
    ),
  );
  Future<void> _initialize(AppUser u) async {
    final input = await showDialog<(bool, String)>(
      context: context,
      builder: (c) => const _InitialDialog(),
    );
    if (input == null) return;
    final result = await ref
        .read(dormRepositoryProvider)
        .initializePresence(
          u.tenantId,
          u.uid,
          ref.read(currentUserProvider)!.uid,
          input.$2,
          inside: input.$1,
        );
    Toast.result(result, successMessage: 'Başlangıç durumu kaydedildi.');
  }
}

class _InitialDialog extends StatefulWidget {
  const _InitialDialog();
  @override
  State<_InitialDialog> createState() => _InitialDialogState();
}

class _InitialDialogState extends State<_InitialDialog> {
  final _reason = TextEditingController();
  bool _inside = true;
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Başlangıç durumu'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Öğrencinin şu anki durumunu doğrulayarak seçin. İşlem gerekçesiyle kaydedilir.',
        ),
        SwitchListTile(
          title: Text(_inside ? 'İçeride' : 'Dışarıda'),
          value: _inside,
          onChanged: (v) => setState(() => _inside = v),
        ),
        TextField(
          controller: _reason,
          decoration: const InputDecoration(labelText: 'Gerekçe'),
          onChanged: (_) => setState(() {}),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Vazgeç'),
      ),
      FilledButton(
        onPressed: _reason.text.trim().isEmpty
            ? null
            : () => Navigator.pop(context, (_inside, _reason.text.trim())),
        child: const Text('Kaydet'),
      ),
    ],
  );
}

class StudentHomePage extends ConsumerWidget {
  const StudentHomePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(dormNowProvider);
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return const AppScaffold(
        title: 'Yurdum',
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return AppScaffold(
      title: 'Yurdum',
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Merhaba, ${user.displayName}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          AsyncValueView<Presence>(
            value: ref.watch(myPresenceProvider),
            builder: (p) => AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    p.label,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  if (p.at != null)
                    Text('Son hareket: ${AppDate.dateTime(p.at!)}'),
                  if (p.inside == null)
                    const Text(
                      'İlk giriş veya çıkış okutmanızla durumunuz belirlenir.',
                    ),
                  for (final w in p.warnings)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(w),
                    ),
                  const SizedBox(height: 16),
                  AppButton.primaryWide(
                    label: p.inside == true
                        ? 'Çıkış QR kodunu okut'
                        : p.inside == false
                        ? 'Giriş QR kodunu okut'
                        : 'Giriş / çıkış QR kodunu okut',
                    onPressed: () => context.push(AppRoutes.scanPath),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Girişte giriş QR’ını, çıkışta çıkış QR’ını kullanın.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          AsyncValueView<List<StudentLeave>>(
            value: ref.watch(dormLeavesProvider),
            builder: (leaves) {
              final leave = leaveAt(leaves, user.uid, now);
              return leave == null
                  ? const SizedBox.shrink()
                  : AppCard(
                      child: Text(
                        'İzinlisiniz · Dönüş: ${AppDate.dateTime(leave.until)}',
                      ),
                    );
            },
          ),
          const SizedBox(height: 20),
          Text(
            'Bugünkü hareketlerim',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          AsyncValueView<List<AttendanceEvent>>(
            value: ref.watch(
              movementsProvider((
                from: DormClock.key(now),
                to: DormClock.key(now),
                uid: user.uid,
              )),
            ),
            builder: (events) => _EventList(events: events),
          ),
        ],
      ),
    );
  }
}

class DormHistoryPage extends ConsumerStatefulWidget {
  const DormHistoryPage({this.userId, super.key});
  final String? userId;
  @override
  ConsumerState<DormHistoryPage> createState() => _DormHistoryState();
}

class _DormHistoryState extends ConsumerState<DormHistoryPage> {
  DateTime? _day;
  @override
  Widget build(BuildContext context) {
    final now = ref.watch(dormNowProvider);
    final day = _day ?? DormClock.local(now);
    final key =
        '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    final name = ref.watch(usersByIdProvider)[widget.userId]?.displayName;
    return AppScaffold(
      title: name == null ? 'Hareket Geçmişi' : '$name · Hareketler',
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.tonalIcon(
            icon: const Icon(Icons.calendar_month),
            label: Text(key),
            onPressed: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: day,
                firstDate: DateTime(2020),
                lastDate: DormClock.local(now),
              );
              if (date != null) setState(() => _day = date);
            },
          ),
          const SizedBox(height: 16),
          AsyncValueView<List<AttendanceEvent>>(
            value: ref.watch(
              movementsProvider((from: key, to: key, uid: widget.userId)),
            ),
            builder: (events) => _EventList(events: events),
          ),
        ],
      ),
    );
  }
}

class DormReportPage extends ConsumerStatefulWidget {
  const DormReportPage({super.key});
  @override
  ConsumerState<DormReportPage> createState() => _DormReportState();
}

class _DormReportState extends ConsumerState<DormReportPage> {
  DateTimeRange? _range;
  String? _uid;
  String _focus = 'Tümü';
  bool _exporting = false;
  @override
  Widget build(BuildContext context) {
    final now = DormClock.local(ref.watch(dormNowProvider));
    final range =
        _range ??
        DateTimeRange(
          start: DateTime(
            now.year,
            now.month,
            now.day,
          ).subtract(const Duration(days: 6)),
          end: now,
        );
    String key(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final from = key(range.start);
    final to = key(range.end);
    final students = ref.watch(usersProvider).value ?? <AppUser>[];
    return AppScaffold(
      title: 'Giriş–Çıkış Raporları',
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.date_range),
            label: Text('$from — $to'),
            onPressed: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: now,
                initialDateRange: range,
              );
              if (picked != null && picked.duration.inDays > 366) {
                Toast.error('Tek raporda en fazla bir yıl seçin.');
                return;
              }
              if (picked != null) setState(() => _range = picked);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _uid ?? '',
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Öğrenci'),
            items: [
              const DropdownMenuItem(value: '', child: Text('Tüm öğrenciler')),
              for (final u in students.where((u) => u.role.isStaff))
                DropdownMenuItem(
                  value: u.uid,
                  child: Text(u.displayName, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) => setState(() => _uid = v == '' ? null : v),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final f in [
                'Tümü',
                'Geç giriş',
                'Erken çıkış',
                'Erken giriş',
                'İzinli',
                'Konum uyarısı',
              ])
                ChoiceChip(
                  label: Text(f),
                  selected: _focus == f,
                  onSelected: (_) => setState(() => _focus = f),
                ),
            ],
          ),
          const SizedBox(height: 16),
          AsyncValueView<List<AttendanceEvent>>(
            value: ref.watch(
              movementsProvider((from: from, to: to, uid: _uid)),
            ),
            builder: (all) {
              final events = all
                  .where(
                    (e) => switch (_focus) {
                      'Geç giriş' => e.lateMinutes > 0,
                      'Erken çıkış' => e.earlyExit,
                      'Erken giriş' => e.earlyEntry,
                      'İzinli' => e.permitted,
                      'Konum uyarısı' => e.verdict.needsAttention,
                      _ => true,
                    },
                  )
                  .toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${events.length} hareket · ${events.where((e) => e.type.isEntry).length} giriş · ${events.where((e) => e.type.isExit).length} çıkış',
                  ),
                  const SizedBox(height: 12),
                  AppButton(
                    label: 'PDF indir',
                    isLoading: _exporting,
                    onPressed: events.isEmpty
                        ? null
                        : () => _export(events, '$from — $to · $_focus'),
                  ),
                  const SizedBox(height: 16),
                  _EventList(events: events),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _export(List<AttendanceEvent> events, String range) async {
    if (events.length > 10000) {
      Toast.error(
        'PDF için tarih aralığını daraltın. En fazla 10.000 hareket aktarılabilir.',
      );
      return;
    }
    setState(() => _exporting = true);
    try {
      final bytes = await DormPdfService.build(
        ref.read(currentTenantProvider)!.name,
        range,
        events,
      );
      FileDownloadService.download(
        bytes: bytes,
        fileName: 'yurt-giris-cikis.pdf',
      );
    } catch (_) {
      Toast.error(
        'PDF oluşturulamadı. Tarih aralığını daraltıp tekrar deneyin.',
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }
}

class _EventList extends ConsumerWidget {
  const _EventList({required this.events});
  final List<AttendanceEvent> events;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final admin = ref.watch(currentUserProvider)?.role.isAdmin ?? false;
    if (events.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Bu aralıkta hareket yok. Bu bilgi öğrencinin dışarıda olduğunu göstermez.',
        ),
      );
    }
    return Column(
      children: [
        for (final e in events)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(e.type.isEntry ? Icons.login : Icons.logout),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${e.userName}\n${AppDate.dateTime(e.at)} · ${e.type.label}',
                        ),
                      ),
                      if (admin)
                        IconButton(
                          tooltip: 'Yanlış kaydı geçersiz kıl',
                          icon: const Icon(Icons.undo),
                          onPressed: () => _void(context, ref, e),
                        ),
                    ],
                  ),
                  Text(e.checkpointName),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (e.lateMinutes > 0)
                        StatusChip(
                          label: '${e.lateMinutes} dk geç giriş',
                          tone: StatusTone.warning,
                        ),
                      if (e.earlyExit)
                        const StatusChip(
                          label: 'Erken çıkış',
                          tone: StatusTone.warning,
                        ),
                      if (e.earlyEntry)
                        const StatusChip(
                          label: 'Erken giriş',
                          tone: StatusTone.warning,
                        ),
                      if (e.permitted)
                        const StatusChip(
                          label: 'İzin kapsamında',
                          tone: StatusTone.info,
                        ),
                      if (admin && e.verdict.needsAttention)
                        StatusChip(
                          label: e.verdict.label,
                          tone: StatusTone.warning,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _void(
    BuildContext context,
    WidgetRef ref,
    AttendanceEvent event,
  ) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (c) => const _ReasonDialog(),
    );
    if (reason == null) return;
    final result = await ref
        .read(dormRepositoryProvider)
        .voidEvent(
          ref.read(currentTenantProvider)!,
          event,
          ref.read(currentUserProvider)!.uid,
          reason,
        );
    Toast.result(
      result,
      successMessage: 'Kayıt gerekçesiyle geçersiz kılındı.',
    );
  }
}

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog();
  @override
  State<_ReasonDialog> createState() => _ReasonState();
}

class _ReasonState extends State<_ReasonDialog> {
  final _text = TextEditingController();
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Hareketi geçersiz kıl'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Asıl kayıt korunur. Gerekçe ve işlemi yapan yönetici kaydedilir.',
        ),
        TextField(
          controller: _text,
          maxLength: 500,
          decoration: const InputDecoration(labelText: 'Gerekçe'),
          onChanged: (_) => setState(() {}),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Vazgeç'),
      ),
      FilledButton(
        onPressed: _text.text.trim().isEmpty
            ? null
            : () => Navigator.pop(context, _text.text.trim()),
        child: const Text('Geçersiz kıl'),
      ),
    ],
  );
}

class DormLeavePage extends ConsumerStatefulWidget {
  const DormLeavePage({super.key});
  @override
  ConsumerState<DormLeavePage> createState() => _LeaveState();
}

class _LeaveState extends ConsumerState<DormLeavePage> {
  bool _busy = false;
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return const AppScaffold(
        title: 'İzinler',
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final now = ref.watch(dormNowProvider);
    final students = ref.watch(studentsProvider);
    return AppScaffold(
      title: 'İzinler',
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (user.role.isAdmin)
            AppButton(
              label: 'Öğrenci izni tanımla',
              isLoading: _busy,
              onPressed: students.isEmpty ? null : () => _add(students),
            ),
          const SizedBox(height: 12),
          const Text(
            'İzin, öğrencinin beklenen dönüş zamanını belirler. Giriş ve çıkış yine ayrı QR kodlarıyla kaydedilir.',
          ),
          const SizedBox(height: 16),
          AsyncValueView<List<StudentLeave>>(
            value: ref.watch(dormLeavesProvider),
            builder: (leaves) {
              final sorted = [...leaves]
                ..sort((a, b) => b.from.compareTo(a.from));
              if (sorted.isEmpty) return const Text('Henüz izin kaydı yok.');
              final names = ref.watch(usersByIdProvider);
              return Column(
                children: [
                  for (final l in sorted)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              names[l.userId]?.displayName ??
                                  (l.userId == user.uid
                                      ? user.displayName
                                      : 'Öğrenci'),
                            ),
                            Text(
                              '${AppDate.dateTime(l.from)} — ${AppDate.dateTime(l.until)}',
                            ),
                            Text(l.reason),
                            Text(
                              l.revoked
                                  ? 'İptal edildi'
                                  : l.covers(now)
                                  ? 'Aktif izin'
                                  : now.isBefore(l.from)
                                  ? 'Planlandı'
                                  : 'Sona erdi',
                            ),
                            if (user.role.isAdmin &&
                                !l.revoked &&
                                l.until.isAfter(now))
                              TextButton(
                                onPressed: _busy ? null : () => _revoke(l),
                                child: const Text('İzni iptal et'),
                              ),
                          ],
                        ),
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

  Future<void> _add(List<AppUser> students) async {
    final value = await showDialog<StudentLeave>(
      context: context,
      builder: (c) => _LeaveDialog(students: students),
    );
    if (value == null) return;
    setState(() => _busy = true);
    final u = ref.read(currentUserProvider)!;
    final result = await ref
        .read(dormRepositoryProvider)
        .saveLeave(u.tenantId, value, u.uid);
    Toast.result(result, successMessage: 'İzin kaydedildi.');
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _revoke(StudentLeave value) async {
    if (!await ConfirmDialog.show(
      context,
      title: 'İzin iptal edilsin mi?',
      message: 'İzin geçmişte korunur, aktif geçerliliği kaldırılır.',
      confirmLabel: 'İptal et',
    )) {
      return;
    }
    setState(() => _busy = true);
    final u = ref.read(currentUserProvider)!;
    final result = await ref
        .read(dormRepositoryProvider)
        .revokeLeave(u.tenantId, value, u.uid);
    Toast.result(result, successMessage: 'İzin iptal edildi.');
    if (mounted) setState(() => _busy = false);
  }
}

class _LeaveDialog extends StatefulWidget {
  const _LeaveDialog({required this.students});
  final List<AppUser> students;
  @override
  State<_LeaveDialog> createState() => _LeaveDialogState();
}

class _LeaveDialogState extends State<_LeaveDialog> {
  final _form = GlobalKey<FormState>();
  final _reason = TextEditingController();
  String? _uid;
  DateTime _from = DateTime.now();
  DateTime _until = DateTime.now().add(const Duration(days: 1));
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pick(bool start) async {
    final current = DormClock.local(start ? _from : _until);
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime(current.year, current.month, current.day),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 366)),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
    );
    if (t == null) return;
    setState(() {
      final v = DormClock.at(d, t.hour * 60 + t.minute);
      if (start) {
        _from = v;
      } else {
        _until = v;
      }
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Öğrenci izni'),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Öğrenci'),
                items: [
                  for (final u in widget.students)
                    DropdownMenuItem(
                      value: u.uid,
                      child: Text(
                        u.displayName,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (v) => _uid = v,
                validator: (v) => v == null ? 'Öğrenci seçin.' : null,
              ),
              ListTile(
                title: const Text('Başlangıç'),
                subtitle: Text(AppDate.dateTime(_from)),
                onTap: () => _pick(true),
              ),
              ListTile(
                title: const Text('Dönüş zamanı'),
                subtitle: Text(AppDate.dateTime(_until)),
                onTap: () => _pick(false),
              ),
              TextFormField(
                controller: _reason,
                maxLength: 500,
                decoration: const InputDecoration(labelText: 'İzin açıklaması'),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Açıklama girin.' : null,
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
          if (!_until.isAfter(_from)) {
            Toast.error('Dönüş zamanı başlangıçtan sonra olmalı.');
            return;
          }
          Navigator.pop(
            context,
            StudentLeave(
              userId: _uid!,
              from: _from,
              until: _until,
              reason: _reason.text.trim(),
            ),
          );
        },
        child: const Text('Kaydet'),
      ),
    ],
  );
}
