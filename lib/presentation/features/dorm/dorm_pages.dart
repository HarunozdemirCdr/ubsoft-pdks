import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ubsoft_pdks/application/auth/session_provider.dart';
import 'package:ubsoft_pdks/application/dorm/dorm_providers.dart';
import 'package:ubsoft_pdks/application/user/user_providers.dart';
import 'package:ubsoft_pdks/core/extensions/context_x.dart';
import 'package:ubsoft_pdks/core/routing/app_routes.dart';
import 'package:ubsoft_pdks/core/theme/app_colors.dart';
import 'package:ubsoft_pdks/core/theme/app_radius.dart';
import 'package:ubsoft_pdks/core/theme/app_spacing.dart';
import 'package:ubsoft_pdks/core/theme/app_typography.dart';
import 'package:ubsoft_pdks/core/utils/date_x.dart';
import 'package:ubsoft_pdks/domain/entities/app_user.dart';
import 'package:ubsoft_pdks/domain/entities/attendance_event.dart';
import 'package:ubsoft_pdks/domain/entities/dormitory.dart';
import 'package:ubsoft_pdks/domain/usecases/dorm/dorm_duration.dart';
import 'package:ubsoft_pdks/presentation/features/dorm/widgets/dorm_ui.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_button.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_card.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_scaffold.dart';
import 'package:ubsoft_pdks/presentation/widgets/async_value_view.dart';
import 'package:ubsoft_pdks/presentation/widgets/confirm_dialog.dart';
import 'package:ubsoft_pdks/presentation/widgets/section_header.dart';
import 'package:ubsoft_pdks/presentation/widgets/status_chip.dart';
import 'package:ubsoft_pdks/services/notification/toast_service.dart';

export 'package:ubsoft_pdks/presentation/features/dorm/dorm_reports_page.dart'
    show DormReportPage;

class DormDashboardPage extends ConsumerStatefulWidget {
  const DormDashboardPage({super.key});
  @override
  ConsumerState<DormDashboardPage> createState() => _DormDashboardState();
}

class _DormDashboardState extends ConsumerState<DormDashboardPage> {
  final TextEditingController _search = TextEditingController();
  String _status = 'all';
  String _attention = 'all';
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

  void _toggle(String status, [String attention = 'all']) =>
      (_status == status && _attention == attention)
      ? _select('all')
      : _select(status, attention);

  void _reset() => setState(() {
    _search.clear();
    _status = 'all';
    _attention = 'all';
    _visibleCount = 30;
  });

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
              final warningCount = students
                  .where((u) => state(u).warnings.isNotEmpty)
                  .length;
              final unknown = students
                  .where((u) => state(u).inside == null)
                  .length;
              final String searchKey = dormSearchKey(_search.text);
              final visible =
                  students.where((u) {
                    if (searchKey.isNotEmpty) {
                      final matchesQuery =
                          dormSearchKey(u.displayName).contains(searchKey) ||
                          dormSearchKey(u.room).contains(searchKey) ||
                          dormSearchKey(u.studentNumber).contains(searchKey);
                      if (!matchesQuery) return false;
                    }
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
                    return physical && attention;
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
              final recentState = ref.watch(recentMovementsProvider);
              final isFiltered =
                  _status != 'all' ||
                  _attention != 'all' ||
                  _search.text.trim().isNotEmpty;
              final allRecent = [
                ...(recentState.value ?? const <AttendanceEvent>[]),
              ]..sort((a, b) => b.at.compareTo(a.at));
              final recentLogs = allRecent.take(10).toList();

              Widget buildMetrics({required bool forceTwoColumns}) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DormMetricGrid(
                    forceTwoColumns: forceTwoColumns,
                    metrics: [
                      DormMetric(
                        'Toplam öğrenci',
                        students.length,
                        Icons.people_outline_rounded,
                        AppColors.primary,
                        'Aktif öğrenci',
                        () => _select('all'),
                        selected: !isFiltered,
                      ),
                      DormMetric(
                        'İçeride',
                        inside,
                        Icons.login_rounded,
                        AppColors.entry,
                        'Son kaydı giriş',
                        () => _toggle('inside'),
                        selected: _status == 'inside' && _attention == 'all',
                      ),
                      DormMetric(
                        'Dışarıda',
                        outside,
                        Icons.logout_rounded,
                        AppColors.exit,
                        onLeave == 0
                            ? 'Son kaydı çıkış'
                            : '$onLeave izinli öğrenci dahil',
                        () => _toggle('outside'),
                        selected: _status == 'outside' && _attention == 'all',
                      ),
                      DormMetric(
                        'Dönüşü geciken',
                        delayed,
                        Icons.schedule_rounded,
                        AppColors.warning,
                        'Dışarıda ve dönüş saati geçti',
                        () => _toggle('outside', 'late'),
                        selected: _attention == 'late',
                      ),
                      DormMetric(
                        'İzinli dışarıda',
                        onLeave,
                        Icons.event_available_outlined,
                        AppColors.primary,
                        'Aktif izin kapsamında',
                        () => _toggle('outside', 'leave'),
                        selected: _attention == 'leave',
                      ),
                      DormMetric(
                        'Saat uyarısı',
                        warningCount,
                        Icons.error_outline_rounded,
                        AppColors.warning,
                        'Geç giriş / erken çıkış',
                        () => _toggle('all', 'warning'),
                        selected: _attention == 'warning',
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
                ],
              );

              final recentLogsSection = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SectionTitleRow(
                    title: 'Son Hareketler',
                    trailing: 'Son ${recentLogs.length} kayıt',
                  ),
                  const SizedBox(height: 12),
                  if (recentState.isLoading && recentState.value == null)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (recentLogs.isEmpty)
                    const DormEmpty(
                      title: 'Henüz son hareket yok',
                      message:
                          'Öğrenciler QR okuttuğunda en son 10 hareket burada üstte görünür.',
                    )
                  else
                    for (final event in recentLogs)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: DormRecentMovementCard(
                          event: event,
                          onTap: () => context.push(
                            AppRoutes.personHistoryPath(event.userId),
                          ),
                        ),
                      ),
                ],
              );

