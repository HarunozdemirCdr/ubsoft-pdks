import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubsoft_pdks/application/auth/session_provider.dart';
import 'package:ubsoft_pdks/application/providers.dart';
import 'package:ubsoft_pdks/application/report/report_providers.dart';
import 'package:ubsoft_pdks/core/error/failure.dart';
import 'package:ubsoft_pdks/core/result/result.dart';
import 'package:ubsoft_pdks/domain/entities/attendance_event.dart';
import 'package:ubsoft_pdks/domain/entities/tenant.dart';

/// Yöneticinin devam kayıtları üzerindeki işlemleri.
///
/// Şu an tek bir iş yapar: yanlış bir okutmayı silmek. **Düzeltme yoktur** —
/// bir devam kaydının saati elle değiştirilebiliyorsa o kayıt artık kanıt
/// değildir. Yanlış okutma silinir, öğrenci yeniden okutur.
class AttendanceAdminController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<Result<void>> deleteEvent(AttendanceEvent event) async {
    state = const AsyncValue<void>.loading();

    final Tenant? tenant = ref.read(currentTenantProvider);
    if (tenant == null) {
      const AuthFailure failure = AuthFailure(
        'Oturumunuz sona ermiş. Lütfen tekrar giriş yapın.',
      );
      state = AsyncValue<void>.error(failure, StackTrace.current);
      return const Err<void>(failure);
    }

    final Result<void> result = await ref
        .read(attendanceRepositoryProvider)
        .deleteEvent(tenant: tenant, event: event);

    // Rapor verisi oturum boyunca önbellekte tutulur (okuma maliyeti için);
    // silinen bir okutmadan sonra o önbellek yanlış olur.
    if (result.isOk) ref.invalidate(reportDaysProvider);

    state = switch (result) {
      Ok<void>() => const AsyncValue<void>.data(null),
      Err<void>(:final Failure failure) => AsyncValue<void>.error(
        failure,
        StackTrace.current,
      ),
    };
    return result;
  }
}

final AsyncNotifierProvider<AttendanceAdminController, void>
attendanceAdminControllerProvider =
    AsyncNotifierProvider<AttendanceAdminController, void>(
      AttendanceAdminController.new,
    );
