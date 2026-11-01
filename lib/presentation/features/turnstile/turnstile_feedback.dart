import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubsoft_pdks/application/providers.dart';
import 'package:ubsoft_pdks/application/turnstile/turnstile_providers.dart';
import 'package:ubsoft_pdks/domain/entities/attendance_event.dart';

class TurnstileFeedback extends ConsumerStatefulWidget {
  const TurnstileFeedback({required this.event, super.key});
  final AttendanceEvent event;
  @override
  ConsumerState<TurnstileFeedback> createState() => _TurnstileFeedbackState();
}

class _TurnstileFeedbackState extends ConsumerState<TurnstileFeedback> {
  late final Timer _timer;
  bool _timedOut = false;
  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 12), () {
      if (mounted) setState(() => _timedOut = true);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(turnstileStateProvider).asData?.value;
    if (config == null ||
        config['paired'] != true ||
        !(config['relays'] as Map? ?? {}).containsValue(
          widget.event.checkpointId,
        )) {
      return const SizedBox.shrink();
    }
    return StreamBuilder(
      stream: ref
          .watch(firestoreProvider)
          .doc('tenants/${widget.event.tenantId}/attendance/${widget.event.id}')
          .snapshots(),
      builder: (context, snapshot) {
        final hardware = snapshot.data?.data()?['turnstile'] as Map?;
        final status = hardware?['status'] as String?;
        final success = status == 'pulse_started';
        final failed =
            snapshot.hasError ||
            (status != null && status != 'queued' && !success) ||
            _timedOut;
        final text = success
            ? 'Röle tetiklendi. Turnikeden geçebilirsiniz.'
            : failed
            ? 'Hareket kaydınız alındı. Karttan açma onayı alınamadı; görevliye başvurun.'
            : 'Hareket kaydınız alındı. Turnike kartının yanıtı bekleniyor…';
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                success
                    ? Icons.check_circle_outline
                    : failed
                    ? Icons.warning_amber_rounded
                    : Icons.hourglass_top,
                color: success ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(text)),
            ],
          ),
        );
      },
    );
  }
}