              final studentsSection = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SectionTitleRow(
                    title: 'Öğrenciler',
                    trailing: '${visible.length} öğrenci',
                    actionLabel: isFiltered ? 'Tümü' : null,
                    onAction: isFiltered ? _reset : null,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const ValueKey('dorm-student-search'),
                    controller: _search,
                    onChanged: (_) => setState(() => _visibleCount = 30),
                    decoration: InputDecoration(
                      hintText: 'Öğrenci adı, oda no veya öğrenci no ara...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      isDense: true,
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Temizle',
                              onPressed: () {
                                _search.clear();
                                setState(() => _visibleCount = 30);
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (visible.isEmpty)
                    DormEmpty(
                      title: students.isEmpty
                          ? 'Henüz aktif öğrenci yok'
                          : 'Bu seçime uyan öğrenci yok',
                      message: students.isEmpty
                          ? 'Öğrenciler bölümünden ilk öğrenciyi ekleyin.'
                          : 'Üstteki özet kartlarından başka bir durum seçebilir veya tüm öğrencilere dönebilirsiniz.',
                      onReset: students.isEmpty ? null : _reset,
                    ),
                  for (final u in visible.take(_visibleCount))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
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
                ],
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 18,
                    ),
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
                              'KURUMSAL YURT YÖNETİMİ',
                              style: AppTypography.eyebrow(
                                AppColors.white.withValues(alpha: 0.72),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              tenant.name,
                              style: AppTypography.h2(AppColors.white),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${AppDate.date(now)} · ${AppDate.dayName(now)}',
                              style: AppTypography.small(
                                AppColors.white.withValues(alpha: 0.78),
                              ),
                            ),
                          ],
                        ),
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
                                'ANLIK DOLULUK',
                                style: AppTypography.eyebrow(
                                  AppColors.white.withValues(alpha: 0.72),
                                ).copyWith(fontSize: 10),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$inside / ${students.length} içeride',
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
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  buildMetrics(forceTwoColumns: false),
                  const SizedBox(height: 20),
                  LayoutBuilder(
                    builder: (context, bounds) {
                      if (bounds.maxWidth >= 960) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 12, child: studentsSection),
                            const SizedBox(width: 24),
                            Expanded(flex: 9, child: recentLogsSection),
                          ],
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          studentsSection,
                          const SizedBox(height: 20),
                          recentLogsSection,
                        ],
                      );
                    },
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
          'İçeride: Son geçerli kaydı giriş olan öğrenci.\n\nDışarıda: Son geçerli kaydı çıkış olan öğrenci. İzinli ve dönüşü geciken öğrenciler de bu sayıya dahildir.\n\nDönüşü geciken: Şu an hâlâ dışarıda olan, geçerli izni bulunmayan ve beklenen dönüş saati geçmiş öğrenci.\n\nİzinli dışarıda: Dışarıda olup aktif bir yurt izni kapsamında olan öğrenci.\n\nSaat uyarısı: Son okutmasında geç giriş, erken çıkış veya erken giriş uyarısı bulunan öğrenci (içeride olsa bile son girişi geç saatte yapılmışsa burada görünür).\n\nBaşlangıç kaydı yok: Henüz hareket veya doğrulanmış başlangıç durumu bulunmuyor. Öğrenci içeride ya da dışarıda varsayılmaz.\n\nDurumlar kayıtlı QR hareketlerine dayanır; okutulmamış bir fiziksel geçişi sistem kendiliğinden bilemez.',
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

