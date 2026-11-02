# macOS ve Windows ortak geliştirme

Bu proje Flutter Web uygulamasıdır. Aynı kaynak kodu macOS ve Windows'ta
çalışır; platforma özel proje kopyası tutulmaz. `pubspec.lock` her iki
bilgisayarda da sürümlenir ve bağımlılık sürümlerini eşit tutar.

## İlk kurulum

Her bilgisayarda Git, Flutter'ın kararlı sürümü ve Chrome kurulu olmalıdır.
Depoyu klonladıktan sonra:

```bash
flutter doctor
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
```

Flutter ve Dart sürümleri `pubspec.yaml` içindeki SDK şartını karşılamalıdır.
Bağımlılık güncellendiğinde `pubspec.yaml` ile `pubspec.lock` aynı commit'te
gönderilir.

## Her çalışmaya başlarken

Yerel değişiklik yokken güncel kodu alın:

```bash
git switch main
git pull --rebase origin main
```

Bir özellik veya düzeltme için kısa ömürlü bir dal açın:

```bash
git switch -c feature/kisa-konu
```

İki bilgisayarda aynı anda çalışılacaksa her bilgisayar farklı dal kullanır.
Aynı dal iki bilgisayarda eşzamanlı değiştirilmez.

## Değişikliği gönderirken

Önce test edin, sonra küçük ve anlamlı bir commit oluşturun:

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
git status
git add <degisen-dosyalar>
git commit -m "feat: kisa aciklama"
```

Uzak depoda arada kalan commit varsa kendi dalınızı güncelleyin:

```bash
git fetch origin
git rebase origin/main
```

Çakışma yoksa dalı gönderin:

```bash
git push -u origin HEAD
```

Dal GitHub üzerinden `main` ile birleştirilir. Tek kişinin yaptığı küçük ve
acil değişikliklerde doğrudan `main` kullanılacaksa göndermeden hemen önce
mutlaka aşağıdaki sıra uygulanır:

```bash
git pull --rebase origin main
git push origin main
```

`--force` veya `--force-with-lease` ile `main` dalı zorlanmaz. Çakışma
çözülmeden ve testler geçmeden gönderim yapılmaz.

## Satır sonları

`.gitattributes` tüm ortak metin dosyalarını LF olarak sabitler. Böylece
Windows'un CRLF satır sonları gereksiz biçimde bütün dosyayı değiştirmiş gibi
göstermez. Windows komut dosyaları (`.bat`, `.cmd`, `.ps1`) istisna olarak
CRLF kullanır. `.editorconfig` destekleyen editörlerde aynı ayarları uygular.
