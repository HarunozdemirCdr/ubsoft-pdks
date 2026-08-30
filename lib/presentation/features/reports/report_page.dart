import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubsoft_pdks/application/auth/session_provider.dart';
import 'package:ubsoft_pdks/application/report/report_providers.dart';
import 'package:ubsoft_pdks/application/user/user_providers.dart';
import 'package:ubsoft_pdks/core/extensions/context_x.dart';
import 'package:ubsoft_pdks/core/theme/app_spacing.dart';
import 'package:ubsoft_pdks/core/theme/app_typography.dart';
import 'package:ubsoft_pdks/core/utils/date_x.dart';
import 'package:ubsoft_pdks/domain/entities/app_user.dart';
import 'package:ubsoft_pdks/domain/entities/attendance_day.dart';
import 'package:ubsoft_pdks/domain/entities/report_filter.dart';
import 'package:ubsoft_pdks/domain/enums/report_focus.dart';
import 'package:ubsoft_pdks/domain/permissions/app_permission.dart';
import 'package:ubsoft_pdks/presentation/features/history/widgets/day_punch_list.dart';
import 'package:ubsoft_pdks/presentation/features/today/widgets/attendance_day_tile.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_button.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_card.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_scaffold.dart';
import 'package:ubsoft_pdks/presentation/widgets/async_value_view.dart';
import 'package:ubsoft_pdks/presentation/widgets/empty_state.dart';
import 'package:ubsoft_pdks/presentation/widgets/info_hint.dart';
import 'package:ubsoft_pdks/presentation/widgets/section_header.dart';
import 'package:ubsoft_pdks/presentation/widgets/status_chip.dart';
import 'package:ubsoft_pdks/services/export/file_download_service.dart';
import 'package:ubsoft_pdks/services/export/pdf_report_service.dart';
import 'package:ubsoft_pdks/services/notification/toast_service.dart';

/// Devam raporu — iki tarih arası, gün gün.
///
/// Bu ekran **inceleme** içindir: aralık seçilir, istenirse tek personele ya
/// da yalnız geç gelinen günlere daraltılır, bir kişiye dokunulduğunda o
/// kişinin aralıktaki günleri gün gün açılır ve aynı içerik PDF olarak
/// indirilebilir. Günlük gözlem (dün kim kaçta geldi) Geçmiş ekranındadır.
///
/// Kişiye dokunmak başka bir sayfaya **gitmez**: rapor bir bütündür; aralık
/// ve süzgeç seçildikten sonra kişiler arasında gezinirken o seçimin
/// kaybolması, aynı ayarı her seferinde yeniden yapmayı gerektirirdi.
class ReportPage extends ConsumerStatefulWidget {
  const ReportPage({super.key});

  @override
  ConsumerState<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends ConsumerState<ReportPage> {
  bool _exporting = false;
  String? _expandedUserId;

  /// Açılmış gün: `{userId}|{dateKey}`.
  String? _expandedDay;

  Future<void> _pickRange(ReportFilter filter) async {
    final DateTime now = DateTime.now();
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
      initialDateRange: DateTimeRange(start: filter.from, end: filter.to),
      locale: const Locale('tr'),
    );
    if (picked == null) return;

    ref
        .read(reportFilterProvider.notifier)
        .setRange(from: picked.start, to: picked.end);
  }

