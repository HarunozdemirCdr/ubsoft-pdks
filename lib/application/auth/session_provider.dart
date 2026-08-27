import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubsoft_pdks/application/providers.dart';
import 'package:ubsoft_pdks/core/config/firebase_collections.dart';
import 'package:ubsoft_pdks/core/result/result.dart';
import 'package:ubsoft_pdks/domain/entities/app_user.dart';
import 'package:ubsoft_pdks/domain/entities/session.dart';
import 'package:ubsoft_pdks/domain/entities/tenant.dart';
import 'package:ubsoft_pdks/domain/permissions/app_permission.dart';
import 'package:ubsoft_pdks/domain/permissions/permission_set.dart';
import 'package:ubsoft_pdks/domain/repositories/tenant_repository.dart';
import 'package:ubsoft_pdks/domain/repositories/user_repository.dart';

/// Firebase oturumunun ham hâli — yalnız kullanıcı kimliği.
final StreamProvider<String?> authStateProvider = StreamProvider<String?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);

/// Uygulamanın merkezî oturum akışı.
///
/// Tüm veri tek bir kök altında (`tenants/{tenantId}/…`) durduğu için oturum
/// çözümü iki adımlıdır:
///
/// ```
/// 1. Firebase oturumu (uid)
/// 2. Koleksiyon-grubu sorgusu: hangi müşterinin altındayım?
/// 3. tenants/{tid}/users/{uid}  → canlı izlenir
/// 4. tenants/{tid}             → canlı izlenir
/// 5. tenants/{tid}/roleDefaults → izinler çözülür
/// ```
///
/// İkinci adım yalnız bir kez çalışır; sonrasında yol bilindiği için doğrudan
/// doküman dinlenir. Kullanıcı ve müşteri **canlı izlenir**: yönetici bir
/// personeli pasifleştirdiği anda o kişinin ekranı engellenir, abonelik askıya
/// alındığında uygulama anında salt okunur olur.
final StreamProvider<Session> sessionProvider = StreamProvider<Session>((
  ref,
) async* {
  final String? uid = await ref.watch(authStateProvider.future);

  if (uid == null) {
    yield const Session.signedOut();
    return;
  }

  final UserRepository users = ref.watch(userRepositoryProvider);
  final TenantRepository tenants = ref.watch(tenantRepositoryProvider);

  // 1) Kullanıcı hangi müşterinin altında?
  final Result<AppUser> located = await users.findByUid(uid);
  if (located case Err<AppUser>()) {
    yield const Session.blocked(SessionBlockReason.profileMissing);
    return;
  }

  final AppUser profile = (located as Ok<AppUser>).value;
  final String tenantId = profile.tenantId;
  if (tenantId.isEmpty) {
    yield const Session.blocked(SessionBlockReason.tenantMissing);
    return;
  }

  // 2) Rol varsayılanları — müşteri başına, oturum başında bir kez okunur.
  final Result<Map<String, Map<String, bool>>> defaultsResult = await tenants
      .getRoleDefaults(tenantId);
  final Map<String, Map<String, bool>> defaults =
      defaultsResult.valueOrNull ?? const <String, Map<String, bool>>{};

  // 3) Süper admin bir müşteriye bağlı değildir; yalnız kendi kaydı izlenir.
  if (profile.role.isSuperAdmin) {
    yield* _quiet(users.watchUser(tenantId, uid)).map(
      (AppUser? user) => switch (user) {
        null => const Session.blocked(SessionBlockReason.profileMissing),
        AppUser(canSignIn: false) => const Session.blocked(
          SessionBlockReason.userInactive,
        ),
        _ => Session.superAdmin(user),
      },
    );
    return;
  }

  // 4) Kullanıcı ve müşteri EŞ ZAMANLI izlenir.
  //
  // İkisi ayrı akıştır ve ikisi de sonsuzdur. Kullanıcı akışının içinden
  // müşteri akışına `yield*` ile delege edilemez: `yield*` delege edilen akış
  // bitene kadar bekler, müşteri akışı ise hiç bitmez — dış döngü orada
  // sonsuza dek donar ve kullanıcı dokümanındaki hiçbir değişiklik (yetki
  // override'ı, rol değişimi, pasifleştirme) bir daha okunmazdı. Bu yüzden iki
  // akış birleştirilir ve her ikisinin son değerinden oturum yeniden kurulur.
  yield* _mergeSession(
    users: _quiet(users.watchUser(tenantId, uid)),
    tenants: _quiet(tenants.watchTenant(tenantId)),
    roleDefaults: defaults,
  ).distinct();
});

