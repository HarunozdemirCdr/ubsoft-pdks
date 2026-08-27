import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ubsoft_pdks/application/attendance/attendance_providers.dart';
import 'package:ubsoft_pdks/application/auth/session_provider.dart';
import 'package:ubsoft_pdks/core/extensions/context_x.dart';
import 'package:ubsoft_pdks/core/routing/app_routes.dart';
import 'package:ubsoft_pdks/core/theme/app_spacing.dart';
import 'package:ubsoft_pdks/core/theme/app_typography.dart';
import 'package:ubsoft_pdks/core/utils/date_x.dart';
import 'package:ubsoft_pdks/domain/entities/app_user.dart';
import 'package:ubsoft_pdks/domain/entities/attendance_day.dart';
import 'package:ubsoft_pdks/domain/permissions/app_permission.dart';
import 'package:ubsoft_pdks/presentation/features/history/widgets/day_roster_table.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_scaffold.dart';
import 'package:ubsoft_pdks/presentation/widgets/empty_state.dart';
import 'package:ubsoft_pdks/presentation/widgets/info_hint.dart';
import 'package:ubsoft_pdks/presentation/widgets/section_header.dart';

/// Geçmiş — bir günün tüm kadrosu tek tabloda.
///
/// Bu ekranın işi **gözlem**dir: "dün kim kaçta geldi, kim gelmedi" sorusu
/// tek bakışta cevaplanmalıdır. Bu yüzden satırlar kişi kartı değil, hizalı
/// bir tablo satırıdır; gün değiştikçe gözün aradığı yer değişmez.
///
/// Kişi bazlı derinlemesine inceleme (bir personelin son on dört günü, geç
/// geldiği günlerin dökümü, yazdırılabilir belge) buraya değil **Raporlar**
/// ekranına aittir. İki ekran birbirinin kopyası olmasın diye buradan kişi
/// geçmişine geçiş bilinçli olarak kaldırıldı; bir satıra dokunmak o günün
/// okutmalarını yerinde açar, günden çıkarmaz.
///
/// Yalnız kendi kayıtlarını görebilen bir personel bu ekranı açtığında
/// doğrudan kendi geçmişine yönlendirilir; ona başkalarının bulunmadığı bir
/// tablo göstermenin anlamı yok.
class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  String? _expandedUserId;

  @override
  Widget build(BuildContext context) {
    final bool canViewAll = ref.watch(
      canProvider(AppPermission.attendanceViewAll),
    );

    if (!canViewAll) {
      final AppUser? user = ref.watch(currentUserProvider);
      if (user == null) return const AppScaffold(body: SizedBox.shrink());
      return _OwnHistoryRedirect(userId: user.uid);
    }

    final String dateKey = ref.watch(selectedDayProvider);
    final DateTime date = DateTime.tryParse(dateKey) ?? DateTime.now();
    final List<AttendanceDay> rows = ref.watch(dayRosterProvider(dateKey));
    final DayOverview overview = ref.watch(dayOverviewProvider(dateKey));

    return AppScaffold(
      title: 'Geçmiş',
      maxContentWidth: AppWidths.wide,
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppSpacing.vSm,
          _DayPicker(
            date: date,
            onChanged: (DateTime value) {
              setState(() => _expandedUserId = null);
              ref.read(selectedDayProvider.notifier).select(value);
            },
          ),
          AppSpacing.vLg,

          SectionHeader(
            title: AppDate.date(date),
            dense: true,
            description:
                '${overview.completed} tamamlandı · ${overview.absent} '
                'gelmedi · ${overview.flagged} dikkat isteyen',
          ),
          AppSpacing.vSm,

          if (rows.isEmpty)
            const EmptyState(
              icon: Icons.history_rounded,
              title: 'Bu gün için kayıt yok',
              description: 'Başka bir gün seçin.',
              compact: true,
            )
          else ...<Widget>[
            DayRosterTable(
              days: rows,
              dateKey: dateKey,
              expandedUserId: _expandedUserId,
              onToggle: (String userId) => setState(
                () =>
                    _expandedUserId = _expandedUserId == userId ? null : userId,
              ),
            ),
            AppSpacing.vSm,
            const InfoNote(
              message:
                  'Bir personelin birden çok günü ya da yazdırılabilir '
                  'dökümü için Raporlar ekranını kullanın.',
            ),
          ],
          AppSpacing.vXl,
        ],
      ),
    );
  }
}

/// Gün seçici — önceki gün, tarih, sonraki gün.
///
/// İleri düğmesi bugünden sonrasında kapanır: gelecekte devam kaydı olmaz ve
/// boş bir günü göstermek kullanıcıya veri kaybı gibi görünürdü.
class _DayPicker extends StatelessWidget {
  const _DayPicker({required this.date, required this.onChanged});

  final DateTime date;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final bool isToday = AppDate.isToday(date);

    return Row(
      children: <Widget>[
        IconButton(
          tooltip: 'Önceki gün',
          icon: const Icon(Icons.chevron_left_rounded),
          onPressed: () => onChanged(date.subtract(const Duration(days: 1))),
        ),
        Expanded(
          child: TextButton(
            onPressed: () => _pick(context),
            child: Text(
              isToday ? 'Bugün' : AppDate.dateShort(date),
              style: AppTypography.bodyStrong(context.colors.onSurface),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Sonraki gün',
          icon: const Icon(Icons.chevron_right_rounded),
          onPressed: isToday
              ? null
              : () => onChanged(date.add(const Duration(days: 1))),
        ),
      ],
    );
  }

  Future<void> _pick(BuildContext context) async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
      locale: const Locale('tr'),
    );
    if (picked != null) onChanged(picked);
  }
}

/// Kendi kayıtlarıyla sınırlı kullanıcıyı doğrudan kendi geçmişine taşır.
class _OwnHistoryRedirect extends StatefulWidget {
  const _OwnHistoryRedirect({required this.userId});

  final String userId;

  @override
  State<_OwnHistoryRedirect> createState() => _OwnHistoryRedirectState();
}

class _OwnHistoryRedirectState extends State<_OwnHistoryRedirect> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.go(AppRoutes.personHistoryPath(widget.userId));
    });
  }

  @override
  Widget build(BuildContext context) =>
      const AppScaffold(body: Center(child: CircularProgressIndicator()));
}
