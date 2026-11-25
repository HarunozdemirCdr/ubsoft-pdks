import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ubsoft_pdks/application/auth/session_provider.dart';
import 'package:ubsoft_pdks/application/user/user_providers.dart';
import 'package:ubsoft_pdks/core/extensions/context_x.dart';
import 'package:ubsoft_pdks/core/result/result.dart';
import 'package:ubsoft_pdks/core/routing/app_routes.dart';
import 'package:ubsoft_pdks/core/theme/app_colors.dart';
import 'package:ubsoft_pdks/core/theme/app_radius.dart';
import 'package:ubsoft_pdks/core/theme/app_spacing.dart';
import 'package:ubsoft_pdks/core/theme/app_typography.dart';
import 'package:ubsoft_pdks/core/utils/validators.dart';
import 'package:ubsoft_pdks/domain/entities/app_user.dart';
import 'package:ubsoft_pdks/domain/enums/user_role.dart';
import 'package:ubsoft_pdks/domain/permissions/app_permission.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_button.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_card.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_scaffold.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_text_field.dart';
import 'package:ubsoft_pdks/presentation/widgets/confirm_dialog.dart';
import 'package:ubsoft_pdks/presentation/widgets/info_hint.dart';
import 'package:ubsoft_pdks/presentation/widgets/section_header.dart';
import 'package:ubsoft_pdks/presentation/widgets/status_chip.dart';
import 'package:ubsoft_pdks/services/notification/toast_service.dart';

/// Öğrenci oluşturma ve düzenleme.
///
/// E-posta ve şifre yalnız **oluştururken** sorulur. Sonradan değiştirilemez:
/// e-posta hesabın kimliğidir, şifreyi ise yalnız sahibi bilmelidir —
/// yöneticinin yapabileceği tek şey sıfırlama bağlantısı göndermektir.
class UserFormPage extends ConsumerStatefulWidget {
  const UserFormPage({this.userId, super.key});

  /// `null` ise yeni öğrenci.
  final String? userId;

  @override
  ConsumerState<UserFormPage> createState() => _UserFormPageState();
}

