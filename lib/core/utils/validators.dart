import 'package:ubsoft_pdks/core/config/app_config.dart';

/// Form doğrulayıcıları.
///
/// Tümü Flutter `TextFormField.validator` imzasına uyar: geçerliyse `null`,
/// geçersizse Türkçe hata metni döner.
abstract final class Validators {
  static final RegExp _email = RegExp(
    r'^[\w.!#$%&’*+/=?^`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?'
    r'(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$',
  );
  static final RegExp _digitsOnly = RegExp(r'^[0-9]+$');
  static final RegExp _phone = RegExp(r'^[0-9\s()+-]{10,20}$');

  /// Zorunlu alan.
  static String? required(String? value, {String field = 'Bu alan'}) {
    if (value == null || value.trim().isEmpty) return '$field zorunludur.';
    return null;
  }

  static String? email(String? value) {
    final String v = value?.trim() ?? '';
    if (v.isEmpty) return 'E-posta adresi zorunludur.';
    if (!_email.hasMatch(v)) return 'Geçerli bir e-posta adresi girin.';
    return null;
  }

  static String? password(String? value, {int minLength = 6}) {
    final String v = value ?? '';
    if (v.isEmpty) return 'Şifre zorunludur.';
    if (v.length < minLength) return 'Şifre en az $minLength karakter olmalı.';
    return null;
  }

  static String? passwordConfirm(String? value, String original) {
    if (value != original) return 'Şifreler eşleşmiyor.';
    return null;
  }

  /// QR nokta kodu — serbest, basit sayısal numara (1, 2, 3…).
  static String? qrCode(String? value) {
    final String v = value?.trim() ?? '';
    if (v.isEmpty) return 'QR kodu zorunludur.';
    if (!_digitsOnly.hasMatch(v)) return 'Kod yalnızca rakamlardan oluşmalı.';
    if (v.length > AppConfig.qrCodeMaxLength) {
      return 'Kod en fazla ${AppConfig.qrCodeMaxLength} haneli olabilir.';
    }
    return null;
  }

  static String? phone(String? value, {bool isRequired = false}) {
    final String v = value?.trim() ?? '';
    if (v.isEmpty) return isRequired ? 'Telefon numarası zorunludur.' : null;
    if (!_phone.hasMatch(v)) return 'Geçerli bir telefon numarası girin.';
    return null;
  }

  /// Metin uzunluğu sınırı.
  static String? maxLength(String? value, int max, {String field = 'Bu alan'}) {
    if (value != null && value.trim().length > max) {
      return '$field en fazla $max karakter olabilir.';
    }
    return null;
  }

  /// Pozitif tam sayı (yarıçap, dakika, limit).
  static String? positiveInt(
    String? value, {
    String field = 'Bu alan',
    int min = 1,
    int? max,
  }) {
    final String v = value?.trim() ?? '';
    if (v.isEmpty) return '$field zorunludur.';
    final int? parsed = int.tryParse(v);
    if (parsed == null) return '$field sayı olmalıdır.';
    if (parsed < min) return '$field en az $min olmalıdır.';
    if (max != null && parsed > max) return '$field en fazla $max olabilir.';
    return null;
  }

  /// Coğrafi enlem.
  ///
  /// Ondalık ayırıcı olarak hem nokta hem virgül kabul edilir: yönetici
  /// koordinatı bir haritadan kopyalayıp yapıştırdığında hangi biçimde
  /// geleceği belli olmaz.
  static String? latitude(String? value) =>
      _coordinate(value, min: -90, max: 90, field: 'Enlem');

  /// Coğrafi boylam.
  static String? longitude(String? value) =>
      _coordinate(value, min: -180, max: 180, field: 'Boylam');

  /// Koordinat metnini sayıya çevirir; geçersizse `null`.
  static double? parseCoordinate(String? value) {
    final String v = (value ?? '').trim().replaceAll(',', '.');
    if (v.isEmpty) return null;
    return double.tryParse(v);
  }

  static String? _coordinate(
    String? value, {
    required double min,
    required double max,
    required String field,
  }) {
    final String v = (value ?? '').trim();
    if (v.isEmpty) return '$field zorunludur.';

    final double? parsed = parseCoordinate(v);
    if (parsed == null) return '$field bir sayı olmalıdır.';
    if (parsed < min || parsed > max) {
      return '$field $min ile $max arasında olmalıdır.';
    }
    return null;
  }

  /// Birden fazla doğrulayıcıyı sırayla uygular; ilk hatayı döner.
  static String? Function(String?) combine(
    List<String? Function(String?)> validators,
  ) {
    return (String? value) {
      for (final String? Function(String?) validator in validators) {
        final String? error = validator(value);
        if (error != null) return error;
      }
      return null;
    };
  }
}
