import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubsoft_pdks/application/auth/auth_controller.dart';
import 'package:ubsoft_pdks/application/auth/session_provider.dart';
import 'package:ubsoft_pdks/core/extensions/context_x.dart';
import 'package:ubsoft_pdks/core/theme/app_spacing.dart';
import 'package:ubsoft_pdks/core/theme/app_typography.dart';
import 'package:ubsoft_pdks/domain/entities/session.dart';
import 'package:ubsoft_pdks/presentation/features/auth/widgets/auth_layout.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_button.dart';

/// Oturum açıldı ancak erişim yok.
///
/// Kullanıcı ne yapması gerektiğini bilmeli: sebebi açıkça yazılır ve tek
/// makul eylem (çıkış yapıp başka hesapla girmek) sunulur.
class BlockedPage extends ConsumerWidget {
  const BlockedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Session session = ref.watch(currentSessionProvider);
    final SessionBlockReason reason = session is SessionBlocked
        ? session.reason
        : SessionBlockReason.userInactive;

    final (IconData icon, String title) = switch (reason) {
      SessionBlockReason.tenantSuspended => (
        Icons.workspace_premium_outlined,
        'Abonelik askıda',
      ),
      SessionBlockReason.subscriptionExpired => (
        Icons.event_busy_outlined,
        'Abonelik süresi doldu',
      ),
      SessionBlockReason.userInactive => (
        Icons.person_off_outlined,
        'Hesabınız devre dışı',
      ),
      SessionBlockReason.profileMissing => (
        Icons.person_search_outlined,
        'Hesap tanımlı değil',
      ),
      SessionBlockReason.tenantMissing => (
        Icons.business_outlined,
        'Şirket kaydı bulunamadı',
      ),
    };

    return AuthLayout(
      icon: icon,
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            reason.message,
            textAlign: TextAlign.center,
            style: AppTypography.body(context.colors.onSurfaceVariant),
          ),
          AppSpacing.vLg,
          AppButton.primaryWide(
            label: 'Çıkış Yap',
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
            icon: Icons.logout_rounded,
          ),
        ],
      ),
    );
  }
}
