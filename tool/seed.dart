// UBSoft PDKS — ilk kurulum ve örnek veri betiği.
//
// Ne yapar:
//   1. Süper admin hesabını açar (`tenants/_system/users/{uid}`).
//   2. Örnek bir müşteri kurar: rol varsayılanları, bir yönetici, on iki
//      öğrenci, üç QR noktası ve son beş güne ait devam kayıtları.
//
// Kullanım:
//   dart run tool/seed.dart --token=<oauth_access_token>
//   dart run tool/seed.dart --token=<...> --only-super-admin
//
// Token nasıl alınır (biri yeterli):
//   gcloud auth print-access-token
//   gcloud auth application-default print-access-token
//
// Betik yeniden çalıştırılabilir: sabit kimlikler kullandığı için kayıtları
// çoğaltmaz, üzerine yazar. Admin SDK yerine REST kullanılır; böylece ek bir
// bağımlılık ya da servis hesabı anahtarı gerekmez.

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:ubsoft_pdks/domain/enums/user_role.dart';
import 'package:ubsoft_pdks/domain/permissions/role_defaults.dart';

const String projectId = 'ubsoft-pdks';
const String firestoreBase =
    'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents';
const String identityBase =
    'https://identitytoolkit.googleapis.com/v1/projects/$projectId';

/// Örnek müşteri — sabit kimlik, betiğin tekrar çalıştırılabilmesi için.
const String demoTenantId = 'turgev-demo';

const String superAdminEmail = 'admin@ubselektronik.com';
const String superAdminPassword = 'UbsTurgev2026!';

const String demoAdminEmail = 'mudire@turgevdemo.com';
const String demoPassword = 'TurgevDemo2026!';

/// Kaç günlük geçmiş üretilecek (yaklaşık 1,5 ay).
const int _historyDays = 5;

/// Bir öğrencinin devam davranışı.
///
/// Demo verisinin tamamı bu profillerden doğar. Amaç "dolu görünen" bir
/// veritabanı değil, arayüzün **her durumunu** gerçek veriyle görebilmektir:
/// sürekli geç gelen biri olmadan geç giriş rozeti, çıkışını unutan biri
/// olmadan "çıkış yok" uyarısı test edilemez.
enum _Profile {
  /// Hep zamanında.
  punctual,

  /// Sık sık geç.
  oftenLate,

  /// Sık sık gelmiyor; arada üç günlük kesintisiz boşluk (rapor).
  absentee,

  /// Çıkışını sık unutuyor.
  forgetsExit,

  /// Konumu sık sık doğrulanamıyor (uzaktan ya da sınırda okutma).
  locationIssues,

  /// Öğle arası çıkıp geri geliyor: günde dört okutma.
  splitDay,

  /// Erken vardiya: 06:30 – 15:30. Geç sayılmaz.
  earlyShift,

  /// Yarı zamanlı: yalnız pazartesi, çarşamba, cuma.
  partTime,

  /// Hafta sonu nöbeti tutabilen personel.
  weekendDuty,

  /// Düzenli çalışan.
  steady,
}

/// Örnek kadro tanımı.
class _DemoPerson {
  const _DemoPerson({
    required this.email,
    required this.name,
    required this.note,
    required this.profile,
    this.role = UserRole.staff,
    this.active = true,
    this.leftDaysAgo,
  });

  final String email;
  final String name;
  final String note;
  final _Profile profile;
  final UserRole role;

  /// `false` ise kadroda pasif görünür.
  final bool active;

  /// Bu kadar gün önce işten ayrıldıysa, o günden sonrası boştur.
  final int? leftDaysAgo;
}

/// Kimliği çözülmüş, kayıt üretmeye hazır öğrenci.
class _SeededPerson {
  const _SeededPerson({
    required this.uid,
    required this.name,
    required this.profile,
    required this.leftDaysAgo,
  });

  final String uid;
  final String name;
  final _Profile profile;
  final int? leftDaysAgo;
}

