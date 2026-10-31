import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:ubsoft_pdks/application/attendance/attendance_providers.dart';
import 'package:ubsoft_pdks/application/attendance/punch_controller.dart';
import 'package:ubsoft_pdks/application/auth/session_provider.dart';
import 'package:ubsoft_pdks/application/providers.dart';
import 'package:ubsoft_pdks/core/config/firebase_collections.dart';
import 'package:ubsoft_pdks/core/error/failure.dart';
import 'package:ubsoft_pdks/core/result/result.dart';
import 'package:ubsoft_pdks/core/theme/app_theme.dart';
import 'package:ubsoft_pdks/data/mappers/attendance_mapper.dart';
import 'package:ubsoft_pdks/domain/entities/app_user.dart';
import 'package:ubsoft_pdks/domain/entities/attendance_day.dart';
import 'package:ubsoft_pdks/domain/entities/attendance_event.dart';
import 'package:ubsoft_pdks/domain/entities/checkpoint.dart';
import 'package:ubsoft_pdks/domain/entities/scan_location.dart';
import 'package:ubsoft_pdks/domain/entities/tenant.dart';
import 'package:ubsoft_pdks/domain/enums/location_verdict.dart';
import 'package:ubsoft_pdks/domain/enums/punch_type.dart';
import 'package:ubsoft_pdks/domain/enums/tenant_status.dart';
import 'package:ubsoft_pdks/domain/enums/user_role.dart';
import 'package:ubsoft_pdks/domain/enums/user_status.dart';
import 'package:ubsoft_pdks/domain/permissions/role_defaults.dart';
import 'package:ubsoft_pdks/domain/repositories/auth_repository.dart';
import 'package:ubsoft_pdks/services/location/location_service.dart';

/// Testlerin ortak kurulumu.
///
/// Gerçek Firebase yerine bellek içi sahteleri kullanır; hiçbir test ağa
/// çıkmaz. Uygulamanın kendisi değişmeden çalışır: yalnız iki kök sağlayıcı
/// (`firestoreProvider`, `firebaseAuthProvider`) değiştirilir.
abstract final class TestData {
  static const String tenantId = 'test-tenant';
  static const String adminUid = 'admin-uid';
  static const String staffUid = 'staff-uid';
  static const String superAdminUid = 'super-uid';

  static const String adminEmail = 'yonetici@test.com';
  static const String staffEmail = 'ogrenci@test.com';

  /// QR noktasının bulunduğu örnek koordinat (İstanbul, Levent).
  static const double lat = 41.081944;
  static const double lon = 29.010556;

  static Tenant tenant({
    TenantStatus status = TenantStatus.active,
    DateTime? expiresAt,
    TenantSettings settings = const TenantSettings(),
  }) {
    final DateTime now = DateTime.now();
    return Tenant(
      id: tenantId,
      name: 'Test Yurdu',
      slug: 'test-sirketi',
      status: status,
      subscription: Subscription(
        plan: SubscriptionPlan.standard,
        startsAt: now.subtract(const Duration(days: 10)),
        expiresAt: expiresAt ?? now.add(const Duration(days: 100)),
        maxUsers: 100,
        maxCheckpoints: 30,
      ),
      settings: settings,
      counters: const TenantCounters(userCount: 2, checkpointCount: 2),
      createdAt: now.subtract(const Duration(days: 10)),
    );
  }

  static AppUser user({
    String uid = staffUid,
    String name = 'Ahmet Yılmaz',
    UserRole role = UserRole.staff,
    UserStatus status = UserStatus.active,
    Map<String, bool> overrides = const <String, bool>{},
    String tenant = tenantId,
    String? note,
  }) => AppUser(
    uid: uid,
    email: role.isStaff ? staffEmail : adminEmail,
    displayName: name,
    tenantId: tenant,
    role: role,
    status: status,
    note: note,
    permissionOverrides: overrides,
    createdAt: DateTime.now().subtract(const Duration(days: 5)),
  );

  static Checkpoint checkpoint({
    String id = 'cp-in',
    String code = '1',
    String name = 'Ana Giriş',
    CheckpointKind kind = CheckpointKind.entry,
    double latitude = lat,
    double longitude = lon,
    int radiusMeters = 75,
    bool active = true,
  }) => Checkpoint(
    id: id,
    code: code,
    name: name,
    kind: kind,
    latitude: latitude,
    longitude: longitude,
    radiusMeters: radiusMeters,
    active: active,
    createdAt: DateTime.now(),
  );

