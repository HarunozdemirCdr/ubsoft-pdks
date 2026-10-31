import 'package:flutter_test/flutter_test.dart';
import 'package:ubsoft_pdks/application/attendance/attendance_providers.dart';
import 'package:ubsoft_pdks/application/report/report_providers.dart';
import 'package:ubsoft_pdks/application/user/user_providers.dart';
import 'package:ubsoft_pdks/core/utils/date_x.dart';
import 'package:ubsoft_pdks/domain/entities/app_user.dart';
import 'package:ubsoft_pdks/domain/entities/attendance_day.dart';
import 'package:ubsoft_pdks/domain/entities/report_filter.dart';
import 'package:ubsoft_pdks/domain/enums/day_status.dart';
import 'package:ubsoft_pdks/domain/enums/location_verdict.dart';
import 'package:ubsoft_pdks/domain/enums/report_focus.dart';
import 'package:ubsoft_pdks/domain/enums/user_role.dart';

import '../support/test_harness.dart';

AttendanceDay _day({
  required String userId,
  required String userName,
  required String dateKey,
  int worked = 480,
  bool late = false,
  bool open = false,
  LocationVerdict verdict = LocationVerdict.verified,
}) => AttendanceDay(
  id: AttendanceDay.buildId(userId: userId, dateKey: dateKey),
  tenantId: TestData.tenantId,
  userId: userId,
  userName: userName,
  dateKey: dateKey,
  firstEntryAt: DateTime.parse('${dateKey}T08:30:00'),
  lastEntryAt: DateTime.parse('${dateKey}T08:30:00'),
  lastExitAt: open ? null : DateTime.parse('${dateKey}T17:30:00'),
  entryCount: 1,
  exitCount: open ? 0 : 1,
  workedMinutes: worked,
  open: open,
  late: late,
  worstVerdict: verdict,
);

