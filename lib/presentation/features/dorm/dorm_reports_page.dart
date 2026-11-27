import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubsoft_pdks/application/auth/session_provider.dart';
import 'package:ubsoft_pdks/application/dorm/dorm_providers.dart';
import 'package:ubsoft_pdks/application/user/user_providers.dart';
import 'package:ubsoft_pdks/core/error/failure.dart';
import 'package:ubsoft_pdks/core/extensions/context_x.dart';
import 'package:ubsoft_pdks/core/result/result.dart';
import 'package:ubsoft_pdks/core/theme/app_colors.dart';
import 'package:ubsoft_pdks/core/theme/app_radius.dart';
import 'package:ubsoft_pdks/core/theme/app_spacing.dart';
import 'package:ubsoft_pdks/core/theme/app_typography.dart';
import 'package:ubsoft_pdks/core/utils/date_x.dart';
import 'package:ubsoft_pdks/data/repositories/dorm_repository.dart';
import 'package:ubsoft_pdks/domain/entities/app_user.dart';
import 'package:ubsoft_pdks/domain/entities/attendance_event.dart';
import 'package:ubsoft_pdks/domain/entities/attention_resolution.dart';
import 'package:ubsoft_pdks/domain/entities/dormitory.dart';
import 'package:ubsoft_pdks/domain/usecases/dorm/dorm_duration.dart';
import 'package:ubsoft_pdks/presentation/features/dorm/dorm_pages.dart';
import 'package:ubsoft_pdks/presentation/features/dorm/widgets/dorm_ui.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_button.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_card.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_scaffold.dart';
import 'package:ubsoft_pdks/presentation/widgets/error_view.dart';
import 'package:ubsoft_pdks/presentation/widgets/section_header.dart';
import 'package:ubsoft_pdks/presentation/widgets/status_chip.dart';
import 'package:ubsoft_pdks/services/export/dorm_pdf_service.dart';
import 'package:ubsoft_pdks/services/export/file_download_service.dart';
import 'package:ubsoft_pdks/services/notification/toast_service.dart';

class DormReportPage extends ConsumerStatefulWidget {
  const DormReportPage({super.key});
  @override
  ConsumerState<DormReportPage> createState() => _DormReportState();
}

class _DormReportState extends ConsumerState<DormReportPage> {
  final TextEditingController _search = TextEditingController();
  DateTimeRange? _range;
  String _preset = 'week';
  String? _uid;
  String _roomFilter = 'all';
  String _focus = 'all';
  String _timeWindow = 'all';
  String _sortBy = 'name';
  String _viewTab = 'students'; // students | analytics | raw
  bool _exporting = false;
  bool _loadingAll = false;
  final Map<String, String> _knownNames = {};

  String? _activeKey;
  int _requestId = 0;
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = false;
  Failure? _error;
  DocumentSnapshot<Map<String, dynamic>>? _cursor;
  List<AttendanceEvent> _loaded = const [];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  DateTimeRange _defaultRange(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return switch (_preset) {
      'today' => DateTimeRange(start: today, end: today),
      'twoWeeks' => DateTimeRange(
        start: today.subtract(const Duration(days: 13)),
        end: today,
      ),
      'month' => DateTimeRange(
        start: today.subtract(const Duration(days: 29)),
        end: today,
      ),
      _ => DateTimeRange(
        start: today.subtract(const Duration(days: 6)),
        end: today,
      ),
    };
  }

