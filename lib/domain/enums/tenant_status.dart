/// Müşteri hesabının durumu.
enum TenantStatus {
  active('active', 'Aktif'),

  /// Ödeme gecikmesi ya da bilinçli karar. Hesap salt okunur olur.
  suspended('suspended', 'Askıda'),

  /// Kapatılmış hesap. Yalnız süper admin görür.
  closed('closed', 'Kapalı');

  const TenantStatus(this.key, this.label);

  final String key;
  final String label;

  static TenantStatus fromKey(String? key) => switch (key) {
    'suspended' => TenantStatus.suspended,
    'closed' => TenantStatus.closed,
    _ => TenantStatus.active,
  };

  bool get isActive => this == TenantStatus.active;

  /// Yeni kayıt kabul eder mi?
  bool get isWritable => this == TenantStatus.active;
}

/// Abonelik planı.
enum SubscriptionPlan {
  trial('trial', 'Deneme', maxUsers: 10, maxCheckpoints: 4),
  basic('basic', 'Temel', maxUsers: 25, maxCheckpoints: 10),
  standard('standard', 'Standart', maxUsers: 100, maxCheckpoints: 30),
  premium('premium', 'Kurumsal', maxUsers: 1000, maxCheckpoints: 200);

  const SubscriptionPlan(
    this.key,
    this.label, {
    required this.maxUsers,
    required this.maxCheckpoints,
  });

  final String key;
  final String label;
  final int maxUsers;
  final int maxCheckpoints;

  static SubscriptionPlan fromKey(String? key) => switch (key) {
    'basic' => SubscriptionPlan.basic,
    'standard' => SubscriptionPlan.standard,
    'premium' => SubscriptionPlan.premium,
    _ => SubscriptionPlan.trial,
  };
}
