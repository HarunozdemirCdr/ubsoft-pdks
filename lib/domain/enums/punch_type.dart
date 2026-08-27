/// Bir okutmanın ne anlama geldiği.
///
/// Personel geldiğinde giriş QR'ını, çıkarken çıkış QR'ını okutur. Yön
/// okutmanın kendisinden gelir; uygulamanın tahmin etmesine gerek yoktur.
enum PunchType {
  entry('in', 'Giriş'),
  exit('out', 'Çıkış');

  const PunchType(this.key, this.label);

  final String key;
  final String label;

  static PunchType fromKey(String? key) =>
      key == 'out' ? PunchType.exit : PunchType.entry;

  bool get isEntry => this == PunchType.entry;
  bool get isExit => this == PunchType.exit;

  PunchType get opposite =>
      this == PunchType.entry ? PunchType.exit : PunchType.entry;
}

/// Bir QR noktasının ne için asıldığı.
///
/// [both] tek bir etiketin hem giriş hem çıkış için kullanıldığı küçük
/// işyerleri içindir: o noktada yön, personelin o anki durumundan çözülür
/// (içeride değilse giriş, içerideyse çıkış).
enum CheckpointKind {
  entry('in', 'Giriş noktası'),
  exit('out', 'Çıkış noktası'),
  both('both', 'Giriş + Çıkış');

  const CheckpointKind(this.key, this.label);

  final String key;
  final String label;

  static CheckpointKind fromKey(String? key) => switch (key) {
    'out' => CheckpointKind.exit,
    'both' => CheckpointKind.both,
    _ => CheckpointKind.entry,
  };

  bool get isBoth => this == CheckpointKind.both;

  /// Noktanın sabit yönü; [both] için yön okutma anında çözülür.
  PunchType? get fixedType => switch (this) {
    CheckpointKind.entry => PunchType.entry,
    CheckpointKind.exit => PunchType.exit,
    CheckpointKind.both => null,
  };
}
