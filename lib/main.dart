import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ubsoft_pdks/bootstrap.dart';
import 'package:ubsoft_pdks/core/config/app_config.dart';
import 'package:ubsoft_pdks/core/routing/app_router.dart';
import 'package:ubsoft_pdks/core/theme/app_theme.dart';
import 'package:ubsoft_pdks/services/notification/toast_service.dart';

void main() => bootstrap(PdksApp.new);

class PdksApp extends ConsumerWidget {
  const PdksApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GoRouter router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: Toast.messengerKey,
      routerConfig: router,

      // Uygulama daima açık temada çalışır. Karanlık tema hazır durur ama
      // devreye girmez: cihaz ayarına göre kendiliğinden değişmesi, aynı
      // ekranı iki farklı kullanıcının iki farklı görmesi demekti.
      theme: AppTheme.light,
      darkTheme: AppTheme.light,
      themeMode: ThemeMode.light,

      locale: const Locale('tr'),
      supportedLocales: const <Locale>[Locale('tr')],
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
