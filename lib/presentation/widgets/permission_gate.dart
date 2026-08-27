import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubsoft_pdks/application/auth/session_provider.dart';
import 'package:ubsoft_pdks/domain/permissions/app_permission.dart';
import 'package:ubsoft_pdks/domain/permissions/permission_set.dart';

/// İzin yoksa içeriği hiç çizmez.
///
/// Arayüzde yetkisiz bir butonu göstermek yerine gizlemek tercih edilir:
/// kullanıcı yapamayacağı bir işlemi denemek zorunda kalmaz. Bu yalnız
/// görsel bir önlemdir; gerçek kapı Firestore güvenlik kurallarıdır.
class PermissionGate extends ConsumerWidget {
  /// Tek bir izin gerektirir.
  PermissionGate({
    required AppPermission permission,
    required this.child,
    this.fallback,
    super.key,
  }) : required = <AppPermission>[permission];

  /// Verilen izinlerden **en az biri** varsa içeriği gösterir.
  const PermissionGate.any({
    required List<AppPermission> permissions,
    required this.child,
    this.fallback,
    super.key,
  }) : required = permissions;

  /// Gerekli izinler — en az biri yeterlidir.
  final List<AppPermission> required;

  final Widget child;

  /// İzin yokken gösterilecek içerik. Verilmezse hiçbir şey çizilmez.
  final Widget? fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PermissionSet permissions = ref.watch(permissionsProvider);
    if (permissions.canAny(required)) return child;
    return fallback ?? const SizedBox.shrink();
  }
}
