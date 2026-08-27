import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ubsoft_pdks/core/routing/app_routes.dart';
import 'package:ubsoft_pdks/presentation/widgets/empty_state.dart';

/// Tanımsız adres.
class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: EmptyState(
          icon: Icons.explore_off_outlined,
          title: 'Sayfa bulunamadı',
          description:
              'Aradığınız adres taşınmış ya da hiç var olmamış olabilir.',
          actionLabel: 'Ana sayfaya dön',
          onAction: () => context.go(AppRoutes.root),
        ),
      ),
    );
  }
}