  Future<void> _export(ReportResult report, String companyName) async {
    setState(() => _exporting = true);
    try {
      final Uint8List bytes = await PdfReportService.build(
        report: report,
        companyName: companyName,
      );
      FileDownloadService.download(
        bytes: bytes,
        fileName: PdfReportService.fileName(companyName, report.filter),
      );
      Toast.success('Rapor indirildi.');
    } catch (error) {
      Toast.failure(error);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ReportFilter filter = ref.watch(reportFilterProvider);
    final String companyName =
        ref.watch(currentTenantProvider)?.name ?? 'Şirket';
    final bool canExport = ref.watch(canProvider(AppPermission.reportExport));

    return AppScaffold(
      title: 'Raporlar',
      maxContentWidth: AppWidths.page,
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppSpacing.vSm,
          const SectionHeader(
            title: 'Devam raporu',
            description:
                'İki tarih arasını seçin, personele dokunun: o kişinin gün '
                'gün giriş ve çıkış saatleri açılır. Aynı döküm PDF olarak '
                'indirilebilir.',
          ),
          AppSpacing.vLg,

          _Filters(filter: filter, onPickRange: () => _pickRange(filter)),
          AppSpacing.vLg,

          AsyncValueView<ReportResult>(
            value: ref.watch(reportProvider(filter)),
            onRetry: () {
              // Hata okuma katmanında doğar ve orası önbelleklidir; yalnız
              // hesap sağlayıcısını tazelemek aynı hatayı geri getirirdi.
              ref
                ..invalidate(reportDaysProvider(ReportQuery.of(filter)))
                ..invalidate(reportProvider(filter));
            },
            builder: (ReportResult report) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (canExport && !report.isEmpty) ...<Widget>[
                  AppButton(
                    label: 'PDF olarak indir',
                    icon: Icons.download_rounded,
                    variant: AppButtonVariant.outline,
                    isLoading: _exporting,
                    onPressed: () => _export(report, companyName),
                  ),
                  AppSpacing.vMd,
                ],
                _ReportList(
                  report: report,
                  expandedUserId: _expandedUserId,
                  expandedDay: _expandedDay,
                  onToggleUser: (String userId) => setState(() {
                    _expandedUserId = _expandedUserId == userId ? null : userId;
                    _expandedDay = null;
                  }),
                  onToggleDay: (String key) => setState(
                    () => _expandedDay = _expandedDay == key ? null : key,
                  ),
                ),
              ],
            ),
          ),
          AppSpacing.vXl,
        ],
      ),
    );
  }
}

/// Tarih aralığı, personel ve gün süzgeci.
/// Hazır tarih aralıkları — açılır listenin seçenekleri.
///
/// Kullanıcının aralık seçmek için bildiği tek yer burasıdır; [custom]
/// takvimi açar ve seçilen aralık listede kendi tarihleriyle görünür.
enum _RangeChoice {
  today('Bugün'),
  last7('Son 7 gün'),
  last30('Son 30 gün'),
  thisMonth('Bu ay'),
  custom('Tarih seç…');

  const _RangeChoice(this.label);

  final String label;

  /// [custom] dışındaki seçeneklerin ürettiği aralık.
  ReportFilter? get filter => switch (this) {
    _RangeChoice.today => ReportFilter.today(),
    _RangeChoice.last7 => ReportFilter.lastDays(7),
    _RangeChoice.last30 => ReportFilter.lastDays(30),
    _RangeChoice.thisMonth => ReportFilter.thisMonth(),
    _RangeChoice.custom => null,
  };

  /// [current] hangi seçeneğe denk düşüyor? Hiçbirine uymuyorsa [custom].
  static _RangeChoice of(ReportFilter current) {
    for (final _RangeChoice choice in values) {
      final ReportFilter? preset = choice.filter;
      if (preset == null) continue;
      if (preset.fromKey == current.fromKey &&
          preset.toKey == current.toKey) {
        return choice;
      }
    }
    return _RangeChoice.custom;
  }
}

/// Rapor süzgeçleri: aralık, personel, hangi günler.
///
/// Üçü de açılır listedir ve hepsi aynı biçimdedir. Önceki hâlinde aralık
/// düğme + rozet dizisi, süzgeç ayrı bir rozet dizisiydi; aynı işi yapan üç
/// şey üç ayrı görünüme sahipti ve ekranın yarısını kaplıyordu. Açılır liste
/// hem seçili değeri hem seçenek sayısını tek satırda söyler.
class _Filters extends ConsumerWidget {
  const _Filters({required this.filter, required this.onPickRange});

  final ReportFilter filter;
  final VoidCallback onPickRange;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<AppUser> users = ref.watch(activeUsersProvider);
    final ReportFilterController controller = ref.read(
      reportFilterProvider.notifier,
    );
    final _RangeChoice choice = _RangeChoice.of(filter);

    final Widget range = _FilterDropdown<_RangeChoice>(
      label: 'Tarih aralığı',
      value: choice,
      values: _RangeChoice.values,
      labelOf: (_RangeChoice item) => item.label,
      // Kapalıyken özel aralık kendi tarihleriyle okunur; "Tarih seç…"
      // yazsaydı kullanıcı hangi aralığa baktığını göremezdi.
      selectedLabelOf: (_RangeChoice item) =>
          item == _RangeChoice.custom ? filter.label : item.label,
      onChanged: (_RangeChoice selected) {
        final ReportFilter? preset = selected.filter;
        if (preset == null) {
          onPickRange();
          return;
        }
        controller.preset(
          preset.copyWith(userId: filter.userId, focus: filter.focus),
        );
      },
    );

