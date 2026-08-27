import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ubsoft_pdks/application/auth/session_provider.dart';
import 'package:ubsoft_pdks/application/checkpoint/checkpoint_providers.dart';
import 'package:ubsoft_pdks/core/config/app_config.dart';
import 'package:ubsoft_pdks/core/extensions/context_x.dart';
import 'package:ubsoft_pdks/core/result/result.dart';
import 'package:ubsoft_pdks/core/routing/app_routes.dart';
import 'package:ubsoft_pdks/core/theme/app_spacing.dart';
import 'package:ubsoft_pdks/core/theme/app_typography.dart';
import 'package:ubsoft_pdks/core/utils/validators.dart';
import 'package:ubsoft_pdks/domain/entities/checkpoint.dart';
import 'package:ubsoft_pdks/domain/entities/scan_location.dart';
import 'package:ubsoft_pdks/domain/entities/tenant.dart';
import 'package:ubsoft_pdks/domain/enums/punch_type.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_button.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_card.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_scaffold.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_text_field.dart';
import 'package:ubsoft_pdks/presentation/widgets/confirm_dialog.dart';
import 'package:ubsoft_pdks/presentation/widgets/info_hint.dart';
import 'package:ubsoft_pdks/presentation/widgets/section_header.dart';
import 'package:ubsoft_pdks/services/location/location_service.dart';
import 'package:ubsoft_pdks/services/notification/toast_service.dart';

/// QR noktası oluşturma ve düzenleme.
///
/// Konum bu ekranın asıl işidir. İki yol vardır ve ikisi de gerekir:
///  • **Bulunduğum konumu al** — yönetici noktanın yanındayken bir dokunuş.
///  • **Elle koordinat** — ofisten kurulum yapılırken haritadan kopyalanan
///    koordinat yapıştırılır.
class CheckpointFormPage extends ConsumerStatefulWidget {
  const CheckpointFormPage({this.checkpointId, super.key});

  /// `null` ise yeni nokta.
  final String? checkpointId;

  @override
  ConsumerState<CheckpointFormPage> createState() => _CheckpointFormPageState();
}