class _UserFormPageState extends ConsumerState<UserFormPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _note = TextEditingController();
  final TextEditingController _number = TextEditingController();
  final TextEditingController _room = TextEditingController();

  UserRole _role = UserRole.staff;
  bool _seeded = false;

  bool get _isNew => widget.userId == null;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _phone.dispose();
    _note.dispose();
    _number.dispose();
    _room.dispose();
    super.dispose();
  }

  void _seed(AppUser user) {
    if (_seeded) return;
    _seeded = true;

    _name.text = user.displayName;
    _email.text = user.email;
    _phone.text = user.phone ?? '';
    _note.text = user.note ?? '';
    _number.text = user.studentNumber;
    _room.text = user.room;
    _role = user.role;
  }

  Future<void> _submit(AppUser? existing) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    final UserController controller = ref.read(userControllerProvider.notifier);

    if (existing == null) {
      final Result<AppUser> created = await controller.createUser(
        email: _email.text,
        password: _password.text,
        displayName: _name.text,
        role: _role,
        phone: _phone.text,
        studentNumber: _number.text,
        room: _room.text,
        note: _note.text,
      );

      if (!mounted) return;
      Toast.result(created, successMessage: 'Öğrenci eklendi.');
      if (created.isOk) context.go(AppRoutes.users);
      return;
    }

    final Result<void> saved = await controller.updateProfile(
      user: existing,
      displayName: _name.text,
      phone: _phone.text,
      studentNumber: _number.text,
      room: _room.text,
      note: _note.text,
    );

    // Rol ayrı bir çağrıdır; güvenlik kuralları rol değişimini kendi
    // yetkisiyle (user.assignRole) denetler.
    if (saved.isOk && _role != existing.role) {
      final Result<void> roleResult = await controller.changeRole(
        existing,
        _role,
      );
      if (!mounted) return;
      Toast.result(roleResult, successMessage: 'Öğrenci güncellendi.');
      if (roleResult.isOk) context.go(AppRoutes.users);
      return;
    }

    if (!mounted) return;
    Toast.result(saved, successMessage: 'Öğrenci güncellendi.');
    if (saved.isOk) context.go(AppRoutes.users);
  }

  @override
  Widget build(BuildContext context) {
    final AppUser? existing = _isNew
        ? null
        : ref.watch(userProvider(widget.userId!));
    if (existing != null) _seed(existing);

    final bool busy = ref.watch(userControllerProvider).isLoading;
    final AppUser? me = ref.watch(currentUserProvider);
    final bool isSelf = existing != null && me?.uid == existing.uid;
    final bool canAssignRole = ref.watch(
      canProvider(AppPermission.userAssignRole),
    );

    return AppScaffold(
      title: _isNew ? 'Yeni Öğrenci' : 'Öğrenciyi Düzenle',
      showBackButton: true,
      scrollable: true,
      bottomBar: AppButton.primaryWide(
        label: _isNew ? 'Öğrenciyi ekle' : 'Değişiklikleri kaydet',
        isLoading: busy,
        onPressed: () => _submit(existing),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 50,
                    height: 50,
                    decoration: const BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: AppRadius.allMd,
                    ),
                    child: const Icon(
                      Icons.person_outline_rounded,
                      size: 26,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          _isNew
                              ? 'Yeni Öğrenci Kaydı'
                              : (existing?.displayName ?? 'Öğrenci Profili'),
                          style: AppTypography.h3(context.colors.onSurface),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _isNew
                              ? 'Kimlik ve yurt yerleşim bilgilerini eksiksiz tanımlayın.'
                              : [
                                  if ((existing?.room ?? '').isNotEmpty)
                                    'Oda ${existing!.room}',
                                  if ((existing?.studentNumber ?? '').isNotEmpty)
                                    'No ${existing!.studentNumber}',
                                  existing?.email ?? '',
                                ].where((s) => s.isNotEmpty).join(' · '),
                          style: AppTypography.caption(
                            context.colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (existing != null)
                    StatusChip(
                      label: existing.status.isActive ? 'Etkin' : 'Pasif',
                      tone: existing.status.isActive
                          ? StatusTone.success
                          : StatusTone.neutral,
                      compact: true,
                    ),
                ],
              ),
            ),
            AppSpacing.vMd,
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const SectionHeader(title: 'Kimlik bilgileri', dense: true),
                  AppSpacing.vMd,
                  AppTextField(
                    label: 'Ad Soyad',
                    controller: _name,
                    prefixIcon: Icons.person_outline_rounded,
                    isRequired: true,
                    validator: (String? v) =>
                        Validators.required(v, field: 'Ad Soyad'),
                  ),
                  AppSpacing.vMd,
                  AppTextField(
                    label: 'E-posta',
                    controller: _email,
                    prefixIcon: Icons.mail_outline_rounded,
                    isRequired: true,
                    enabled: _isNew,
                    keyboardType: TextInputType.emailAddress,
                    helper: _isNew
                        ? 'Öğrenci bu adresle giriş yapacak.'
                        : 'E-posta adresi hesabın kimliğidir, değiştirilemez.',
                    validator: _isNew ? Validators.email : null,
                  ),
                  if (_isNew) ...<Widget>[
                    AppSpacing.vMd,
                    AppPasswordField(
                      label: 'Geçici şifre',
                      controller: _password,
                      validator: Validators.password,
                    ),
                    AppSpacing.vXs,
                    const InfoNote(
                      message:
                          'Bu şifreyi öğrenciye iletin. Kendi şifresini profil '
                          'ekranından değiştirebilir.',
                    ),
                  ],
                ],
              ),
            ),
            AppSpacing.vMd,
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const SectionHeader(title: 'Yurt bilgileri', dense: true),
                  AppSpacing.vMd,
                  LayoutBuilder(
                    builder: (context, bounds) {
                      final numberField = AppTextField(
                        label: 'Öğrenci numarası',
                        controller: _number,
                        prefixIcon: Icons.badge_outlined,
                      );
                      final roomField = AppTextField(
                        label: 'Oda numarası',
                        controller: _room,
                        prefixIcon: Icons.meeting_room_outlined,
                      );
                      if (bounds.maxWidth >= 520) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: numberField),
                            const SizedBox(width: 12),
                            Expanded(child: roomField),
                          ],
                        );
                      }
                      return Column(
                        children: [
                          numberField,
                          AppSpacing.vMd,
                          roomField,
                        ],
                      );
                    },
                  ),
                  AppSpacing.vMd,
                  AppTextField(
                    label: 'Telefon',
                    controller: _phone,
                    prefixIcon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    validator: Validators.phone,
                  ),
                  AppSpacing.vMd,
                  AppTextField(
                    label: 'Açıklama',
                    controller: _note,
                    prefixIcon: Icons.notes_rounded,
                    hint: 'Oda / öğrenim notu',
                    helper: 'Listelerde ve raporun öğrenci başlığında görünür.',
                    validator: (String? v) =>
                        Validators.maxLength(v, 60, field: 'Açıklama'),
                  ),
                ],
              ),
            ),
            AppSpacing.vMd,
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const SectionHeader(title: 'Sistem rolü', dense: true),
                  AppSpacing.vSm,
                  _RoleSelector(
                    value: _role,
                    enabled: canAssignRole && !isSelf,
                    onChanged: (UserRole value) =>
                        setState(() => _role = value),
                  ),
                  if (isSelf) ...<Widget>[
                    AppSpacing.vXs,
                    const InfoNote(
                      message:
                          'Kendi rolünüzü değiştiremezsiniz. Aksi hâlde son '
                          'yönetici kendini öğrenciye düşürüp yurdu yönetimsiz '
                          'bırakabilirdi.',
                    ),
                  ],
                ],
              ),
            ),

            if (existing != null) ...<Widget>[
              AppSpacing.vLg,
              _ExistingUserActions(user: existing, isSelf: isSelf),
            ],
            AppSpacing.vXl,
          ],
        ),
      ),
    );
  }
}