    final Widget person = _FilterDropdown<String?>(
      label: 'Personel',
      value: filter.userId,
      values: <String?>[null, for (final AppUser user in users) user.uid],
      labelOf: (String? uid) => uid == null
          ? 'Tüm personel'
          : users
                .firstWhere((AppUser user) => user.uid == uid)
                .displayName,
      onChanged: controller.setUser,
    );

    final Widget focus = _FilterDropdown<ReportFocus>(
      label: 'Hangi günler',
      value: filter.focus,
      values: ReportFocus.values,
      labelOf: (ReportFocus item) => item.label,
      onChanged: controller.setFocus,
    );

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              // Dar ekranda üç açılır liste yan yana sıkışır ve personel
              // adları okunmaz olur; orada alt alta dizilirler.
              if (constraints.maxWidth < 620) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    range,
                    AppSpacing.vSm,
                    person,
                    AppSpacing.vSm,
                    focus,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(child: range),
                  AppSpacing.hSm,
                  Expanded(child: person),
                  AppSpacing.hSm,
                  Expanded(child: focus),
                ],
              );
            },
          ),
          AppSpacing.vSm,
          Text(
            filter.focus.isAll
                ? '${filter.label} · ${filter.dayCount} gün'
                : '${filter.label} · ${filter.dayCount} gün — '
                      '${filter.focus.description}',
            style: AppTypography.small(context.colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Süzgeç açılır listesi — üçü de aynı biçimde.
///
/// `DropdownButtonFormField` yerine `DropdownButton` kullanılır çünkü ilki
/// seçili değeri **kendi içinde** tutar: dışarıdan gelen bir değişimi
/// yansıtmaz. Somut sonucu şuydu — kullanıcı "Tarih seç…"e basıp takvimi
/// kapatsa (iptal etse) bile liste "Tarih seç…"te takılı kalırdı, oysa
/// aralık hiç değişmemişti. Burada gösterilen değer her zaman süzgecin
/// gerçek hâlidir.
class _FilterDropdown<T> extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.values,
    required this.labelOf,
    required this.onChanged,
    this.selectedLabelOf,
  });

  final String label;
  final T value;
  final List<T> values;

  /// Listedeki satırın metni.
  final String Function(T) labelOf;

  /// Liste kapalıyken görünen metin. Verilmezse [labelOf] kullanılır.
  final String Function(T)? selectedLabelOf;

  final void Function(T) onChanged;

  @override
  Widget build(BuildContext context) {
    final String Function(T) closed = selectedLabelOf ?? labelOf;

    return InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          isDense: true,
          selectedItemBuilder: (BuildContext context) => <Widget>[
            for (final T item in values)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  closed(item),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          items: <DropdownMenuItem<T>>[
            for (final T item in values)
              DropdownMenuItem<T>(
                value: item,
                child: Text(labelOf(item), overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (T? selected) {
            if (selected != null || null is T) onChanged(selected as T);
          },
        ),
      ),
    );
  }
}

/// Personel satırları. Bir satıra dokunmak o kişinin günlerini açar.
class _ReportList extends StatelessWidget {
  const _ReportList({
    required this.report,
    required this.expandedUserId,
    required this.expandedDay,
    required this.onToggleUser,
    required this.onToggleDay,
  });

  final ReportResult report;
  final String? expandedUserId;
  final String? expandedDay;
  final ValueChanged<String> onToggleUser;
  final ValueChanged<String> onToggleDay;

