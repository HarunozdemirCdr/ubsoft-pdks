import 'package:flutter_test/flutter_test.dart';
import 'package:ubsoft_pdks/core/config/app_config.dart';
import 'package:ubsoft_pdks/core/utils/geo.dart';
import 'package:ubsoft_pdks/core/utils/qr_code.dart';
import 'package:ubsoft_pdks/core/utils/validators.dart';

void main() {
  group('Geo.distanceMeters', () {
    test('aynı nokta sıfır mesafe verir', () {
      expect(
        Geo.distanceMeters(lat1: 41.0, lon1: 29.0, lat2: 41.0, lon2: 29.0),
        0,
      );
    });

    test('bir derece enlem yaklaşık 111 km', () {
      final double distance = Geo.distanceMeters(
        lat1: 41,
        lon1: 29,
        lat2: 42,
        lon2: 29,
      );
      expect(distance, closeTo(111195, 500));
    });

    test('kısa mesafeler metre hassasiyetinde', () {
      // 100 metre kuzey.
      final double distance = Geo.distanceMeters(
        lat1: 41.081944,
        lon1: 29.010556,
        lat2: 41.081944 + 100 / 111320.0,
        lon2: 29.010556,
      );
      expect(distance, closeTo(100, 1));
    });

    test('yön fark etmez', () {
      final double ab = Geo.distanceMeters(
        lat1: 41,
        lon1: 29,
        lat2: 41.01,
        lon2: 29.01,
      );
      final double ba = Geo.distanceMeters(
        lat1: 41.01,
        lon1: 29.01,
        lat2: 41,
        lon2: 29,
      );
      expect(ab, closeTo(ba, 0.001));
    });

    test('İstanbul–Ankara arası bilinen değere yakın', () {
      final double distance = Geo.distanceMeters(
        lat1: 41.0082,
        lon1: 28.9784,
        lat2: 39.9334,
        lon2: 32.8597,
      );
      // Kuş uçuşu yaklaşık 350 km.
      expect(distance / 1000, closeTo(350, 10));
    });
  });

  group('Geo.isValidCoordinate', () {
    test('geçerli koordinat kabul edilir', () {
      expect(Geo.isValidCoordinate(41.0, 29.0), isTrue);
      expect(Geo.isValidCoordinate(-33.8, 151.2), isTrue);
    });

    test('sıfır noktası "girilmemiş" sayılır', () {
      // (0, 0) Gine Körfezi'ndedir; boş form kaydedildiğinde oraya bir
      // nokta kurulmasın diye geçersiz kabul edilir.
      expect(Geo.isValidCoordinate(0, 0), isFalse);
    });

    test('aralık dışı değerler reddedilir', () {
      expect(Geo.isValidCoordinate(91, 29), isFalse);
      expect(Geo.isValidCoordinate(41, 181), isFalse);
      expect(Geo.isValidCoordinate(null, 29), isFalse);
      expect(Geo.isValidCoordinate(double.nan, 29), isFalse);
    });
  });

  group('Geo.formatDistance', () {
    test('metre ve kilometre biçimleri', () {
      expect(Geo.formatDistance(18.4), '18 m');
      expect(Geo.formatDistance(999), '999 m');
      expect(Geo.formatDistance(2400), '2,4 km');
    });

    test('geçersiz değer tire verir', () {
      expect(Geo.formatDistance(double.nan), '—');
      expect(Geo.formatDistance(double.infinity), '—');
    });
  });

  group('QrCode', () {
    test('boşluk ve satır sonu temizlenir', () {
      expect(QrCode.normalize('  42 \n'), '42');
      expect(QrCode.normalize('kod: 7'), '7');
    });

    test('geçerli kodlar kabul edilir', () {
      expect(QrCode.isValid('1'), isTrue);
      expect(QrCode.isValid('1234567890'), isTrue);
    });

    test('boş, uzun ya da harf içeren kod reddedilir', () {
      expect(QrCode.isValid(''), isFalse);
      expect(QrCode.isValid('12345678901'), isFalse);
      expect(QrCode.isValid('12a'), isFalse);
    });

    test('kural güvenlik kurallarındaki regex ile aynı sınırı kullanır', () {
      // firestore.rules: ^[0-9]{1,10}$
      expect(AppConfig.qrCodeMaxLength, 10);
      final RegExp rules = RegExp(r'^[0-9]{1,10}$');
      for (final String code in <String>['1', '99', '1234567890']) {
        expect(QrCode.isValid(code), rules.hasMatch(code));
      }
      for (final String code in <String>['', '12345678901', 'abc']) {
        expect(QrCode.isValid(code), rules.hasMatch(code));
      }
    });

    test('başka bir sistemin QR içeriği reddedilir', () {
      // Rakam içeren bir URL normalize edilince rakamları kalır; uzunluk
      // sınırı bunu yakalar.
      final String normalized = QrCode.normalize(
        'https://ornek.com/kapi/123456789012',
      );
      expect(QrCode.isValid(normalized), isFalse);
    });
  });

  group('Validators.parseCoordinate', () {
    test('nokta ve virgül ayırıcısı kabul edilir', () {
      expect(Validators.parseCoordinate('41.0819'), closeTo(41.0819, 1e-9));
      expect(Validators.parseCoordinate('41,0819'), closeTo(41.0819, 1e-9));
    });

    test('boş ve bozuk girdi null döner', () {
      expect(Validators.parseCoordinate(''), isNull);
      expect(Validators.parseCoordinate('kuzey'), isNull);
    });

    test('enlem ve boylam aralıkları denetlenir', () {
      expect(Validators.latitude('41,08'), isNull);
      expect(Validators.latitude('95'), isNotNull);
      expect(Validators.longitude('181'), isNotNull);
      expect(Validators.longitude(''), isNotNull);
    });
  });
}