/// Tek bir okutma.
class _Punch {
  const _Punch({
    required this.index,
    required this.at,
    required this.isEntry,
    required this.verdict,
    required this.distance,
  });

  /// Gün içindeki sırası — belge kimliğini benzersiz yapar.
  final int index;

  final DateTime at;
  final bool isEntry;
  final String verdict;
  final double distance;
}

/// Örnek müşterinin kadrosu: bir yönetici + üç öğrenci.
const List<_DemoPerson> _demoTeam = <_DemoPerson>[
  _DemoPerson(
    email: demoAdminEmail,
    name: 'Ayşe Yılmaz',
    note: 'Müdire',
    profile: _Profile.steady,
    role: UserRole.admin,
  ),
  _DemoPerson(
    email: 'belletmen@turgevdemo.com',
    name: 'Zeynep Kaya',
    note: 'Belletmen',
    profile: _Profile.steady,
    role: UserRole.admin,
  ),
  _DemoPerson(
    email: 'ogrenci1@turgevdemo.com',
    name: 'Elif Demir',
    note: '101 numaralı oda',
    profile: _Profile.punctual,
  ),
  _DemoPerson(
    email: 'ogrenci2@turgevdemo.com',
    name: 'Merve Şahin',
    note: '102 numaralı oda',
    profile: _Profile.splitDay,
  ),
  _DemoPerson(
    email: 'ogrenci3@turgevdemo.com',
    name: 'Fatma Aydın',
    note: '103 numaralı oda',
    profile: _Profile.oftenLate,
  ),
];

late final String token;
late final bool onlySuperAdmin;

Future<void> main(List<String> args) async {
  final String provided = args
      .firstWhere((String arg) => arg.startsWith('--token='), orElse: () => '')
      .split('=')
      .skip(1)
      .join('=');

  if (provided.isEmpty) {
    stderr.writeln('Kullanım: dart run tool/seed.dart --token=<token>');
    stderr.writeln('Token: gcloud auth print-access-token');
    exit(64);
  }
  token = provided;
  onlySuperAdmin = args.contains('--only-super-admin');

  stdout.writeln('UBSoft PDKS kurulumu başlıyor ($projectId)\n');

  final String superUid = await _ensureAuthUser(
    superAdminEmail,
    superAdminPassword,
  );
  await _writeUser(
    tenantId: '_system',
    uid: superUid,
    email: superAdminEmail,
    displayName: 'Sistem Yöneticisi',
    role: UserRole.superAdmin,
  );
  stdout.writeln('  Süper admin hazır: $superAdminEmail / $superAdminPassword');

  if (onlySuperAdmin) {
    stdout.writeln('\nTamamlandı (yalnız süper admin).');
    exit(0);
  }

  await _seedTenant();
  await _seedRoleDefaults();

  final List<_SeededPerson> team = <_SeededPerson>[];
  for (final _DemoPerson person in _demoTeam) {
    final String uid = await _seedUser(person);
    team.add(
      _SeededPerson(
        uid: uid,
        name: person.name,
        profile: person.profile,
        leftDaysAgo: person.leftDaysAgo,
      ),
    );
  }

  await _seedCheckpoints();

  // Eski örnek kayıtlar silinmeden yazılırsa, belge kimliği değişen okutmalar
  // yanlarında kalır: gün özeti "bir giriş" derken listede iki giriş görünür.
  await _wipeCollection('attendance');
  await _wipeCollection('attendanceDays');

  await _seedAttendance(team.skip(2).toList());

  stdout
    ..writeln('\nTamamlandı.')
    ..writeln('  Süper admin : $superAdminEmail / $superAdminPassword')
    ..writeln('  Yönetici    : $demoAdminEmail / $demoPassword')
    ..writeln(
      '  Öğrenciler  : 3 kişi, hepsinin şifresi '
      '$demoPassword',
    );
  exit(0);
}

// ─────────────────────────── Müşteri ───────────────────────────