  /// Noktanın [meters] metre kuzeyindeki bir ölçüm.
  ///
  /// Enlem başına yaklaşık 111.320 metre; kısa mesafede bu yaklaşım
  /// haversine ile birkaç santimetre içinde uyuşur.
  static ScanLocation locationNorthOf(double meters, {double accuracy = 10}) =>
      ScanLocation(
        latitude: lat + meters / 111320.0,
        longitude: lon,
        accuracy: accuracy,
        capturedAt: DateTime.now(),
      );
}

/// Konum servisinin test karşılığı.
///
/// Gerçek GPS beklenmez: her test hangi ölçümün geleceğine kendisi karar
/// verir, "izin reddedildi" durumu bile tek satırla kurulur.
class FakeLocationService implements LocationService {
  FakeLocationService({this.location, this.failure});

  ScanLocation? location;
  String? failure;

  int currentCalls = 0;

  @override
  Future<bool> ensurePermission() async => failure == null;

  @override
  Future<Result<ScanLocation>> current() async {
    currentCalls++;
    final ScanLocation? value = location;
    if (value == null) {
      return Err<ScanLocation>(LocationFailure(failure ?? 'Konum alınamadı.'));
    }
    return Ok<ScanLocation>(value);
  }
}

/// Kimlik doğrulamanın test karşılığı.
///
/// `MockFirebaseAuth` yerine kendi sahtemizi kullanmamızın sebebi somut:
/// onun `authStateChanges()` akışı sıradan bir yayın (broadcast) akışıdır ve
/// oturumu kurucu içinde yayınlar — dinleyici bağlanmadan önce. Olay
/// kaybolur, uygulama oturumu asla çözemez ve testler zaman aşımına uğrar.
/// Buradaki uygulama, dinleyen herkese **önce mevcut durumu** verir.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({String? uid}) : _uid = uid;

  String? _uid;
  int _created = 0;
  final StreamController<String?> _changes =
      StreamController<String?>.broadcast();

  @override
  Stream<String?> authStateChanges() =>
      Stream<String?>.multi((MultiStreamController<String?> controller) {
        controller.add(_uid);
        final StreamSubscription<String?> sub = _changes.stream.listen(
          controller.add,
        );
        controller.onCancel = sub.cancel;
      });

  @override
  String? get currentUid => _uid;

  @override
  Future<Result<String>> signIn({
    required String email,
    required String password,
  }) async {
    _uid = email;
    _changes.add(_uid);
    return Ok<String>(_uid!);
  }

  @override
  Future<Result<void>> signOut() async {
    _uid = null;
    _changes.add(null);
    return okVoid;
  }

  @override
  Future<Result<void>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async => okVoid;

  @override
  Future<Result<void>> sendPasswordResetEmail(String email) async => okVoid;

  @override
  Future<Result<String>> createAuthAccount({
    required String email,
    required String password,
  }) async {
    _created++;
    return Ok<String>('yeni-uid-$_created');
  }

  void dispose() => _changes.close();
}

/// Bellek içi Firestore + sahte Auth ile hazırlanmış bir kapsam.
class TestScope {
  TestScope._({
    required this.firestore,
    required this.auth,
    required this.container,
    required this.location,
  });

  final FakeFirebaseFirestore firestore;
  final FakeAuthRepository auth;
  final ProviderContainer container;
  final FakeLocationService location;

  /// Bir dinleyiciyi test boyunca canlı tutar.
  ///
  /// Riverpod 3'te sağlayıcılar **varsayılan olarak** dinleyicisi kalmayınca
  /// atılır. `container.read(x.future)` tek başına bir dinleyici saymaz:
  /// akış kurulur, hemen kapatılır ve future asla tamamlanmaz. Testlerin
  /// zaman aşımına uğramasının sebebi budur.
  ///
  /// ```dart
  /// scope.retain(scope.container.listen(myTodayProvider, (_, __) {}));
  /// ```
  void retain(ProviderSubscription<Object?> subscription) =>
      _subscriptions.add(subscription);

  final List<ProviderSubscription<Object?>> _subscriptions =
      <ProviderSubscription<Object?>>[];