  void _ensureLoaded(String tid, String from, String to) {
    final key = '$tid|$from|$to|${_uid ?? ''}';
    if (_activeKey == key) return;
    _activeKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load(tid: tid, from: from, to: to, reset: true);
    });
  }

  Future<void> _load({
    required String tid,
    required String from,
    required String to,
    required bool reset,
  }) async {
    if (tid.isEmpty) return;
    final req = ++_requestId;
    setState(() {
      if (reset) {
        _loading = true;
        _error = null;
        _cursor = null;
        _hasMore = false;
        _loaded = const [];
      } else {
        _loadingMore = true;
      }
    });
    final res = await ref
        .read(dormRepositoryProvider)
        .fetchReportEvents(
          tid,
          from,
          to,
          uid: _uid,
          startAfter: reset ? null : _cursor,
        );
    if (!mounted || req != _requestId) return;
    switch (res) {
      case Ok<ReportEventsPage>(:final value):
        final merged = reset
            ? value.events
            : <AttendanceEvent>[
                ..._loaded,
                ...value.events.where(
                  (e) => !_loaded.any((prev) => prev.id == e.id),
                ),
              ]
          ..sort((a, b) => b.at.compareTo(a.at));
        for (final event in merged) {
          _knownNames[event.userId] = event.userName;
        }
        setState(() {
          _loaded = merged;
          _cursor = value.cursor;
          _hasMore = value.hasMore;
          _loading = false;
          _loadingMore = false;
          _error = null;
        });
      case Err<ReportEventsPage>(:final failure):
        setState(() {
          _loading = false;
          _loadingMore = false;
          _error = failure;
        });
    }
  }

  Future<void> _loadAllPages(String tid, String from, String to) async {
    if (_loadingAll || !_hasMore) return;
    setState(() => _loadingAll = true);
    try {
      int guardCount = 0;
      while (mounted && _hasMore && guardCount < 20) {
        guardCount++;
        await _load(tid: tid, from: from, to: to, reset: false);
      }
    } finally {
      if (mounted) setState(() => _loadingAll = false);
    }
  }

  bool _matchesTimeWindow(DateTime at) {
    final local = DormClock.local(at);
    final h = local.hour;
    return switch (_timeWindow) {
      'morning' => h >= 6 && h < 12,
      'afternoon' => h >= 12 && h < 18,
      'evening' => h >= 18 && h < 22,
      'night' => h >= 22 || h < 6,
      _ => true,
    };
  }

  @override
  Widget build(BuildContext context) {
    final tid = ref.watch(tenantIdProvider);
    final rawNow = ref.watch(dormNowProvider);
    final now = DormClock.local(rawNow);
    final range = _range ?? _defaultRange(now);
    final from = dormCalendarKey(range.start);
    final to = dormCalendarKey(range.end);
    _ensureLoaded(tid, from, to);

    final users = ref.watch(usersProvider).value ?? <AppUser>[];
    final activeStudents = ref.watch(studentsProvider);
    final residents = ref.watch(residentsProvider).value ?? const <Presence>[];
    final attentionCount = ref.watch(dormAttentionCountProvider);
    final attentionLogs =
        ref.watch(attentionLogsProvider).value ?? const <AttentionResolution>[];
    final usersById = ref.watch(usersByIdProvider);
    final leaves = ref.watch(dormLeavesProvider).value ?? const <StudentLeave>[];
    final Map<String, Presence> presenceByUid = {
      for (final p in residents) p.userId: p,
    };
    int insideNowCount = 0;
    int outsideNowCount = 0;
    for (final s in activeStudents) {
      final p = presenceByUid[s.uid];
      if (p?.inside == true) {
        insideNowCount++;
      } else if (p?.inside == false) {
        outsideNowCount++;
      }
    }
    final names = {
      ..._knownNames,
      for (final u in users.where((u) => u.role.isStaff)) u.uid: u.displayName,
    };
    final rooms =
        users
            .where((u) => u.role.isStaff && u.room.trim().isNotEmpty)
            .map((u) => u.room.trim())
            .toSet()
            .toList()
          ..sort();

    final hasFilters =
        _uid != null ||
        _focus != 'all' ||
        _roomFilter != 'all' ||
        _timeWindow != 'all' ||
        _range != null ||
        _preset != 'week' ||
        _search.text.trim().isNotEmpty;

    return AppScaffold(
      title: 'Raporlar',
      maxContentWidth: AppWidths.wide,
      scrollable: true,
      actions: [
        IconButton(
          tooltip: 'Raporu yenile',
          onPressed: _loading
              ? null
              : () => _load(tid: tid, from: from, to: to, reset: true),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(
            eyebrow: 'YÖNETİM VE DENETİM',
            title: 'Raporlama Merkezi',
            description:
                'Tarih, oda, öğrenci, saat aralığı ve uyarı türüne göre verileri süzün; yoğunluk analizini inceleyin ve PDF veya Excel (CSV) çıktısı alın.',
          ),
          const SizedBox(height: 14),
          DormSegmentedBar<String>(
            value: _range == null ? _preset : 'custom',
            options: const [
              DormSegmentedOption('today', 'Bugün'),
              DormSegmentedOption('week', 'Son 7 gün'),
              DormSegmentedOption('twoWeeks', 'Son 14 gün'),
              DormSegmentedOption('month', 'Son 30 gün'),
            ],
            onChanged: (v) => setState(() {
              _preset = v;
              _range = null;
            }),
          ),
          const SizedBox(height: 12),
          DormFilterPanel(
            onReset: hasFilters
                ? () => setState(() {
                    _uid = null;
                    _roomFilter = 'all';
                    _focus = 'all';
                    _timeWindow = 'all';
                    _sortBy = 'name';
                    _preset = 'week';
                    _range = null;
                    _search.clear();
                  })
                : null,
            children: [
              DormDateRangeField(
                label: '${dormDisplayDate(from)} — ${dormDisplayDate(to)}',
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
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('report-search'),
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
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, bounds) {
                  final row1 = [
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
                        DormOption(
                          'entry',
                          'Yalnızca giriş',
                          Icons.login_rounded,
                        ),
                        DormOption(
                          'exit',
                          'Yalnızca çıkış',
                          Icons.logout_rounded,
                        ),
                        DormOption(
                          'late',
                          'Geç giriş',
                          Icons.schedule_rounded,
                        ),
                        DormOption(
                          'earlyExit',
                          'Erken çıkış',
                          Icons.running_with_errors_rounded,
                        ),
                        DormOption(
                          'earlyEntry',
                          'Erken giriş',
                          Icons.wb_twilight_rounded,
                        ),
                        DormOption(
                          'leave',
                          'İzinli geçişler',
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
                  final row2 = [
                    DormSelect<String>(
                      label: 'Oda filtresi',
                      value: rooms.contains(_roomFilter) ? _roomFilter : 'all',
                      options: [
                        const DormOption(
                          'all',
                          'Tüm odalar',
                          Icons.meeting_room_outlined,
                        ),
                        for (final r in rooms)
                          DormOption(
                            r,
                            'Oda $r',
                            Icons.meeting_room_rounded,
                          ),
                      ],
                      onChanged: (v) => setState(() => _roomFilter = v),
                    ),
                    DormSelect<String>(
                      label: 'Saat dilimi',
                      value: _timeWindow,
                      options: const [
                        DormOption(
                          'all',
                          'Tüm saatler (00–24)',
                          Icons.access_time_rounded,
                        ),
                        DormOption(
                          'morning',
                          'Sabah (06:00–12:00)',
                          Icons.wb_sunny_outlined,
                        ),
                        DormOption(
                          'afternoon',
                          'Öğle (12:00–18:00)',
                          Icons.light_mode_outlined,
                        ),
                        DormOption(
                          'evening',
                          'Akşam (18:00–22:00)',
                          Icons.nights_stay_outlined,
                        ),
                        DormOption(
                          'night',
                          'Gece (22:00–06:00)',
                          Icons.bedtime_outlined,
                        ),
                      ],
                      onChanged: (v) => setState(() => _timeWindow = v),
                    ),
                    DormSelect<String>(
                      label: 'Sıralama',
                      value: _sortBy,
                      options: const [
                        DormOption(
                          'name',
                          'Ad soyad (A–Z)',
                          Icons.sort_by_alpha_rounded,
                        ),
                        DormOption(
                          'events',
                          'En çok hareket',
                          Icons.bar_chart_rounded,
                        ),
                        DormOption(
                          'late',
                          'En çok gecikme',
                          Icons.warning_amber_rounded,
                        ),
                        DormOption(
                          'room',
                          'Oda numarası',
                          Icons.meeting_room_outlined,
                        ),
                      ],
                      onChanged: (v) => setState(() => _sortBy = v),
                    ),
                  ];

                  if (bounds.maxWidth >= 700) {
                    return Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: row1[0]),
                            const SizedBox(width: 12),
                            Expanded(child: row1[1]),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: row2[0]),
                            const SizedBox(width: 12),
                            Expanded(child: row2[1]),
                            const SizedBox(width: 12),
                            Expanded(child: row2[2]),
                          ],
                        ),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      row1[0],
                      const SizedBox(height: 12),
                      row1[1],
                      const SizedBox(height: 12),
                      row2[0],
                      const SizedBox(height: 12),
                      row2[1],
                      const SizedBox(height: 12),
                      row2[2],
                    ],
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null && _loaded.isEmpty)
            ErrorView(
              error: _error!,
              onRetry: () => _load(tid: tid, from: from, to: to, reset: true),
            )
          else
            Builder(
              builder: (context) {
                final q = dormSearchKey(_search.text);
                final events = _loaded.where((e) {
                  final stu = usersById[e.userId];
                  if (_roomFilter != 'all' &&
                      (stu?.room.trim() ?? '') != _roomFilter) {
                    return false;
                  }
                  if (q.isNotEmpty) {
                    final hay = [
                      e.userName,
                      e.checkpointName,
                      stu?.room ?? '',
                      stu?.studentNumber ?? '',
                    ].join(' ');
                    if (!dormSearchKey(hay).contains(q)) return false;
                  }
                  if (!_matchesTimeWindow(e.at)) return false;
                  return switch (_focus) {
                    'entry' => e.type.isEntry,
                    'exit' => e.type.isExit,
                    'late' => e.lateMinutes > 0,
                    'earlyExit' => e.earlyExit,
                    'earlyEntry' => e.earlyEntry,
                    'leave' => e.permitted,
                    'location' => e.verdict.needsAttention,
                    _ => true,
                  };
                }).toList();

                final analytics = _ReportAnalytics.compute(
                  events: events,
                  usersById: usersById,
                  leaves: leaves,
                  fromKey: from,
                  toKey: to,
                  sortBy: _sortBy,
                  now: rawNow,
                );

                final Set<String> matchingStudentIds = events
                    .map((e) => e.userId)
                    .toSet();
                final List<AttentionResolution> filteredLogs = attentionLogs
                    .where(
                      (l) => _uid != null
                          ? l.userId == _uid
                          : matchingStudentIds.contains(l.userId),
                    )
                    .toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: LayoutBuilder(
                        builder: (context, barBounds) {
                          final summaryInfo = Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: const BoxDecoration(
                                  color: AppColors.primarySurface,
                                  borderRadius: AppRadius.allSm,
                                ),
                                child: const Icon(
                                  Icons.assessment_outlined,
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
                                      '${analytics.studentSummaries.length} öğrenci · ${events.length} kayıt',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.bodyStrong(
                                        context.colors.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${analytics.totalEntries} giriş · ${analytics.totalExits} çıkış',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.caption(
                                        context.colors.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                          final csvBtn = AppButton(
                            label: 'Excel (CSV)',
                            icon: Icons.table_chart_outlined,
                            variant: AppButtonVariant.outline,
                            size: AppButtonSize.small,
                            onPressed: events.isEmpty
                                ? null
                                : () => _exportCsv(
                                    events,
                                    analytics,
                                    usersById,
                                    filteredLogs,
                                  ),
                          );
                          final pdfBtn = AppButton(
                            label: 'PDF indir',
                            icon: Icons.file_download_outlined,
                            size: AppButtonSize.small,
                            isLoading: _exporting,
                            onPressed: events.isEmpty
                                ? null
                                : () => _exportPdf(
                                    events,
                                    '${dormDisplayDate(from)} — ${dormDisplayDate(to)} · ${dormFocusLabel(_focus)}${_uid == null ? '' : ' · ${names[_uid] ?? 'Seçili öğrenci'}'}',
                                    usersById,
                                    filteredLogs,
                                  ),
                          );
                          if (barBounds.maxWidth >= 540) {
                            return Row(
                              children: [
                                Expanded(child: summaryInfo),
                                const SizedBox(width: 12),
                                csvBtn,
                                const SizedBox(width: 8),
                                pdfBtn,
                              ],
                            );
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              summaryInfo,
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(child: csvBtn),
                                  const SizedBox(width: 8),
                                  Expanded(child: pdfBtn),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                    DormSegmentedBar<String>(
                      value: _viewTab,
                      options: const [
                        DormSegmentedOption(
                          'students',
                          'Öğrenci Detayı',
                          icon: Icons.person_search_outlined,
                        ),
                        DormSegmentedOption(
                          'analytics',
                          'Özet & Saatlik Analiz',
                          icon: Icons.analytics_outlined,
                        ),
                        DormSegmentedOption(
                          'raw',
                          'Ham Kayıt Tablosu',
                          icon: Icons.list_alt_rounded,
                        ),
                      ],
                      onChanged: (v) => setState(() => _viewTab = v),
                    ),
                    const SizedBox(height: 14),
                    if (_viewTab == 'analytics')
                      _AnalyticsDashboardView(
                        analytics: analytics,
                        insideNowCount: insideNowCount,
                        outsideNowCount: outsideNowCount,
                        totalActiveStudents: activeStudents.length,
                        attentionCount: attentionCount,
                      )
                    else if (_viewTab == 'raw')
                      _RawEventTableView(
                        events: events,
                        usersById: usersById,
                        attentionLogs: filteredLogs,
                      )
                    else ...[
                      const DormMovementLegend(),
                      const SizedBox(height: 12),
                      DormGroupedMovements(
                        key: ValueKey(
                          'report-$from-$to-$_uid-$_focus-$_roomFilter-$_timeWindow-$_sortBy-$q',
                        ),
                        events: events,
                        byStudent: _uid == null,
                        usersById: usersById,
                        attentionLogs: filteredLogs,
                        orderedUserIds: analytics.orderedUserIds,
                        now: rawNow,
                      ),
                    ],
                    if (_hasMore) ...[
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: _loadingMore || _loadingAll
                                ? null
                                : () => _load(
                                    tid: tid,
                                    from: from,
                                    to: to,
                                    reset: false,
                                  ),
                            child: Text(
                              _loadingMore
                                  ? 'Yükleniyor...'
                                  : 'Daha fazla kayıt yükle',
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _loadingMore || _loadingAll
                                ? null
                                : () => _loadAllPages(tid, from, to),
                            icon: const Icon(Icons.download_for_offline_outlined),
                            label: Text(
                              _loadingAll
                                  ? 'Tümü getiriliyor...'
                                  : 'Tüm sayfaları getir',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Future<void> _exportPdf(
    List<AttendanceEvent> events,
    String range,
    Map<String, AppUser> usersById,
    List<AttentionResolution> attentionLogs,
  ) async {
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
        usersById: usersById,
        attentionLogs: attentionLogs,
      );
      FileDownloadService.download(
        bytes: bytes,
        fileName: 'yurt-giris-cikis-raporu.pdf',
      );
    } catch (_) {
      Toast.error(
        'PDF oluşturulamadı. Tarih aralığını daraltıp tekrar deneyin.',
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _exportCsv(
    List<AttendanceEvent> events,
    _ReportAnalytics analytics,
    Map<String, AppUser> usersById,
    List<AttentionResolution> attentionLogs,
  ) {
    final buf = StringBuffer();
    String csvCell(String value) => '"${value.replaceAll('"', '""')}"';

    // Özet + öğrenci matrisi
    buf.writeln(
      'Öğrenci;Oda No;Öğrenci No;Giriş;Çıkış;Geç Giriş Sayısı;Toplam Gecikme (dk);Erken Çıkış;Konum Uyarısı',
    );
    for (final row in analytics.studentSummaries) {
      final u = usersById[row.summary.userId];
      buf.writeln(
        [
          csvCell(row.userName),
          csvCell(u?.room ?? ''),
          csvCell(u?.studentNumber ?? ''),
          '${row.summary.entryCount}',
          '${row.summary.exitCount}',
          '${row.summary.lateCount}',
          '${row.summary.lateMinutes}',
          '${row.summary.earlyExitCount}',
          '${row.summary.locationWarningCount}',
        ].join(';'),
      );
    }

    buf
      ..writeln()
      ..writeln(
        'Tarih;Saat;Öğrenci;Oda No;Öğrenci No;İşlem;Nokta;Mesafe (m);Konum Durumu;Gecikme (dk);İzinli;Erken Çıkış;Erken Giriş;Uyarı Çözüm Notu',
      );
    for (final e in events) {
      final u = usersById[e.userId];
      final String matchedNote = attentionLogs
          .where(
            (l) =>
                (l.eventId.isNotEmpty && l.eventId == e.id) ||
                (l.eventId.isEmpty &&
                    l.userId == e.userId &&
                    l.dateKey == e.dateKey),
          )
          .map((l) => '${l.title}: ${l.resolutionNote}')
          .join(' | ');
      buf.writeln(
        [
          csvCell(AppDate.dateShort(e.at)),
          csvCell(AppDate.time(e.at)),
          csvCell(e.userName),
          csvCell(u?.room ?? ''),
          csvCell(u?.studentNumber ?? ''),
          csvCell(e.type.label),
          csvCell(e.checkpointName),
          e.distanceMeters == null ? '' : e.distanceMeters!.toStringAsFixed(0),
          csvCell(e.verdict.label),
          '${e.lateMinutes}',
          e.permitted ? 'Evet' : 'Hayır',
          e.earlyExit ? 'Evet' : 'Hayır',
          e.earlyEntry ? 'Evet' : 'Hayır',
          csvCell(matchedNote),
        ].join(';'),
      );
    }

    if (attentionLogs.isNotEmpty) {
      buf
        ..writeln()
        ..writeln('Uyarı ve Çözüm Kayıtları')
        ..writeln(
          'Tarih;Öğrenci;Oda No;Uyarı;Özet;Çözüm Notu;Çözen Yönetici',
        );
      for (final l in attentionLogs) {
        buf.writeln(
          [
            csvCell(AppDate.dateTime(l.resolvedAt)),
            csvCell(l.userName),
            csvCell(l.room),
            csvCell(l.title),
            csvCell(l.summary),
            csvCell(l.resolutionNote),
            csvCell(l.resolvedByName),
          ].join(';'),
        );
      }
    }

    final bytes = Uint8List.fromList(<int>[0xEF, 0xBB, 0xBF, ...utf8.encode(buf.toString())]);
    FileDownloadService.download(
      bytes: bytes,
      fileName: 'yurt-detayli-rapor.csv',
    );
    Toast.success('Excel (CSV) raporu indirildi.');
  }
}

class _StudentRowData {
  const _StudentRowData({
    required this.userName,
    required this.room,
    required this.summary,
  });

  final String userName;
  final String room;
  final StudentMovementSummary summary;
}

class _ReportAnalytics {
  const _ReportAnalytics({
    required this.studentSummaries,
    required this.orderedUserIds,
    required this.checkpointCounts,
    required this.hourlyEntries,
    required this.hourlyExits,
    required this.leaveCategoryCounts,
    required this.totalEntries,
    required this.totalExits,
    required this.totalLate,
    required this.totalLateMinutes,
    required this.totalLocationWarnings,
  });

  final List<_StudentRowData> studentSummaries;
  final List<String> orderedUserIds;
  final List<MapEntry<String, int>> checkpointCounts;
  final List<int> hourlyEntries;
  final List<int> hourlyExits;
  final List<MapEntry<String, int>> leaveCategoryCounts;
  final int totalEntries;
  final int totalExits;
  final int totalLate;
  final int totalLateMinutes;
  final int totalLocationWarnings;

  static _ReportAnalytics compute({
    required List<AttendanceEvent> events,
    required Map<String, AppUser> usersById,
    required List<StudentLeave> leaves,
    required String fromKey,
    required String toKey,
    required String sortBy,
    required DateTime now,
  }) {
    final byUser = <String, List<AttendanceEvent>>{};
    final cpMap = <String, int>{};
    final hEntries = List<int>.filled(24, 0);
    final hExits = List<int>.filled(24, 0);

    int entries = 0;
    int exits = 0;
    int late = 0;
    int lateMin = 0;
    int locWarn = 0;

    for (final e in events) {
      byUser.putIfAbsent(e.userId, () => []).add(e);
      cpMap[e.checkpointName] = (cpMap[e.checkpointName] ?? 0) + 1;
      final h = DormClock.local(e.at).hour;
      if (e.type.isEntry) {
        entries++;
        hEntries[h]++;
      } else {
        exits++;
        hExits[h]++;
      }
      if (e.lateMinutes > 0) {
        late++;
        lateMin += e.lateMinutes;
      }
      if (e.verdict.needsAttention) locWarn++;
    }

    final rows = <_StudentRowData>[];

    for (final entry in byUser.entries) {
      final uid = entry.key;
      final list = entry.value;
      final u = usersById[uid];
      final summary = DormDurationCalculator.summarize(
        list,
        userId: uid,
        now: now,
      );
      rows.add(
        _StudentRowData(
          userName: list.first.userName,
          room: u?.room.trim() ?? '',
          summary: summary,
        ),
      );
    }

    int compareRooms(String a, String b) {
      if (a.isEmpty && b.isEmpty) return 0;
      if (a.isEmpty) return 1;
      if (b.isEmpty) return -1;
      final na = int.tryParse(a.replaceAll(RegExp(r'[^0-9]'), ''));
      final nb = int.tryParse(b.replaceAll(RegExp(r'[^0-9]'), ''));
      if (na != null && nb != null && na != nb) return na.compareTo(nb);
      return dormSearchKey(a).compareTo(dormSearchKey(b));
    }

    rows.sort((a, b) {
      final cmp = switch (sortBy) {
        'events' => b.summary.totalEvents.compareTo(a.summary.totalEvents),
        'late' => b.summary.lateMinutes.compareTo(a.summary.lateMinutes),
        'room' => compareRooms(a.room, b.room),
        _ => 0,
      };
      if (cmp != 0) return cmp;
      return dormSearchKey(a.userName).compareTo(dormSearchKey(b.userName));
    });

    final cpList = cpMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final leaveCats = <String, int>{};
    for (final l in leaves.where((l) => !l.revoked)) {
      final startK = AppDate.dateKey(l.from);
      final endK = AppDate.dateKey(l.until);
      if (endK.compareTo(fromKey) < 0 || startK.compareTo(toKey) > 0) continue;
      final cat = l.category.isNotEmpty ? l.category : 'Diğer';
      leaveCats[cat] = (leaveCats[cat] ?? 0) + 1;
    }
    final leaveList = leaveCats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return _ReportAnalytics(
      studentSummaries: rows,
      orderedUserIds: rows.map((r) => r.summary.userId).toList(),
      checkpointCounts: cpList,
      hourlyEntries: hEntries,
      hourlyExits: hExits,
      leaveCategoryCounts: leaveList,
      totalEntries: entries,
      totalExits: exits,
      totalLate: late,
      totalLateMinutes: lateMin,
      totalLocationWarnings: locWarn,
    );
  }
}

class _AnalyticsDashboardView extends StatelessWidget {
  const _AnalyticsDashboardView({
    required this.analytics,
    required this.insideNowCount,
    required this.outsideNowCount,
    required this.totalActiveStudents,
    required this.attentionCount,
  });

  final _ReportAnalytics analytics;
  final int insideNowCount;
  final int outsideNowCount;
  final int totalActiveStudents;
  final int attentionCount;

  @override
  Widget build(BuildContext context) {
    final totalMovements = analytics.totalEntries + analytics.totalExits;
    if (totalMovements == 0) {
      return const DormEmpty(
        title: 'Analiz edilecek hareket yok',
        message: 'Seçilen filtreler için veri bulunamadı.',
      );
    }

    int maxHourCount = 1;
    int peakHour = 0;
    for (int h = 0; h < 24; h++) {
      final sum = analytics.hourlyEntries[h] + analytics.hourlyExits[h];
      if (sum > maxHourCount) {
        maxHourCount = sum;
        peakHour = h;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, bounds) {
            final int cols = bounds.maxWidth >= 820
                ? 4
                : bounds.maxWidth >= 460
                ? 2
                : 1;
            const double gap = 10;
            final double cardWidth = (bounds.maxWidth - gap * (cols - 1)) / cols;
            final kpis = <Widget>[
              _AnalyticsKpi(
                label: 'TOPLAM HAREKET',
                value: '$totalMovements',
                sub: '${analytics.totalEntries} giriş · ${analytics.totalExits} çıkış',
                color: AppColors.primary,
              ),
              _AnalyticsKpi(
                label: 'ANLIK İÇERİDE',
                value: '$insideNowCount öğrenci',
                sub: 'Toplam $totalActiveStudents aktif öğrenci içinde',
                color: AppColors.entry,
              ),
              _AnalyticsKpi(
                label: 'ANLIK DIŞARIDA',
                value: '$outsideNowCount öğrenci',
                sub: attentionCount > 0
                    ? '$attentionCount dikkat gerektiren durum'
                    : 'Şu an yurt dışında olanlar',
                color: AppColors.exit,
              ),
              _AnalyticsKpi(
                label: 'GECİKME & KONUM',
                value: '${analytics.totalLate} geç · ${analytics.totalLocationWarnings} konum',
                sub: 'Toplam ${analytics.totalLateMinutes} dk geç dönüş',
                color: AppColors.warning,
              ),
            ];
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final k in kpis) SizedBox(width: cardWidth, child: k),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Saatlik giriş–çıkış yoğunluğu (00:00 – 23:59)',
                      style: AppTypography.bodyStrong(context.colors.onSurface),
                    ),
                  ),
                  Text(
                    'En yoğun: ${peakHour.toString().padLeft(2, '0')}:00',
                    style: AppTypography.caption(AppColors.primary),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 132,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (int h = 0; h < 24; h++)
                      Expanded(
                        child: Tooltip(
                          message:
                              '${h.toString().padLeft(2, '0')}:00 · ${analytics.hourlyEntries[h]} giriş, ${analytics.hourlyExits[h]} çıkış',
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Align(
                                  alignment: Alignment.bottomCenter,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 1.5,
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        if (analytics.hourlyExits[h] > 0)
                                          Container(
                                            height: math.max(
                                              3,
                                              95 *
                                                  (analytics.hourlyExits[h] /
                                                      maxHourCount),
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.exit,
                                              borderRadius: BorderRadius.circular(
                                                2,
                                              ),
                                            ),
                                          ),
                                        if (analytics.hourlyEntries[h] > 0) ...[
                                          if (analytics.hourlyExits[h] > 0)
                                            const SizedBox(height: 1),
                                          Container(
                                            height: math.max(
                                              3,
                                              95 *
                                                  (analytics.hourlyEntries[h] /
                                                      maxHourCount),
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.entry,
                                              borderRadius: BorderRadius.circular(
                                                2,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                h % 3 == 0 ? h.toString().padLeft(2, '0') : '',
                                style: AppTypography.caption(
                                  context.colors.onSurfaceVariant,
                                ).copyWith(fontSize: 9.5),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const DormMovementLegend(),
            ],
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, bounds) {
            final checkpointCard = AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Kapı / QR noktası dağılımı',
                    style: AppTypography.bodyStrong(context.colors.onSurface),
                  ),
                  const SizedBox(height: 10),
                  for (final entry in analytics.checkpointCounts) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.key,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.small(context.colors.onSurface),
                          ),
                        ),
                        Text(
                          '${entry.value} (%${(entry.value * 100 / totalMovements).round()})',
                          style: AppTypography.caption(
                            context.colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: entry.value / totalMovements,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            );

            final leaveCard = AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Dönem içi izin nedenleri',
                    style: AppTypography.bodyStrong(context.colors.onSurface),
                  ),
                  const SizedBox(height: 10),
                  if (analytics.leaveCategoryCounts.isEmpty)
                    Text(
                      'Bu tarih aralığında aktif izin kaydı bulunmuyor.',
                      style: AppTypography.small(
                        context.colors.onSurfaceVariant,
                      ),
                    )
                  else
                    for (final entry in analytics.leaveCategoryCounts)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                entry.key,
                                style: AppTypography.small(
                                  context.colors.onSurface,
                                ),
                              ),
                            ),
                            StatusChip(
                              label: '${entry.value} izin',
                              tone: StatusTone.info,
                              compact: true,
                            ),
                          ],
                        ),
                      ),
                ],
              ),
            );

            if (bounds.maxWidth >= 700) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: checkpointCard),
                  const SizedBox(width: 12),
                  Expanded(child: leaveCard),
                ],
              );
            }
            return Column(
              children: [
                checkpointCard,
                const SizedBox(height: 12),
                leaveCard,
              ],
            );
          },
        ),
      ],
    );
  }
}

class _AnalyticsKpi extends StatelessWidget {
  const _AnalyticsKpi({
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
  });

  final String label;
  final String value;
  final String sub;
  final Color color;

  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.eyebrow(context.colors.onSurfaceVariant),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: AppTypography.h2(context.colors.onSurface).copyWith(
            fontSize: 18,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          sub,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.caption(context.colors.onSurfaceVariant),
        ),
      ],
    ),
  );
}