Future<void> _seedTenant() async {
  final DateTime now = DateTime.now();
  await _patch('tenants/$demoTenantId', <String, Object?>{
    'name': _str('TÜRGEV Demo'),
    'slug': _str('turgev-demo'),
    'timezone': _str('Europe/Istanbul'),
    'locale': _str('tr'),
    'status': _str('active'),
    'subscription': _map(<String, Object?>{
      'plan': _str('standard'),
      'startsAt': _time(now.subtract(const Duration(days: 60))),
      'expiresAt': _time(now.add(const Duration(days: 335))),
      'maxUsers': _int(100),
      'maxCheckpoints': _int(30),
    }),
    'settings': _map(<String, Object?>{
      'defaultRadiusMeters': _int(75),
      'requireLocation': _bool(true),
      'blockOutsideScans': _bool(false),
      'workStartMinutes': _int(6 * 60),
      'workEndMinutes': _int(23 * 60),
      'lateToleranceMinutes': _int(15),
    }),
    'counters': _map(<String, Object?>{
      'userCount': _int(_demoTeam.length),
      'checkpointCount': _int(3),
    }),
    'createdAt': _time(now.subtract(const Duration(days: 60))),
    'updatedAt': _time(now),
  });
  stdout.writeln('  Yurt hazır: TÜRGEV Demo');
}

Future<void> _seedRoleDefaults() async {
  final Map<String, Map<String, bool>> defaults = RoleDefaults.allAsMaps();
  for (final MapEntry<String, Map<String, bool>> entry in defaults.entries) {
    await _patch(
      'tenants/$demoTenantId/roleDefaults/${entry.key}',
      <String, Object?>{
        'permissions': _map(<String, Object?>{
          for (final MapEntry<String, bool> perm in entry.value.entries)
            perm.key: _bool(perm.value),
        }),
        'updatedAt': _time(DateTime.now()),
      },
    );
  }
  stdout.writeln('  Rol varsayılanları yazıldı (${defaults.length} rol)');
}

// ─────────────────────────── Kullanıcılar ───────────────────────────

Future<String> _seedUser(_DemoPerson person) async {
  final String uid = await _ensureAuthUser(person.email, demoPassword);
  await _writeUser(
    tenantId: demoTenantId,
    uid: uid,
    email: person.email,
    displayName: person.name,
    role: person.role,
    note: person.note,
    active: person.active,
  );
  stdout.writeln('  Kullanıcı hazır: ${person.name} (${person.role.label})');
  return uid;
}

Future<void> _writeUser({
  required String tenantId,
  required String uid,
  required String email,
  required String displayName,
  required UserRole role,
  String? note,
  bool active = true,
}) async {
  await _patch('tenants/$tenantId/users/$uid', <String, Object?>{
    'uid': _str(uid),
    'email': _str(email),
    'displayName': _str(displayName),
    'tenantId': _str(tenantId),
    'role': _str(role.key),
    'status': _str(active ? 'active' : 'inactive'),
    'permissions': _map(<String, Object?>{}),
    if (note != null) 'note': _str(note),
    'createdAt': _time(DateTime.now()),
    'updatedAt': _time(DateTime.now()),
  });
}

/// Auth hesabını açar; zaten varsa mevcut kimliği bulur.
///
/// Yönetici uç noktası `POST /v1/projects/{projectId}/accounts` kullanılır —
/// istemcinin çağırdığı `accounts:signUp` değil. İkincisi bir API anahtarı
/// bekler ve OAuth jetonuyla çağrıldığında sessizce boş döner.
Future<String> _ensureAuthUser(String email, String password) async {
  final Map<String, Object?> created = await _post(
    '$identityBase/accounts',
    <String, Object?>{
      'email': email,
      'password': password,
      'emailVerified': false,
    },
    allowFailure: true,
  );

  final Object? uid = created['localId'];
  if (uid is String) return uid;

  // Hesap zaten var: kimliğini sorgula.
  final Map<String, Object?> lookup = await _post(
    '$identityBase/accounts:lookup',
    <String, Object?>{
      'email': <String>[email],
    },
  );

  final Object? users = lookup['users'];
  if (users is List && users.isNotEmpty) {
    final Object? first = users.first;
    if (first is Map && first['localId'] is String) {
      return first['localId'] as String;
    }
  }

  stderr.writeln('Kullanıcı kimliği çözülemedi: $email');
  exit(70);
}