  void dispose() {
    for (final ProviderSubscription<Object?> sub in _subscriptions) {
      sub.close();
    }
    container.dispose();
    auth.dispose();
  }
}

/// Testler için hazır bir bağımlılık kapsamı kurar.
///
/// [signedInAs] verildiğinde o kullanıcı oturum açmış sayılır ve Firestore'a
/// yurt, rol varsayılanları ve kullanıcı kaydı yazılır.
Future<TestScope> buildScope({
  AppUser? signedInAs,
  Tenant? tenant,
  List<Checkpoint> checkpoints = const <Checkpoint>[],
  List<AppUser> extraUsers = const <AppUser>[],
  ScanLocation? location,
  Duration punchCooldown = Duration.zero,
}) async {
  final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
  final Tenant company = tenant ?? TestData.tenant();

  await _writeTenant(firestore, company);
  await _writeRoleDefaults(firestore, company.id);

  for (final AppUser user in <AppUser>[?signedInAs, ...extraUsers]) {
    await _writeUser(firestore, user);
  }

  for (final Checkpoint checkpoint in checkpoints) {
    await _writeCheckpoint(firestore, company.id, checkpoint);
  }

  final FakeAuthRepository auth = FakeAuthRepository(uid: signedInAs?.uid);

  final FakeLocationService locationService = FakeLocationService(
    location: location,
  );

  // `Override` tipi `flutter_riverpod` tarafından dışa aktarılmıyor; liste
  // tipi çağrı yerinden çıkarılıyor.
  final ProviderContainer container = ProviderContainer(
    overrides: [
      firestoreProvider.overrideWithValue(firestore),
      authRepositoryProvider.overrideWithValue(auth),
      locationServiceProvider.overrideWithValue(locationService),
      // Kazara ikinci okutmaya karşı konan bekleme süresi testlerde
      // varsayılan olarak SIFIRDIR.
      //
      // Uçtan uca senaryolar bir girişi ve çıkışı milisaniyeler içinde
      // yapar — gerçek bir insanın asla yapamayacağı hızda. Süre açık
      // bırakılsaydı bu testler kuralın kendisini değil, testin hızını
      // ölçerdi. Kuralın doğruluğu `resolve_punch_test.dart` içinde ve
      // `punch_flow_test.dart`'taki "kazara ikinci okutma" senaryosunda
      // ayrıca sınanır.
      punchCooldownProvider.overrideWithValue(punchCooldown),
    ],
  );

  // Oturum zinciri (auth → kullanıcı → yurt → izinler) test boyunca canlı
  // tutulur; ekranların ve denetleyicilerin dayandığı temel budur.
  return TestScope._(
      firestore: firestore,
      auth: auth,
      container: container,
      location: locationService,
    )
    ..retain(container.listen(sessionProvider, (_, _) {}))
    ..retain(container.listen(myTodayProvider, (_, _) {}))
    ..retain(container.listen(myTodayEventsProvider, (_, _) {}));
}

/// Hazır bir gün özeti yazar.
///
/// Geçmiş ve rapor ekranlarının testleri gerçek okutma akışını çalıştırmaz;
/// onların sınadığı şey kaydın nasıl oluştuğu değil, oluşmuş bir kaydın
/// nasıl gösterildiğidir. Saatler `dateKey` üzerine bindirilir ki gün
/// değiştiğinde test kırılmasın.
Future<AttendanceDay> seedDay(
  TestScope scope, {
  required String userId,
  required String dateKey,
  String userName = 'Ahmet Yılmaz',
  String? entryAt = '08:30',
  String? exitAt = '17:30',
  int workedMinutes = 480,
  bool late = false,
  LocationVerdict verdict = LocationVerdict.verified,
  String tenantId = TestData.tenantId,
}) async {
  DateTime? at(String? time) =>
      time == null ? null : DateTime.parse('${dateKey}T$time:00');

  final AttendanceDay day = AttendanceDay(
    id: AttendanceDay.buildId(userId: userId, dateKey: dateKey),
    tenantId: tenantId,
    userId: userId,
    userName: userName,
    dateKey: dateKey,
    firstEntryAt: at(entryAt),
    lastEntryAt: at(entryAt),
    lastExitAt: at(exitAt),
    entryCount: entryAt == null ? 0 : 1,
    exitCount: exitAt == null ? 0 : 1,
    workedMinutes: exitAt == null ? 0 : workedMinutes,
    open: entryAt != null && exitAt == null,
    late: late,
    worstVerdict: verdict,
  );

  await scope.firestore
      .collection(FsPaths.tenants)
      .doc(tenantId)
      .collection(FsPaths.attendanceDays)
      .doc(day.id)
      .set(AttendanceDayMapper.toMap(day));

  return day;
}

