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
  String _viewTab = 'students'; // students | analytics | rooms | raw
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
    final usersById = ref.watch(usersByIdProvider);
    final leaves = ref.watch(dormLeavesProvider).value ?? const <StudentLeave>[];
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
                'Tarih, oda, öğrenci, saat aralığı ve uyarı türüne göre verileri süzün; süre analizini inceleyin ve PDF veya Excel (CSV) çıktısı alın.',
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
                          'inside',
                          'En uzun içeride',
                          Icons.login_rounded,
                        ),
                        DormOption(
                          'outside',
                          'En uzun dışarıda',
                          Icons.logout_rounded,
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

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${analytics.studentSummaries.length} öğrenci · ${events.length} hareket',
                              style: AppTypography.bodyStrong(
                                context.colors.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${analytics.totalEntries} giriş · ${analytics.totalExits} çıkış · İçeride: ${DormDurationCalculator.formatDuration(analytics.totalInside)} · Dışarıda: ${DormDurationCalculator.formatDuration(analytics.totalOutside)}',
                              style: AppTypography.caption(
                                context.colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            AppButton(
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
                                    ),
                            ),
                            AppButton(
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
                                    ),
                            ),
                          ],
                        ),
                      ],
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
                          'rooms',
                          'Oda & Gün Kırılımı',
                          icon: Icons.meeting_room_outlined,
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
                        onSelectRoom: (room) => setState(() {
                          _roomFilter = room;
                          _viewTab = 'students';
                        }),
                      )
                    else if (_viewTab == 'rooms')
                      _RoomAndDayMatrixView(
                        analytics: analytics,
                        onFilterRoom: (room) => setState(() {
                          _roomFilter = room;
                          _viewTab = 'students';
                        }),
                      )
                    else if (_viewTab == 'raw')
                      _RawEventTableView(
                        events: events,
                        usersById: usersById,
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
  ) {
    final buf = StringBuffer();
    String csvCell(String value) => '"${value.replaceAll('"', '""')}"';

    // Özet + öğrenci matrisi
    buf.writeln(
      'Öğrenci;Oda No;Öğrenci No;Giriş;Çıkış;İçeride Süre;Dışarıda Süre;Geç Giriş Sayısı;Toplam Gecikme (dk);Erken Çıkış;Konum Uyarısı',
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
          csvCell(DormDurationCalculator.formatDuration(row.summary.insideDuration)),
          csvCell(DormDurationCalculator.formatDuration(row.summary.outsideDuration)),
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
        'Tarih;Saat;Öğrenci;Oda No;Öğrenci No;İşlem;Nokta;Mesafe (m);Konum Durumu;Gecikme (dk);İzinli;Erken Çıkış;Erken Giriş',
      );
    for (final e in events) {
      final u = usersById[e.userId];
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
        ].join(';'),
      );
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

class _RoomRowData {
  const _RoomRowData({
    required this.room,
    required this.studentCount,
    required this.entryCount,
    required this.exitCount,
    required this.lateCount,
    required this.insideDuration,
    required this.outsideDuration,
  });

  final String room;
  final int studentCount;
  final int entryCount;
  final int exitCount;
  final int lateCount;
  final Duration insideDuration;
  final Duration outsideDuration;
}

class _DayRowData {
  const _DayRowData({
    required this.dateKey,
    required this.studentCount,
    required this.entryCount,
    required this.exitCount,
    required this.lateCount,
    required this.locationWarnings,
  });

  final String dateKey;
  final int studentCount;
  final int entryCount;
  final int exitCount;
  final int lateCount;
  final int locationWarnings;
}

class _ReportAnalytics {
  const _ReportAnalytics({
    required this.studentSummaries,
    required this.orderedUserIds,
    required this.roomRows,
    required this.dayRows,
    required this.checkpointCounts,
    required this.hourlyEntries,
    required this.hourlyExits,
    required this.leaveCategoryCounts,
    required this.totalEntries,
    required this.totalExits,
    required this.totalLate,
    required this.totalLateMinutes,
    required this.totalLocationWarnings,
    required this.totalInside,
    required this.totalOutside,
  });