// ─────────────────────────── QR noktaları ───────────────────────────

/// İstanbul, Levent civarında iki örnek nokta.
const double _baseLat = 41.081944;
const double _baseLon = 29.010556;

Future<void> _seedCheckpoints() async {
  final List<(String, String, String, double, double)> points =
      <(String, String, String, double, double)>[
        ('giris', '1', 'Ana Giriş Turnikesi', _baseLat, _baseLon),
        ('cikis', '2', 'Çıkış Kapısı', _baseLat + 0.0004, _baseLon + 0.0003),
        // Tek etiketin hem giriş hem çıkış için kullanıldığı yan kapı:
        // yön, öğrencinin o anki durumundan çözülür.
        ('yan', '3', 'Yan Kapı', _baseLat - 0.0003, _baseLon + 0.0005),
      ];

  for (final (String id, String code, String name, double lat, double lon)
      in points) {
    await _patch('tenants/$demoTenantId/checkpoints/$id', <String, Object?>{
      'code': _str(code),
      'name': _str(name),
      'description': _str(''),
      'kind': _str(switch (id) {
        'giris' => 'in',
        'cikis' => 'out',
        _ => 'both',
      }),
      'latitude': _double(lat),
      'longitude': _double(lon),
      'radiusMeters': _int(75),
      'active': _bool(true),
      'order': _int(switch (id) {
        'giris' => 0,
        'cikis' => 1,
        _ => 2,
      }),
      'createdAt': _time(DateTime.now()),
      'updatedAt': _time(DateTime.now()),
    });

    await _patch('tenants/$demoTenantId/qrIndex/$code', <String, Object?>{
      'checkpointId': _str(id),
      'createdAt': _time(DateTime.now()),
    });
  }
  stdout.writeln(
    '  QR noktaları hazır: 1 (giriş), 2 (çıkış), 3 (giriş + çıkış)',
  );
}

// ─────────────────────────── Devam kayıtları ───────────────────────────

/// Son [_historyDays] güne ait okutmalar ve gün özetleri.
///
/// Veri bilinçli olarak "temiz" değildir. Her öğrencinin bir **davranış
/// profili** vardır ([_Profile]) ve profiller birlikte arayüzün karşılaşacağı
/// bütün durumları üretir: geç giriş, unutulmuş çıkış, öğle arası dört
/// okutma, yarım gün, uzaktan okutma, sınırda konum, hiç gelinmemiş gün ve
/// yurttan ayrılmış öğrencinin eski kayıtları.
///
/// Üretim **belirlenimcidir**: rastgele üreteç gün ve kişi kimliğinden
/// tohumlanır, böylece betik yeniden çalıştırıldığında aynı veri oluşur ve
/// kayıtlar çoğalmaz.
///
/// Gün özeti, o günün okutmalarından hesaplanır — uygulamadaki
/// `SummarizeDay.rebuild` ile aynı kural. Elle uydurulmuş bir özet, ekranda
/// kendi okutmalarıyla çelişen bir demo verirdi.
Future<void> _seedAttendance(List<_SeededPerson> people) async {
  final DateTime today = DateTime.now();
  final List<Future<void> Function()> jobs = <Future<void> Function()>[];
  int events = 0;
  int days = 0;

  for (final _SeededPerson person in people) {
    for (int back = _historyDays - 1; back >= 0; back--) {
      final DateTime day = DateTime(
        today.year,
        today.month,
        today.day,
      ).subtract(Duration(days: back));

      // İşten ayrılmış personelin ayrıldığı günden sonrası boştur.
      if (person.leftDaysAgo != null && back < person.leftDaysAgo!) continue;

      final List<_Punch> punches = _punchesFor(person, day, back);
      if (punches.isEmpty) continue;

      final String dateKey = _dateKey(day);

      for (final _Punch punch in punches) {
        jobs.add(
          () => _writeEvent(
            id: '${person.uid}-$dateKey-${punch.index}',
            userId: person.uid,
            userName: person.name,
            dateKey: dateKey,
            type: punch.isEntry ? 'in' : 'out',
            at: punch.at,
            checkpointId: punch.isEntry ? 'giris' : 'cikis',
            checkpointName: punch.isEntry
                ? 'Ana Giriş Turnikesi'
                : 'Çıkış Kapısı',
            code: punch.isEntry ? '1' : '2',
            verdict: punch.verdict,
            distance: punch.distance,
          ),
        );
        events++;
      }

      jobs.add(() => _writeDaySummary(person, dateKey, punches));
      days++;
    }
  }

  await _runAll(jobs);
  stdout.writeln('  Devam kayıtları hazır ($events okutma, $days gün özeti)');
}