/// Rol seçimi — yalnız yönetici ve öğrenci atanabilir.
class _RoleSelector extends StatelessWidget {
  const _RoleSelector({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final UserRole value;
  final bool enabled;
  final ValueChanged<UserRole> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SegmentedButton<UserRole>(
          segments: <ButtonSegment<UserRole>>[
            for (final UserRole role in UserRole.assignable)
              ButtonSegment<UserRole>(
                value: role,
                label: Text(role.label),
                icon: Icon(
                  role.isAdmin
                      ? Icons.verified_user_outlined
                      : Icons.badge_outlined,
                ),
              ),
          ],
          selected: <UserRole>{value},
          onSelectionChanged: enabled
              ? (Set<UserRole> selection) => onChanged(selection.first)
              : null,
        ),
        AppSpacing.vXs,
        Text(
          value.isAdmin
              ? 'Yönetici yurttaki tüm yetkilere sahiptir; ayrıca izin '
                    'ayarlanmaz.'
              : 'Öğrenci QR okutur ve kendi kayıtlarını görür; başkasının '
                    'kaydını göremez.',
          style: AppTypography.small(context.colors.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Var olan kullanıcıya özel işlemler: yetkiler, şifre sıfırlama, pasife
/// alma, silme.
class _ExistingUserActions extends ConsumerWidget {
  const _ExistingUserActions({required this.user, required this.isSelf});

  final AppUser user;
  final bool isSelf;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UserController controller = ref.read(userControllerProvider.notifier);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (ref.watch(canProvider(AppPermission.userResetPassword)))
            ListTile(
              leading: const Icon(Icons.lock_reset_rounded),
              title: const Text('Şifre sıfırlama gönder'),
              subtitle: Text('${user.email} adresine bağlantı gider'),
              contentPadding: EdgeInsets.zero,
              onTap: () async {
                final Result<void> result = await controller.sendPasswordReset(
                  user,
                );
                Toast.result(
                  result,
                  successMessage: 'Sıfırlama bağlantısı gönderildi.',
                );
              },
            ),

          if (!isSelf && ref.watch(canProvider(AppPermission.userEdit)))
            SwitchListTile.adaptive(
              value: user.status.isActive,
              contentPadding: EdgeInsets.zero,
              title: const Text('Hesap etkin'),
              subtitle: const Text(
                'Kapatıldığında giriş yapamaz; kayıtları korunur.',
              ),
              onChanged: (bool value) async {
                final Result<void> result = await controller.setActive(
                  user,
                  active: value,
                );
                Toast.result(
                  result,
                  successMessage: value
                      ? 'Hesap etkinleştirildi.'
                      : 'Hesap devre dışı bırakıldı.',
                );
              },
            ),

          if (!isSelf && ref.watch(canProvider(AppPermission.userDelete)))
            ListTile(
              leading: Icon(
                Icons.person_remove_outlined,
                color: context.colors.error,
              ),
              title: Text(
                'Öğrenciyi sil',
                style: AppTypography.bodyStrong(context.colors.error),
              ),
              subtitle: const Text(
                'Listeden kaldırılır; geçmiş devam kayıtları durur.',
              ),
              contentPadding: EdgeInsets.zero,
              onTap: () => _confirmDelete(context, controller),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    UserController controller,
  ) async {
    final bool ok = await ConfirmDialog.show(
      context,
      title: 'Öğrenci silinsin mi?',
      message:
          '${user.displayName} listeden kaldırılacak ve giriş yapamayacak. '
          'Geçmiş devam kayıtları raporlarda görünmeye devam eder.',
      confirmLabel: 'Sil',
      isDestructive: true,
    );
    if (!ok || !context.mounted) return;

    final Result<void> result = await controller.deleteUser(user);
    if (!context.mounted) return;

    Toast.result(result, successMessage: 'Öğrenci silindi.');
    if (result.isOk) context.go(AppRoutes.users);
  }
}