class _CheckpointFormPageState extends ConsumerState<CheckpointFormPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _code = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _latitude = TextEditingController();
  final TextEditingController _longitude = TextEditingController();
  final TextEditingController _radius = TextEditingController();

  CheckpointKind _kind = CheckpointKind.entry;
  bool _active = true;
  bool _locating = false;
  bool _seeded = false;
  double? _capturedAccuracy;

  bool get _isNew => widget.checkpointId == null;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _description.dispose();
    _latitude.dispose();
    _longitude.dispose();
    _radius.dispose();
    super.dispose();
  }

  /// Var olan noktayı forma **bir kez** doldurur.
  ///
  /// Her çizimde doldurmak, kullanıcı yazarken alanları geri alırdı.
  void _seed(Checkpoint checkpoint) {
    if (_seeded) return;
    _seeded = true;

    _name.text = checkpoint.name;
    _code.text = checkpoint.code;
    _description.text = checkpoint.description ?? '';
    _radius.text = '${checkpoint.radiusMeters}';
    _kind = checkpoint.kind;
    _active = checkpoint.active;

    if (checkpoint.hasLocation) {
      _latitude.text = checkpoint.latitude.toStringAsFixed(6);
      _longitude.text = checkpoint.longitude.toStringAsFixed(6);
    }
  }

  void _seedDefaults(TenantSettings settings) {
    if (_seeded) return;
    _seeded = true;
    _radius.text = '${settings.defaultRadiusMeters}';
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);

    final Result<ScanLocation> result = await ref
        .read(locationServiceProvider)
        .current();

    if (!mounted) return;
    setState(() => _locating = false);

    switch (result) {
      case Ok<ScanLocation>(:final ScanLocation value):
        setState(() {
          _latitude.text = value.latitude.toStringAsFixed(6);
          _longitude.text = value.longitude.toStringAsFixed(6);
          _capturedAccuracy = value.accuracy;
        });
        Toast.success('Bulunduğunuz konum alındı.');
      case Err<ScanLocation>(:final failure):
        Toast.error(failure.message);
    }
  }

  Future<void> _submit(Checkpoint? existing) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    final double latitude = Validators.parseCoordinate(_latitude.text) ?? 0;
    final double longitude = Validators.parseCoordinate(_longitude.text) ?? 0;
    final int radius =
        int.tryParse(_radius.text.trim()) ?? AppConfig.defaultRadiusMeters;

    final Checkpoint draft = Checkpoint(
      id: existing?.id ?? '',
      code: _code.text.trim(),
      name: _name.text.trim(),
      description: _description.text.trim(),
      kind: _kind,
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radius,
      active: _active,
      order: existing?.order ?? 0,
      createdAt: existing?.createdAt ?? DateTime.now(),
      createdBy: existing?.createdBy,
    );

    final CheckpointController controller = ref.read(
      checkpointControllerProvider.notifier,
    );

    final Result<Object?> result = existing == null
        ? await controller.create(draft)
        : await controller.save(draft);

    if (!mounted) return;

    Toast.result(
      result,
      successMessage: existing == null
          ? 'Nokta oluşturuldu.'
          : 'Nokta güncellendi.',
    );
    if (result.isOk) context.go(AppRoutes.checkpoints);
  }

  Future<void> _delete(Checkpoint checkpoint) async {
    final bool ok = await ConfirmDialog.show(
      context,
      title: 'Nokta silinsin mi?',
      message:
          '${checkpoint.name} noktası ve ${checkpoint.code} kodu silinecek. '
          'Geçmiş okutma kayıtları korunur. Bu işlem geri alınamaz.',
      confirmLabel: 'Sil',
      isDestructive: true,
    );
    if (!ok || !mounted) return;

    final Result<void> result = await ref
        .read(checkpointControllerProvider.notifier)
        .delete(checkpoint);

    if (!mounted) return;
    Toast.result(result, successMessage: 'Nokta silindi.');
    if (result.isOk) context.go(AppRoutes.checkpoints);
  }

  @override
  Widget build(BuildContext context) {
    final Checkpoint? existing = _isNew
        ? null
        : ref.watch(checkpointProvider(widget.checkpointId!)).value;

    if (existing != null) {
      _seed(existing);
    } else if (_isNew) {
      final Tenant? tenant = ref.watch(currentTenantProvider);
      if (tenant != null) _seedDefaults(tenant.settings);
    }

    final bool busy = ref.watch(checkpointControllerProvider).isLoading;

    return AppScaffold(
      title: _isNew ? 'Yeni QR Noktası' : 'Noktayı Düzenle',
      showBackButton: true,
      scrollable: true,
      actions: <Widget>[
        if (existing != null)
          IconButton(
            tooltip: 'QR kodunu göster',
            icon: const Icon(Icons.qr_code_rounded),
            onPressed: () =>
                context.go(AppRoutes.checkpointQrPath(existing.id)),
          ),
      ],
      bottomBar: AppButton.primaryWide(
        label: _isNew ? 'Noktayı oluştur' : 'Değişiklikleri kaydet',
        isLoading: busy,
        onPressed: () => _submit(existing),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppSpacing.vSm,
            const SectionHeader(title: 'Nokta bilgileri', dense: true),
            AppSpacing.vMd,

            AppTextField(
              label: 'Nokta adı',
              controller: _name,
              isRequired: true,
              hint: 'Ana Giriş Kapısı',
              validator: (String? v) =>
                  Validators.required(v, field: 'Nokta adı'),
            ),
            AppSpacing.vMd,

            AppTextField(
              label: 'QR kodu',
              controller: _code,
              isRequired: true,
              hint: '1',
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(AppConfig.qrCodeMaxLength),
              ],
              helper:
                  'Etikete basılacak numara. Şirketiniz içinde tekil olmalı; '
                  'başka şirketlerde aynı numara kullanılabilir.',
              validator: Validators.qrCode,
            ),
            AppSpacing.vMd,

            AppTextField(
              label: 'Açıklama',
              controller: _description,
              hint: 'Turnikenin sol yanındaki tabela',
              maxLines: 2,
              validator: (String? v) =>
                  Validators.maxLength(v, 120, field: 'Açıklama'),
            ),
            AppSpacing.vLg,

            const SectionHeader(title: 'Ne için kullanılacak?', dense: true),
            AppSpacing.vSm,
            _KindSelector(
              value: _kind,
              onChanged: (CheckpointKind value) =>
                  setState(() => _kind = value),
            ),
            AppSpacing.vLg,

            const SectionHeader(
              title: 'Konum',
              dense: true,
              description:
                  'Okutmanın gerçekten burada yapılıp yapılmadığı bu '
                  'koordinata olan uzaklıkla ölçülür.',
            ),
            AppSpacing.vMd,

            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  AppButton(
                    label: 'Bulunduğum konumu al',
                    icon: Icons.my_location_rounded,
                    variant: AppButtonVariant.outline,
                    expand: true,
                    isLoading: _locating,
                    onPressed: _useCurrentLocation,
                  ),
                  if (_capturedAccuracy case final double accuracy) ...<Widget>[
                    AppSpacing.vXs,
                    Text(
                      'Ölçüm hassasiyeti ±${accuracy.round()} m. '
                      'Yarıçapı bundan küçük seçmeyin.',
                      style: AppTypography.small(
                        context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                  AppSpacing.vMd,
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: AppTextField(
                          label: 'Enlem',
                          controller: _latitude,
                          isRequired: true,
                          hint: '41.015137',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          validator: Validators.latitude,
                        ),
                      ),
                      AppSpacing.hSm,
                      Expanded(
                        child: AppTextField(
                          label: 'Boylam',
                          controller: _longitude,
                          isRequired: true,
                          hint: '28.979530',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          validator: Validators.longitude,
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.vMd,
                  AppTextField(
                    label: 'Yarıçap (metre)',
                    controller: _radius,
                    isRequired: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    helper:
                        'Bu mesafe içindeki okutmalar doğrulanmış sayılır. '
                        'Telefon GPS\'i şehir içinde 10–30 m yanılabilir; '
                        '${AppConfig.defaultRadiusMeters} m çoğu işyeri için '
                        'uygundur.',
                    validator: (String? v) => Validators.positiveInt(
                      v,
                      field: 'Yarıçap',
                      min: AppConfig.minRadiusMeters,
                      max: AppConfig.maxRadiusMeters,
                    ),
                  ),
                ],
              ),
            ),
            AppSpacing.vLg,

            SwitchListTile.adaptive(
              value: _active,
              onChanged: (bool value) => setState(() => _active = value),
              title: const Text('Nokta etkin'),
              subtitle: const Text(
                'Kapatıldığında bu koddan okutma yapılamaz.',
              ),
              contentPadding: EdgeInsets.zero,
            ),

            if (!_isNew) ...<Widget>[
              AppSpacing.vLg,
              const InfoNote(
                message:
                    'Kodu değiştirirseniz eski etiket çalışmaz. Yeni kodla '
                    'QR etiketini yeniden yazdırmayı unutmayın.',
              ),
              AppSpacing.vMd,
              if (existing != null)
                AppButton(
                  label: 'Noktayı sil',
                  icon: Icons.delete_outline_rounded,
                  variant: AppButtonVariant.danger,
                  expand: true,
                  onPressed: () => _delete(existing),
                ),
            ],
            AppSpacing.vXl,
          ],
        ),
      ),
    );
  }
}

