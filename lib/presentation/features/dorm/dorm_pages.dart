import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ubsoft_pdks/application/auth/session_provider.dart';
import 'package:ubsoft_pdks/application/dorm/dorm_providers.dart';
import 'package:ubsoft_pdks/application/user/user_providers.dart';
import 'package:ubsoft_pdks/core/extensions/context_x.dart';
import 'package:ubsoft_pdks/core/routing/app_routes.dart';
import 'package:ubsoft_pdks/core/theme/app_colors.dart';
import 'package:ubsoft_pdks/core/theme/app_spacing.dart';
import 'package:ubsoft_pdks/core/theme/app_typography.dart';
import 'package:ubsoft_pdks/core/utils/date_x.dart';
import 'package:ubsoft_pdks/domain/entities/app_user.dart';
import 'package:ubsoft_pdks/domain/entities/attendance_event.dart';
import 'package:ubsoft_pdks/domain/entities/dormitory.dart';
import 'package:ubsoft_pdks/presentation/features/dorm/widgets/dorm_ui.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_button.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_card.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_scaffold.dart';
import 'package:ubsoft_pdks/presentation/widgets/async_value_view.dart';
import 'package:ubsoft_pdks/presentation/widgets/confirm_dialog.dart';
import 'package:ubsoft_pdks/services/export/dorm_pdf_service.dart';
import 'package:ubsoft_pdks/services/export/file_download_service.dart';
import 'package:ubsoft_pdks/services/notification/toast_service.dart';

class DormDashboardPage extends ConsumerStatefulWidget {
  const DormDashboardPage({super.key});
  @override
  ConsumerState<DormDashboardPage> createState() => _DormDashboardState();
}

