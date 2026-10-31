/// Kullanıcı hesabının durumu.
enum UserStatus {
  /// Giriş yapabilir, veri görebilir.
  active('active', 'Aktif'),

  /// Yönetici tarafından geçici olarak durduruldu. Kayıtları korunur.
  inactive('inactive', 'Pasif'),

  /// Silinmiş sayılır. Listelerde görünmez; geçmiş devam kayıtları durur.
  ///
  /// Kayıt fiziksel olarak silinmez: silinseydi geçmiş raporlarda kimin
  /// giriş yaptığı bilinmez, "silinmiş öğrenci" satırları kalırdı.
  deleted('deleted', 'Silinmiş');

  const UserStatus(this.key, this.label);

  final String key;
  final String label;

  static UserStatus fromKey(String? key) => switch (key) {
    'inactive' => UserStatus.inactive,
    'deleted' => UserStatus.deleted,
    _ => UserStatus.active,
  };

  bool get isActive => this == UserStatus.active;
  bool get isDeleted => this == UserStatus.deleted;

  /// Listelerde görünür mü?
  bool get isVisible => this != UserStatus.deleted;
}