class _SectionTitleRow extends StatelessWidget {
  const _SectionTitleRow({
    required this.title,
    required this.trailing,
    this.actionLabel,
    this.onAction,
  });
  final String title;
  final String trailing;
  final String? actionLabel;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.h2(context.colors.onSurface),
        ),
      ),
      if (actionLabel != null && onAction != null) ...[
        const SizedBox(width: 6),
        TextButton(
          onPressed: onAction,
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          ),
          child: Text(actionLabel!),
        ),
      ],
      const SizedBox(width: 8),
      Text(
        trailing,
        style: AppTypography.small(context.colors.onSurfaceVariant),
      ),
    ],
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
          AppSpacing.vMd,
          Text(
            user.displayName.isEmpty
                ? 'Merhaba'
                : 'Merhaba, ${user.displayName}',
            style: AppTypography.h1(context.colors.onSurface),
          ),
          AppSpacing.vXxs,
          Text(
            '${AppDate.date(now)} · ${AppDate.dayName(now)}',
            style: AppTypography.small(context.colors.onSurfaceVariant),
          ),
          AppSpacing.vLg,
          const SectionHeader(
            eyebrow: 'ŞU AN',
            title: 'Yurttaki Durumunuz',
          ),
          AppSpacing.vSm,
          AsyncValueView<Presence>(
            value: ref.watch(myPresenceProvider),
            builder: (p) {
              final Duration? ongoing = DormDurationCalculator.ongoingDuration(
                p,
                now,
              );
              final Color badgeColor = p.inside == null
                  ? AppColors.gray300
                  : p.inside!
                  ? AppColors.entryOnDark
                  : AppColors.exitOnDark;
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: AppColors.navy,
                  borderRadius: AppRadius.allMd,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppColors.white.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            p.inside == null
                                ? Icons.help_outline_rounded
                                : p.inside!
                                ? Icons.login_rounded
                                : Icons.logout_rounded,
                            size: 20,
                            color: badgeColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'YURTTAKİ DURUMUNUZ',
                                style: AppTypography.eyebrow(
                                  AppColors.white.withValues(alpha: 0.72),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                p.label,
                                style: AppTypography.h2(AppColors.white),
                              ),
                            ],
                          ),
                        ),
                        if (ongoing != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.white.withValues(alpha: 0.12),
                              borderRadius: AppRadius.allSm,
                            ),
                            child: Text(
                              DormDurationCalculator.formatDuration(ongoing),
                              style: AppTypography.caption(
                                AppColors.white,
                              ).copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Divider(
                      height: 1,
                      color: AppColors.white.withValues(alpha: 0.14),
                    ),
                    const SizedBox(height: 14),
                    if (p.at != null)
                      Text(
                        'Son hareket: ${AppDate.dateTime(p.at!)}',
                        style: AppTypography.small(
                          AppColors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    if (p.inside == null)
                      Text(
                        'İlk giriş veya çıkış okutmanızla durumunuz belirlenir.',
                        style: AppTypography.small(
                          AppColors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    for (final w in p.warnings)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          w,
                          style: AppTypography.small(AppColors.warningOnDark),
                        ),
                      ),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.white,
                          foregroundColor: AppColors.navy,
                          elevation: 0,
                          shape: const RoundedRectangleBorder(
                            borderRadius: AppRadius.allMd,
                          ),
                          textStyle: AppTypography.label(AppColors.navy),
                        ),
                        onPressed: () => context.push(AppRoutes.scanPath),
                        icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                        label: Text(
                          p.inside == true
                              ? 'Çıkış QR kodunu okut'
                              : p.inside == false
                              ? 'Giriş QR kodunu okut'
                              : 'Giriş / çıkış QR kodunu okut',
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: Text(
                        'Girişte giriş QR’ını, çıkışta çıkış QR’ını kullanın.',
                        style: AppTypography.caption(
                          AppColors.white.withValues(alpha: 0.68),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          AsyncValueView<List<StudentLeave>>(
            value: ref.watch(dormLeavesProvider),
            builder: (leaves) {
              final leave = leaveAt(leaves, user.uid, now);
              return leave == null
                  ? const SizedBox.shrink()
                  : AppCard(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.event_available_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          AppSpacing.hSm,
                          Expanded(
                            child: Text(
                              'İzinlisiniz · Dönüş: ${AppDate.dateTime(leave.until)}',
                              style: AppTypography.bodyStrong(
                                context.colors.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
            },
          ),
          AppSpacing.vLg,
          const SectionHeader(
            eyebrow: 'GEÇMİŞ',
            title: 'Bugünkü Hareketlerim',
          ),
          AppSpacing.vSm,
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
  final TextEditingController _search = TextEditingController();
  DateTimeRange? _range;
  String _preset = 'today';
  String _focus = 'all';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  DateTimeRange _defaultRange(DateTime localNow, bool isPersonView) {
    final DateTime today = DateTime(localNow.year, localNow.month, localNow.day);
    if (isPersonView) {
      return DateTimeRange(
        start: today.subtract(const Duration(days: 29)),
        end: today,
      );
    }
    return switch (_preset) {
      'yesterday' => DateTimeRange(
        start: today.subtract(const Duration(days: 1)),
        end: today.subtract(const Duration(days: 1)),
      ),
      'week' => DateTimeRange(
        start: today.subtract(const Duration(days: 6)),
        end: today,
      ),
      'month' => DateTimeRange(
        start: today.subtract(const Duration(days: 29)),
        end: today,
      ),
      _ => DateTimeRange(start: today, end: today),
    };
  }

  void _selectPreset(String preset) => setState(() {
    _preset = preset;
    _range = null;
  });

  @override
  Widget build(BuildContext context) {
    final rawNow = ref.watch(dormNowProvider);
    final now = DormClock.local(rawNow);
    final user = ref.watch(currentUserProvider);
    final uid = user?.role.isStaff == true ? user!.uid : widget.userId;
    final usersById = ref.watch(usersByIdProvider);
    final selected = uid == null ? null : usersById[uid];
    final range = _range ?? _defaultRange(now, uid != null);
    final from = dormCalendarKey(range.start);
    final to = dormCalendarKey(range.end);
    final queryRangeLabel = from == to
        ? dormDisplayDate(from)
        : '${dormDisplayDate(from)} — ${dormDisplayDate(to)}';

    final states = ref.watch(residentsProvider).value ?? const <Presence>[];
    final Presence? selectedPresence = uid == null
        ? null
        : states.cast<Presence?>().firstWhere(
            (p) => p?.userId == uid,
            orElse: () => null,
          );
    final Duration? ongoing = selectedPresence == null
        ? null
        : DormDurationCalculator.ongoingDuration(selectedPresence, rawNow);

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
            if (selectedPresence != null && selectedPresence.inside != null) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  StatusChip(
                    label:
                        '${selectedPresence.label}${ongoing == null ? '' : ' · ${DormDurationCalculator.formatDuration(ongoing)}'}',
                    icon: selectedPresence.inside == true
                        ? Icons.login_rounded
                        : Icons.logout_rounded,
                    tone: selectedPresence.inside == true
                        ? StatusTone.success
                        : StatusTone.danger,
                  ),
                  if (selectedPresence.at != null)
                    StatusChip(
                      label:
                          'Son okutma: ${AppDate.dateTime(selectedPresence.at!)}',
                      tone: StatusTone.neutral,
                    ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Bir güne dokunarak o günkü giriş–çıkışları ve kalma sürelerini açın.',
              style: AppTypography.small(context.colors.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
          ] else ...[
            const SectionHeader(
              eyebrow: 'KAYIT ARŞİVİ',
              title: 'Hareket Geçmişi',
              description:
                  'Tarih, öğrenci adı, oda numarası veya duruma göre geçmiş kayıtları sorgulayın.',
            ),
            const SizedBox(height: 14),
            DormSegmentedBar<String>(
              value: _range == null ? _preset : 'custom',
              options: const [
                DormSegmentedOption('today', 'Bugün'),
                DormSegmentedOption('yesterday', 'Dün'),
                DormSegmentedOption('week', 'Son 7 gün'),
                DormSegmentedOption('month', 'Son 30 gün'),
              ],
              onChanged: _selectPreset,
            ),
            const SizedBox(height: 12),
          ],
          DormDateRangeField(
            label: queryRangeLabel,
            onTap: () async {
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
            },
          ),
          if (uid == null) ...[
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('history-search'),
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Öğrenci adı, oda no, öğrenci no veya kapı ara...',
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
              value: _focus,
              options: const [
                DormSegmentedOption('all', 'Tümü'),
                DormSegmentedOption('late', 'Geç giriş'),
                DormSegmentedOption('earlyExit', 'Erken çıkış'),
                DormSegmentedOption('leave', 'İzinli'),
                DormSegmentedOption('location', 'Konum uyarısı'),
              ],
              onChanged: (v) => setState(() => _focus = v),
            ),
          ],
          const SizedBox(height: 16),
          AsyncValueView<List<AttendanceEvent>>(
            onRetry: () => ref.invalidate(
              movementsProvider((from: from, to: to, uid: uid)),
            ),
            value: ref.watch(movementsProvider((from: from, to: to, uid: uid))),
            builder: (events) {
              final q = dormSearchKey(_search.text);
              final filtered = events.where((e) {
                if (uid == null && q.isNotEmpty) {
                  final stu = usersById[e.userId];
                  final hit =
                      dormSearchKey(e.userName).contains(q) ||
                      dormSearchKey(e.checkpointName).contains(q) ||
                      dormSearchKey(stu?.room ?? '').contains(q) ||
                      dormSearchKey(stu?.studentNumber ?? '').contains(q);
                  if (!hit) return false;
                }
                if (uid == null) {
                  final matchFocus = switch (_focus) {
                    'late' => e.lateMinutes > 0,
                    'earlyExit' => e.earlyExit,
                    'leave' => e.permitted,
                    'location' => e.verdict.needsAttention,
                    _ => true,
                  };
                  if (!matchFocus) return false;
                }
                return true;
              }).toList();

              final overall = _computeAggregateSummary(
                filtered,
                now: rawNow,
                singleUser: uid != null,
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (filtered.isNotEmpty) ...[
                    _HistorySummaryStrip(
                      studentCount: filtered
                          .map((e) => e.userId)
                          .toSet()
                          .length,
                      eventCount: filtered.length,
                      insideDuration: overall.inside,
                      outsideDuration: overall.outside,
                      warningCount: filtered
                          .where(
                            (e) =>
                                e.lateMinutes > 0 ||
                                e.earlyExit ||
                                e.earlyEntry ||
                                e.verdict.needsAttention,
                          )
                          .length,
                    ),
                    const SizedBox(height: 14),
                  ],
                  const DormMovementLegend(),
                  const SizedBox(height: 12),
                  DormGroupedMovements(
                    key: ValueKey('history-$from-$to-$uid-$_focus-$q'),
                    events: filtered,
                    byStudent: uid == null,
                    usersById: usersById,
                    now: rawNow,
                    onOpenStudent: uid == null
                        ? (studentId) =>
                              context.push(AppRoutes.personHistoryPath(studentId))
                        : null,
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

({Duration inside, Duration outside}) _computeAggregateSummary(
  List<AttendanceEvent> events, {
  required DateTime now,
  required bool singleUser,
}) {
  if (events.isEmpty) return (inside: Duration.zero, outside: Duration.zero);
  final byUser = <String, List<AttendanceEvent>>{};
  for (final e in events) {
    byUser.putIfAbsent(e.userId, () => []).add(e);
  }
  Duration inside = Duration.zero;
  Duration outside = Duration.zero;
  for (final entry in byUser.entries) {
    final s = DormDurationCalculator.summarize(
      entry.value,
      userId: entry.key,
      now: now,
      includeOngoing: singleUser,
    );
    inside += s.insideDuration;
    outside += s.outsideDuration;
  }
  return (inside: inside, outside: outside);
}

class _HistorySummaryStrip extends StatelessWidget {
  const _HistorySummaryStrip({
    required this.studentCount,
    required this.eventCount,
    required this.insideDuration,
    required this.outsideDuration,
    required this.warningCount,
  });

  final int studentCount;
  final int eventCount;
  final Duration insideDuration;
  final Duration outsideDuration;
  final int warningCount;

  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    child: Wrap(
      spacing: 18,
      runSpacing: 8,
      children: [
        _StatPill(
          label: 'Hareket',
          value: '$eventCount ($studentCount öğrenci)',
          color: AppColors.primary,
        ),
        _StatPill(
          label: 'Toplam içeride',
          value: DormDurationCalculator.formatDuration(insideDuration),
          color: AppColors.entry,
        ),
        _StatPill(
          label: 'Toplam dışarıda',
          value: DormDurationCalculator.formatDuration(outsideDuration),
          color: AppColors.exit,
        ),
        if (warningCount > 0)
          _StatPill(
            label: 'Uyarı',
            value: '$warningCount',
            color: AppColors.warning,
          ),
      ],
    ),
  );
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 8),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTypography.caption(context.colors.onSurfaceVariant),
          ),
          const SizedBox(height: 1),
          Text(
            value,
            style: AppTypography.bodyStrong(context.colors.onSurface).copyWith(
              fontSize: 13.5,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    ],
  );
}

String dormCalendarKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String dormDisplayDate(String key) {
  final parts = key.split('-');
  return '${parts[2]}.${parts[1]}.${parts[0]}';
}

String dormFocusLabel(String value) => switch (value) {
  'entry' => 'Yalnızca giriş',
  'exit' => 'Yalnızca çıkış',
  'late' => 'Geç giriş',
  'earlyExit' => 'Erken çıkış',
  'earlyEntry' => 'Erken giriş',
  'leave' => 'İzinli',
  'location' => 'Konum uyarısı',
  _ => 'Tüm hareketler',
};

class DormDateRangeField extends StatelessWidget {
  const DormDateRangeField({
    required this.label,
    required this.onTap,
    super.key,
  });
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

class DormMovementLegend extends StatelessWidget {
  const DormMovementLegend({super.key});
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

class DormGroupedMovements extends StatefulWidget {
  const DormGroupedMovements({
    required this.events,
    required this.byStudent,
    this.usersById = const <String, AppUser>{},
    this.orderedUserIds,
    this.now,
    this.onOpenStudent,
    super.key,
  });
  final List<AttendanceEvent> events;
  final bool byStudent;
  final Map<String, AppUser> usersById;
  final List<String>? orderedUserIds;
  final DateTime? now;
  final ValueChanged<String>? onOpenStudent;
  @override
  State<DormGroupedMovements> createState() => _DormGroupedMovementsState();
}

class _DormGroupedMovementsState extends State<DormGroupedMovements> {
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
    final List<String> keys = widget.orderedUserIds != null
        ? widget.orderedUserIds!.where(groups.containsKey).toList()
        : (groups.keys.toList()
            ..sort(
              (a, b) => dormSearchKey(
                groups[a]!.first.userName,
              ).compareTo(dormSearchKey(groups[b]!.first.userName)),
            ));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final uid in keys.take(_limit))
          Builder(
            builder: (context) {
              final stu = widget.usersById[uid];
              final list = groups[uid]!;
              final summary = DormDurationCalculator.summarize(
                list,
                userId: uid,
                now: widget.now,
              );
              final metaParts = <String>[
                if ((stu?.room ?? '').isNotEmpty) 'Oda ${stu!.room}',
                if ((stu?.studentNumber ?? '').isNotEmpty)
                  'No ${stu!.studentNumber}',
                '${list.map((e) => e.dateKey).toSet().length} gün',
                '${list.length} hareket',
              ];
              return Padding(
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        list.first.userName,
                                        style: AppTypography.bodyStrong(
                                          context.colors.onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        metaParts.join(' · '),
                                        style: AppTypography.caption(
                                          context.colors.onSurfaceVariant,
                                        ),
                                      ),
                                      if (summary.insideDuration >
                                              Duration.zero ||
                                          summary.outsideDuration >
                                              Duration.zero ||
                                          summary.warningCount > 0) ...[
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          children: [
                                            if (summary.insideDuration >
                                                Duration.zero)
                                              StatusChip(
                                                label:
                                                    'İçeride: ${DormDurationCalculator.formatDuration(summary.insideDuration)}',
                                                tone: StatusTone.success,
                                                compact: true,
                                              ),
                                            if (summary.outsideDuration >
                                                Duration.zero)
                                              StatusChip(
                                                label:
                                                    'Dışarıda: ${DormDurationCalculator.formatDuration(summary.outsideDuration)}',
                                                tone: StatusTone.danger,
                                                compact: true,
                                              ),
                                            if (summary.warningCount > 0)
                                              StatusChip(
                                                label:
                                                    '${summary.warningCount} uyarı',
                                                tone: StatusTone.warning,
                                                compact: true,
                                              ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (widget.onOpenStudent != null)
                                  IconButton(
                                    tooltip: 'Öğrenci tam geçmişi',
                                    onPressed: () => widget.onOpenStudent!(uid),
                                    icon: const Icon(
                                      Icons.open_in_new_rounded,
                                      size: 18,
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
                          child: Column(children: _dayRows(list)),
                        ),
                    ],
                  ),
                ),
              );
            },
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
                        ..sort((a, b) => b.at.compareTo(a.at)),
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
  final TextEditingController _search = TextEditingController();
  String _statusFilter = 'all';
  bool _busy = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _statusOf(StudentLeave l, DateTime now) {
    if (l.revoked) return 'revoked';
    if (l.covers(now)) return 'active';
    if (now.isBefore(l.from)) return 'planned';
    return 'ended';
  }

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
    final usersById = ref.watch(usersByIdProvider);
    return AppScaffold(
      title: 'İzinler',
      maxContentWidth: AppWidths.wide,
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, bounds) {
              const header = SectionHeader(
                eyebrow: 'İZİN YÖNETİMİ',
                title: 'Öğrenci İzinleri',
                description:
                    'İzinler öğrencinin beklenen dönüş saatini, izin nedenini, gideceği adresi ve yakın iletişim bilgisini saklar. Giriş ve çıkış yine ayrı QR kodlarıyla kaydedilir.',
              );
              if (!user.role.isAdmin) return header;
              final action = AppButton(
                label: 'Öğrenci izni tanımla',
                icon: Icons.add_rounded,
                size: bounds.maxWidth >= 620
                    ? AppButtonSize.small
                    : AppButtonSize.medium,
                isLoading: _busy,
                onPressed: students.isEmpty ? null : () => _add(students),
              );
              if (bounds.maxWidth >= 620) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(child: header),
                    const SizedBox(width: 16),
                    action,
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [header, const SizedBox(height: 12), action],
              );
            },
          ),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('leave-search'),
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Öğrenci, oda no, neden, gideceği yer veya kişi ara...',
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
            value: _statusFilter,
            options: const [
              DormSegmentedOption('all', 'Tümü'),
              DormSegmentedOption('active', 'Aktif izinler'),
              DormSegmentedOption('planned', 'Planlananlar'),
              DormSegmentedOption('ended', 'Sona erenler'),
              DormSegmentedOption('revoked', 'İptal edilenler'),
            ],
            onChanged: (v) => setState(() => _statusFilter = v),
          ),
          const SizedBox(height: 16),
          AsyncValueView<List<StudentLeave>>(
            value: ref.watch(dormLeavesProvider),
            builder: (leaves) {
              final q = dormSearchKey(_search.text);
              final sorted =
                  leaves.where((l) {
                    if (_statusFilter != 'all' &&
                        _statusOf(l, now) != _statusFilter) {
                      return false;
                    }
                    if (q.isEmpty) return true;
                    final stu = usersById[l.userId];
                    final hay = [
                      stu?.displayName ?? '',
                      stu?.room ?? '',
                      stu?.studentNumber ?? '',
                      l.category,
                      l.reason,
                      l.destination,
                      l.contactName,
                      l.contactRelation,
                      l.contactPhone,
                    ].join(' ');
                    return dormSearchKey(hay).contains(q);
                  }).toList()..sort((a, b) => b.from.compareTo(a.from));
              if (sorted.isEmpty) {
                return DormEmpty(
                  title: leaves.isEmpty
                      ? 'Henüz izin kaydı yok'
                      : 'Bu filtreye uygun izin bulunamadı',
                  message: leaves.isEmpty
                      ? 'Öğrencilere evci, aile ziyareti veya sağlık izni tanımladığınızda burada görünür.'
                      : 'Arama metnini veya durum filtresini değiştirebilirsiniz.',
                  onReset: (q.isNotEmpty || _statusFilter != 'all')
                      ? () {
                          _search.clear();
                          setState(() => _statusFilter = 'all');
                        }
                      : null,
                );
              }
              return Column(
                children: [
                  for (final l in sorted)
                    _LeaveCard(
                      leave: l,
                      student: usersById[l.userId],
                      fallbackName: l.userId == user.uid
                          ? user.displayName
                          : 'Öğrenci',
                      now: now,
                      canManage: user.role.isAdmin,
                      busy: _busy,
                      onRevoke: () => _revoke(l),
                      onDelete: () => _delete(l),
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
      message: 'İznin aktif geçerliliği kaldırılır. İsterseniz sonra kartı silebilirsiniz.',
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

  Future<void> _delete(StudentLeave value) async {
    if (!await ConfirmDialog.show(
      context,
      title: 'İzin kaydı silinsin mi?',
      message: 'Bu izin kaydı listeden ve veritabanından kalıcı olarak silinir.',
      confirmLabel: 'Sil',
    )) {
      return;
    }
    setState(() => _busy = true);
    final u = ref.read(currentUserProvider)!;
    final result = await ref
        .read(dormRepositoryProvider)
        .deleteLeave(u.tenantId, value);
    Toast.result(result, successMessage: 'İzin kaydı silindi.');
    if (mounted) setState(() => _busy = false);
  }
}

class _LeaveCard extends StatelessWidget {
  const _LeaveCard({
    required this.leave,
    required this.student,
    required this.fallbackName,
    required this.now,
    required this.canManage,
    required this.busy,
    required this.onRevoke,
    required this.onDelete,
  });

  final StudentLeave leave;
  final AppUser? student;
  final String fallbackName;
  final DateTime now;
  final bool canManage;
  final bool busy;
  final VoidCallback onRevoke;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final String statusLabel = leave.revoked
        ? 'İptal edildi'
        : leave.covers(now)
        ? 'Aktif izin'
        : now.isBefore(leave.from)
        ? 'Planlandı'
        : 'Sona erdi';
    final StatusTone statusTone = leave.revoked
        ? StatusTone.neutral
        : leave.covers(now)
        ? StatusTone.success
        : now.isBefore(leave.from)
        ? StatusTone.info
        : StatusTone.neutral;
    final String contactSummary = [
      if (leave.contactName.isNotEmpty) leave.contactName,
      if (leave.contactRelation.isNotEmpty) '(${leave.contactRelation})',
      if (leave.contactPhone.isNotEmpty) leave.contactPhone,
    ].join(' ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student?.displayName ?? fallbackName,
                        style: AppTypography.bodyStrong(context.colors.onSurface),
                      ),
                      if (student != null &&
                          (student!.room.isNotEmpty ||
                              student!.studentNumber.isNotEmpty))
                        Text(
                          [
                            if (student!.room.isNotEmpty)
                              'Oda ${student!.room}',
                            if (student!.studentNumber.isNotEmpty)
                              'No ${student!.studentNumber}',
                          ].join(' · '),
                          style: AppTypography.caption(
                            context.colors.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                StatusChip(label: statusLabel, tone: statusTone, compact: true),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '${AppDate.dateTime(leave.from)} — ${AppDate.dateTime(leave.until)}',
                  style: AppTypography.small(context.colors.onSurface),
                ),
                StatusChip(
                  label:
                      'Süre: ${DormDurationCalculator.formatDuration(leave.duration)}',
                  icon: Icons.timelapse_rounded,
                  tone: StatusTone.info,
                  compact: true,
                ),
                if (leave.category.isNotEmpty)
                  StatusChip(
                    label: leave.category,
                    tone: StatusTone.neutral,
                    compact: true,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              leave.reason,
              style: AppTypography.body(context.colors.onSurface),
            ),
            if (leave.destination.isNotEmpty || contactSummary.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.colors.surfaceContainerLowest,
                  borderRadius: AppRadius.allMd,
                  border: Border.all(
                    color: context.colors.outline.withValues(alpha: 0.45),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (leave.destination.isNotEmpty)
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 15,
                            color: context.colors.primary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Gideceği yer: ${leave.destination}',
                              style: AppTypography.caption(
                                context.colors.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (leave.destination.isNotEmpty &&
                        contactSummary.isNotEmpty)
                      const SizedBox(height: 4),
                    if (contactSummary.isNotEmpty)
                      Row(
                        children: [
                          Icon(
                            Icons.phone_outlined,
                            size: 15,
                            color: context.colors.primary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Gideceği kişi / iletişim: $contactSummary',
                              style: AppTypography.caption(
                                context.colors.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
            if (canManage) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!leave.revoked && leave.until.isAfter(now))
                    TextButton(
                      onPressed: busy ? null : onRevoke,
                      child: const Text('İzni iptal et'),
                    ),
                  if (leave.revoked || !leave.until.isAfter(now))
                    TextButton.icon(
                      onPressed: busy ? null : onDelete,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.danger,
                      ),
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text('Sil'),
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

class _LeaveDialog extends StatefulWidget {
  const _LeaveDialog({required this.students});
  final List<AppUser> students;
  @override
  State<_LeaveDialog> createState() => _LeaveDialogState();
}

class _LeaveDialogState extends State<_LeaveDialog> {
  static const List<String> _categories = <String>[
    'Aile ziyareti',
    'Sağlık / Hastane',
    'Akademik / Sınav',
    'Resmi işlem',
    'Şehir dışı',
    'Diğer',
  ];

  static const List<String> _relations = <String>[
    'Anne',
    'Baba',
    'Dayı',
    'Amca',
    'Teyze',
    'Hala',
    'Ağabey / Abla',
    'Resmi Kurum / Kendisi',
    'Diğer',
  ];

  final _form = GlobalKey<FormState>();
  final _reason = TextEditingController();
  final _destination = TextEditingController();
  final _contactName = TextEditingController();
  final _contactPhone = TextEditingController();
  String? _uid;
  String _category = 'Aile ziyareti';
  String _relation = 'Anne';
  DateTime _from = DateTime.now();
  DateTime _until = DateTime.now().add(const Duration(days: 1));

  @override
  void dispose() {
    _reason.dispose();
    _destination.dispose();
    _contactName.dispose();
    _contactPhone.dispose();
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
        if (!_until.isAfter(_from)) {
          _until = _from.add(const Duration(hours: 6));
        }
      } else {
        _until = v;
      }
    });
  }

  void _applyPreset(Duration duration) {
    setState(() {
      _until = _from.add(duration);
    });
  }

  @override
  Widget build(BuildContext context) {
    final Duration totalDuration = _until.isAfter(_from)
        ? _until.difference(_from)
        : Duration.zero;
    return AlertDialog(
      title: const Text('Öğrenci izni'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Öğrenci'),
                  items: [
                    for (final u in widget.students)
                      DropdownMenuItem(
                        value: u.uid,
                        child: Text(
                          u.room.isEmpty
                              ? u.displayName
                              : '${u.displayName} (Oda ${u.room})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) => _uid = v,
                  validator: (v) => v == null ? 'Öğrenci seçin.' : null,
                ),
                const SizedBox(height: 12),
                Text(
                  'İzin nedeni',
                  style: AppTypography.caption(context.colors.onSurfaceVariant),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final c in _categories)
                      ChoiceChip(
                        label: Text(c),
                        selected: _category == c,
                        onSelected: (_) => setState(() => _category = c),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.play_circle_outline_rounded),
                  title: const Text('Başlangıç'),
                  subtitle: Text(AppDate.dateTime(_from)),
                  onTap: () => _pick(true),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.stop_circle_outlined),
                  title: const Text('Dönüş zamanı'),
                  subtitle: Text(AppDate.dateTime(_until)),
                  trailing: StatusChip(
                    label: DormDurationCalculator.formatDuration(totalDuration),
                    tone: StatusTone.info,
                    compact: true,
                  ),
                  onTap: () => _pick(false),
                ),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final p in const [
                      ('6 sa', Duration(hours: 6)),
                      ('1 gün', Duration(days: 1)),
                      ('2 gün', Duration(days: 2)),
                      ('3 gün', Duration(days: 3)),
                    ])
                      ActionChip(
                        label: Text(p.$1),
                        onPressed: () => _applyPreset(p.$2),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _destination,
                  maxLength: 200,
                  decoration: const InputDecoration(
                    labelText: 'Gideceği yer / Adres (isteğe bağlı)',
                    hintText: 'Örn: Ankara Çankaya / Aile yanı',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: TextFormField(
                        controller: _contactName,
                        maxLength: 120,
                        decoration: const InputDecoration(
                          labelText: 'Gideceği kişi adı',
                          hintText: 'Örn: Ahmet Yılmaz',
                          counterText: '',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 5,
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _relation,
                        decoration: const InputDecoration(labelText: 'Yakınlığı'),
                        items: [
                          for (final rel in _relations)
                            DropdownMenuItem(
                              value: rel,
                              child: Text(rel, overflow: TextOverflow.ellipsis),
                            ),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _relation = v);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _contactPhone,
                  maxLength: 40,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'İletişim telefonu (gideceği kişi / acil)',
                    hintText: '05xx xxx xx xx',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _reason,
                  maxLength: 500,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'İzin açıklaması',
                  ),
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
                category: _category,
                destination: _destination.text.trim(),
                contactName: _contactName.text.trim(),
                contactRelation:
                    _contactName.text.trim().isEmpty ? '' : _relation,
                contactPhone: _contactPhone.text.trim(),
              ),
            );
          },
          child: const Text('Kaydet'),
        ),
      ],
    );
  }
}