  final List<_StudentRowData> studentSummaries;
  final List<String> orderedUserIds;
  final List<_RoomRowData> roomRows;
  final List<_DayRowData> dayRows;
  final List<MapEntry<String, int>> checkpointCounts;
  final List<int> hourlyEntries;
  final List<int> hourlyExits;
  final List<MapEntry<String, int>> leaveCategoryCounts;
  final int totalEntries;
  final int totalExits;
  final int totalLate;
  final int totalLateMinutes;
  final int totalLocationWarnings;
  final Duration totalInside;
  final Duration totalOutside;

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
    final dayMap = <String, List<AttendanceEvent>>{};
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
      dayMap.putIfAbsent(e.dateKey, () => []).add(e);
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

    Duration sumInside = Duration.zero;
    Duration sumOutside = Duration.zero;
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
      sumInside += summary.insideDuration;
      sumOutside += summary.outsideDuration;
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
        'inside' => b.summary.insideDuration.compareTo(
          a.summary.insideDuration,
        ),
        'outside' => b.summary.outsideDuration.compareTo(
          a.summary.outsideDuration,
        ),
        'room' => compareRooms(a.room, b.room),
        _ => 0,
      };
      if (cmp != 0) return cmp;
      return dormSearchKey(a.userName).compareTo(dormSearchKey(b.userName));
    });

    final roomAgg = <String, List<_StudentRowData>>{};
    for (final r in rows) {
      roomAgg.putIfAbsent(r.room, () => []).add(r);
    }
    final roomRows = roomAgg.entries.map((entry) {
      Duration rIn = Duration.zero;
      Duration rOut = Duration.zero;
      int rEnt = 0;
      int rEx = 0;
      int rLate = 0;
      for (final item in entry.value) {
        rIn += item.summary.insideDuration;
        rOut += item.summary.outsideDuration;
        rEnt += item.summary.entryCount;
        rEx += item.summary.exitCount;
        rLate += item.summary.lateCount;
      }
      return _RoomRowData(
        room: entry.key,
        studentCount: entry.value.length,
        entryCount: rEnt,
        exitCount: rEx,
        lateCount: rLate,
        insideDuration: rIn,
        outsideDuration: rOut,
      );
    }).toList()..sort((a, b) => compareRooms(a.room, b.room));

    final dayRows = dayMap.entries.map((entry) {
      final list = entry.value;
      return _DayRowData(
        dateKey: entry.key,
        studentCount: list.map((e) => e.userId).toSet().length,
        entryCount: list.where((e) => e.type.isEntry).length,
        exitCount: list.where((e) => e.type.isExit).length,
        lateCount: list.where((e) => e.lateMinutes > 0).length,
        locationWarnings: list.where((e) => e.verdict.needsAttention).length,
      );
    }).toList()..sort((a, b) => b.dateKey.compareTo(a.dateKey));

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
      roomRows: roomRows,
      dayRows: dayRows,
      checkpointCounts: cpList,
      hourlyEntries: hEntries,
      hourlyExits: hExits,
      leaveCategoryCounts: leaveList,
      totalEntries: entries,
      totalExits: exits,
      totalLate: late,
      totalLateMinutes: lateMin,
      totalLocationWarnings: locWarn,
      totalInside: sumInside,
      totalOutside: sumOutside,
    );
  }
}

class _AnalyticsDashboardView extends StatelessWidget {
  const _AnalyticsDashboardView({
    required this.analytics,
    required this.onSelectRoom,
  });

  final _ReportAnalytics analytics;
  final ValueChanged<String> onSelectRoom;

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
                label: 'İÇERİDE SÜRE',
                value: DormDurationCalculator.formatDuration(analytics.totalInside),
                sub: '${analytics.studentSummaries.length} öğrenci toplamı',
                color: AppColors.entry,
              ),
              _AnalyticsKpi(
                label: 'DIŞARIDA SÜRE',
                value: DormDurationCalculator.formatDuration(analytics.totalOutside),
                sub: 'Ölçülen çıkış aralıkları',
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
    child: IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 3,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: AppTypography.eyebrow(context.colors.onSurfaceVariant),
                ),
                const SizedBox(height: 4),
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
          ),
        ],
      ),
    ),
  );
}

class _RoomAndDayMatrixView extends StatelessWidget {
  const _RoomAndDayMatrixView({
    required this.analytics,
    required this.onFilterRoom,
  });

