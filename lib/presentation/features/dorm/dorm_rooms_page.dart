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
import 'package:ubsoft_pdks/domain/entities/dormitory.dart';
import 'package:ubsoft_pdks/domain/usecases/dorm/dorm_duration.dart';
import 'package:ubsoft_pdks/presentation/features/dorm/widgets/dorm_ui.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_card.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_scaffold.dart';
import 'package:ubsoft_pdks/presentation/widgets/async_value_view.dart';
import 'package:ubsoft_pdks/presentation/widgets/section_header.dart';
import 'package:ubsoft_pdks/presentation/widgets/status_chip.dart';

/// Odalar modülü — her odada kalan öğrencileri ve anlık içeride/dışarıda
/// durumlarını yeşil/kırmızı kartlarla gösterir; dokunulunca öğrencinin
/// geçmişini açar.
class DormRoomsPage extends ConsumerStatefulWidget {
  const DormRoomsPage({super.key});

  @override
  ConsumerState<DormRoomsPage> createState() => _DormRoomsPageState();
}

class _DormRoomsPageState extends ConsumerState<DormRoomsPage> {
  final TextEditingController _search = TextEditingController();
  String _filter = 'all';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  static int _compareRoomNames(String a, String b) {
    if (a.isEmpty && b.isEmpty) return 0;
    if (a.isEmpty) return 1;
    if (b.isEmpty) return -1;
    final int? na = int.tryParse(a.replaceAll(RegExp(r'[^0-9]'), ''));
    final int? nb = int.tryParse(b.replaceAll(RegExp(r'[^0-9]'), ''));
    if (na != null && nb != null && na != nb) return na.compareTo(nb);
    return dormSearchKey(a).compareTo(dormSearchKey(b));
  }