class _DormDashboardState extends ConsumerState<DormDashboardPage> {
  String _status = 'all';
  String _attention = 'all';
  final _search = TextEditingController();
  int _visibleCount = 30;
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _select(String status, [String attention = 'all']) => setState(() {
    _status = status;
    _attention = attention;
    _visibleCount = 30;
  });
  void _reset() {
    _search.clear();
    _select('all');
  }

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(dormNowProvider);
    final tenant = ref.watch(currentTenantProvider);
    if (tenant == null) {
      return const AppScaffold(
        title: 'Yurt Durumu',
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final students = ref.watch(studentsProvider);
    return AppScaffold(
      title: 'Yurt Durumu',
      maxContentWidth: AppWidths.page,
      scrollable: true,
      actions: [
        IconButton(
          tooltip: 'Durumlar ne anlama geliyor?',
          onPressed: _explain,
          icon: const Icon(Icons.help_outline_rounded),
        ),
      ],
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
              final leavesByUser = <String, List<StudentLeave>>{};
              for (final leave in leaves) {
                leavesByUser.putIfAbsent(leave.userId, () => []).add(leave);
              }
              final overdueByUser = {
                for (final student in students)
                  student.uid: tenant.settings.dormPolicy.overdue(
                    state(student),
                    now,
                    relevantLeave(
                      leavesByUser[student.uid] ?? [],
                      state(student),
                      now,
                    ),
                  ),
              };
              bool overdue(AppUser u) => overdueByUser[u.uid] ?? false;
              bool permitted(AppUser u) =>
                  state(u).inside == false &&
                  leaveAt(leavesByUser[u.uid] ?? [], u.uid, now) != null;
              final inside = students
                  .where((u) => state(u).inside == true)
                  .length;
              final outside = students
                  .where((u) => state(u).inside == false)
                  .length;
              final delayed = students.where(overdue).length;
              final onLeave = students.where(permitted).length;
              final unknown = students
                  .where((u) => state(u).inside == null)
                  .length;
              final visible =
                  students.where((u) {
                    final physical = switch (_status) {
                      'inside' => state(u).inside == true,
                      'outside' => state(u).inside == false,
                      'unknown' => state(u).inside == null,
                      _ => true,
                    };
                    final attention = switch (_attention) {
                      'late' => overdue(u),
                      'leave' => permitted(u),
                      'warning' => state(u).warnings.isNotEmpty,
                      _ => true,
                    };
                    return physical &&
                        attention &&
                        dormSearchKey(
                          '${u.displayName} ${u.room} ${u.studentNumber}',
                        ).contains(dormSearchKey(_search.text));
                  }).toList()..sort((a, b) {
                    final urgent = (overdue(b) ? 1 : 0).compareTo(
                      overdue(a) ? 1 : 0,
                    );
                    return urgent != 0
                        ? urgent
                        : dormSearchKey(
                            a.displayName,
                          ).compareTo(dormSearchKey(b.displayName));
                  });
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    tenant.name,
                    style: AppTypography.bodyStrong(context.colors.onSurface),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${AppDate.date(now)} · ${AppDate.time(now)}',
                    style: AppTypography.small(context.colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 20),
                  DormMetricGrid(
                    metrics: [
                      DormMetric(
                        'Toplam öğrenci',
                        students.length,
                        Icons.people_outline_rounded,
                        AppColors.primary,
                        'Aktif öğrenci',
                        () => _select('all'),
                      ),
                      DormMetric(
                        'İçeride',
                        inside,
                        Icons.login_rounded,
                        AppColors.entry,
                        'Son kaydı giriş',
                        () => _select('inside'),
                      ),
                      DormMetric(
                        'Dışarıda',
                        outside,
                        Icons.logout_rounded,
                        AppColors.exit,
                        onLeave == 0
                            ? 'Son kaydı çıkış'
                            : '$onLeave izinli öğrenci dahil',
                        () => _select('outside'),
                      ),
                      DormMetric(
                        'Dönüşü geciken',
                        delayed,
                        Icons.schedule_rounded,
                        AppColors.warning,
                        'Dışarıdakilerin içinden',
                        () => _select('outside', 'late'),
                      ),
                    ],
                  ),
                  if (unknown > 0) ...[
                    const SizedBox(height: 12),
                    AppCard(
                      background: AppColors.primarySurface.withValues(
                        alpha: 0.3,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '$unknown öğrencinin başlangıç kaydı yok. İlk QR okutması veya yönetici doğrulaması bekleniyor.',
                              style: AppTypography.small(
                                context.colors.onSurface,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => _select('unknown'),
                            child: const Text('İncele'),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  DormFilterPanel(
                    onReset:
                        _status != 'all' ||
                            _attention != 'all' ||
                            _search.text.isNotEmpty
                        ? _reset
                        : null,
                    children: [
                      TextField(
                        key: const ValueKey('dashboard-search'),
                        controller: _search,
                        decoration: InputDecoration(
                          hintText: 'Öğrenci, numara veya oda ara',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _search.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Aramayı temizle',
                                  icon: const Icon(Icons.close_rounded),
                                  onPressed: () {
                                    _search.clear();
                                    setState(() {});
                                  },
                                ),
                        ),
                        onChanged: (_) => setState(() => _visibleCount = 30),
                      ),
                      const SizedBox(height: 14),
                      LayoutBuilder(
                        builder: (context, bounds) {
                          final fields = [
                            DormSelect<String>(
                              label: 'Bulunma durumu',
                              value: _status,
                              options: const [
                                DormOption(
                                  'all',
                                  'Tüm öğrenciler',
                                  Icons.people_outline_rounded,
                                ),
                                DormOption(
                                  'inside',
                                  'İçeride',
                                  Icons.login_rounded,
                                ),
                                DormOption(
                                  'outside',
                                  'Dışarıda',
                                  Icons.logout_rounded,
                                ),
                                DormOption(
                                  'unknown',
                                  'Başlangıç bekleyen',
                                  Icons.help_outline_rounded,
                                ),
                              ],
                              onChanged: (v) => setState(() {
                                _status = v;
                                _visibleCount = 30;
                              }),
                            ),
                            DormSelect<String>(
                              label: 'İnceleme',
                              value: _attention,
                              options: const [
                                DormOption(
                                  'all',
                                  'Tüm durumlar',
                                  Icons.filter_list_rounded,
                                ),
                                DormOption(
                                  'late',
                                  'Dönüşü geciken',
                                  Icons.schedule_rounded,
                                ),
                                DormOption(
                                  'leave',
                                  'İzinli dışarıda',
                                  Icons.event_available_outlined,
                                ),
                                DormOption(
                                  'warning',
                                  'Saat uyarısı',
                                  Icons.error_outline_rounded,
                                ),
                              ],
                              onChanged: (v) => setState(() {
                                _attention = v;
                                _visibleCount = 30;
                              }),
                            ),
                          ];
                          return bounds.maxWidth >= 300
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: fields[0]),
                                    const SizedBox(width: 12),
                                    Expanded(child: fields[1]),
                                  ],
                                )
                              : Column(
                                  children: [
                                    fields[0],
                                    const SizedBox(height: 12),
                                    fields[1],
                                  ],
                                );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Text(
                        'Öğrenciler',
                        style: AppTypography.h2(context.colors.onSurface),
                      ),
                      const Spacer(),
                      Text(
                        '${visible.length} öğrenci',
                        style: AppTypography.small(
                          context.colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (visible.isEmpty)
                    DormEmpty(
                      title: students.isEmpty
                          ? 'Henüz aktif öğrenci yok'
                          : 'Bu seçime uyan öğrenci yok',
                      message: students.isEmpty
                          ? 'Öğrenciler bölümünden ilk öğrenciyi ekleyin.'
                          : 'Durum ve inceleme filtrelerini değiştirerek tekrar bakabilirsiniz.',
                      onReset: students.isEmpty ? null : _reset,
                    ),
                  for (final u in visible.take(_visibleCount))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: DormStudentCard(
                        user: u,
                        presence: state(u),
                        overdue: overdue(u),
                        permitted: permitted(u),
                        now: now,
                        onTap: () =>
                            context.push(AppRoutes.personHistoryPath(u.uid)),
                        onInitialize:
                            state(u).inside == null && tenant.isWritable
                            ? () => _initialize(u)
                            : null,
                      ),
                    ),
                  if (visible.length > _visibleCount)
                    OutlinedButton(
                      onPressed: () => setState(() => _visibleCount += 30),
                      child: Text(
                        'Daha fazla göster (${visible.length - _visibleCount})',
                      ),
                    ),
                  const SizedBox(height: 20),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

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

  Future<void> _explain() => showDialog<void>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Durumları doğru okuyun'),
      content: const SingleChildScrollView(
        child: Text(
          'İçeride: Son geçerli kaydı giriş olan öğrenci.\n\nDışarıda: Son geçerli kaydı çıkış olan öğrenci. İzinli ve dönüşü geciken öğrenciler de bu sayıya dahildir.\n\nDönüşü geciken: Dışarıda olan, geçerli izni bulunmayan ve beklenen dönüş saati geçmiş öğrenci. Ayrı bir öğrenci grubu olarak toplama eklenmez.\n\nBaşlangıç kaydı yok: Henüz hareket veya doğrulanmış başlangıç durumu bulunmuyor. Öğrenci içeride ya da dışarıda varsayılmaz.\n\nDurumlar kayıtlı QR hareketlerine dayanır; okutulmamış bir fiziksel geçişi sistem kendiliğinden bilemez.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c),
          child: const Text('Anladım'),
        ),
      ],
    ),
  );
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
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color:
                              (p.inside == null
                                      ? AppColors.neutral
                                      : p.inside!
                                      ? AppColors.entry
                                      : AppColors.exit)
                                  .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          p.inside == null
                              ? Icons.help_outline_rounded
                              : p.inside!
                              ? Icons.login_rounded
                              : Icons.logout_rounded,
                          color: p.inside == null
                              ? AppColors.neutral
                              : p.inside!
                              ? AppColors.entry
                              : AppColors.exit,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Yurttaki durumunuz',
                              style: AppTypography.caption(
                                context.colors.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              p.label,
                              style: AppTypography.h2(
                                p.inside == null
                                    ? context.colors.onSurface
                                    : p.inside!
                                    ? AppColors.entry
                                    : AppColors.exit,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
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
            onRetry: () => ref.invalidate(
              movementsProvider((
                from: DormClock.key(now),
                to: DormClock.key(now),
                uid: user.uid,
              )),
            ),
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
  DateTimeRange? _range;
  @override
  Widget build(BuildContext context) {
    final now = DormClock.local(ref.watch(dormNowProvider));
    final user = ref.watch(currentUserProvider);
    final uid = user?.role.isStaff == true ? user!.uid : widget.userId;
    final selected = ref.watch(usersByIdProvider)[uid];
    final day = _day ?? DateTime(now.year, now.month, now.day);
    final range =
        _range ??
        DateTimeRange(
          start: DateTime(
            now.year,
            now.month,
            now.day,
          ).subtract(const Duration(days: 29)),
          end: now,
        );
    final from = _calendarKey(uid == null ? day : range.start);
    final to = _calendarKey(uid == null ? day : range.end);
    return AppScaffold(
      title: uid == null ? 'Hareket Geçmişi' : 'Öğrenci Geçmişi',
      showBackButton: widget.userId != null,
      maxContentWidth: AppWidths.wide,
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (uid != null) ...[
            Text(
              selected?.displayName ?? user?.displayName ?? 'Öğrenci',
              style: AppTypography.h2(context.colors.onSurface),
            ),
            if (selected != null &&
                (selected.studentNumber.isNotEmpty || selected.room.isNotEmpty))
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  selected.subtitle,
                  style: AppTypography.small(context.colors.onSurfaceVariant),
                ),
              ),
            const SizedBox(height: 8),
            Text(
              'Bir güne dokunarak bütün giriş ve çıkışları açın.',
              style: AppTypography.small(context.colors.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
          ],
          _DateRangeField(
            label: uid == null
                ? _displayDate(from)
                : '${_displayDate(from)} — ${_displayDate(to)}',
            onTap: () async {
              if (uid == null) {
                final d = await showDatePicker(
                  context: context,
                  initialDate: day,
                  firstDate: DateTime(2020),
                  lastDate: now,
                );
                if (d != null) setState(() => _day = d);
              } else {
                final r = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: now,
                  initialDateRange: range,
                );
                if (r == null) return;
                if (r.duration.inDays > 366) {
                  Toast.error('Tek seferde en fazla bir yıl seçin.');
                  return;
                }
                setState(() => _range = r);
              }
            },
          ),
          const SizedBox(height: 20),
          const _MovementLegend(),
          const SizedBox(height: 12),
          AsyncValueView<List<AttendanceEvent>>(
            onRetry: () => ref.invalidate(
              movementsProvider((from: from, to: to, uid: uid)),
            ),
            value: ref.watch(movementsProvider((from: from, to: to, uid: uid))),
            builder: (events) => _GroupedMovements(
              key: ValueKey('history-$from-$to-$uid'),
              events: events,
              byStudent: uid == null,
            ),
          ),
        ],
      ),
    );
  }
}

String _calendarKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _displayDate(String key) {
  final parts = key.split('-');
  return '${parts[2]}.${parts[1]}.${parts[0]}';
}

String _focusLabel(String value) => switch (value) {
  'late' => 'Geç giriş',
  'earlyExit' => 'Erken çıkış',
  'earlyEntry' => 'Erken giriş',
  'leave' => 'İzinli',
  'location' => 'Konum uyarısı',
  _ => 'Tüm hareketler',
};

class _DateRangeField extends StatelessWidget {
  const _DateRangeField({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => DormActionField(
    label: 'Tarih aralığı',
    value: label,
    icon: Icons.date_range_rounded,
    onTap: onTap,
  );
}

class DormReportPage extends ConsumerStatefulWidget {
  const DormReportPage({super.key});
  @override
  ConsumerState<DormReportPage> createState() => _DormReportState();
}

class _DormReportState extends ConsumerState<DormReportPage> {
  DateTimeRange? _range;
  String? _uid;
  String _focus = 'all';
  bool _exporting = false;
  final Map<String, String> _knownNames = {};
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
    final from = _calendarKey(range.start);
    final to = _calendarKey(range.end);
    final users = ref.watch(usersProvider).value ?? <AppUser>[];
    final movementState = ref.watch(
      movementsProvider((from: from, to: to, uid: _uid)),
    );
    for (final event in movementState.value ?? <AttendanceEvent>[]) {
      _knownNames[event.userId] = event.userName;
    }
    final names = {
      ..._knownNames,
      for (final u in users.where((u) => u.role.isStaff)) u.uid: u.displayName,
    };
    return AppScaffold(
      title: 'Raporlar',
      maxContentWidth: AppWidths.wide,
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Öğrenci hareketlerini inceleyin',
            style: AppTypography.h2(context.colors.onSurface),
          ),
          const SizedBox(height: 6),
          Text(
            'Öğrenciyi ve günü açın; tüm giriş–çıkışları saatleriyle görün.',
            style: AppTypography.small(context.colors.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          DormFilterPanel(
            onReset: _uid != null || _focus != 'all' || _range != null
                ? () => setState(() {
                    _uid = null;
                    _focus = 'all';
                    _range = null;
                  })
                : null,
            children: [
              _DateRangeField(
                label: '${_displayDate(from)} — ${_displayDate(to)}',
                onTap: () async {
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: now,
                    initialDateRange: range,
                  );
                  if (picked == null) return;
                  if (picked.duration.inDays > 366) {
                    Toast.error('Tek raporda en fazla bir yıl seçin.');
                    return;
                  }
                  setState(() => _range = picked);
                },
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, bounds) {
                  final fields = [
                    DormStudentPicker(
                      names: names,
                      value: _uid,
                      onChanged: (v) => setState(() => _uid = v),
                    ),
                    DormSelect<String>(
                      label: 'Hareket filtresi',
                      value: _focus,
                      options: const [
                        DormOption(
                          'all',
                          'Tüm hareketler',
                          Icons.filter_list_rounded,
                        ),
                        DormOption('late', 'Geç giriş', Icons.schedule_rounded),
                        DormOption(
                          'earlyExit',
                          'Erken çıkış',
                          Icons.logout_rounded,
                        ),
                        DormOption(
                          'earlyEntry',
                          'Erken giriş',
                          Icons.login_rounded,
                        ),
                        DormOption(
                          'leave',
                          'İzinli',
                          Icons.event_available_outlined,
                        ),
                        DormOption(
                          'location',
                          'Konum uyarısı',
                          Icons.location_on_outlined,
                        ),
                      ],
                      onChanged: (v) => setState(() => _focus = v),
                    ),
                  ];
                  return bounds.maxWidth >= 580
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: fields[0]),
                            const SizedBox(width: 12),
                            Expanded(child: fields[1]),
                          ],
                        )
                      : Column(
                          children: [
                            fields[0],
                            const SizedBox(height: 14),
                            fields[1],
                          ],
                        );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          AsyncValueView<List<AttendanceEvent>>(
            onRetry: () => ref.invalidate(
              movementsProvider((from: from, to: to, uid: _uid)),
            ),
            value: movementState,
            builder: (all) {
              final events = all
                  .where(
                    (e) => switch (_focus) {
                      'late' => e.lateMinutes > 0,
                      'earlyExit' => e.earlyExit,
                      'earlyEntry' => e.earlyEntry,
                      'leave' => e.permitted,
                      'location' => e.verdict.needsAttention,
                      _ => true,
                    },
                  )
                  .toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${events.map((e) => e.userId).toSet().length} öğrenci · ${events.length} hareket',
                              style: AppTypography.bodyStrong(
                                context.colors.onSurface,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${events.where((e) => e.type.isEntry).length} giriş · ${events.where((e) => e.type.isExit).length} çıkış',
                              style: AppTypography.caption(
                                context.colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      AppButton(
                        label: 'PDF indir',
                        icon: Icons.file_download_outlined,
                        size: AppButtonSize.small,
                        isLoading: _exporting,
                        onPressed: events.isEmpty
                            ? null
                            : () => _export(
                                events,
                                '${_displayDate(from)} — ${_displayDate(to)} · ${_focusLabel(_focus)}${_uid == null ? '' : ' · ${names[_uid] ?? 'Seçili öğrenci'}'}',
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const _MovementLegend(),
                  const SizedBox(height: 12),
                  _GroupedMovements(
                    key: ValueKey('report-$from-$to-$_uid-$_focus'),
                    events: events,
                    byStudent: _uid == null,
                  ),
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

class _MovementLegend extends StatelessWidget {
  const _MovementLegend();
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 16,
    runSpacing: 6,
    children: [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.login_rounded, size: 15, color: AppColors.entry),
          const SizedBox(width: 5),
          Text('Giriş', style: AppTypography.caption(AppColors.entry)),
        ],
      ),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.logout_rounded, size: 15, color: AppColors.exit),
          const SizedBox(width: 5),
          Text('Çıkış', style: AppTypography.caption(AppColors.exit)),
        ],
      ),
      Text(
        'Özet saatler: ilk giriş · son çıkış',
        style: AppTypography.caption(context.colors.onSurfaceVariant),
      ),
    ],
  );
}

class _GroupedMovements extends StatefulWidget {
  const _GroupedMovements({
    required this.events,
    required this.byStudent,
    super.key,
  });
  final List<AttendanceEvent> events;
  final bool byStudent;
  @override
  State<_GroupedMovements> createState() => _GroupedMovementsState();
}

class _GroupedMovementsState extends State<_GroupedMovements> {
  final Set<String> _students = {};
  final Set<String> _days = {};
  int _limit = 30;
  void _toggle(Set<String> target, String key) => setState(() {
    if (!target.add(key)) target.remove(key);
  });
  @override
  Widget build(BuildContext context) {
    if (widget.events.isEmpty) {
      return const DormEmpty(
        title: 'Bu aralıkta hareket yok',
        message:
            'Farklı bir tarih veya hareket filtresi seçin. Kayıt olmaması öğrencinin dışarıda olduğu anlamına gelmez.',
      );
    }
    if (!widget.byStudent) return Column(children: _dayRows(widget.events));
    final groups = <String, List<AttendanceEvent>>{};
    for (final e in widget.events) {
      groups.putIfAbsent(e.userId, () => []).add(e);
    }
    final keys = groups.keys.toList()
      ..sort(
        (a, b) => dormSearchKey(
          groups[a]!.first.userName,
        ).compareTo(dormSearchKey(groups[b]!.first.userName)),
      );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final uid in keys.take(_limit))
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    button: true,
                    expanded: _students.contains(uid),
                    child: InkWell(
                      key: ValueKey('student-group-$uid'),
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _toggle(_students, uid),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              radius: 18,
                              backgroundColor: AppColors.primarySurface,
                              child: Icon(
                                Icons.person_outline_rounded,
                                size: 19,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    groups[uid]!.first.userName,
                                    style: AppTypography.bodyStrong(
                                      context.colors.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${groups[uid]!.map((e) => e.dateKey).toSet().length} gün · ${groups[uid]!.length} hareket',
                                    style: AppTypography.caption(
                                      context.colors.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              _students.contains(uid)
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              color: context.colors.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_students.contains(uid))
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                      child: Column(children: _dayRows(groups[uid]!)),
                    ),
                ],
              ),
            ),
          ),
        if (keys.length > _limit)
          OutlinedButton(
            onPressed: () => setState(() => _limit += 30),
            child: const Text('Daha fazla öğrenci göster'),
          ),
      ],
    );
  }

  List<Widget> _dayRows(List<AttendanceEvent> events) {
    final groups = <String, List<AttendanceEvent>>{};
    for (final e in events) {
      groups.putIfAbsent(e.dateKey, () => []).add(e);
    }
    final dates = groups.keys.toList()..sort((a, b) => b.compareTo(a));
    return [
      for (final date in dates)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AppCard(
            padding: EdgeInsets.zero,
            background: context.colors.surfaceContainerLowest,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DormDaySummary(
                  key: ValueKey('day-group-${events.first.userId}-$date'),
                  events: groups[date]!,
                  expanded: _days.contains('${events.first.userId}-$date'),
                  onTap: () => _toggle(_days, '${events.first.userId}-$date'),
                ),
                if (_days.contains('${events.first.userId}-$date'))
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                    child: _EventList(
                      events: [...groups[date]!]
                        ..sort((a, b) => a.at.compareTo(b.at)),
                    ),
                  ),
              ],
            ),
          ),
        ),
    ];
  }
}

class _EventList extends ConsumerWidget {
  const _EventList({required this.events});
  final List<AttendanceEvent> events;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final admin =
        ref.watch(currentUserProvider)?.role.isAdmin == true &&
        ref.watch(currentTenantProvider)?.isWritable == true;
    if (events.isEmpty) {
      return const DormEmpty(
        title: 'Henüz hareket yok',
        message:
            'Giriş veya çıkış QR kodunu okuttuğunuzda kaydınız burada görünür.',
      );
    }
    return Column(
      children: [
        for (final e in events)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: DormMovementTile(
              event: e,
              onVoid: admin ? () => _void(context, ref, e) : null,
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
