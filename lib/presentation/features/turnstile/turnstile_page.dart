import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubsoft_pdks/application/auth/session_provider.dart';
import 'package:ubsoft_pdks/application/checkpoint/checkpoint_providers.dart';
import 'package:ubsoft_pdks/application/turnstile/turnstile_providers.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_card.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_scaffold.dart';

class TurnstilePage extends ConsumerStatefulWidget {
  const TurnstilePage({super.key});
  @override
  ConsumerState<TurnstilePage> createState() => _TurnstilePageState();
}

class _TurnstilePageState extends ConsumerState<TurnstilePage> {
  final _id = TextEditingController();
  Map<String, String>? _draft;
  Map<String, dynamic>? _status;
  bool _busy = false;
  String? _message;
  bool _error = false;
  @override
  void dispose() {
    _id.dispose();
    super.dispose();
  }

  Future<void> _run(String name, [Map<String, dynamic> data = const {}]) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final result = await turnstileCall(ref, name, data);
      if (!mounted) return;
      setState(() {
        _error = false;
        if (name == 'getTurnstileStatus') {
          _status = result;
        } else {
          _message = 'Ayarlar kaydedildi.';
          _draft = null;
          _status = null;
        }
      });
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        setState(() {
          _error = true;
          _message = e.message ?? 'İşlem tamamlanamadı.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = true;
          _message =
              'Bağlantı kurulamadı. İnternetinizi kontrol edip yeniden deneyin.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user?.role.isAdmin != true) {
      return const AppScaffold(
        title: 'Turnike kartı',
        body: Text('Bu bölümü yurt yöneticisi yönetir.'),
      );
    }
    final state = ref.watch(turnstileStateProvider);
    final points = ref.watch(checkpointsProvider);
    return AppScaffold(
      title: 'Turnike kartı',
      scrollable: true,
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            const Text('Kart ayarları alınamadı. Sayfayı yeniden açın.'),
        data: (config) {
          final paired = config['paired'] == true;
          final enabled = config['enabled'] == true;
          final relays =
              _draft ??
              Map<String, String>.from(config['relays'] as Map? ?? {});
          final available =
              points.asData?.value
                  .where((p) => p.active && ['in', 'out'].contains(p.kind.key))
                  .toList() ??
              [];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          paired
                              ? Icons.memory_rounded
                              : Icons.bluetooth_rounded,
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            paired ? 'Kart yurda bağlı' : 'Kartı yurda bağla',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      paired
                          ? 'Kart kimliği: ${config['deviceId']}'
                          : 'Önce kartın Bluetooth kurulumundan Wi-Fi bilgilerini kaydedin. Kart internete bağlandıktan sonra ekranda gösterilen kimliğini buraya girin.',
                    ),
                    const SizedBox(height: 12),
                    if (!paired) ...[
                      const Text(
                        'Yurt ataması kalıcıdır. Kimliği kartınızdan kontrol ederek girin.',
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _id,
                        enabled: !_busy,
                        maxLength: 32,
                        decoration: const InputDecoration(
                          labelText: 'Kart kimliği',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _run('bindTurnstileDevice', {
                                'deviceId': _id.text.trim().toLowerCase(),
                              }),
                        icon: const Icon(Icons.link),
                        label: const Text('Bu yurda bağla'),
                      ),
                    ] else ...[
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Turnike tetikleme etkin'),
                        subtitle: const Text(
                          'Kapalıyken QR hareket kaydı tutulur; röle çalıştırılmaz.',
                        ),
                        value: enabled,
                        onChanged: _busy
                            ? null
                            : (v) =>
                                  _run('setTurnstileEnabled', {'enabled': v}),
                      ),
                      if (_status != null)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            _status!['online'] == true
                                ? Icons.wifi
                                : Icons.wifi_off,
                            color: _status!['online'] == true
                                ? Colors.green
                                : Colors.orange,
                          ),
                          title: Text(
                            _status!['online'] == true
                                ? 'Kart çevrimiçi'
                                : 'Kart çevrimdışı',
                          ),
                          subtitle: Text(
                            _status!['lastSeen'] is num
                                ? 'Son bağlantı: ${DateTime.fromMillisecondsSinceEpoch((_status!['lastSeen'] as num).toInt()).toLocal()}\n${_status!['firmware']}'
                                : 'Henüz bağlantı bilgisi yok.',
                          ),
                        ),
                      OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _run('getTurnstileStatus'),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Bağlantıyı kontrol et'),
                      ),
                    ],
                  ],
                ),
              ),
              if (paired) ...[
                const SizedBox(height: 16),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'QR ve röle eşlemesi',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Kullanacağınız rölelere giriş veya çıkış noktası seçin. Kullanılmayanları boş bırakın. Bir QR yalnız bir röleyi çalıştırır. Her tetik 1 saniyedir.',
                      ),
                      const SizedBox(height: 16),
                      if (points.isLoading) const LinearProgressIndicator(),
                      if (points.hasError)
                        const Text('QR noktaları yüklenemedi.'),
                      for (var i = 1; i <= 8; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: DropdownButtonFormField<String>(
                            key: ValueKey(
                              '$i:${relays[i.toString()]}:${available.map((p) => p.id).join()}',
                            ),
                            initialValue:
                                available.any(
                                  (p) => p.id == relays[i.toString()],
                                )
                                ? relays[i.toString()]
                                : '',
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Röle $i · GPIO ${relayPins[i - 1]}',
                              border: const OutlineInputBorder(),
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: '',
                                child: Text('Kullanılmıyor'),
                              ),
                              for (final p in available)
                                DropdownMenuItem(
                                  value: p.id,
                                  child: Text(
                                    '${p.name} · ${p.kind.label}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged:
                                _busy || points.isLoading || points.hasError
                                ? null
                                : (value) => setState(() {
                                    _draft = {...relays};
                                    if (value == null || value.isEmpty) {
                                      _draft!.remove(i.toString());
                                    } else {
                                      _draft![i.toString()] = value;
                                    }
                                  }),
                          ),
                        ),
                      FilledButton.icon(
                        onPressed:
                            _busy ||
                                _draft == null ||
                                points.isLoading ||
                                points.hasError
                            ? null
                            : () => _run('saveTurnstileRelays', {
                                'relays': relays,
                              }),
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Eşlemeyi kaydet'),
                      ),
                    ],
                  ),
                ),
              ],
              if (_busy)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: LinearProgressIndicator(),
                ),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _message!,
                    style: TextStyle(
                      color: _error
                          ? Theme.of(context).colorScheme.error
                          : Colors.green,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              const Text(
                'Kartın röle yanıtı fiziksel geçişi doğrulamaz. Turnike sensörü olmayan kurulumlarda geçişi görevli kontrol eder.',
              ),
            ],
          );
        },
      ),
    );
  }
}