/// Bir öğrencinin bir gündeki okutmaları — profiline göre.
List<_Punch> _punchesFor(_SeededPerson person, DateTime day, int back) {
  final bool weekend =
      day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;

  // Tohum: kişi + gün. Aynı betik çalıştırması aynı veriyi üretir.
  final Random random = Random(
    person.uid.hashCode ^ (day.year * 10000 + day.month * 100 + day.day),
  );

  if (weekend) {
    // Hafta sonu yalnız nöbetçi profili çalışır ve ayda birkaç kez.
    if (person.profile != _Profile.weekendDuty || random.nextInt(3) != 0) {
      return const <_Punch>[];
    }
  }

  if (person.profile == _Profile.partTime &&
      day.weekday != DateTime.monday &&
      day.weekday != DateTime.wednesday &&
      day.weekday != DateTime.friday) {
    return const <_Punch>[];
  }

  // Hiç gelinmemiş günler: devamsız profil daha sık, herkes ara sıra.
  final int absentChance = switch (person.profile) {
    _Profile.absentee => 4,
    _Profile.partTime => 20,
    _ => 16,
  };
  if (!weekend && random.nextInt(absentChance) == 0) return const <_Punch>[];

  // Devamsız profilin ortasında üç günlük kesintisiz bir boşluk (rapor).
  if (person.profile == _Profile.absentee && back >= 12 && back <= 14) {
    return const <_Punch>[];
  }

  final bool late = switch (person.profile) {
    _Profile.oftenLate => random.nextInt(10) < 4,
    _Profile.punctual => false,
    _ => random.nextInt(14) == 0,
  };

  final int startHour = switch (person.profile) {
    _Profile.earlyShift => 6,
    _ => 8,
  };
  final int startMinute = switch (person.profile) {
    _Profile.earlyShift => 25 + random.nextInt(10),
    _ => late ? 46 + random.nextInt(40) : 18 + random.nextInt(12),
  };

  final DateTime entry = DateTime(
    day.year,
    day.month,
    day.day,
    startHour + (startMinute >= 60 ? 1 : 0),
    startMinute % 60,
  );

  // Bugün mesai sürüyor: son okutma giriştir, kişi hâlâ içeridedir.
  final bool stillInside = back == 0 && DateTime.now().hour < 18;

  final int workedHours = switch (person.profile) {
    _Profile.partTime => 5,
    _Profile.earlyShift => 9,
    _ => 9,
  };
  final DateTime exit = entry.add(
    Duration(hours: workedHours, minutes: random.nextInt(25)),
  );

  // Konum kararı: uyarılı profil ara sıra dışarıda ya da sınırda okutur.
  final (String verdict, double distance) = switch (person.profile) {
    _Profile.locationIssues when random.nextInt(6) == 0 => (
      'outside',
      3200 + random.nextInt(2600).toDouble(),
    ),
    _Profile.locationIssues when random.nextInt(5) == 0 => (
      'borderline',
      95 + random.nextInt(60).toDouble(),
    ),
    _ when random.nextInt(30) == 0 => (
      'borderline',
      88 + random.nextInt(40).toDouble(),
    ),
    _ => ('verified', 9 + random.nextInt(40).toDouble()),
  };

  final List<_Punch> punches = <_Punch>[
    _Punch(
      index: 0,
      at: entry,
      isEntry: true,
      verdict: verdict,
      distance: distance,
    ),
  ];

  // Öğle arası: çıkıp geri gelen profil dört okutma yapar.
  if (person.profile == _Profile.splitDay && !stillInside) {
    final DateTime lunchOut = DateTime(day.year, day.month, day.day, 12, 30);
    final DateTime lunchIn = lunchOut.add(
      Duration(minutes: 40 + random.nextInt(25)),
    );
    punches
      ..add(
        _Punch(
          index: 1,
          at: lunchOut,
          isEntry: false,
          verdict: 'verified',
          distance: 14,
        ),
      )
      ..add(
        _Punch(
          index: 2,
          at: lunchIn,
          isEntry: true,
          verdict: 'verified',
          distance: 16,
        ),
      );
  }

  // Çıkışı unutmak: bu profilde sık, diğerlerinde nadir.
  final bool forgetsExit = switch (person.profile) {
    _Profile.forgetsExit => random.nextInt(4) == 0,
    _ => random.nextInt(22) == 0,
  };

  if (!stillInside && !forgetsExit) {
    punches.add(
      _Punch(
        index: punches.length,
        at: exit,
        isEntry: false,
        verdict: 'verified',
        distance: 12 + random.nextInt(30).toDouble(),
      ),
    );
  }

  return punches;
}