/// Tek bir okutma kaydı yazar — açılan gün listesini beslemek için.
Future<void> seedEvent(
  TestScope scope, {
  required String userId,
  required String dateKey,
  required PunchType type,
  String time = '08:30',
  String userName = 'Ahmet Yılmaz',
  String tenantId = TestData.tenantId,
}) async {
  final AttendanceEvent event = AttendanceEvent(
    id: '$userId-$dateKey-${type.key}',
    tenantId: tenantId,
    userId: userId,
    userName: userName,
    type: type,
    at: DateTime.parse('${dateKey}T$time:00'),
    dateKey: dateKey,
    checkpointId: 'cp-in',
    checkpointName: 'Ana Giriş',
    checkpointCode: '1',
    verdict: LocationVerdict.verified,
  );

  // `toCreateMap` `at` alanına sunucu damgası koyar; testin saati kendi
  // belirlemesi gerektiği için o alan burada gerçek değerle ezilir.
  await scope.firestore
      .collection(FsPaths.tenants)
      .doc(tenantId)
      .collection(FsPaths.attendance)
      .doc(event.id)
      .set(<String, Object?>{
        ...AttendanceEventMapper.toCreateMap(event),
        'at': Timestamp.fromDate(event.at),
      });
}

Future<void> _writeTenant(FakeFirebaseFirestore db, Tenant tenant) =>
    db.collection(FsPaths.tenants).doc(tenant.id).set(<String, Object?>{
      'name': tenant.name,
      'slug': tenant.slug,
      'timezone': tenant.timezone,
      'locale': tenant.locale,
      'status': tenant.status.key,
      'subscription': <String, Object?>{
        'plan': tenant.subscription.plan.key,
        'startsAt': Timestamp.fromDate(tenant.subscription.startsAt),
        'expiresAt': Timestamp.fromDate(tenant.subscription.expiresAt),
        'maxUsers': tenant.subscription.maxUsers,
        'maxCheckpoints': tenant.subscription.maxCheckpoints,
      },
      'settings': <String, Object?>{
        'defaultRadiusMeters': tenant.settings.defaultRadiusMeters,
        'requireLocation': tenant.settings.requireLocation,
        'blockOutsideScans': tenant.settings.blockOutsideScans,
        'workStartMinutes': tenant.settings.workStartMinutes,
        'workEndMinutes': tenant.settings.workEndMinutes,
        'lateToleranceMinutes': tenant.settings.lateToleranceMinutes,
      },
      'counters': <String, Object?>{
        'userCount': tenant.counters.userCount,
        'checkpointCount': tenant.counters.checkpointCount,
      },
      'createdAt': Timestamp.fromDate(tenant.createdAt),
    });

Future<void> _writeRoleDefaults(
  FakeFirebaseFirestore db,
  String tenantId,
) async {
  final Map<String, Map<String, bool>> defaults = RoleDefaults.allAsMaps();
  for (final MapEntry<String, Map<String, bool>> entry in defaults.entries) {
    await db
        .collection(FsPaths.tenants)
        .doc(tenantId)
        .collection(FsPaths.roleDefaults)
        .doc(entry.key)
        .set(<String, Object?>{'permissions': entry.value});
  }
}

Future<void> _writeUser(FakeFirebaseFirestore db, AppUser user) => db
    .collection(FsPaths.tenants)
    .doc(user.tenantId)
    .collection(FsPaths.users)
    .doc(user.uid)
    .set(<String, Object?>{
      'uid': user.uid,
      'email': user.email,
      'displayName': user.displayName,
      'tenantId': user.tenantId,
      'role': user.role.key,
      'status': user.status.key,
      'permissions': user.permissionOverrides,
      if (user.note != null) 'note': user.note,
      'createdAt': Timestamp.fromDate(user.createdAt),
    });

