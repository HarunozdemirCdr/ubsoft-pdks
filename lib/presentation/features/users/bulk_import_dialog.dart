import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubsoft_pdks/application/auth/session_provider.dart';
import 'package:ubsoft_pdks/application/user/user_providers.dart';
import 'package:ubsoft_pdks/core/extensions/context_x.dart';
import 'package:ubsoft_pdks/core/result/result.dart';
import 'package:ubsoft_pdks/core/theme/app_colors.dart';
import 'package:ubsoft_pdks/core/theme/app_spacing.dart';
import 'package:ubsoft_pdks/core/theme/app_typography.dart';
import 'package:ubsoft_pdks/domain/entities/app_user.dart';
import 'package:ubsoft_pdks/domain/entities/tenant.dart';
import 'package:ubsoft_pdks/domain/enums/user_role.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_button.dart';
import 'package:ubsoft_pdks/services/export/file_download_service.dart';
import 'package:ubsoft_pdks/services/import/student_csv_parser.dart';
import 'package:ubsoft_pdks/services/notification/toast_service.dart';

/// Excel'den kopyalanan satırlar veya CSV metni ile toplu öğrenci aktarımı.
class BulkStudentImportDialog extends ConsumerStatefulWidget {
  const BulkStudentImportDialog({super.key});

  @override
  ConsumerState<BulkStudentImportDialog> createState() =>
      _BulkStudentImportDialogState();
}

class _BulkStudentImportDialogState
    extends ConsumerState<BulkStudentImportDialog> {
  final TextEditingController _input = TextEditingController();
  bool _importing = false;
  int _processed = 0;
  int _total = 0;
  int _created = 0;
  final List<String> _errors = <String>[];

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _startImport(StudentImportParseResult parsed) async {
    if (!parsed.hasValidRows || _importing) return;
    setState(() {
      _importing = true;
      _processed = 0;
      _total = parsed.rows.length;
      _created = 0;
      _errors.clear();
    });

    final controller = ref.read(userControllerProvider.notifier);
    for (final row in parsed.rows) {
      final Result<AppUser> result = await controller.createUser(
        email: row.email,
        password: row.password,
        displayName: row.displayName,
        role: UserRole.staff,
        phone: row.phone,
        studentNumber: row.studentNumber,
        room: row.room,
      );
      if (!mounted) return;
      setState(() {
        _processed++;
        switch (result) {
          case Ok<AppUser>():
            _created++;
          case Err<AppUser>(:final failure):
            _errors.add('Satır ${row.lineNumber} (${row.email}): ${failure.message}');
        }
      });
    }

    if (!mounted) return;
    setState(() => _importing = false);
    if (_errors.isEmpty) {
      Toast.success('$_created öğrenci başarıyla eklendi.');
      Navigator.of(context).pop(true);
    } else {
      Toast.error('$_created öğrenci eklendi, ${_errors.length} satırda hata oluştu.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final StudentImportParseResult parsed = parseStudentTable(_input.text);
    final Tenant? tenant = ref.watch(currentTenantProvider);
    final int? remaining = tenant == null
        ? null
        : (tenant.subscription.maxUsers - tenant.counters.userCount).clamp(
            0,
            tenant.subscription.maxUsers,
          );
    final bool exceedsQuota =
        remaining != null && parsed.rows.length > remaining;

    return AlertDialog(
      title: const Text('Toplu öğrenci aktarımı (Excel / CSV)'),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Excel tablosundan satırları kopyalayıp aşağıya yapıştırın veya CSV metni girin. '
                'Sütun sırası: Ad Soyad · E-posta · Şifre · [Oda] · [Öğrenci No] · [Telefon]',
                style: AppTypography.small(context.colors.onSurfaceVariant),
              ),
              AppSpacing.vSm,
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _importing
                      ? null
                      : () => FileDownloadService.download(
                            bytes: utf8.encode(buildSampleStudentCsv()),
                            fileName: 'ornek-ogrenciler.csv',
                          ),
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('Örnek CSV şablonu indir'),
                ),
              ),
              AppSpacing.vMd,
              TextField(
                controller: _input,
                enabled: !_importing,
                minLines: 6,
                maxLines: 10,
                decoration: const InputDecoration(
                  hintText:
                      'Elif Yılmaz;elif@yurt.edu.tr;123456;101;2026001;5551112233\n'
                      'Zeynep Kaya;zeynep@yurt.edu.tr;123456;102;2026002;5551112234',
                ),
                onChanged: (_) => setState(() {}),
              ),
              AppSpacing.vSm,
              if (_input.text.trim().isNotEmpty)
                Text(
                  '${parsed.rows.length} geçerli satır · ${parsed.issues.length} hatalı satır'
                  '${remaining == null ? '' : ' · Kalan kota: $remaining'}',
                  style: AppTypography.caption(
                    exceedsQuota || parsed.issues.isNotEmpty
                        ? AppColors.warning
                        : AppColors.entry,
                  ),
                ),
              if (exceedsQuota) ...<Widget>[
                AppSpacing.vXs,
                Text(
                  'Seçilen öğrenci sayısı (${parsed.rows.length}) kalan kullanıcı kotasını ($remaining) aşıyor.',
                  style: AppTypography.caption(AppColors.danger),
                ),
              ],
              if (parsed.issues.isNotEmpty) ...<Widget>[
                AppSpacing.vXs,
                for (final issue in parsed.issues.take(5))
                  Text(
                    'Satır ${issue.lineNumber}: ${issue.message}',
                    style: AppTypography.caption(AppColors.danger),
                  ),
                if (parsed.issues.length > 5)
                  Text(
                    've ${parsed.issues.length - 5} diğer uyarı...',
                    style: AppTypography.caption(AppColors.danger),
                  ),
              ],
              if (_importing || _errors.isNotEmpty) ...<Widget>[
                AppSpacing.vMd,
                if (_importing) LinearProgressIndicator(value: _total == 0 ? null : _processed / _total),
                AppSpacing.vXs,
                Text(
                  '$_processed / $_total işlendi ($_created başarılı)',
                  style: AppTypography.small(context.colors.onSurface),
                ),
                for (final err in _errors.take(5))
                  Text(err, style: AppTypography.caption(AppColors.danger)),
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _importing ? null : () => Navigator.of(context).pop(false),
          child: const Text('Kapat'),
        ),
        AppButton(
          label: 'Aktar (${parsed.rows.length})',
          size: AppButtonSize.small,
          isLoading: _importing,
          onPressed: !_importing && parsed.hasValidRows && !exceedsQuota
              ? () => _startImport(parsed)
              : null,
        ),
      ],
    );
  }
}
