import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ubsoft_pdks/application/user/user_providers.dart';
import 'package:ubsoft_pdks/core/extensions/context_x.dart';
import 'package:ubsoft_pdks/core/result/result.dart';
import 'package:ubsoft_pdks/core/theme/app_spacing.dart';
import 'package:ubsoft_pdks/core/theme/app_typography.dart';
import 'package:ubsoft_pdks/domain/entities/app_user.dart';
import 'package:ubsoft_pdks/domain/permissions/app_permission.dart';
import 'package:ubsoft_pdks/domain/permissions/permission_set.dart';
import 'package:ubsoft_pdks/domain/permissions/role_defaults.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_button.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_card.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_scaffold.dart';
import 'package:ubsoft_pdks/presentation/widgets/async_value_view.dart';
import 'package:ubsoft_pdks/presentation/widgets/section_header.dart';
import 'package:ubsoft_pdks/services/notification/toast_service.dart';

/// Bir iznin kullanıcı için nasıl ayarlandığı.
enum _OverrideState {
  /// Rol varsayılanı geçerli.
  inherited,

  /// Kullanıcıya özel açık.
  granted,

  /// Kullanıcıya özel kapalı.
  denied,
}

/// Kullanıcı bazlı yetki düzenleme.
///
/// Her izin üç durumludur: **Varsayılan** (rolden gelir), **Açık**, **Kapalı**.
/// Varsayılan bırakılan izinler kullanıcı dokümanına yazılmaz; rol değişirse
/// kendiliğinden yeni role uyum sağlarlar.
class PermissionEditorPage extends ConsumerWidget {
  const PermissionEditorPage({required this.userId, super.key});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AppUser?> user = ref
        .watch(usersProvider)
        .whenData((List<AppUser> users) => ref.watch(userProvider(userId)));