  @override
  Widget build(BuildContext context) {
    if (report.isEmpty) {
      return EmptyState(
        icon: Icons.bar_chart_rounded,
        title: report.filter.focus.isAll
            ? 'Bu aralıkta kayıt yok'
            : '${report.filter.focus.label} bulunmadı',
        description: 'Tarih aralığını genişletin ya da süzgeci değiştirin.',
        compact: true,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final ReportRow row in report.rows)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: _RowCard(
              row: row,
              focus: report.filter.focus,
              expanded: expandedUserId == row.userId,
              expandedDay: expandedDay,
              onToggle: () => onToggleUser(row.userId),
              onToggleDay: onToggleDay,
            ),
          ),
        AppSpacing.vSm,
        const InfoNote(
          message:
              'Toplam süre, eşleşmiş giriş–çıkış çiftlerinden hesaplanır. '
              'Çıkışı okutulmamış günler bu toplama girmez; uygulama '
              'personelin ne zaman çıktığını uydurmaz.',
        ),
      ],
    );
  }
}

class _RowCard extends StatelessWidget {
  const _RowCard({
    required this.row,
    required this.focus,
    required this.expanded,
    required this.expandedDay,
    required this.onToggle,
    required this.onToggleDay,
  });

  final ReportRow row;
  final ReportFocus focus;
  final bool expanded;
  final String? expandedDay;
  final VoidCallback onToggle;
  final ValueChanged<String> onToggleDay;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppCard(
          onTap: onToggle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          row.userName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodyStrong(
                            context.colors.onSurface,
                          ),
                        ),
                        if (row.userNote.isNotEmpty)
                          Text(
                            row.userNote,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.small(
                              context.colors.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  AppSpacing.hXs,
                  Text(
                    AppDate.durationHuman(row.workedDuration),
                    style: AppTypography.h3(context.colors.onSurface),
                  ),
                  AppSpacing.hXxs,
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: context.colors.onSurfaceVariant,
                  ),
                ],
              ),
              AppSpacing.vXs,
              Text(
                _summaryLine(),
                style: AppTypography.small(context.colors.onSurfaceVariant),
              ),
              if (row.hasProblem) ...<Widget>[
                AppSpacing.vXs,
                Wrap(
                  spacing: AppSpacing.xxs,
                  runSpacing: AppSpacing.xxs,
                  children: <Widget>[
                    if (row.lateDays > 0)
                      StatusChip(
                        label: '${row.lateDays} geç giriş',
                        tone: StatusTone.warning,
                        compact: true,
                      ),
                    if (row.missingExitDays > 0)
                      StatusChip(
                        label: '${row.missingExitDays} çıkış yok',
                        tone: StatusTone.warning,
                        compact: true,
                      ),
                    if (row.flaggedDays > 0)
                      StatusChip(
                        label: '${row.flaggedDays} konum uyarısı',
                        tone: StatusTone.danger,
                        compact: true,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),

        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: expanded
              ? _DayBreakdown(
                  row: row,
                  expandedDay: expandedDay,
                  onToggleDay: onToggleDay,
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }

  /// `12 gün geldi · 8 gün gelmedi · günlük ort. 8 sa 40 dk`
  String _summaryLine() {
    final String average = row.presentDays == 0
        ? '—'
        : AppDate.durationHuman(Duration(minutes: row.averageMinutes));

    final String base =
        '${row.presentDays} gün geldi · ${row.absentDays} gün gelmedi · '
        'günlük ort. $average';

    return focus.isAll
        ? base
        : '$base · ${row.matchedDays} gün ${focus.label.toLowerCase()}';
  }
}

/// Açılan personelin gün gün dökümü.
class _DayBreakdown extends StatelessWidget {
  const _DayBreakdown({
    required this.row,
    required this.expandedDay,
    required this.onToggleDay,
  });

  final ReportRow row;
  final String? expandedDay;
  final ValueChanged<String> onToggleDay;

  @override
  Widget build(BuildContext context) {
    if (row.days.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(left: AppSpacing.md, top: AppSpacing.xs),
        child: Text(
          'Bu aralıkta gösterilecek gün yok.',
          style: AppTypography.small(context.colors.onSurfaceVariant),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.md, top: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final AttendanceDay day in row.days) ...<Widget>[
            AttendanceDayTile(
              day: day,
              showName: false,
              showDate: true,
              onTap: day.isEmpty
                  ? null
                  : () => onToggleDay('${row.userId}|${day.dateKey}'),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: expandedDay == '${row.userId}|${day.dateKey}'
                  ? DayPunchList(userId: row.userId, dateKey: day.dateKey)
                  : const SizedBox(width: double.infinity),
            ),
            AppSpacing.vXxs,
          ],
        ],
      ),
    );
  }
}