/// Gün özetini okutmalardan hesaplar.
Future<void> _writeDaySummary(
  _SeededPerson person,
  String dateKey,
  List<_Punch> punches,
) async {
  DateTime? firstEntry;
  DateTime? lastEntry;
  DateTime? lastExit;
  int entryCount = 0;
  int exitCount = 0;
  int worked = 0;
  DateTime? openSince;
  String worst = 'verified';

  const Map<String, int> severity = <String, int>{
    'verified': 0,
    'borderline': 1,
    'unavailable': 2,
    'outside': 3,
  };

  for (final _Punch punch in punches) {
    if ((severity[punch.verdict] ?? 0) > (severity[worst] ?? 0)) {
      worst = punch.verdict;
    }

    if (punch.isEntry) {
      entryCount++;
      firstEntry ??= punch.at;
      lastEntry = punch.at;
      openSince = punch.at;
    } else {
      exitCount++;
      lastExit = punch.at;
      if (openSince != null) {
        final int minutes = punch.at.difference(openSince).inMinutes;
        if (minutes > 0) worked += minutes;
        openSince = null;
      }
    }
  }

  final bool open = openSince != null;
  final bool late = punches.any(
    (_Punch punch) =>
        punch.isEntry && (punch.at.hour * 60 + punch.at.minute) > 23 * 60,
  );

  await _patch(
    'tenants/$demoTenantId/attendanceDays/${person.uid}_$dateKey',
    <String, Object?>{
      'tenantId': _str(demoTenantId),
      'userId': _str(person.uid),
      'userName': _str(person.name),
      'dateKey': _str(dateKey),
      if (firstEntry != null) 'firstEntryAt': _time(firstEntry),
      if (lastEntry != null) 'lastEntryAt': _time(lastEntry),
      if (lastExit != null) 'lastExitAt': _time(lastExit),
      'entryCount': _int(entryCount),
      'exitCount': _int(exitCount),
      'workedMinutes': _int(worked),
      'open': _bool(open),
      'late': _bool(late),
      'worstVerdict': _str(worst),
      'updatedAt': _time(DateTime.now()),
    },
  );
}

