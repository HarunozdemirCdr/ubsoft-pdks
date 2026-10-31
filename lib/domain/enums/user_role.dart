/// Kullanıcı rolleri.
///
/// Rol, izinlerin **varsayılan** kümesini belirler; kesin yetki her zaman
/// `PermissionSet` üzerinden çözülür (rol varsayılanı + kullanıcıya özel
/// override). Bu yüzden koda `if (role == admin)` yazılmaz — `can(izin)`
/// sorulur.
enum UserRole {
  /// Sistem sahibi. Yurt (tenant) açar, kapatır, abonelik yönetir.
  /// Bir tenant'a ait değildir; tüm veriye erişir.
  superAdmin('superAdmin'),

  /// Yurt yöneticisi. Müdire/belletmen ayrımı açıklama alanında tutulur.
  admin('admin'),

  /// Öğrenci. Yalnız QR ile giriş-çıkış kaydı oluşturur.
  staff('staff');

  const UserRole(this.key);

  /// Firestore'da saklanan değer.
  final String key;

  static UserRole fromKey(String? key) => switch (key) {
    'superAdmin' => UserRole.superAdmin,
    'admin' => UserRole.admin,
    _ => UserRole.staff,
  };

  bool get isSuperAdmin => this == UserRole.superAdmin;
  bool get isAdmin => this == UserRole.admin;
  bool get isStaff => this == UserRole.staff;

  /// Bir tenant'a bağlı mı? Süper admin bağlı değildir.
  bool get belongsToTenant => this != UserRole.superAdmin;

  /// Arayüzde görünen ad.
  String get label => switch (this) {
    UserRole.superAdmin => 'UBS Süper Admin',
    UserRole.admin => 'Yönetici',
    UserRole.staff => 'Öğrenci',
  };

  /// Bir yöneticinin başkasına atayabileceği roller.
  ///
  /// Süper admin rolü arayüzden atanamaz — güvenlik kurallarında da yasaktır.
  static const List<UserRole> assignable = <UserRole>[
    UserRole.admin,
    UserRole.staff,
  ];
}
