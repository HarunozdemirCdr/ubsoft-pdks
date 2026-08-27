import 'package:flutter_test/flutter_test.dart';
import 'package:ubsoft_pdks/core/config/app_config.dart';
import 'package:ubsoft_pdks/domain/entities/checkpoint.dart';
import 'package:ubsoft_pdks/domain/entities/scan_location.dart';
import 'package:ubsoft_pdks/domain/enums/location_verdict.dart';
import 'package:ubsoft_pdks/domain/usecases/attendance/verify_location.dart';

import '../support/test_harness.dart';

/// Konum doğrulaması — ürünün asıl vaadi.
///
/// "Adam noktanın yanında mı okuttu, yoksa etiketin fotoğrafını çekip evden
/// mi?" sorusunun cevabı buradaki kurallardır; bu yüzden sınır durumlarının
/// hepsi tek tek kilitlenir.
void main() {
  group('VerifyLocation', () {
    final Checkpoint checkpoint = TestData.checkpoint();

    test('yarıçap içindeki okutma doğrulanmış sayılır', () {
      final LocationCheck check = VerifyLocation.call(
        checkpoint: checkpoint,
        location: TestData.locationNorthOf(20),
      );

      expect(check.verdict, LocationVerdict.verified);
      expect(check.distanceMeters, closeTo(20, 1));
      expect(check.radiusMeters, 75);
    });

    test('tam yarıçap üzerindeki okutma hâlâ doğrulanmıştır', () {
      final LocationCheck check = VerifyLocation.call(
        checkpoint: checkpoint,
        location: TestData.locationNorthOf(75),
      );

      // Sınır kapsayıcıdır: 75 metre "yarıçap içi" demektir. Aksi hâlde
      // etiketin tam kenarında duran biri rastgele reddedilirdi.
      expect(check.verdict, LocationVerdict.verified);
    });

    test('yarıçabın hemen dışı, ölçüm hatası payı içindeyse sınırdadır', () {
      final LocationCheck check = VerifyLocation.call(
        checkpoint: checkpoint,
        // 100 m uzakta ama cihaz ±40 m hata bildiriyor: 75 + 40 = 115 > 100.
        location: TestData.locationNorthOf(100, accuracy: 40),
      );

      expect(check.verdict, LocationVerdict.borderline);
    });

    test('hata payı da yetmiyorsa nokta dışıdır', () {
      final LocationCheck check = VerifyLocation.call(
        checkpoint: checkpoint,
        location: TestData.locationNorthOf(100, accuracy: 5),
      );

      expect(check.verdict, LocationVerdict.outside);
      expect(check.distanceMeters, closeTo(100, 2));
    });

    test('kilometrelerce uzaktan okutma nokta dışıdır', () {
      final LocationCheck check = VerifyLocation.call(
        checkpoint: checkpoint,
        location: TestData.locationNorthOf(5000, accuracy: 20),
      );

      expect(check.verdict, LocationVerdict.outside);
    });

    test('abartılı hata payı sınırlanır — evden okutma sınırda sayılmaz', () {
      // Tarayıcı bazen IP tabanlı, kilometrelerce hatalı konum bildirir.
      // Pay sınırsız olsaydı bu okutma "sınırda" sayılır ve doğrulama
      // tümüyle anlamsızlaşırdı.
      final LocationCheck check = VerifyLocation.call(
        checkpoint: checkpoint,
        location: TestData.locationNorthOf(3000, accuracy: 5000),
      );

      expect(check.verdict, LocationVerdict.outside);
      expect(AppConfig.maxAccuracySlackMeters, lessThan(3000));
    });

    test('hata payı tam sınırda kabul edilir', () {
      final LocationCheck check = VerifyLocation.call(
        checkpoint: checkpoint,
        // 75 + 150 (üst sınır) = 225 metre.
        location: TestData.locationNorthOf(225, accuracy: 400),
      );

      expect(check.verdict, LocationVerdict.borderline);
    });

    test('konum yoksa sonuç "konum yok" olur', () {
      final LocationCheck check = VerifyLocation.call(
        checkpoint: checkpoint,
        location: null,
      );

      expect(check.verdict, LocationVerdict.unavailable);
      expect(check.distanceMeters, isNull);
    });

    test('noktanın koordinatı girilmemişse doğrulama yapılmaz', () {
      final LocationCheck check = VerifyLocation.call(
        checkpoint: TestData.checkpoint(latitude: 0, longitude: 0),
        location: TestData.locationNorthOf(10),
      );

      expect(check.verdict, LocationVerdict.unavailable);
    });

    test('geçersiz koordinat ölçümü yok sayılır', () {
      final LocationCheck check = VerifyLocation.call(
        checkpoint: checkpoint,
        location: const ScanLocation(latitude: 0, longitude: 0),
      );

      expect(check.verdict, LocationVerdict.unavailable);
    });

    test('küçük yarıçap dar bir alan tanımlar', () {
      final LocationCheck check = VerifyLocation.call(
        checkpoint: TestData.checkpoint(radiusMeters: 10),
        location: TestData.locationNorthOf(25, accuracy: 0),
      );

      expect(check.verdict, LocationVerdict.outside);
    });
  });

  group('LocationVerdict', () {
    test('en kötü sonuç doğru seçilir', () {
      expect(
        LocationVerdict.verified.worst(LocationVerdict.outside),
        LocationVerdict.outside,
      );
      expect(
        LocationVerdict.outside.worst(LocationVerdict.verified),
        LocationVerdict.outside,
      );
      expect(
        LocationVerdict.unavailable.worst(LocationVerdict.borderline),
        LocationVerdict.borderline,
      );
      expect(
        LocationVerdict.verified.worst(LocationVerdict.verified),
        LocationVerdict.verified,
      );
    });

    test('yalnız doğrulanmış sonuç dikkat istemez', () {
      for (final LocationVerdict verdict in LocationVerdict.values) {
        expect(
          verdict.needsAttention,
          verdict != LocationVerdict.verified,
          reason: '${verdict.key} için yanlış',
        );
      }
    });

    test('bilinmeyen anahtar güvenli tarafa düşer', () {
      expect(LocationVerdict.fromKey('sacma'), LocationVerdict.unavailable);
      expect(LocationVerdict.fromKey(null), LocationVerdict.unavailable);
    });
  });
}