/// İşleri sınırlı eşzamanlılıkla çalıştırır.
///
/// Bin küçük REST çağrısını sırayla yapmak dakikalar sürer; hepsini birden
/// açmak da bağlantı havuzunu boğar ve 429 aldırır. Onarlı gruplar ikisinin
/// arasındaki tatlı noktadır.
Future<void> _runAll(List<Future<void> Function()> jobs) async {
  const int batch = 10;
  for (int i = 0; i < jobs.length; i += batch) {
    final int end = i + batch > jobs.length ? jobs.length : i + batch;
    await Future.wait<void>(<Future<void>>[
      for (int j = i; j < end; j++) jobs[j](),
    ]);
    stdout.write('\r  Yazılıyor... $end/${jobs.length}');
  }
  stdout.write('\r');
}

Future<void> _writeEvent({
  required String id,
  required String userId,
  required String userName,
  required String dateKey,
  required String type,
  required DateTime at,
  required String checkpointId,
  required String checkpointName,
  required String code,
  required String verdict,
  required double distance,
}) async {
  await _patch('tenants/$demoTenantId/attendance/$id', <String, Object?>{
    'tenantId': _str(demoTenantId),
    'userId': _str(userId),
    'userName': _str(userName),
    'type': _str(type),
    'at': _time(at),
    'dateKey': _str(dateKey),
    'checkpointId': _str(checkpointId),
    'checkpointName': _str(checkpointName),
    'checkpointCode': _str(code),
    'verdict': _str(verdict),
    'distanceMeters': _double(distance),
    'radiusMeters': _int(75),
    'location': _map(<String, Object?>{
      'latitude': _double(verdict == 'outside' ? 41.045 : _baseLat + 0.0001),
      'longitude': _double(verdict == 'outside' ? 28.96 : _baseLon + 0.0001),
      'accuracy': _double(verdict == 'outside' ? 35 : 12),
      'capturedAt': _time(at),
    }),
  });
}

/// Örnek müşterinin bir alt koleksiyonunu tümüyle siler.
///
/// Yalnız `turgev-demo` altında çalışır; yol dışarıdan verilmez ki
/// betik yanlışlıkla gerçek bir müşterinin kayıtlarına dokunamasın.
Future<void> _wipeCollection(String collection) async {
  int deleted = 0;
  String? pageToken;

  do {
    final Map<String, Object?> page = await _get(
      'tenants/$demoTenantId/$collection',
      query: <String, String>{
        'pageSize': '300',
        // Alanlara ihtiyaç yok; yalnız belge adları okunacak.
        'mask.fieldPaths': '_none_',
        if (pageToken != null) 'pageToken': pageToken,
      },
    );

    final Object? documents = page['documents'];
    if (documents is List) {
      final List<Future<void> Function()> jobs = <Future<void> Function()>[
        for (final Object? doc in documents)
          if (doc is Map && doc['name'] is String)
            () => _deleteByName(doc['name']! as String),
      ];
      await _runAll(jobs);
      deleted += jobs.length;
    }

    final Object? next = page['nextPageToken'];
    pageToken = next is String && next.isNotEmpty ? next : null;
  } while (pageToken != null);

  if (deleted > 0) {
    stdout.writeln('  Eski kayıtlar silindi: $collection ($deleted belge)');
  }
}

Future<Map<String, Object?>> _get(
  String path, {
  Map<String, String> query = const <String, String>{},
}) async {
  final HttpClient client = HttpClient();
  try {
    final Uri uri = Uri.parse(
      '$firestoreBase/$path',
    ).replace(queryParameters: query);
    final HttpClientRequest request = await client.getUrl(uri);
    request.headers
      ..set(HttpHeaders.authorizationHeader, 'Bearer $token')
      ..set('x-goog-user-project', projectId);

    final HttpClientResponse response = await request.close();
    final String body = await response.transform(utf8.decoder).join();

    if (response.statusCode >= 400) {
      stderr.writeln('Okuma başarısız ($path): ${response.statusCode}\n$body');
      exit(70);
    }
    return jsonDecode(body) as Map<String, Object?>;
  } finally {
    client.close();
  }
}