  final _ReportAnalytics analytics;
  final ValueChanged<String> onFilterRoom;

  @override
  Widget build(BuildContext context) {
    if (analytics.roomRows.isEmpty && analytics.dayRows.isEmpty) {
      return const DormEmpty(
        title: 'Bu aralıkta hareket yok',
        message: 'Farklı bir tarih aralığı veya filtre seçin.',
      );
    }

    final Color headerBg = context.isDark
        ? AppColors.surfaceAltDark
        : AppColors.gray50;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (analytics.roomRows.isNotEmpty) ...[
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
                          'ODA BAZLI HAREKET ÖZETİ',
                          style: AppTypography.eyebrow(
                            context.colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Text(
                        '${analytics.roomRows.length} oda · filtre için satıra dokunun',
                        style: AppTypography.caption(
                          context.colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                for (int i = 0; i < analytics.roomRows.length; i++) ...[
                  _RoomMatrixRow(
                    row: analytics.roomRows[i],
                    onTap: analytics.roomRows[i].room.isEmpty
                        ? null
                        : () => onFilterRoom(analytics.roomRows[i].room),
                  ),
                  if (i < analytics.roomRows.length - 1) const Divider(height: 1),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (analytics.dayRows.isNotEmpty)
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
                          'GÜN BAZLI HAREKET DÖKÜMÜ',
                          style: AppTypography.eyebrow(
                            context.colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Text(
                        '${analytics.dayRows.length} gün',
                        style: AppTypography.caption(
                          context.colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                for (int i = 0; i < analytics.dayRows.length; i++) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 11,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                dormDisplayDate(analytics.dayRows[i].dateKey),
                                style: AppTypography.bodyStrong(
                                  context.colors.onSurface,
                                ),
                              ),
                              Text(
                                '${analytics.dayRows[i].studentCount} öğrenci · ${analytics.dayRows[i].entryCount} giriş · ${analytics.dayRows[i].exitCount} çıkış',
                                style: AppTypography.caption(
                                  context.colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (analytics.dayRows[i].lateCount > 0)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: StatusChip(
                              label: '${analytics.dayRows[i].lateCount} geç',
                              tone: StatusTone.warning,
                              compact: true,
                            ),
                          ),
                        if (analytics.dayRows[i].locationWarnings > 0)
                          StatusChip(
                            label: '${analytics.dayRows[i].locationWarnings} konum',
                            tone: StatusTone.warning,
                            compact: true,
                          ),
                      ],
                    ),
                  ),
                  if (i < analytics.dayRows.length - 1) const Divider(height: 1),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _RoomMatrixRow extends StatelessWidget {
  const _RoomMatrixRow({required this.row, this.onTap});

  final _RoomRowData row;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Wrap(
        spacing: 12,
        runSpacing: 6,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                row.room.isEmpty ? 'Oda atanmamış' : 'Oda ${row.room}',
                style: AppTypography.bodyStrong(context.colors.onSurface),
              ),
              Text(
                '${row.studentCount} öğrenci · ${row.entryCount} giriş · ${row.exitCount} çıkış',
                style: AppTypography.caption(context.colors.onSurfaceVariant),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusChip(
                label:
                    'İçeride: ${DormDurationCalculator.formatDuration(row.insideDuration)}',
                tone: StatusTone.success,
                compact: true,
              ),
              StatusChip(
                label:
                    'Dışarıda: ${DormDurationCalculator.formatDuration(row.outsideDuration)}',
                tone: StatusTone.danger,
                compact: true,
              ),
              if (row.lateCount > 0)
                StatusChip(
                  label: '${row.lateCount} gecikme',
                  tone: StatusTone.warning,
                  compact: true,
                ),
              if (onTap != null)
                Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: context.colors.onSurfaceVariant,
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _RawEventTableView extends StatefulWidget {
  const _RawEventTableView({
    required this.events,
    required this.usersById,
  });

  final List<AttendanceEvent> events;
  final Map<String, AppUser> usersById;

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
  const _RawLedgerRow({required this.event, this.student});

  final AttendanceEvent event;
  final AppUser? student;

  @override
  Widget build(BuildContext context) {
    final bool isEntry = event.type.isEntry;
    final Color color = isEntry ? AppColors.entry : AppColors.exit;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 28,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
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
