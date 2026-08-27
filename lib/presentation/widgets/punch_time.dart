import 'package:flutter/material.dart';
import 'package:ubsoft_pdks/core/extensions/context_x.dart';
import 'package:ubsoft_pdks/core/theme/app_colors.dart';
import 'package:ubsoft_pdks/core/theme/app_spacing.dart';
import 'package:ubsoft_pdks/core/theme/app_typography.dart';
import 'package:ubsoft_pdks/core/utils/date_x.dart';

/// Bir devam saati: yön ikonu + saatin kendisi, giriş yeşil çıkış kırmızı.
///
/// Saat de ikonla **aynı renktedir**. Yalnız ikonu renklendirmek, listeye
/// göz gezdiren yöneticiyi her satırda küçük bir ikonu okumaya zorlardı;
/// oysa asıl aranan şey saatin kendisidir.
///
/// Kayıt yoksa hem ikon hem çizgi soluk gridir: "okutulmamış" ile "erken
/// çıkmış" birbirine karışmaz.
class PunchTime extends StatelessWidget {
  const PunchTime({
    required this.at,
    required this.isEntry,
    this.dense = false,
    super.key,
  });

  /// Giriş için ilk giriş saati, çıkış için son çıkış saati. `null` ise `—`.
  final DateTime? at;

  final bool isEntry;

  /// Dar tablolarda ikon ve punto bir tık küçülür.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final bool dark = context.isDark;
    final bool missing = at == null;

    final Color color = missing
        ? context.colors.onSurfaceVariant.withValues(alpha: 0.6)
        : isEntry
        ? (dark ? AppColors.entryOnDark : AppColors.entry)
        : (dark ? AppColors.exitOnDark : AppColors.exit);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(
          isEntry ? Icons.login_rounded : Icons.logout_rounded,
          size: dense ? 15 : 17,
          color: color,
        ),
        const SizedBox(width: AppSpacing.xxs + 1),
        Text(
          missing ? '—' : AppDate.time(at!),
          style: AppTypography.bodyStrong(color).copyWith(
            fontSize: dense ? 13 : 15,
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// Giriş ve çıkış saatlerinin hizalı çifti.
///
/// İki saat sabit genişlikli kolonlarda durur; alt alta gelen satırlarda
/// rakamlar hizalanır ve tablo gözle taranabilir hâle gelir.
class PunchTimePair extends StatelessWidget {
  const PunchTimePair({
    required this.entryAt,
    required this.exitAt,
    this.dense = false,
    this.columnWidth = 78,
    super.key,
  });

  final DateTime? entryAt;
  final DateTime? exitAt;
  final bool dense;
  final double columnWidth;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          width: columnWidth,
          child: PunchTime(at: entryAt, isEntry: true, dense: dense),
        ),
        SizedBox(
          width: columnWidth,
          child: PunchTime(at: exitAt, isEntry: false, dense: dense),
        ),
      ],
    );
  }
}
