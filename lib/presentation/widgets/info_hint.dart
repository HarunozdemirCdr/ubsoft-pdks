import 'package:flutter/material.dart';

/// Bir ayarın ne işe yaradığını açıklayan küçük bilgi düğmesi.
///
/// Uzun açıklamalar dar ekranda alanın altına sığmayıp "…" ile kesiliyordu.
/// Onun yerine sade bir bilgi ikonu durur; dokununca tam açıklama bir pencerede
/// görünür. Böylece arayüz sade kalır ama isteyen ayrıntıyı okuyabilir.
class InfoHintButton extends StatelessWidget {
  const InfoHintButton({
    required this.title,
    required this.message,
    this.compact = false,
    super.key,
  });

  final String title;
  final String message;

  /// Alan içi (suffix) kullanımda ikonu biraz küçültür.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.info_outline_rounded, size: compact ? 20 : 22),
      tooltip: 'Bilgi',
      visualDensity: compact ? VisualDensity.compact : null,
      onPressed: () => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Anladım'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Satır içi bilgi notu — bir formun ya da ayarın yanındaki uyarı.
///
/// Kendi rengi ya da ikonu yoktur; mevcut yüzey ve metin token'larını
/// kullanır. Amaç dikkat çekmek değil, okunduğunda bir soruyu kapatmaktır.
class InfoNote extends StatelessWidget {
  const InfoNote({required this.message, this.icon, super.key});

  final String message;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            icon ?? Icons.info_outline_rounded,
            size: 18,
            color: colors.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