/// Tam belge adıyla siler (`projects/.../documents/tenants/...`).
Future<void> _deleteByName(String name) async {
  final HttpClient client = HttpClient();
  try {
    final Uri uri = Uri.parse('https://firestore.googleapis.com/v1/$name');
    final HttpClientRequest request = await client.deleteUrl(uri);
    request.headers
      ..set(HttpHeaders.authorizationHeader, 'Bearer $token')
      ..set('x-goog-user-project', projectId);

    final HttpClientResponse response = await request.close();
    final String body = await response.transform(utf8.decoder).join();

    if (response.statusCode >= 400) {
      stderr.writeln('Silme başarısız ($name): ${response.statusCode}\n$body');
      exit(70);
    }
  } finally {
    client.close();
  }
}

// ─────────────────────────── REST yardımcıları ───────────────────────────

Future<Map<String, Object?>> _patch(
  String path,
  Map<String, Object?> fields,
) async {
  final HttpClient client = HttpClient();
  try {
    final Uri uri = Uri.parse('$firestoreBase/$path');
    final HttpClientRequest request = await client.patchUrl(uri);
    request.headers
      ..set(HttpHeaders.authorizationHeader, 'Bearer $token')
      ..set(HttpHeaders.contentTypeHeader, 'application/json; charset=utf-8')
      ..set('x-goog-user-project', projectId);

    // Gövde BAYT olarak yazılır. `request.write` dizeyi latin1 ile kodlar ve
    // "TÜRGEV Demo" gibi bir metin "Contains invalid characters" ile
    // patlar.
    request.add(utf8.encode(jsonEncode(<String, Object?>{'fields': fields})));

    final HttpClientResponse response = await request.close();
    final String body = await response.transform(utf8.decoder).join();

    if (response.statusCode >= 400) {
      stderr.writeln('Yazma başarısız ($path): ${response.statusCode}\n$body');
      exit(70);
    }
    return jsonDecode(body) as Map<String, Object?>;
  } finally {
    client.close();
  }
}

Future<Map<String, Object?>> _post(
  String url,
  Map<String, Object?> payload, {
  bool allowFailure = false,
}) async {
  final HttpClient client = HttpClient();
  try {
    final HttpClientRequest request = await client.postUrl(Uri.parse(url));
    // Kota projesi başlığı ŞART: `gcloud auth print-access-token` ile alınan
    // kullanıcı kimliği hiçbir projeye bağlı değildir ve Identity Toolkit
    // "SERVICE_DISABLED / quota project is not set" diyerek reddeder.
    request.headers
      ..set(HttpHeaders.authorizationHeader, 'Bearer $token')
      ..set(HttpHeaders.contentTypeHeader, 'application/json; charset=utf-8')
      ..set('x-goog-user-project', projectId);
    request.add(utf8.encode(jsonEncode(payload)));

    final HttpClientResponse response = await request.close();
    final String body = await response.transform(utf8.decoder).join();

    if (response.statusCode >= 400) {
      if (allowFailure) return <String, Object?>{};
      stderr.writeln('İstek başarısız ($url): ${response.statusCode}\n$body');
      exit(70);
    }
    return jsonDecode(body) as Map<String, Object?>;
  } finally {
    client.close();
  }
}

// Firestore REST tip sarmalayıcıları.
Map<String, Object?> _str(String value) => <String, Object?>{
  'stringValue': value,
};
Map<String, Object?> _int(int value) => <String, Object?>{
  'integerValue': '$value',
};
Map<String, Object?> _double(double value) => <String, Object?>{
  'doubleValue': value,
};
Map<String, Object?> _bool(bool value) => <String, Object?>{
  'booleanValue': value,
};
Map<String, Object?> _time(DateTime value) => <String, Object?>{
  'timestampValue': value.toUtc().toIso8601String(),
};
Map<String, Object?> _map(Map<String, Object?> fields) => <String, Object?>{
  'mapValue': <String, Object?>{'fields': fields},
};

String _dateKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
