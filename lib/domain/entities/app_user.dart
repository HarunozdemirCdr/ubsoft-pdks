import 'package:equatable/equatable.dart';
import 'package:ubsoft_pdks/core/config/firebase_collections.dart';
import 'package:ubsoft_pdks/domain/enums/user_role.dart';
import 'package:ubsoft_pdks/domain/enums/user_status.dart';

/// Uygulama kullanıcısı.
///
/// Firebase Authentication kaydının Firestore'daki karşılığıdır. Kimlik
/// doğrulama Auth'ta, **yetkilendirme** burada yaşar.
class AppUser extends Equatable {
  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    required this.status,
    required this.createdAt,
    required this.tenantId,
    this.phone,
    this.note,
    this.permissionOverrides = const <String, bool>{},
    this.updatedAt,
    this.lastLoginAt,
    this.deletedAt,
    this.createdBy,
  });

  /// Firebase Auth kullanıcı kimliği. Doküman kimliğiyle aynıdır.
  final String uid;

  final String email;
  final String displayName;
  final String? phone;

  /// Personel hakkında serbest not — "Gece vardiyası", "Yarı zamanlı".
  ///
  /// Bilinçli olarak biçimsizdir: unvan ya da sicil numarası gibi ayrı
  /// alanlar, hiçbir şirketin kendi kayıtlarıyla birebir uyuşmuyordu ve
  /// çoğunlukla boş kalıyordu. Raporun personel başlığında bu not yazar.
  final String? note;

  /// Kullanıcının bulunduğu müşteri (doküman yolundaki `tenantId`).
  ///
  /// Süper adminler gerçek bir müşteriye ait değildir; onlar sistem
  /// müşterisinde (`_system`) yaşar.
  final String tenantId;

  final UserRole role;

  /// Rol varsayılanının üzerine yazılan kullanıcıya özel izinler.
  ///
  /// Anahtar bulunmuyorsa rol varsayılanı geçerlidir. Bu yüzden burada
  /// tüm izinlerin bulunması gerekmez — yalnız bilinçli değiştirilenler.
  final Map<String, bool> permissionOverrides;

  final UserStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? lastLoginAt;
  final DateTime? deletedAt;
  final String? createdBy;

  /// Giriş yapıp veri görebilir mi?
  bool get canSignIn => status.isActive;

  /// Gerçek bir müşteriye mi bağlı? (Sistem müşterisi sayılmaz.)
  bool get hasRealTenant =>
      tenantId.isNotEmpty && tenantId != FsPaths.systemTenantId;

  /// Ad-soyadın baş harfleri — avatar yerine kullanılır.
  String get initials {
    final List<String> parts = displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return email.isNotEmpty ? email[0].toUpperCase() : '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  /// Listelerde ad altında gösterilen ikinci satır.
  String get subtitle => (note ?? '').isEmpty ? email : note!;

  AppUser copyWith({
    String? email,
    String? displayName,
    String? phone,
    String? note,
    String? tenantId,
    UserRole? role,
    Map<String, bool>? permissionOverrides,
    UserStatus? status,
    DateTime? updatedAt,
    DateTime? lastLoginAt,
    DateTime? deletedAt,
  }) => AppUser(
    uid: uid,
    email: email ?? this.email,
    displayName: displayName ?? this.displayName,
    phone: phone ?? this.phone,
    note: note ?? this.note,
    tenantId: tenantId ?? this.tenantId,
    role: role ?? this.role,
    permissionOverrides: permissionOverrides ?? this.permissionOverrides,
    status: status ?? this.status,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    deletedAt: deletedAt ?? this.deletedAt,
    createdBy: createdBy,
  );

  @override
  List<Object?> get props => <Object?>[
    uid,
    email,
    displayName,
    phone,
    note,
    tenantId,
    role,
    permissionOverrides,
    status,
    createdAt,
    updatedAt,
    lastLoginAt,
    deletedAt,
  ];
}