class _RawEventTableView extends StatefulWidget {
  const _RawEventTableView({
    required this.events,
    required this.usersById,
    this.attentionLogs = const <AttentionResolution>[],
  });

  final List<AttendanceEvent> events;
  final Map<String, AppUser> usersById;
  final List<AttentionResolution> attentionLogs;

  @override
  State<_RawEventTableView> createState() => _RawEventTableViewState();
}

class _RawEventTableViewState extends State<_RawEventTableView> {
  int _limit = 60;

  @override
  Widget build(BuildContext context) {
    if (widget.events.isEmpty) {
      return const DormEmpty(
        title: 'Bu aralıkta hareket yok',
        message: 'Seçilen filtrelere uygun kayıt bulunamadı.',
      );
    }

    final visible = widget.events.take(_limit).toList();
    final Color headerBg = context.isDark
        ? AppColors.surfaceAltDark
        : AppColors.gray50;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: headerBg,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppRadius.lg),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'ÖĞRENCİ VE HAREKET DETAYI',
                        style: AppTypography.eyebrow(
                          context.colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Text(
                      '${visible.length} / ${widget.events.length} kayıt',
                      style: AppTypography.caption(
                        context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              for (int i = 0; i < visible.length; i++) ...[
                _RawLedgerRow(
                  event: visible[i],
                  student: widget.usersById[visible[i].userId],
                  resolutionLog: widget.attentionLogs
                      .cast<AttentionResolution?>()
                      .firstWhere(
                        (l) =>
                            l != null &&
                            ((l.eventId.isNotEmpty &&
                                    l.eventId == visible[i].id) ||
                                (l.eventId.isEmpty &&
                                    l.userId == visible[i].userId &&
                                    l.dateKey == visible[i].dateKey)),
                        orElse: () => null,
                      ),
                ),
                if (i < visible.length - 1) const Divider(height: 1),
              ],
            ],
          ),
        ),
        if (widget.events.length > _limit) ...[
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => setState(() => _limit += 60),
            child: Text(
              'Daha fazla satır göster (${widget.events.length - _limit})',
            ),
          ),
        ],
      ],
    );
  }
}

