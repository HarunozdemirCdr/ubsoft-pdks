import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubsoft_pdks/application/auth/session_provider.dart';
import 'package:ubsoft_pdks/application/settings/settings_providers.dart';
import 'package:ubsoft_pdks/core/config/app_config.dart';
import 'package:ubsoft_pdks/core/extensions/context_x.dart';
import 'package:ubsoft_pdks/core/result/result.dart';
import 'package:ubsoft_pdks/core/theme/app_spacing.dart';
import 'package:ubsoft_pdks/core/theme/app_typography.dart';
import 'package:ubsoft_pdks/core/utils/date_x.dart';
import 'package:ubsoft_pdks/core/utils/validators.dart';
import 'package:ubsoft_pdks/domain/entities/tenant.dart';
import 'package:ubsoft_pdks/domain/permissions/app_permission.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_button.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_card.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_scaffold.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_text_field.dart';
import 'package:ubsoft_pdks/presentation/widgets/info_hint.dart';
import 'package:ubsoft_pdks/presentation/widgets/section_header.dart';
import 'package:ubsoft_pdks/presentation/widgets/status_chip.dart';
import 'package:ubsoft_pdks/services/notification/toast_service.dart';

/// Yurt ayarları: ad, giriş saatleri ve konum kuralları.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _radius = TextEditingController();

  TimeOfDay _start = const TimeOfDay(hour: 6, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 23, minute: 0);
  bool _requireLocation = true;
  bool _blockOutside = false;
  bool _seeded = false;

  @override
  void dispose() {
    _name.dispose();
    _radius.dispose();
    super.dispose();
  }

  void _seed(Tenant tenant) {
    if (_seeded) return;
    _seeded = true;

    final TenantSettings settings = tenant.settings;
    _name.text = tenant.name;
    _radius.text = '${settings.defaultRadiusMeters}';
    _start = _toTime(settings.workStartMinutes);
    _end = _toTime(settings.workEndMinutes);
    _requireLocation = settings.requireLocation;
    _blockOutside = settings.blockOutsideScans;
  }

  static TimeOfDay _toTime(int minutes) =>
      TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);

  static int _toMinutes(TimeOfDay time) => time.hour * 60 + time.minute;

  Future<void> _pickTime({required bool isStart}) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _start : _end,
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _start = picked;
      } else {
        _end = picked;
      }
    });
  }

  Future<void> _save() async {
    final Tenant? tenant = ref.read(currentTenantProvider);
    if (tenant == null) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_toMinutes(_start) >= _toMinutes(_end)) {
      Toast.warning('İlk giriş saati, son giriş saatinden önce olmalıdır.');
      return;
    }
    FocusScope.of(context).unfocus();

    final Result<void> result = await ref
        .read(settingsControllerProvider.notifier)
        .save(
          name: _name.text,
          settings: TenantSettings(
            defaultRadiusMeters:
                int.tryParse(_radius.text.trim()) ??
                AppConfig.defaultRadiusMeters,
            requireLocation: _requireLocation,
            blockOutsideScans: _blockOutside,
            workStartMinutes: _toMinutes(_start),
            workEndMinutes: _toMinutes(_end),
            lateToleranceMinutes: tenant.settings.lateToleranceMinutes,
          ),
        );

    Toast.result(result, successMessage: 'Ayarlar kaydedildi.');
  }

  @override
  Widget build(BuildContext context) {
    final Tenant? tenant = ref.watch(currentTenantProvider);
    if (tenant == null) {
      return const AppScaffold(
        title: 'Ayarlar',
        body: Center(child: CircularProgressIndicator()),
      );
    }
    _seed(tenant);

    final bool canEdit = ref.watch(canProvider(AppPermission.settingsEdit));
    final bool busy = ref.watch(settingsControllerProvider).isLoading;

    return AppScaffold(
      title: 'Ayarlar',
      scrollable: true,
      bottomBar: canEdit
          ? AppButton.primaryWide(
              label: 'Ayarları kaydet',
              isLoading: busy,
              onPressed: _save,
            )
          : null,
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppSpacing.vSm,
            _SubscriptionCard(tenant: tenant),
            AppSpacing.vLg,

            const SectionHeader(title: 'Yurt', dense: true),
            AppSpacing.vMd,
            AppTextField(
              label: 'Yurt adı',
              controller: _name,
              isRequired: true,
              enabled: canEdit,
              validator: (String? v) =>
                  Validators.required(v, field: 'Yurt adı'),
            ),

            AppSpacing.vLg,
            const SectionHeader(
              title: 'Yurt giriş saatleri',
              dense: true,
              description:
                  'Öğrenciler bu saat aralığında giriş yapar. Son giriş saati '
                  'aşılırsa kayıt yönetici için işaretlenir.',
            ),
            AppSpacing.vMd,
            AppCard(
              child: Column(
                children: <Widget>[
                  _TimeRow(
                    label: 'İlk giriş saati',
                    value: _start,
                    enabled: canEdit,
                    onTap: () => _pickTime(isStart: true),
                  ),
                  const Divider(height: AppSpacing.lg),
                  _TimeRow(
                    label: 'Son giriş saati',
                    value: _end,
                    enabled: canEdit,
                    onTap: () => _pickTime(isStart: false),
                  ),
                ],
              ),
            ),

            AppSpacing.vLg,
            const SectionHeader(
              title: 'Konum kuralları',
              dense: true,
              description:
                  'Okutmanın gerçekten yurtta yapıldığını bu ayarlar '
                  'belirler.',
            ),
            AppSpacing.vMd,
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  AppTextField(
                    label: 'Varsayılan yarıçap (metre)',
                    controller: _radius,
                    enabled: canEdit,
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    helper:
                        'Yeni QR noktalarına önerilir; her nokta kendi '
                        'yarıçapını ayrıca ayarlayabilir.',
                    validator: (String? v) => Validators.positiveInt(
                      v,
                      field: 'Yarıçap',
                      min: AppConfig.minRadiusMeters,
                      max: AppConfig.maxRadiusMeters,
                    ),
                  ),
                  AppSpacing.vSm,
                  SwitchListTile.adaptive(
                    value: _requireLocation,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Konum zorunlu olsun'),
                    subtitle: const Text(
                      'Konum alınamazsa okutma reddedilir. Kapalıyken kayıt '
                      '"Konum yok" damgasıyla tutulur.',
                    ),
                    onChanged: canEdit
                        ? (bool value) =>
                              setState(() => _requireLocation = value)
                        : null,
                  ),
                  SwitchListTile.adaptive(
                    value: _blockOutside,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Nokta dışındaki okutmaları reddet'),
                    subtitle: const Text(
                      'Kapalı tutmanız önerilir: hatalı bir GPS ölçümü '
                      'yüzünden reddedilen giriş, öğrenciyi o gün hiç '
                      'gelmemiş gösterir.',
                    ),
                    onChanged: canEdit
                        ? (bool value) => setState(() => _blockOutside = value)
                        : null,
                  ),
                ],
              ),
            ),

            AppSpacing.vMd,
            const InfoNote(
              message:
                  'Konum verisi yalnız okutma anında, bir kez ölçülür ve o '
                  'kaydın parçası olarak saklanır. Uygulama öğrenciyi sürekli '
                  'takip etmez.',
            ),
            AppSpacing.vXl,
          ],
        ),
      ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final TimeOfDay value;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: AppTypography.body(context.colors.onSurface),
          ),
        ),
        AppButton(
          label:
              '${value.hour.toString().padLeft(2, '0')}:'
              '${value.minute.toString().padLeft(2, '0')}',
          size: AppButtonSize.small,
          variant: AppButtonVariant.outline,
          onPressed: enabled ? onTap : null,
        ),
      ],
    );
  }
}