/// Kullanıcı ve müşteri akışlarını tek bir oturum akışına birleştirir.
///
/// İki kaynak da bağımsız olarak yayın yapar; her yayında o anki iki değerden
/// oturum yeniden çözülür. Her iki taraftan da en az bir değer gelmeden oturum
/// yayınlanmaz — aksi hâlde müşteri henüz yüklenmemişken kullanıcı yanlışlıkla
/// "müşterisi yok" sayılırdı.
Stream<Session> _mergeSession({
  required Stream<AppUser?> users,
  required Stream<Tenant?> tenants,
  required Map<String, Map<String, bool>> roleDefaults,
}) {
  final StreamController<Session> controller = StreamController<Session>();
  StreamSubscription<AppUser?>? userSub;
  StreamSubscription<Tenant?>? tenantSub;

  AppUser? user;
  Tenant? tenant;
  bool hasUser = false;
  bool hasTenant = false;

  void publish() {
    if (!hasUser || controller.isClosed) return;

    final AppUser? current = user;
    if (current == null) {
      controller.add(const Session.blocked(SessionBlockReason.profileMissing));
      return;
    }
    if (!current.canSignIn) {
      controller.add(const Session.blocked(SessionBlockReason.userInactive));
      return;
    }

    if (!hasTenant) return;

    final Tenant? company = tenant;
    if (company == null) {
      controller.add(const Session.blocked(SessionBlockReason.tenantMissing));
      return;
    }

    // Abonelik süresi dolduğunda personelin yapabileceği hiçbir şey kalmaz:
    // okutma yapamaz. Ona sebebi söylenmeyen, düğmeleri sessizce kaybolmuş
    // bir uygulama göstermek en kötü seçenektir — "program bozuldu" telefonu
    // gelir ve kimse aboneliğin bittiğini fark etmez.
    //
    // Yönetici ise girebilmelidir: geçmiş raporlarına ulaşsın, aboneliği
    // yenilemek için kiminle konuşacağını görsün. Onda uygulama salt okunur
    // kalır ([PermissionSet.tenantWritable]) ve üstte kalıcı bir uyarı çıkar.
    if (current.role.isStaff && company.subscription.isExpired) {
      controller.add(
        const Session.blocked(SessionBlockReason.subscriptionExpired),
      );
      return;
    }

    // Askıya alma tek başına oturumu kesmez; hesap salt okunur hâle gelir.
    // Erişim yalnız abonelik de bittiyse tamamen kapanır.
    if (!company.status.isWritable && company.subscription.isExpired) {
      controller.add(const Session.blocked(SessionBlockReason.tenantSuspended));
      return;
    }

    controller.add(
      Session.active(
        user: current,
        tenant: company,
        permissions: PermissionSet(
          role: current.role,
          overrides: current.permissionOverrides,
          roleDefaults:
              roleDefaults[current.role.key] ?? const <String, bool>{},
          tenantWritable: company.isWritable,
        ),
      ),
    );
  }

  controller
    ..onListen = () {
      userSub = users.listen((AppUser? value) {
        user = value;
        hasUser = true;
        publish();
      }, onDone: controller.close);
      tenantSub = tenants.listen((Tenant? value) {
        tenant = value;
        hasTenant = true;
        publish();
      });
    }
    ..onCancel = () async {
      await userSub?.cancel();
      await tenantSub?.cancel();
    };

  return controller.stream;
}

/// Canlı dinlemedeki hatayı yutar ve akışı sessizce kapatır.
///
/// Çıkış yapıldığı anda hâlâ açık olan Firestore dinleyicileri
/// "permission-denied" fırlatır — kural gereği doğrudur, kullanıcı artık o
/// dokümanı okuyamaz. Ama bu hata oturum akışını `AsyncError`'a düşürseydi,
/// yönlendirici oturumu "henüz çözülmedi" sayar ve kullanıcı çıkış yaptığı
/// hâlde bulunduğu ekranda kalırdı. Akışın kapanması yeterli: `authState`
/// zaten `null` yayınlayıp oturumu yeniden çözdürür.
Stream<T> _quiet<T>(Stream<T> source) =>
    source.handleError((Object error, StackTrace stackTrace) {});

/// Yönlendiricinin baktığı oturum.
///
/// Firebase "kullanıcı yok" dediği an sonuç [Session.signedOut]'tur; oturum
/// akışının kendini toplamasını beklemeyiz. Aksi hâlde çıkış ile giriş ekranı
/// arasında, akış yeniden kurulurken eski oturumun görünmeye devam ettiği bir
/// boşluk kalırdı.
final Provider<Session> routingSessionProvider = Provider<Session>((ref) {
  final AsyncValue<String?> auth = ref.watch(authStateProvider);
  if (auth.hasValue && auth.value == null) return const Session.signedOut();
  return ref.watch(sessionProvider).value ?? const Session.unknown();
});

/// Oturumun anlık hâli. Henüz çözülmediyse [Session.unknown].
final Provider<Session> currentSessionProvider = Provider<Session>(
  (ref) => ref.watch(sessionProvider).value ?? const Session.unknown(),
);

/// Giriş yapmış kullanıcı.
final Provider<AppUser?> currentUserProvider = Provider<AppUser?>(
  (ref) => ref.watch(currentSessionProvider).userOrNull,
);

/// Aktif müşteri. Süper adminde `null`.
final Provider<Tenant?> currentTenantProvider = Provider<Tenant?>(
  (ref) => ref.watch(currentSessionProvider).tenantOrNull,
);

/// Aktif müşteri kimliği — tenant'a bağlı tüm veri provider'ları bunu izler.
///
/// Süper admin için sistem müşterisi döner; gerçek müşteri verisine erişmesi
/// gerektiğinde kimlik açıkça parametre olarak geçilir.
///
/// Oturum yoksa hata fırlatır: tenant gerektiren bir ekran oturumsuz
/// açılmışsa sorun yönlendirme katmanındadır, sessizce boş veri göstermek
/// hatayı gizlerdi.
final Provider<String> tenantIdProvider = Provider<String>((ref) {
  final AppUser? user = ref.watch(currentUserProvider);
  if (user == null) {
    throw StateError('Aktif oturum yok: bu ekran giriş gerektirir.');
  }
  return user.tenantId;
});

/// Çözülmüş izinler.
final Provider<PermissionSet> permissionsProvider = Provider<PermissionSet>(
  (ref) => ref.watch(currentSessionProvider).permissionsOrNone,
);

/// Tek bir izin kontrolü.
///
/// ```dart
/// if (ref.watch(canProvider(AppPermission.regionCreate))) { ... }
/// ```
final canProvider = Provider.family<bool, AppPermission>(
  (ref, permission) => ref.watch(permissionsProvider).can(permission),
);

/// Süper adminlerin barındığı sistem müşterisi kimliği.
const String systemTenantId = FsPaths.systemTenantId;