class _RawLedgerRow extends StatelessWidget {
  const _RawLedgerRow({
    required this.event,
    this.student,
    this.resolutionLog,
  });

  final AttendanceEvent event;
  final AppUser? student;
  final AttentionResolution? resolutionLog;

  @override
  Widget build(BuildContext context) {
    final bool isEntry = event.type.isEntry;
    final Color color = isEntry ? AppColors.entry : AppColors.exit;
    final Color surface = isEntry
        ? AppColors.entrySurface
        : AppColors.exitSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: surface, shape: BoxShape.circle),
            child: Icon(
              isEntry ? Icons.login_rounded : Icons.logout_rounded,
              size: 16,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  [
                    event.userName,
                    if ((student?.room ?? '').isNotEmpty) 'Oda ${student!.room}',
                  ].join(' · '),
                  style: AppTypography.bodyStrong(
                    context.colors.onSurface,
                  ).copyWith(fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    event.checkpointName,
                    AppDate.dateTime(event.at),
                    if (event.distanceMeters != null)
                      '${event.distanceMeters!.round()} m',
                    if (event.lateMinutes > 0) '${event.lateMinutes} dk geç',
                    if (event.permitted) 'İzinli',
                    if (event.verdict.needsAttention) event.verdict.label,
                  ].join(' · '),
                  style: AppTypography.caption(context.colors.onSurfaceVariant),
                ),
                if (resolutionLog != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    'Çözüm notu: ${resolutionLog!.resolutionNote}',
                    style: AppTypography.caption(
                      AppColors.primary,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            event.type.label,
            style: AppTypography.label(color).copyWith(fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}