/// Abonelik durumu — yönetici hesabının ne zamana kadar geçerli olduğu.
class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard({required this.tenant});

  final Tenant tenant;

  @override
  Widget build(BuildContext context) {
    final Subscription subscription = tenant.subscription;
    final bool expired = subscription.isExpired;

    return AppCard(
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  '${subscription.plan.label} abonelik',
                  style: AppTypography.bodyStrong(context.colors.onSurface),
                ),
                AppSpacing.vXxs,
                Text(
                  expired
                      ? '${AppDate.date(subscription.expiresAt)} tarihinde doldu'
                      : '${AppDate.date(subscription.expiresAt)} tarihine kadar '
                            'geçerli',
                  style: AppTypography.small(context.colors.onSurfaceVariant),
                ),
                AppSpacing.vXxs,
                Text(
                  '${tenant.counters.userCount}/${subscription.maxUsers} '
                  'kullanıcı · '
                  '${tenant.counters.checkpointCount}/'
                  '${subscription.maxCheckpoints} nokta',
                  style: AppTypography.small(context.colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          StatusChip(
            label: expired
                ? 'Süresi doldu'
                : subscription.isExpiringSoon
                ? '${subscription.daysRemaining} gün kaldı'
                : 'Aktif',
            tone: expired
                ? StatusTone.danger
                : subscription.isExpiringSoon
                ? StatusTone.warning
                : StatusTone.success,
            compact: true,
          ),
        ],
      ),
    );
  }
}
