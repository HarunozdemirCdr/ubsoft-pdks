/// İzin grupları — yetki düzenleme ekranında başlık olarak kullanılır.
enum PermissionGroup {
  general('Genel'),
  punch('Okutma'),
  attendance('Devam Kayıtları'),
  checkpoint('QR Noktaları'),
  user('Kullanıcılar'),
  report('Raporlar'),
  settings('Ayarlar');

  const PermissionGroup(this.label);

  /// Arayüzde görünen Türkçe başlık.
  final String label;
}

/// Uygulamadaki tüm izinler.
///
/// İzinler role gömülü değildir: rol yalnız bir **varsayılan küme** sunar,
/// yönetici her izni personel bazında açıp kapatabilir. Bu yüzden kodda
/// `if (user.role.isAdmin)` yazılmaz; `permissions.can(AppPermission.x)`
/// sorulur.
///
/// [key] hem Firestore'da hem güvenlik kurallarında kullanılan değerdir —
/// iki taraf birebir aynı anahtarları kullanır.
enum AppPermission {
  // ─────────────────────────── Genel ───────────────────────────
  dashboardView(
    'dashboard.view',
    'Günlük paneli görüntüle',
    PermissionGroup.general,
    description: 'Bugün kimin içeride olduğunu gösteren panele erişim.',
  ),

  // ─────────────────────────── Okutma ───────────────────────────
  punchCreate(
    'punch.create',
    'QR okut',
    PermissionGroup.punch,
    isWrite: true,
    description: 'Giriş ve çıkış QR kodlarını okutarak devam kaydı bırakır.',
  ),

  // ─────────────────────────── Devam kayıtları ───────────────────────────
  attendanceViewOwn(
    'attendance.viewOwn',
    'Kendi kayıtlarını görüntüle',
    PermissionGroup.attendance,
    description: 'Eski kayıtlarla uyumluluk için saklanır; öğrenciye verilmez.',
  ),
  attendanceViewAll(
    'attendance.viewAll',
    'Tüm öğrencilerin kayıtlarını görüntüle',
    PermissionGroup.attendance,
    description: 'Yurttaki bütün öğrencilerin giriş-çıkış kayıtlarına erişir.',
  ),
  attendanceDelete(
    'attendance.delete',
    'Okutma kaydını sil',
    PermissionGroup.attendance,
    isWrite: true,
    description:
        'Yanlışlıkla yapılmış bir okutmayı siler ve gün özetini yeniden '
        'hesaplatır. Yönetici yetkisidir.',
  ),

  // ─────────────────────────── QR noktaları ───────────────────────────
  checkpointView(
    'checkpoint.view',
    'Noktaları görüntüle',
    PermissionGroup.checkpoint,
  ),
  checkpointCreate(
    'checkpoint.create',
    'Nokta oluştur',
    PermissionGroup.checkpoint,
    isWrite: true,
    description: 'Yeni QR noktası ekler ve konumunu tanımlar.',
  ),
  checkpointEdit(
    'checkpoint.edit',
    'Nokta düzenle',
    PermissionGroup.checkpoint,
    isWrite: true,
    description: 'Nokta adını, kodunu, konumunu ve yarıçapını değiştirir.',
  ),
  checkpointDelete(
    'checkpoint.delete',
    'Nokta sil',
    PermissionGroup.checkpoint,
    isWrite: true,
  ),

  // ─────────────────────────── Kullanıcı ───────────────────────────
  userView('user.view', 'Kullanıcıları görüntüle', PermissionGroup.user),
  userCreate(
    'user.create',
    'Kullanıcı oluştur',
    PermissionGroup.user,
    isWrite: true,
  ),
  userEdit(
    'user.edit',
    'Kullanıcı düzenle',
    PermissionGroup.user,
    isWrite: true,
  ),
  userDelete(
    'user.delete',
    'Kullanıcı sil',
    PermissionGroup.user,
    isWrite: true,
    description:
        'Kullanıcı listeden kaldırılır ve giriş yapamaz. Geçmiş devam '
        'kayıtları korunur.',
  ),
  userResetPassword(
    'user.resetPassword',
    'Şifre sıfırlama gönder',
    PermissionGroup.user,
    isWrite: true,
    description: 'Kullanıcıya şifre sıfırlama bağlantısı e-postalar.',
  ),
  userAssignRole(
    'user.assignRole',
    'Rol ata',
    PermissionGroup.user,
    isWrite: true,
  ),
  userAssignPermissions(
    'user.assignPermissions',
    'Yetki ata',
    PermissionGroup.user,
    isWrite: true,
    description: 'Öğrenci bazında izinleri açıp kapatır.',
  ),

  // ─────────────────────────── Rapor ───────────────────────────
  reportView('report.view', 'Raporları görüntüle', PermissionGroup.report),
  reportExport(
    'report.export',
    'PDF rapor indir',
    PermissionGroup.report,
    description: 'Rapor sonuçlarını PDF dosyası olarak indirir.',
  ),

  // ─────────────────────────── Ayarlar ───────────────────────────
  settingsView('settings.view', 'Ayarları görüntüle', PermissionGroup.settings),
  settingsEdit(
    'settings.edit',
    'Ayarları düzenle',
    PermissionGroup.settings,
    isWrite: true,
    description:
        'Yurt bilgileri, ilk ve son giriş saatleri ve konum kuralları.',
  );

  const AppPermission(
    this.key,
    this.label,
    this.group, {
    this.description,
    this.isWrite = false,
  });

  /// Firestore ve güvenlik kurallarında kullanılan anahtar.
  final String key;

  /// Yetki ekranında görünen Türkçe ad.
  final String label;

  final PermissionGroup group;

  /// Yetkinin ne işe yaradığını anlatan açıklama.
  final String? description;

  /// Veri değiştiren bir izin mi?
  ///
  /// Askıya alınmış müşterilerde yazma izinleri otomatik olarak kapanır.
  final bool isWrite;

  static AppPermission? fromKey(String? key) {
    for (final AppPermission permission in AppPermission.values) {
      if (permission.key == key) return permission;
    }
    return null;
  }

  /// İzinleri gruplara ayırarak döner — yetki düzenleme ekranı için.
  static Map<PermissionGroup, List<AppPermission>> grouped() {
    final Map<PermissionGroup, List<AppPermission>> result =
        <PermissionGroup, List<AppPermission>>{};
    for (final AppPermission permission in AppPermission.values) {
      result
          .putIfAbsent(permission.group, () => <AppPermission>[])
          .add(permission);
    }
    return result;
  }
}
