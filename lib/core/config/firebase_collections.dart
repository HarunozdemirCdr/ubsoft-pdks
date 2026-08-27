/// Firestore koleksiyon ve alan adları.
///
/// Kural: kod içinde `'attendance'` gibi düz metin koleksiyon adı yazılmaz.
/// Şema değişimi tek dosyadan yönetilir ve yazım hatası derleme zamanında
/// yakalanır.
abstract final class FsPaths {
  /// Tek kök koleksiyon. Diğer her şey bir müşterinin altında yaşar:
  /// `tenants/{tenantId}/…`
  static const String tenants = 'tenants';

  // ─────────────────────────── Tenant alt koleksiyonları ───────────────────
  static const String users = 'users';
  static const String roleDefaults = 'roleDefaults';

  /// QR noktaları: `tenants/{tid}/checkpoints/{id}`.
  static const String checkpoints = 'checkpoints';

  /// Kod tekilliği defteri: `tenants/{tid}/qrIndex/{code}`.
  ///
  /// Aynı numaranın iki noktaya verilmesini engeller. Ayrı bir koleksiyon
  /// olması şart: Firestore'da "şu alan benzersiz olsun" diye bir kısıt
  /// yoktur, tekillik ancak doküman kimliğiyle kurulur.
  static const String qrIndex = 'qrIndex';

  /// Tekil giriş/çıkış okutmaları: `tenants/{tid}/attendance/{eventId}`.
  static const String attendance = 'attendance';

  /// Kişi-gün özetleri: `tenants/{tid}/attendanceDays/{uid}_{dateKey}`.
  ///
  /// Okutmalardan türetilir ve her okutmayla aynı işlemde güncellenir.
  /// Ayrı tutulmasının sebebi maliyet: "bu ay kim kaç saat çalıştı"
  /// sorusunu binlerce okutmayı tarayarak değil, 30 özet dokümanı okuyarak
  /// cevaplar.
  static const String attendanceDays = 'attendanceDays';

  /// Süper adminlerin barındığı sistem müşterisi.
  ///
  /// Süper admin gerçek bir müşteriye ait değildir, ancak tüm veri tek bir
  /// kök altında toplandığı için ona da bir yer gerekir. Bu müşteri arayüzde
  /// listelenmez ve silinemez.
  static const String systemTenantId = '_system';
}

/// Sık kullanılan alan adları — sorgu ve `update` çağrılarında.
abstract final class FsFields {
  static const String tenantId = 'tenantId';
  static const String status = 'status';
  static const String role = 'role';
  static const String active = 'active';
  static const String order = 'order';
  static const String name = 'name';
  static const String displayName = 'displayName';
  static const String email = 'email';
  static const String code = 'code';
  static const String checkpointId = 'checkpointId';
  static const String userId = 'userId';
  static const String dateKey = 'dateKey';
  static const String type = 'type';
  static const String at = 'at';
  static const String verdict = 'verdict';
  static const String createdAt = 'createdAt';
  static const String updatedAt = 'updatedAt';
  static const String lastLoginAt = 'lastLoginAt';
  static const String permissions = 'permissions';
  static const String open = 'open';
  static const String firstEntryAt = 'firstEntryAt';
  static const String lastExitAt = 'lastExitAt';
}