void main() {
  group('buildReport — kişi denklemi', () {
    final ReportFilter filter = ReportFilter(
      from: DateTime(2026, 8, 24),
      to: DateTime(2026, 8, 26),
    );

    final List<AppUser> roster = <AppUser>[
      TestData.user(uid: 'u1'),
      TestData.user(uid: 'u2', name: 'Mehmet Demir'),
    ];

    test('gelinen ve gelinmeyen günler kadrodan hesaplanır', () {
      final ReportResult report = buildReport(
        filter: filter,
        days: <AttendanceDay>[
          _day(userId: 'u1', userName: 'Ahmet Yılmaz', dateKey: '2026-08-24'),
          _day(userId: 'u1', userName: 'Ahmet Yılmaz', dateKey: '2026-08-25'),
        ],
        roster: roster,
      );

      expect(report.rows.length, 2);

      final ReportRow ahmet = report.rows.firstWhere(
        (ReportRow row) => row.userId == 'u1',
      );
      expect(ahmet.presentDays, 2);
      expect(ahmet.absentDays, 1);
      expect(ahmet.workedMinutes, 960);

      // Hiç kaydı olmayan öğrenci raporda SIFIR satırıyla görünür; yoksa
      // hiç gelmeyen kişi görünmez olurdu.
      final ReportRow mehmet = report.rows.firstWhere(
        (ReportRow row) => row.userId == 'u2',
      );
      expect(mehmet.presentDays, 0);
      expect(mehmet.absentDays, 3);
    });

    test('günlük ortalama gelinen günlere bölünür', () {
      final ReportResult report = buildReport(
        filter: filter,
        days: <AttendanceDay>[
          _day(
            userId: 'u1',
            userName: 'Ahmet Yılmaz',
            dateKey: '2026-08-24',
            worked: 400,
          ),
          _day(
            userId: 'u1',
            userName: 'Ahmet Yılmaz',
            dateKey: '2026-08-25',
            worked: 500,
          ),
        ],
        roster: <AppUser>[roster.first],
      );

      expect(report.rows.single.averageMinutes, 450);
    });

    test('geç giriş ve konum uyarısı sayılır', () {
      final ReportResult report = buildReport(
        filter: filter,
        days: <AttendanceDay>[
          _day(
            userId: 'u1',
            userName: 'Ahmet Yılmaz',
            dateKey: '2026-08-24',
            late: true,
          ),
          _day(
            userId: 'u1',
            userName: 'Ahmet Yılmaz',
            dateKey: '2026-08-25',
            verdict: LocationVerdict.outside,
          ),
        ],
        roster: <AppUser>[roster.first],
      );

      final ReportRow row = report.rows.single;
      expect(row.lateDays, 1);
      expect(row.flaggedDays, 1);
      expect(row.hasProblem, isTrue);
    });

    test('kadrodan çıkmış öğrencinin geçmişi raporda kalır', () {
      // İşten ayrılan biri raporun kapsadığı günlerde çalışmışsa, o günler
      // rapordan silinmemeli.
      final ReportResult report = buildReport(
        filter: filter,
        days: <AttendanceDay>[
          _day(userId: 'eski', userName: 'Ayrılan Kişi', dateKey: '2026-08-24'),
        ],
        roster: roster,
      );

      expect(report.rows.length, 3);
      expect(report.rows.any((ReportRow row) => row.userId == 'eski'), isTrue);
    });

    test('gün süzgeci eşleşmeyen öğrenciyi tümüyle eler', () {
      final ReportResult report = buildReport(
        filter: ReportFilter(
          from: DateTime(2026, 8, 24),
          to: DateTime(2026, 8, 24),
          focus: ReportFocus.lateArrival,
        ),
        days: <AttendanceDay>[
          _day(userId: 'u1', userName: 'Ahmet Yılmaz', dateKey: '2026-08-24'),
          _day(
            userId: 'u2',
            userName: 'Mehmet Demir',
            dateKey: '2026-08-24',
            late: true,
          ),
        ],
        roster: roster,
      );

      expect(report.rows.length, 1);
      expect(report.rows.single.userId, 'u2');
    });

    test('toplam süre satırların toplamıdır', () {
      final ReportResult report = buildReport(
        filter: filter,
        days: <AttendanceDay>[
          _day(
            userId: 'u1',
            userName: 'Ahmet Yılmaz',
            dateKey: '2026-08-24',
            worked: 300,
          ),
          _day(
            userId: 'u2',
            userName: 'Mehmet Demir',
            dateKey: '2026-08-24',
            worked: 200,
          ),
        ],
        roster: roster,
      );

      expect(report.totalMinutes, 500);
    });

    test('satırlar ada göre sıralanır', () {
      final ReportResult report = buildReport(
        filter: filter,
        days: const <AttendanceDay>[],
        roster: <AppUser>[
          TestData.user(uid: 'z', name: 'Zeynep Kaya'),
          TestData.user(uid: 'a', name: 'Ali Vural'),
        ],
      );

      expect(report.rows.map((ReportRow row) => row.userName), <String>[
        'Ali Vural',
        'Zeynep Kaya',
      ]);
    });
  });

  group('buildReport — gün dökümü', () {
    final ReportFilter range = ReportFilter(
      from: DateTime(2026, 8, 24),
      to: DateTime(2026, 8, 26),
    );

    final List<AppUser> roster = <AppUser>[
      TestData.user(uid: 'u1', note: 'Oda / öğrenim notu'),
    ];

    test('günler eskiden yeniye sıralanır', () {
      final ReportResult report = buildReport(
        filter: range,
        days: <AttendanceDay>[
          _day(userId: 'u1', userName: 'Ahmet Yılmaz', dateKey: '2026-08-26'),
          _day(userId: 'u1', userName: 'Ahmet Yılmaz', dateKey: '2026-08-24'),
        ],
        roster: roster,
      );

      expect(
        report.rows.single.days.map((AttendanceDay day) => day.dateKey),
        <String>['2026-08-24', '2026-08-26'],
      );
    });

    test('öğrencinin açıklaması satıra taşınır', () {
      final ReportResult report = buildReport(
        filter: range,
        days: const <AttendanceDay>[],
        roster: roster,
      );

      expect(report.rows.single.userNote, 'Oda / öğrenim notu');
    });

    test('süzgeç günleri eler ama toplamlar aralığın tamamından gelir', () {
      final ReportResult report = buildReport(
        filter: range.copyWith(focus: ReportFocus.lateArrival),
        days: <AttendanceDay>[
          _day(
            userId: 'u1',
            userName: 'Ahmet Yılmaz',
            dateKey: '2026-08-24',
            worked: 300,
          ),
          _day(
            userId: 'u1',
            userName: 'Ahmet Yılmaz',
            dateKey: '2026-08-25',
            worked: 200,
            late: true,
          ),
        ],
        roster: roster,
      );

      final ReportRow row = report.rows.single;

      // Listelenen tek gün geç gelinen gündür…
      expect(row.matchedDays, 1);
      expect(row.days.single.dateKey, '2026-08-25');

      // …ama kişinin toplamı iki günün tamamıdır.
      expect(row.presentDays, 2);
      expect(row.workedMinutes, 500);
    });

    test('gelmediği gün süzgeci kaydı olmayan günleri üretir', () {
      final ReportResult report = buildReport(
        filter: range.copyWith(focus: ReportFocus.absent),
        days: <AttendanceDay>[
          _day(userId: 'u1', userName: 'Ahmet Yılmaz', dateKey: '2026-08-25'),
        ],
        roster: roster,
      );

      final ReportRow row = report.rows.single;
      expect(row.days.map((AttendanceDay day) => day.dateKey), <String>[
        '2026-08-24',
        '2026-08-26',
      ]);
      expect(row.days.every((AttendanceDay day) => day.isEmpty), isTrue);
    });

    test('gelmediği gün süzgeci dışında boş günler üretilmez', () {
      final ReportResult report = buildReport(
        filter: range,
        days: <AttendanceDay>[
          _day(userId: 'u1', userName: 'Ahmet Yılmaz', dateKey: '2026-08-25'),
        ],
        roster: roster,
      );

      expect(report.rows.single.days.length, 1);
    });

    test('çıkışı okutulmamış gün ancak süre dolunca eşleşir', () {
      final AttendanceDay open = _day(
        userId: 'u1',
        userName: 'Ahmet Yılmaz',
        dateKey: '2026-08-24',
        open: true,
      );

      // Girişin üstünden bir gün geçmiş: artık "içeride" değil, "çıkış yok".
      final ReportResult late = buildReport(
        filter: range.copyWith(focus: ReportFocus.missingExit),
        days: <AttendanceDay>[open],
        roster: roster,
        now: DateTime(2026, 8, 25, 12),
      );
      expect(late.rows.single.matchedDays, 1);

      // Aynı gün öğlen bakıldığında kişi hâlâ içeridedir; uyarı doğmaz.
      final ReportResult sameDay = buildReport(
        filter: range.copyWith(focus: ReportFocus.missingExit),
        days: <AttendanceDay>[open],
        roster: roster,
        now: DateTime(2026, 8, 24, 12),
      );
      expect(sameDay.rows, isEmpty);
    });

    test('rapordaki toplam gün satırı sayısı listelenenleri sayar', () {
      final ReportResult report = buildReport(
        filter: range,
        days: <AttendanceDay>[
          _day(userId: 'u1', userName: 'Ahmet Yılmaz', dateKey: '2026-08-24'),
          _day(userId: 'u1', userName: 'Ahmet Yılmaz', dateKey: '2026-08-25'),
        ],
        roster: roster,
      );

      expect(report.totalDayRows, 2);
    });
  });

  group('ReportFilter', () {
    test('tek gün aralığı bir gün sayar', () {
      final ReportFilter filter = ReportFilter.today();
      expect(filter.dayCount, 1);
      expect(filter.isSingleDay, isTrue);
      expect(filter.dayKeys.length, 1);
    });

    test('son N gün kapsayıcıdır', () {
      final ReportFilter filter = ReportFilter.lastDays(7);
      expect(filter.dayCount, 7);
      expect(filter.dayKeys.length, 7);
      expect(filter.dayKeys.last, AppDate.todayKey());
    });

    test('gün anahtarları sıralıdır', () {
      final ReportFilter filter = ReportFilter(
        from: DateTime(2026, 8, 24),
        to: DateTime(2026, 8, 26),
      );
      expect(filter.dayKeys, <String>[
        '2026-08-24',
        '2026-08-25',
        '2026-08-26',
      ]);
    });

    test('kullanıcı süzgeci temizlenebilir', () {
      final ReportFilter filter = ReportFilter.today().copyWith(userId: 'u1');
      expect(filter.userId, 'u1');
      expect(filter.copyWith(clearUser: true).userId, isNull);
    });

    test('odak süzgeci kimliğin parçasıdır', () {
      final ReportFilter all = ReportFilter.today();
      expect(all.focus, ReportFocus.all);
      expect(all.copyWith(focus: ReportFocus.flagged) == all, isFalse);
    });
  });

  group('Günlük tablo — kadrodan kurulur', () {
    late TestScope scope;

    setUp(() async {
      scope = await buildScope(
        signedInAs: TestData.user(
          uid: TestData.adminUid,
          name: 'Mustafa Özdemir',
          role: UserRole.admin,
        ),
        extraUsers: <AppUser>[
          TestData.user(uid: 'u1'),
          TestData.user(uid: 'u2', name: 'Mehmet Demir'),
        ],
      );
      // Kadro ve gün kayıtları canlı tutulur: dinleyicisi kalmayan bir
      // sağlayıcı Riverpod 3'te hemen atılır ve liste boş görünür.
      scope
        ..retain(scope.container.listen(usersProvider, (_, _) {}))
        ..retain(
          scope.container.listen(
            daySummariesProvider(AppDate.todayKey()),
            (_, _) {},
          ),
        );
      await flush();
    });

    tearDown(() => scope.dispose());

    test('hiç okutma yokken herkes "gelmedi" satırıyla görünür', () {
      final List<AttendanceDay> rows = scope.container.read(
        dayRosterProvider(AppDate.todayKey()),
      );

      expect(rows.length, 3);
      expect(
        rows.every(
          (AttendanceDay day) =>
              day.statusAt(DateTime.now()) == DayStatus.absent,
        ),
        isTrue,
      );
    });

    test('gün özeti kadro büyüklüğünü raporlar', () {
      final DayOverview overview = scope.container.read(
        dayOverviewProvider(AppDate.todayKey()),
      );

      expect(overview.total, 3);
      expect(overview.absent, 3);
      expect(overview.inside, 0);
      expect(overview.completed, 0);
    });

    test('bir gün en fazla bir kez işaretlenir', () async {
      // Hem çıkışı eksik hem konumu şüpheli bir gün, kartta iki kişi gibi
      // görünmemeli.
      await scope.firestore
          .collection('tenants')
          .doc(TestData.tenantId)
          .collection('attendanceDays')
          .doc('u1_${AppDate.todayKey()}')
          .set(<String, Object?>{
            'tenantId': TestData.tenantId,
            'userId': 'u1',
            'userName': 'Ahmet Yılmaz',
            'dateKey': AppDate.todayKey(),
            'entryCount': 1,
            'exitCount': 0,
            'workedMinutes': 0,
            'open': true,
            'late': true,
            'worstVerdict': 'outside',
            'firstEntryAt': DateTime.now().subtract(const Duration(hours: 20)),
            'lastEntryAt': DateTime.now().subtract(const Duration(hours: 20)),
          });
      await flush();

      final DayOverview overview = scope.container.read(
        dayOverviewProvider(AppDate.todayKey()),
      );

      expect(overview.flagged, 1);
      expect(overview.late, 1);
      expect(overview.absent, 2);
    });
  });
}