  @override
  Widget build(BuildContext context) {
    final DateTime now = ref.watch(dormNowProvider);
    final tenant = ref.watch(currentTenantProvider);
    final List<AppUser> students = ref.watch(studentsProvider);

    if (tenant == null) {
      return const AppScaffold(
        title: 'Odalar',
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return AppScaffold(
      title: 'Odalar',
      maxContentWidth: AppWidths.page,
      scrollable: true,
      body: AsyncValueView(
        value: ref.watch(usersProvider),
        builder: (_) => AsyncValueView<List<Presence>>(
          value: ref.watch(residentsProvider),
          builder: (List<Presence> states) => AsyncValueView<List<StudentLeave>>(
            value: ref.watch(dormLeavesProvider),
            builder: (List<StudentLeave> leaves) {
              final Map<String, Presence> byId = <String, Presence>{
                for (final Presence p in states) p.userId: p,
              };
              Presence presenceOf(AppUser u) =>
                  byId[u.uid] ?? Presence(userId: u.uid);

              final Map<String, List<StudentLeave>> leavesByUser =
                  <String, List<StudentLeave>>{};
              for (final StudentLeave l in leaves) {
                leavesByUser.putIfAbsent(l.userId, () => <StudentLeave>[]).add(l);
              }

              bool isOverdue(AppUser u) => tenant.settings.dormPolicy.overdue(
                presenceOf(u),
                now,
                relevantLeave(
                  leavesByUser[u.uid] ?? const <StudentLeave>[],
                  presenceOf(u),
                  now,
                ),
              );

              bool isPermitted(AppUser u) =>
                  presenceOf(u).inside == false &&
                  leaveAt(
                        leavesByUser[u.uid] ?? const <StudentLeave>[],
                        u.uid,
                        now,
                      ) !=
                      null;

              bool matchesStudentFilter(AppUser u) {
                final Presence p = presenceOf(u);
                return switch (_filter) {
                  'inside' => p.inside == true,
                  'outside' => p.inside == false,
                  'late' => isOverdue(u),
                  'unknown' => p.inside == null,
                  _ => true,
                };
              }

              final String q = dormSearchKey(_search.text);
              final Map<String, List<AppUser>> allRooms =
                  <String, List<AppUser>>{};
              for (final AppUser u in students) {
                final String key = u.room.trim();
                allRooms.putIfAbsent(key, () => <AppUser>[]).add(u);
              }

              final List<String> roomKeys = allRooms.keys.where((String room) {
                final List<AppUser> list = allRooms[room]!;
                final bool roomMatches =
                    q.isEmpty ||
                    dormSearchKey(room).contains(q) ||
                    list.any(
                      (AppUser u) =>
                          dormSearchKey(u.displayName).contains(q) ||
                          dormSearchKey(u.studentNumber).contains(q),
                    );
                if (!roomMatches) return false;
                if (_filter == 'all') return true;
                return list.any(matchesStudentFilter);
              }).toList()..sort(_compareRoomNames);

              final int insideCount = students
                  .where((AppUser u) => presenceOf(u).inside == true)
                  .length;
              final int outsideCount = students
                  .where((AppUser u) => presenceOf(u).inside == false)
                  .length;
              final int lateCount = students.where(isOverdue).length;
              final int roomCount = allRooms.keys
                  .where((String k) => k.isNotEmpty)
                  .length;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionHeader(
                    eyebrow: 'YERLEŞİM VE CANLI TAKİP',
                    title: 'Yurt Odaları',
                    description:
                        'Yeşil kart içeride, kırmızı kart dışarıda olan öğrenciyi gösterir. Öğrenciye dokunarak geçmişini açabilirsiniz.',
                  ),
                  const SizedBox(height: 16),
                  DormMetricGrid(
                    metrics: <DormMetric>[
                      DormMetric(
                        'Tanımlı oda',
                        roomCount,
                        Icons.meeting_room_outlined,
                        AppColors.primary,
                        '${students.length} öğrenci yerleşimi',
                        () => setState(() => _filter = 'all'),
                        selected: _filter == 'all',
                      ),
                      DormMetric(
                        'Odada / İçeride',
                        insideCount,
                        Icons.login_rounded,
                        AppColors.entry,
                        'Yeşil öğrenci kartı',
                        () => setState(
                          () => _filter = _filter == 'inside' ? 'all' : 'inside',
                        ),
                        selected: _filter == 'inside',
                      ),
                      DormMetric(
                        'Dışarıda',
                        outsideCount,
                        Icons.logout_rounded,
                        AppColors.exit,
                        'Kırmızı öğrenci kartı',
                        () => setState(
                          () =>
                              _filter = _filter == 'outside' ? 'all' : 'outside',
                        ),
                        selected: _filter == 'outside',
                      ),
                      DormMetric(
                        'Dönüşü geciken',
                        lateCount,
                        Icons.schedule_rounded,
                        AppColors.warning,
                        'Dönüş saati geçenler',
                        () => setState(
                          () => _filter = _filter == 'late' ? 'all' : 'late',
                        ),
                        selected: _filter == 'late',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _search,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: 'Oda no, öğrenci adı veya öğrenci no ara...',
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
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  DormSegmentedBar<String>(
                    value: _filter,
                    options: const [
                      DormSegmentedOption('all', 'Tümü'),
                      DormSegmentedOption('inside', 'İçeride (Yeşil)'),
                      DormSegmentedOption('outside', 'Dışarıda (Kırmızı)'),
                      DormSegmentedOption('late', 'Dönüşü geciken'),
                      DormSegmentedOption('unknown', 'Kayıt yok'),
                    ],
                    onChanged: (v) => setState(() => _filter = v),
                  ),
                  const SizedBox(height: 16),
                  if (roomKeys.isEmpty)
                    DormEmpty(
                      title: students.isEmpty
                          ? 'Henüz öğrenci yok'
                          : 'Aramaya uygun oda bulunamadı',
                      message: students.isEmpty
                          ? 'Öğrenciler bölümünden oda numaralarıyla öğrenci ekleyin.'
                          : 'Farklı bir oda numarası veya filtre seçin.',
                      onReset: (_search.text.isNotEmpty || _filter != 'all')
                          ? () {
                              _search.clear();
                              setState(() => _filter = 'all');
                            }
                          : null,
                    )
                  else
                    LayoutBuilder(
                      builder: (BuildContext context, BoxConstraints bounds) {
                        final int cols = bounds.maxWidth >= 980
                            ? 3
                            : bounds.maxWidth >= 620
                            ? 2
                            : 1;
                        const double gap = 14;
                        final double width =
                            (bounds.maxWidth - gap * (cols - 1)) / cols;
                        return Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: [
                            for (final String roomKey in roomKeys)
                              SizedBox(
                                width: width,
                                child: _RoomCard(
                                  roomName: roomKey,
                                  students:
                                      allRooms[roomKey]!
                                          .where(
                                            (AppUser u) =>
                                                _filter == 'all' ||
                                                matchesStudentFilter(u),
                                          )
                                          .toList()
                                        ..sort(
                                          (AppUser a, AppUser b) =>
                                              dormSearchKey(a.displayName)
                                                  .compareTo(
                                                    dormSearchKey(
                                                      b.displayName,
                                                    ),
                                                  ),
                                        ),
                                  presenceOf: presenceOf,
                                  isOverdue: isOverdue,
                                  isPermitted: isPermitted,
                                  now: now,
                                  onSelectStudent: (AppUser u) => context.push(
                                    AppRoutes.personHistoryPath(u.uid),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({
    required this.roomName,
    required this.students,
    required this.presenceOf,
    required this.isOverdue,
    required this.isPermitted,
    required this.now,
    required this.onSelectStudent,
  });

  final String roomName;
  final List<AppUser> students;
  final Presence Function(AppUser u) presenceOf;
  final bool Function(AppUser u) isOverdue;
  final bool Function(AppUser u) isPermitted;
  final DateTime now;
  final ValueChanged<AppUser> onSelectStudent;

  @override
  Widget build(BuildContext context) {
    final int insideCount = students
        .where((AppUser u) => presenceOf(u).inside == true)
        .length;
    final bool isUnassigned = roomName.isEmpty;

    return AppCard(
      padding: const EdgeInsets.all(14),
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
                      isUnassigned ? 'Odası atanmamış' : 'Oda $roomName',
                      style: AppTypography.bodyStrong(context.colors.onSurface),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${students.length} kayıtlı öğrenci',
                      style: AppTypography.caption(
                        context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              StatusChip(
                label: '$insideCount / ${students.length} içeride',
                tone: insideCount == students.length && students.isNotEmpty
                    ? StatusTone.success
                    : insideCount == 0
                    ? StatusTone.neutral
                    : StatusTone.info,
                compact: true,
              ),
            ],
          ),
          const Divider(height: 20),
          for (final AppUser u in students) ...[
            _RoomStudentTile(
              user: u,
              presence: presenceOf(u),
              overdue: isOverdue(u),
              permitted: isPermitted(u),
              now: now,
              onTap: () => onSelectStudent(u),
            ),
            if (u != students.last) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _RoomStudentTile extends StatelessWidget {
  const _RoomStudentTile({
    required this.user,
    required this.presence,
    required this.overdue,
    required this.permitted,
    required this.now,
    required this.onTap,
  });

  final AppUser user;
  final Presence presence;
  final bool overdue;
  final bool permitted;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool dark = context.isDark;
    final bool? inside = presence.inside;
    final Color accent = inside == null
        ? AppColors.neutral
        : inside
        ? AppColors.entry
        : AppColors.exit;
    final Color surface = inside == null
        ? context.colors.surfaceContainerLowest
        : inside
        ? (dark ? AppColors.entry.withValues(alpha: 0.14) : AppColors.entrySoft)
        : (dark ? AppColors.exit.withValues(alpha: 0.14) : AppColors.exitSoft);
    final Color borderColor = inside == null
        ? context.colors.outline
        : inside
        ? (dark ? AppColors.entry.withValues(alpha: 0.45) : AppColors.entryBorder)
        : (dark ? AppColors.exit.withValues(alpha: 0.45) : AppColors.exitBorder);
    final Duration? elapsed = DormDurationCalculator.ongoingDuration(
      presence,
      now,
    );

    final String statusText = inside == null
        ? 'İlk okutma yok'
        : inside
        ? 'İçeride${elapsed == null ? '' : ' · ${DormDurationCalculator.formatDuration(elapsed)}'}'
        : 'Dışarıda${elapsed == null ? '' : ' · ${DormDurationCalculator.formatDuration(elapsed)}'}';

    return Semantics(
      button: true,
      label: '${user.displayName}, $statusText. Geçmişi aç.',
      child: Material(
        color: surface,
        borderRadius: AppRadius.allSm,
        child: InkWell(
          key: ValueKey('room-student-${user.uid}'),
          onTap: onTap,
          borderRadius: AppRadius.allSm,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: AppRadius.allSm,
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 30,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
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
                        ).copyWith(fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          statusText,
                          if (user.studentNumber.isNotEmpty)
                            'No: ${user.studentNumber}',
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption(accent).copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (overdue || (permitted && inside == false)) ...[
                  const SizedBox(width: 6),
                  StatusChip(
                    label: overdue ? 'Geç' : 'İzinli',
                    tone: overdue ? StatusTone.warning : StatusTone.info,
                    compact: true,
                  ),
                ],
                if (presence.at != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    AppDate.time(presence.at!),
                    style: AppTypography.caption(accent).copyWith(
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
                const SizedBox(width: 2),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: accent,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
