import 'package:flutter/material.dart';
import 'package:ubsoft_pdks/core/extensions/context_x.dart';
import 'package:ubsoft_pdks/core/theme/app_radius.dart';
import 'package:ubsoft_pdks/core/theme/app_spacing.dart';
import 'package:ubsoft_pdks/core/theme/app_typography.dart';
import 'package:ubsoft_pdks/core/utils/date_x.dart';
import 'package:ubsoft_pdks/domain/entities/attendance_day.dart';
import 'package:ubsoft_pdks/domain/enums/day_status.dart';
import 'package:ubsoft_pdks/presentation/formatters/enum_labels.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_card.dart';
import 'package:ubsoft_pdks/presentation/widgets/punch_time.dart';
import 'package:ubsoft_pdks/presentation/widgets/status_chip.dart';

/// Bir personelin bir gündeki satırı: ad, giriş, çıkış, süre, durum.
///
/// Hem günlük panelde hem raporun ayrıntısında aynı satır kullanılır; iki
/// ekranın aynı veriyi farklı biçimde göstermesi kafa karıştırırdı.
///
/// Giriş ve çıkış saatleri düz metin değil renkli birer [PunchTime]'dır:
/// yön, metni okumadan önce renkten anlaşılır.
class AttendanceDayTile extends StatelessWidget {
  const AttendanceDayTile({
    required this.day,
    this.onTap,
    this.showName = true,
    this.showDate = false,
    this.showFlags = true,
    super.key,
  });

  final AttendanceDay day;
  final VoidCallback? onTap;

  /// Personel adı yazılsın mı? (Kişinin kendi geçmişinde gereksiz.)
  final bool showName;

  /// Başlıkta gün yazılsın mı? (Kişinin geçmiş listesinde gerekir.)
  final bool showDate;

  /// Geç giriş ve konum rozetleri gösterilsin mi?
  ///
  /// Personelin kendi ekranında kapatılır; orada gösterilen tek yargı günün
  /// durumudur (tamamlandı / çıkış yok / giriş yok).
  final bool showFlags;

  @override
  Widget build(BuildContext context) {
    final DayStatus status = day.statusAt(DateTime.now());
    final bool flagged = !day.isEmpty && day.worstVerdict.needsAttention;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          _Avatar(name: day.userName, status: status),
          AppSpacing.hSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  showDate ? _dateTitle() : day.userName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyStrong(context.colors.onSurface),
                ),
                AppSpacing.vXxs,
                if (day.isEmpty)
                  Text(
                    showName ? 'Okutma yok' : 'Bu gün okutma yapılmamış',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.small(context.colors.onSurfaceVariant),
                  )
                else
                  Row(
                    children: <Widget>[
                      PunchTimePair(
                        entryAt: day.firstEntryAt,
                        exitAt: day.lastExitAt,
                        dense: true,
                        columnWidth: 72,
                      ),
                      if (_durationLabel() case final String label)
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.small(
                              context.colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
          AppSpacing.hXs,
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              StatusChip(
                label: showFlags ? status.label : status.selfLabel,
                tone: EnumLabels.toneOf(status),
                compact: true,
              ),
              if (showFlags && (day.late || flagged)) ...<Widget>[
                AppSpacing.vXxs,
                StatusChip(
                  label: day.late ? 'Geç' : day.worstVerdict.label,
                  tone: day.late
                      ? StatusTone.warning
                      : EnumLabels.toneOfVerdict(day.worstVerdict),
                  compact: true,
                ),
              ],
            ],
          ),
          if (onTap != null) ...<Widget>[
            AppSpacing.hXxs,
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: context.colors.onSurfaceVariant,
            ),
          ],
        ],
      ),
    );
  }

  String _dateTitle() =>
      '${AppDate.dateShort(_dateOf())} · ${AppDate.dayName(_dateOf())}';

  /// Gün anahtarını tarihe çevirir. Bozuk anahtar bugüne düşer — satır
  /// kaybolmaktansa yanlış başlıkla görünmesi yeğdir.
  DateTime _dateOf() => DateTime.tryParse(day.dateKey) ?? DateTime.now();

  /// Saatlerin yanındaki `· 8 sa 12 dk`. Süre yoksa `null`.
  String? _durationLabel() {
    final int minutes = day.workedMinutesAt(DateTime.now());
    if (minutes <= 0) return null;
    return '· ${AppDate.durationHuman(Duration(minutes: minutes))}';
  }
}

/// Ad baş harflerini taşıyan yuvarlak kutu; rengi günün durumundan gelir.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.status});

  final String name;
  final DayStatus status;

  @override
  Widget build(BuildContext context) {
    final bool muted = status.isAbsent;

    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: muted
            ? context.colors.surfaceContainerHigh
            : context.colors.primaryContainer,
        borderRadius: AppRadius.allMd,
      ),
      child: Text(
        _initials(),
        style: AppTypography.caption(
          muted ? context.colors.onSurfaceVariant : context.colors.primary,
        ),
      ),
    );
  }

  String _initials() {
    final List<String> parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((String p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}
