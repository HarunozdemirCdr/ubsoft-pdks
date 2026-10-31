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
    this.studentNumber = '',
    this.room = '',
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
  final String studentNumber;
  final String room;

  /// Öğrenci hakkında serbest not — "Oda / öğrenim notu", "Yarı zamanlı".
  ///
  /// Bilinçli olarak biçimsizdir: unvan ya da sicil numarası gibi ayrı
  /// alanlar, hiçbir yurdun kendi kayıtlarıyla birebir uyuşmuyordu ve
  /// çoğunlukla boş kalıyordu. Raporun öğrenci başlığında bu not yazar.
  final String? note;

  /// Kullanıcının bulunduğu yurt (doküman yolundaki `tenantId`).
  ///
  /// Süper adminler gerçek bir yurda ait değildir; onlar sistem
  /// yurdunda (`_system`) yaşar.
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

  /// Gerçek bir yurda mi bağlı? (Sistem yurtsi sayılmaz.)
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
  String get subtitle => <String>[
    if (studentNumber.isNotEmpty) 'No: $studentNumber',
    if (room.isNotEmpty) 'Oda: $room',
    if ((note ?? '').isNotEmpty) note!,
    if (studentNumber.isEmpty && room.isEmpty && (note ?? '').isEmpty) email,
  ].join(' · ');

  AppUser copyWith({
    String? email,
    String? displayName,
    String? phone,
    String? studentNumber,
    String? room,
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
    studentNumber: studentNumber ?? this.studentNumber,
    room: room ?? this.room,
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
    studentNumber,
    room,
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
