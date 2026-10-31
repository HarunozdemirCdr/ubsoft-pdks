import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ubsoft_pdks/application/admin/tenant_providers.dart';
import 'package:ubsoft_pdks/core/extensions/context_x.dart';
import 'package:ubsoft_pdks/core/result/result.dart';
import 'package:ubsoft_pdks/core/routing/app_routes.dart';
import 'package:ubsoft_pdks/core/theme/app_spacing.dart';
import 'package:ubsoft_pdks/core/theme/app_typography.dart';
import 'package:ubsoft_pdks/core/utils/date_x.dart';
import 'package:ubsoft_pdks/core/utils/validators.dart';
import 'package:ubsoft_pdks/domain/entities/tenant.dart';
import 'package:ubsoft_pdks/domain/enums/tenant_status.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_button.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_card.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_scaffold.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_text_field.dart';
import 'package:ubsoft_pdks/presentation/widgets/info_hint.dart';
import 'package:ubsoft_pdks/presentation/widgets/section_header.dart';
import 'package:ubsoft_pdks/services/notification/toast_service.dart';

/// Yeni yurt açma — yurt, abonelik ve ilk yönetici tek formda.
///
/// Üçü birlikte sorulur çünkü yöneticisi olmayan bir yurda kimse
/// giremez; ayrı adımlara bölmek yarım kalmış hesaplar üretirdi.
class TenantFormPage extends ConsumerStatefulWidget {
  const TenantFormPage({super.key});

  @override
  ConsumerState<TenantFormPage> createState() => _TenantFormPageState();
}

class _TenantFormPageState extends ConsumerState<TenantFormPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _company = TextEditingController();
  final TextEditingController _slug = TextEditingController();
  final TextEditingController _adminName = TextEditingController();
  final TextEditingController _adminEmail = TextEditingController();
  final TextEditingController _adminPassword = TextEditingController();

  SubscriptionPlan _plan = SubscriptionPlan.trial;
  DateTime _expiresAt = DateTime.now().add(const Duration(days: 14));

  @override
  void dispose() {
    _company.dispose();
    _slug.dispose();
    _adminName.dispose();
    _adminEmail.dispose();
    _adminPassword.dispose();
    super.dispose();
  }

  /// Yurt adından adres dostu kısa ad üretir.
  void _syncSlug(String value) {
    _slug.text = value
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c')
        .replaceAll(RegExp('[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  Future<void> _pickExpiry() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _expiresAt,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
      locale: const Locale('tr'),
    );
    if (picked != null) setState(() => _expiresAt = picked);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    final Result<Tenant> result = await ref
        .read(tenantControllerProvider.notifier)
        .createTenantWithAdmin(
          companyName: _company.text,
          slug: _slug.text,
          adminEmail: _adminEmail.text,
          adminPassword: _adminPassword.text,
          adminName: _adminName.text,
          plan: _plan,
          expiresAt: _expiresAt,
        );

    if (!mounted) return;
    Toast.result(result, successMessage: 'Yurt açıldı.');
    if (result.isOk) context.go(AppRoutes.tenants);
  }

  @override
  Widget build(BuildContext context) {
    final bool busy = ref.watch(tenantControllerProvider).isLoading;

    return AppScaffold(
      title: 'Yeni Yurt',
      showBackButton: true,
      scrollable: true,
      bottomBar: AppButton.primaryWide(
        label: 'Yurtyi aç',
        isLoading: busy,
        onPressed: _submit,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppSpacing.vSm,
            const SectionHeader(title: 'Yurt', dense: true),
            AppSpacing.vMd,

            AppTextField(
              label: 'Yurt adı',
              controller: _company,
              isRequired: true,
              onChanged: _syncSlug,
              validator: (String? v) =>
                  Validators.required(v, field: 'Yurt adı'),
            ),
            AppSpacing.vMd,
            AppTextField(
              label: 'Kısa ad',
              controller: _slug,
              isRequired: true,
              helper: 'Yalnız küçük harf, rakam ve tire.',
              validator: (String? v) =>
                  Validators.required(v, field: 'Kısa ad'),
            ),

            AppSpacing.vLg,
            const SectionHeader(title: 'Abonelik', dense: true),
            AppSpacing.vMd,
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  DropdownButtonFormField<SubscriptionPlan>(
                    initialValue: _plan,
                    decoration: const InputDecoration(labelText: 'Plan'),
                    items: <DropdownMenuItem<SubscriptionPlan>>[
                      for (final SubscriptionPlan plan
                          in SubscriptionPlan.values)
                        DropdownMenuItem<SubscriptionPlan>(
                          value: plan,
                          child: Text(
                            '${plan.label} — ${plan.maxUsers} kullanıcı, '
                            '${plan.maxCheckpoints} nokta',
                          ),
                        ),
                    ],
                    onChanged: (SubscriptionPlan? value) {
                      if (value != null) setState(() => _plan = value);
                    },
                  ),
                  AppSpacing.vMd,
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'Bitiş tarihi',
                          style: AppTypography.body(context.colors.onSurface),
                        ),
                      ),
                      AppButton(
                        label: AppDate.dateShort(_expiresAt),
                        size: AppButtonSize.small,
                        variant: AppButtonVariant.outline,
                        onPressed: _pickExpiry,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            AppSpacing.vLg,
            const SectionHeader(title: 'İlk yönetici', dense: true),
            AppSpacing.vMd,

            AppTextField(
              label: 'Ad Soyad',
              controller: _adminName,
              isRequired: true,
              validator: (String? v) =>
                  Validators.required(v, field: 'Ad Soyad'),
            ),
            AppSpacing.vMd,
            AppTextField(
              label: 'E-posta',
              controller: _adminEmail,
              isRequired: true,
              keyboardType: TextInputType.emailAddress,
              validator: Validators.email,
            ),
            AppSpacing.vMd,
            AppPasswordField(
              label: 'Geçici şifre',
              controller: _adminPassword,
              validator: Validators.password,
            ),

            AppSpacing.vLg,
            const InfoNote(
              message:
                  'Yurt açıldığında rol varsayılanları da kurulur. '
                  'Yönetici bu bilgilerle giriş yapıp kendi öğrencinini ve '
                  'QR noktalarını ekleyebilir.',
            ),
            AppSpacing.vXl,
          ],
        ),
      ),
    );
  }
}

/// Durum seçiminde kullanılan etiketler — detay ekranıyla ortak.
String tenantStatusLabel(TenantStatus status) => status.label;