/// Noktanın giriş mi, çıkış mı, ikisi birden mi olduğunu seçer.
class _KindSelector extends StatelessWidget {
  const _KindSelector({required this.value, required this.onChanged});

  final CheckpointKind value;
  final ValueChanged<CheckpointKind> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SegmentedButton<CheckpointKind>(
          segments: const <ButtonSegment<CheckpointKind>>[
            ButtonSegment<CheckpointKind>(
              value: CheckpointKind.entry,
              label: Text('Giriş'),
              icon: Icon(Icons.login_rounded),
            ),
            ButtonSegment<CheckpointKind>(
              value: CheckpointKind.exit,
              label: Text('Çıkış'),
              icon: Icon(Icons.logout_rounded),
            ),
            ButtonSegment<CheckpointKind>(
              value: CheckpointKind.both,
              label: Text('İkisi'),
              icon: Icon(Icons.swap_horiz_rounded),
            ),
          ],
          selected: <CheckpointKind>{value},
          onSelectionChanged: (Set<CheckpointKind> selection) =>
              onChanged(selection.first),
        ),
        AppSpacing.vXs,
        Text(switch (value) {
          CheckpointKind.entry =>
            'Bu kod okutulduğunda her zaman giriş kaydedilir.',
          CheckpointKind.exit =>
            'Bu kod okutulduğunda her zaman çıkış kaydedilir.',
          CheckpointKind.both =>
            'Tek etiket iki iş görür: personel içeride değilse giriş, '
                'içerideyse çıkış kaydedilir.',
        }, style: AppTypography.small(context.colors.onSurfaceVariant)),
      ],
    );
  }
}