Future<void> _writeCheckpoint(
  FakeFirebaseFirestore db,
  String tenantId,
  Checkpoint checkpoint,
) async {
  final DocumentReference<Map<String, dynamic>> tenantRef = db
      .collection(FsPaths.tenants)
      .doc(tenantId);

  await tenantRef
      .collection(FsPaths.checkpoints)
      .doc(checkpoint.id)
      .set(<String, Object?>{
        'code': checkpoint.code,
        'name': checkpoint.name,
        'description': checkpoint.description ?? '',
        'kind': checkpoint.kind.key,
        'latitude': checkpoint.latitude,
        'longitude': checkpoint.longitude,
        'radiusMeters': checkpoint.radiusMeters,
        'active': checkpoint.active,
        'order': checkpoint.order,
        'createdAt': Timestamp.fromDate(checkpoint.createdAt),
      });

  await tenantRef.collection(FsPaths.qrIndex).doc(checkpoint.code).set(
    <String, Object?>{'checkpointId': checkpoint.id},
  );
}

/// Türkçe tarih biçimleri — `AppDate` bunlar olmadan çalışmaz.
Future<void> initTestLocale() => initializeDateFormatting('tr');

/// Bir ekranı test edilebilir bir uygulama iskeleti içinde çizer.
Widget wrapPage(
  Widget page, {
  required ProviderContainer container,
  Size size = const Size(400, 900),
  bool dark = false,
}) {
  return UncontrolledProviderScope(
    container: container,
    child: MediaQuery(
      data: MediaQueryData(size: size),
      child: MaterialApp(
        theme: dark ? AppTheme.dark : AppTheme.light,
        locale: const Locale('tr'),
        supportedLocales: const <Locale>[Locale('tr')],
        localizationsDelegates: const <LocalizationsDelegate<Object>>[
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: page,
      ),
    ),
  );
}

/// Firestore akışlarının yeni değeri yayınlamasına izin verir.
///
/// `container.read(streamProvider.future)` **ilk** değeri döner ve bir daha
/// güncellenmez; yazma sonrası durumu okumak için akışın yerleşmesini
/// bekleyip o anki [AsyncValue] okunmalıdır.
///
/// **Yalnız düz `test()` içinde kullanılır.** Widget testlerinde
/// zamanlayıcılar sahte bir saate bağlıdır ve `Future.delayed` ancak
/// `tester.pump()` çağrıldığında ilerler; orada [settle] kullanılmalıdır.
Future<void> flush([int rounds = 4]) async {
  for (int i = 0; i < rounds; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// Yönlendirme yapan bir ekranı test edilebilir hâlde çizer.
///
/// Kaydettikten sonra `context.go(...)` ya da `context.pop()` çağıran
/// sayfalar, çevrelerinde bir `GoRouter` bulamazsa patlar. Burada iki
/// kademeli bir yönlendirici kurulur: sayfa `/sayfa` üzerinde durur, altında
/// bir kök vardır — böylece `pop()` da geçerli bir hedef bulur. Gidilen her
/// bilinmeyen adres boş bir ekrana düşer; testin ilgilendiği şey yazılan
/// veridir, varılan ekran değil.
Widget wrapRouted(
  Widget page, {
  required ProviderContainer container,
  Size size = const Size(400, 900),
}) {
  final GoRouter router = GoRouter(
    initialLocation: '/sayfa',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (BuildContext _, GoRouterState _) =>
            const Scaffold(body: Center(child: Text('kök'))),
        routes: <RouteBase>[
          GoRoute(
            path: 'sayfa',
            builder: (BuildContext _, GoRouterState _) => page,
          ),
        ],
      ),
    ],
    errorBuilder: (BuildContext _, GoRouterState state) =>
        Scaffold(body: Center(child: Text('→ ${state.uri}'))),
  );

  return UncontrolledProviderScope(
    container: container,
    child: MediaQuery(
      data: MediaQueryData(size: size),
      child: MaterialApp.router(
        theme: AppTheme.light,
        locale: const Locale('tr'),
        supportedLocales: const <Locale>[Locale('tr')],
        localizationsDelegates: const <LocalizationsDelegate<Object>>[
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routerConfig: router,
      ),
    ),
  );
}

/// Widget testlerinde akışların yerleşmesi için birkaç kare çizer.
///
/// Süre vererek beklemek şart: `tester.pump()` tek başına yalnız mikro
/// görevleri boşaltır, `Future.delayed(Duration.zero)` ile kurulan
/// Firestore anlık görüntüleri ancak sahte saat ilerleyince ulaşır.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  for (int i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}
