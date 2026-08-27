import 'package:flutter/material.dart';
import 'package:ubsoft_pdks/core/theme/app_colors.dart';
import 'package:ubsoft_pdks/core/theme/app_radius.dart';
import 'package:ubsoft_pdks/core/theme/app_spacing.dart';

/// Oturum çözülürken gösterilen ara ekran.
///
/// HTML açılış ekranı Flutter ilk kareyi çizince kaldırılır; oturumun
/// Firestore'dan çözülmesi bundan birkaç yüz milisaniye sonra tamamlanır.
/// Bu ekran o boşluğu doldurur, kullanıcı beyaz bir sayfa görmez.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: AppRadius.allLg,
              ),
              child: SizedBox(
                width: 56,
                height: 56,
                child: Icon(
                  Icons.shield_outlined,
                  size: 28,
                  color: AppColors.white,
                ),
              ),
            ),
            AppSpacing.vLg,
            SizedBox(width: 120, child: LinearProgressIndicator(minHeight: 3)),
          ],
        ),
      ),
    );
  }
}