    return AsyncValueView<AppUser?>(
      value: user,
      builder: (AppUser? value) {
        if (value == null) {
          return const AppScaffold(
            title: 'Yetkiler',
            showBackButton: true,
            body: Center(child: Text('Kullanıcı bulunamadı.')),
          );
        }
        // İzinler yalnız personel içindir; yönetici zaten tüm yetkilere
        // sahiptir, dolayısıyla düzenlenecek bir şey yoktur.
        if (!value.role.isStaff) {
          return AppScaffold(
            title: 'Yetkiler',
            showBackButton: true,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.verified_user_outlined,
                      size: 40,
                      color: context.colors.primary,
                    ),
                    AppSpacing.vMd,
                    Text(
                      '${value.displayName} bir yöneticidir ve şirketteki tüm '
                      'yetkilere sahiptir. İzinler yalnız personel hesapları '
                      'için ayarlanır.',
                      textAlign: TextAlign.center,
                      style: AppTypography.body(
                        context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return _PermissionEditor(user: value);
      },
    );
  }
}

class _PermissionEditor extends ConsumerStatefulWidget {
  const _PermissionEditor({required this.user});

  final AppUser user;

  @override
  ConsumerState<_PermissionEditor> createState() => _PermissionEditorState();
}

class _PermissionEditorState extends ConsumerState<_PermissionEditor> {
  late final Map<String, bool> _overrides = Map<String, bool>.of(
    widget.user.permissionOverrides,
  );

  /// Anahtar değiştiğinde: değer rol varsayılanına eşitse override silinir
  /// (izin rolden gelmeye devam etsin), değilse açık/kapalı olarak yazılır.
  void _toggle(
    AppPermission permission, {
    required bool on,
    required bool defaultValue,
  }) {
    _set(
      permission,
      on == defaultValue
          ? _OverrideState.inherited
          : (on ? _OverrideState.granted : _OverrideState.denied),
    );
  }

  void _set(AppPermission permission, _OverrideState next) {
    setState(() {
      switch (next) {
        case _OverrideState.inherited:
          _overrides.remove(permission.key);
        case _OverrideState.granted:
          _overrides[permission.key] = true;
        case _OverrideState.denied:
          _overrides[permission.key] = false;
      }
    });
  }

  Future<void> _save() async {
    final Result<void> result = await ref
        .read(userControllerProvider.notifier)
        .savePermissions(widget.user, _overrides);

    if (!mounted) return;

    switch (result) {
      case Ok<void>():
        Toast.success('Yetkiler kaydedildi');
        context.pop();
      case Err<void>(:final failure):
        Toast.error(failure.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<void> state = ref.watch(userControllerProvider);

    // Rol varsayılanları DÜZENLENEN kullanıcının kendi rolünden okunur —
    // yöneticinin (hepsi açık) varsayılanlarından değil. Aksi hâlde bir personeli
    // düzenlerken tüm izinler açık görünür ve toggle'lar gerçeği yansıtmazdı.
    final Map<String, Map<String, bool>> allDefaults =
        ref.watch(roleDefaultsProvider).value ??
        const <String, Map<String, bool>>{};
    final PermissionSet reference = PermissionSet(
      role: widget.user.role,
      overrides: _overrides,
      roleDefaults:
          allDefaults[widget.user.role.key] ??
          RoleDefaults.toMap(widget.user.role),
    );

    final Map<PermissionGroup, List<AppPermission>> grouped =
        AppPermission.grouped();

    return AppScaffold(
      title: 'Yetkiler',
      showBackButton: true,
      scrollable: true,
      bottomBar: AppButton.primaryWide(
        label: 'Kaydet',
        onPressed: _save,
        isLoading: state.isLoading,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AppSpacing.vMd,
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  widget.user.displayName,
                  style: AppTypography.bodyStrong(context.colors.onSurface),
                ),
                AppSpacing.vXxs,
                Text(
                  'Rol: ${widget.user.role.label}',
                  style: AppTypography.small(context.colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (_overrides.isNotEmpty) ...<Widget>[
            AppSpacing.vXs,
            Align(
              alignment: Alignment.centerLeft,
              child: AppButton(
                label: 'Tümünü sıfırla',
                onPressed: () => setState(_overrides.clear),
                variant: AppButtonVariant.text,
                size: AppButtonSize.small,
                icon: Icons.restart_alt_rounded,
              ),
            ),
          ],

          for (final MapEntry<PermissionGroup, List<AppPermission>> entry
              in grouped.entries) ...<Widget>[
            AppSpacing.vLg,
            SectionHeader(title: entry.key.label, dense: true),
            AppSpacing.vXs,
            AppCard(
              child: Column(
                children: <Widget>[
                  for (int i = 0; i < entry.value.length; i++) ...<Widget>[
                    if (i > 0) const Divider(height: AppSpacing.lg),
                    Builder(
                      builder: (context) {
                        final AppPermission permission = entry.value[i];
                        final bool defaultValue = reference.defaultValue(
                          permission,
                        );
                        final bool value =
                            _overrides[permission.key] ?? defaultValue;
                        return _PermissionRow(
                          permission: permission,
                          value: value,
                          onChanged: (on) => _toggle(
                            permission,
                            on: on,
                            defaultValue: defaultValue,
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
          AppSpacing.vXxl,
        ],
      ),
    );
  }
}

/// Tek izin satırı — açık/kapalı anahtarı.
///
/// İzin adı ve açıklaması solda, sağda basit bir anahtar durur. Anahtar
/// açıksa personelin o izni vardır; kapalıysa yoktur. Varsayılan durum
/// başlangıçta anahtara zaten yansıdığı için ayrıca "varsayılan" etiketi
/// göstermeye gerek kalmaz.
class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.permission,
    required this.value,
    required this.onChanged,
  });

  final AppPermission permission;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                permission.label,
                style: AppTypography.bodyStrong(context.colors.onSurface),
              ),
              if (permission.description
                  case final String description) ...<Widget>[
                AppSpacing.vXxs,
                Text(
                  description,
                  style: AppTypography.small(context.colors.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
        AppSpacing.hSm,
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}
