import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubsoft_pdks/application/attendance/attendance_admin_controller.dart';
import 'package:ubsoft_pdks/application/attendance/attendance_providers.dart';
import 'package:ubsoft_pdks/application/auth/session_provider.dart';
import 'package:ubsoft_pdks/core/result/result.dart';
import 'package:ubsoft_pdks/core/theme/app_spacing.dart';
import 'package:ubsoft_pdks/domain/entities/attendance_event.dart';
import 'package:ubsoft_pdks/domain/permissions/app_permission.dart';
import 'package:ubsoft_pdks/presentation/features/punch/widgets/punch_event_tile.dart';
import 'package:ubsoft_pdks/presentation/widgets/async_value_view.dart';
import 'package:ubsoft_pdks/presentation/widgets/confirm_dialog.dart';
import 'package:ubsoft_pdks/services/notification/toast_service.dart';

/// Bir personelin bir gündeki okutmaları.
///
/// Geçmiş tablosunda, rapor ayrıntısında ve kişi geçmişinde aynı liste
/// kullanılır: okutmanın kanıt değeri (saat, nokta, konum rozeti) her üç
/// ekranda da aynı biçimde görünmelidir.
class DayPunchList extends ConsumerWidget {
  const DayPunchList({
    required this.userId,
    required this.dateKey,
    this.padding = const EdgeInsets.only(left: AppSpacing.md),
    super.key,
  });

  final String userId;
  final String dateKey;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool canDelete = ref.watch(
      canProvider(AppPermission.attendanceDelete),
    );

    return Padding(
      padding: padding,
      child: AsyncValueView<List<AttendanceEvent>>(
        value: ref.watch(
          personDayEventsProvider((userId: userId, dateKey: dateKey)),
        ),
        compact: true,
        builder: (List<AttendanceEvent> events) => Column(
          children: <Widget>[
            for (final AttendanceEvent event in events)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
                child: PunchEventTile(
                  event: event,
                  onDelete: canDelete
                      ? () => _confirmDelete(context, ref, event)
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    AttendanceEvent event,
  ) async {
    final bool ok = await ConfirmDialog.show(
      context,
      title: 'Okutma silinsin mi?',
      message:
          '${event.timeLabel} ${event.type.label.toLowerCase()} kaydı '
          'silinecek ve günün çalışma süresi yeniden hesaplanacak. '
          'Bu işlem geri alınamaz.',
      confirmLabel: 'Sil',
      isDestructive: true,
    );
    if (!ok) return;

    final Result<void> result = await ref
        .read(attendanceAdminControllerProvider.notifier)
        .deleteEvent(event);

    Toast.result(result, successMessage: 'Okutma silindi.');
  }
}
