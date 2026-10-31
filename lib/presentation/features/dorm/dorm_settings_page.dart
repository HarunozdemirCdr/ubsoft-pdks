import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubsoft_pdks/application/auth/session_provider.dart';
import 'package:ubsoft_pdks/application/settings/settings_providers.dart';
import 'package:ubsoft_pdks/domain/entities/dormitory.dart';
import 'package:ubsoft_pdks/domain/entities/tenant.dart';
import 'package:ubsoft_pdks/domain/permissions/app_permission.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_button.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_card.dart';
import 'package:ubsoft_pdks/presentation/widgets/app_scaffold.dart';
import 'package:ubsoft_pdks/services/notification/toast_service.dart';

class DormSettingsPage extends ConsumerStatefulWidget {
  const DormSettingsPage({super.key});
  @override
  ConsumerState<DormSettingsPage> createState() => _DormSettingsState();
}

class _DormSettingsState extends ConsumerState<DormSettingsPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _radius = TextEditingController();
  final _tolerance = TextEditingController();
  DormHours _hours = const DormHours();
  Map<String, DormHours> _weekdays = {};
  Map<String, DormHours> _exceptions = {};
  bool _location = true;
  bool _block = false;
  bool _seeded = false;
  @override
  void dispose() {
    _name.dispose();
    _radius.dispose();
    _tolerance.dispose();
    super.dispose();
  }

  void _seed(Tenant t) {
    if (_seeded) return;
    _seeded = true;
    final s = t.settings;
    _name.text = t.name;
    _radius.text = '${s.defaultRadiusMeters}';
    _tolerance.text = '${s.dormPolicy.tolerance}';
    _hours = s.dormPolicy.hours;
    _weekdays = {...s.dormPolicy.weekdays};
    _exceptions = {...s.dormPolicy.exceptions};
    _location = s.requireLocation;
    _block = s.blockOutsideScans;
  }

  Future<void> _edit(DormHours current, void Function(DormHours) save) async {
    final value = await showDialog<DormHours>(
      context: context,
      builder: (c) => _HoursDialog(hours: current),
    );
    if (value != null) setState(() => save(value));
  }

  @override
  Widget build(BuildContext context) {
    final tenant = ref.watch(currentTenantProvider);
    if (tenant == null) {
      return const AppScaffold(
        title: 'Yurt Ayarları',
        body: Center(child: CircularProgressIndicator()),
      );
    }
    _seed(tenant);
    final enabled = ref.watch(canProvider(AppPermission.settingsEdit));
    const days = [
      'Pazartesi',
      'Salı',
      'Çarşamba',
      'Perşembe',
      'Cuma',
      'Cumartesi',
      'Pazar',
    ];
    return AppScaffold(
      title: 'Yurt Ayarları',
      scrollable: true,
      bottomBar: enabled
          ? AppButton.primaryWide(
              label: 'Ayarları kaydet',
              isLoading: ref.watch(settingsControllerProvider).isLoading,
              onPressed: _save,
            )
          : null,
      body: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _name,
              enabled: enabled,
              decoration: const InputDecoration(labelText: 'Yurt adı'),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Yurt adı girin.' : null,
            ),
            const SizedBox(height: 20),
            Text(
              'Giriş–çıkış saatleri',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Saatler Türkiye saatidir. Kurallar uyarı üretir; geç veya erken hareketin kaydedilmesini engellemez. Başlangıç saatleri örnektir; yurdunuzun uygulamasına göre düzenleyin.',
            ),
            const SizedBox(height: 12),
            AppCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Genel saatler'),
                subtitle: Text(_label(_hours)),
                trailing: const Icon(Icons.edit_outlined),
                onTap: enabled ? () => _edit(_hours, (v) => _hours = v) : null,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _tolerance,
              enabled: enabled,
              decoration: const InputDecoration(
                labelText: 'Geç dönüş toleransı (dakika)',
              ),
              keyboardType: TextInputType.number,
              validator: (v) {
                final n = int.tryParse(v ?? '');
                return n == null || n < 0 || n > 120
                    ? '0–120 arasında dakika girin.'
                    : null;
              },
            ),
            const SizedBox(height: 20),
            Text(
              'Güne göre kurallar',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Text('Özel saat seçilmeyen günlerde genel kural kullanılır.'),
            for (var i = 1; i <= 7; i++)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(days[i - 1]),
                subtitle: Text(
                  _weekdays['$i'] == null
                      ? 'Genel kural'
                      : _label(_weekdays['$i']!),
                ),
                onTap: enabled
                    ? () => _edit(
                        _weekdays['$i'] ?? _hours,
                        (v) => _weekdays['$i'] = v,
                      )
                    : null,
                trailing: _weekdays['$i'] == null
                    ? const Icon(Icons.edit_outlined)
                    : IconButton(
                        tooltip: 'Genel kurala dön',
                        icon: const Icon(Icons.restore),
                        onPressed: enabled
                            ? () => setState(() => _weekdays.remove('$i'))
                            : null,
                      ),
              ),
            const SizedBox(height: 16),
            Text(
              'Özel tarihler',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            for (final key in (_exceptions.keys.toList()..sort()))
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(key),
                subtitle: Text(_label(_exceptions[key]!)),
                onTap: enabled
                    ? () =>
                          _edit(_exceptions[key]!, (v) => _exceptions[key] = v)
                    : null,
                trailing: IconButton(
                  tooltip: 'İstisnayı kaldır',
                  icon: const Icon(Icons.close),
                  onPressed: enabled
                      ? () => setState(() => _exceptions.remove(key))
                      : null,
                ),
              ),
            if (enabled)
              TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Özel tarih ekle'),
                onPressed: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now().subtract(const Duration(days: 1)),
                    lastDate: DateTime.now().add(const Duration(days: 730)),
                  );
                  if (d == null) return;
                  final key =
                      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
                  await _edit(
                    _exceptions[key] ?? _hours,
                    (v) => _exceptions[key] = v,
                  );
                },
              ),
            const SizedBox(height: 20),
            Text('QR ve konum', style: Theme.of(context).textTheme.titleLarge),
            const Text(
              'Giriş ve çıkış için farklı QR noktaları oluşturun. Aynı kod iki yön için kullanılamaz.',
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _radius,
              enabled: enabled,
              decoration: const InputDecoration(
                labelText: 'Varsayılan konum yarıçapı (metre)',
              ),
              keyboardType: TextInputType.number,
              validator: (v) {
                final n = int.tryParse(v ?? '');
                return n == null || n < 10 || n > 1000
                    ? '10–1000 arasında metre girin.'
                    : null;
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Konum zorunlu olsun'),
              value: _location,
              onChanged: enabled ? (v) => setState(() => _location = v) : null,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Nokta dışındaki okutmaları reddet'),
              subtitle: const Text(
                'Kapalıyken okutma kaydedilir ve konum uyarısıyla işaretlenir.',
              ),
              value: _block,
              onChanged: enabled ? (v) => setState(() => _block = v) : null,
            ),
            const SizedBox(height: 20),
            const Text(
              'Konum yalnız QR okutulurken ölçülür. Öğrencinin sürekli konumu izlenmez.',
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final original = ref.read(currentTenantProvider)!.settings;
    final result = await ref
        .read(settingsControllerProvider.notifier)
        .save(
          name: _name.text,
          settings: original.copyWith(
            defaultRadiusMeters: int.parse(_radius.text),
            requireLocation: _location,
            blockOutsideScans: _block,
            dormPolicy: DormPolicy(
              hours: _hours,
              tolerance: int.parse(_tolerance.text),
              weekdays: _weekdays,
              exceptions: _exceptions,
            ),
          ),
        );
    Toast.result(result, successMessage: 'Yurt kuralları kaydedildi.');
  }
}

String _time(int m) =>
    '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
String _label(DormHours h) => !h.enabled
    ? 'Saat uyarıları kapalı'
    : 'En erken çıkış ${_time(h.earliestExit)} · Son dönüş ${_time(h.latestEntry)}${h.earliestEntry == null ? '' : ' · En erken giriş ${_time(h.earliestEntry!)}'}';

class _HoursDialog extends StatefulWidget {
  const _HoursDialog({required this.hours});
  final DormHours hours;
  @override
  State<_HoursDialog> createState() => _HoursState();
}

class _HoursState extends State<_HoursDialog> {
  late int _exit;
  late int _entry;
  int? _first;
  late bool _enabled;
  @override
  void initState() {
    super.initState();
    _exit = widget.hours.earliestExit;
    _entry = widget.hours.latestEntry;
    _first = widget.hours.earliestEntry;
    _enabled = widget.hours.enabled;
  }

  Future<void> _pick(int value, void Function(int) assign) async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: value ~/ 60, minute: value % 60),
    );
    if (t != null) setState(() => assign(t.hour * 60 + t.minute));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Saat kuralı'),
    content: SizedBox(
      width: 430,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Saat uyarıları etkin'),
              value: _enabled,
              onChanged: (v) => setState(() => _enabled = v),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('En erken çıkış'),
              trailing: Text(_time(_exit)),
              onTap: () => _pick(_exit, (v) => _exit = v),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('En geç dönüş'),
              trailing: Text(_time(_entry)),
              onTap: () => _pick(_entry, (v) => _entry = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('En erken giriş kuralı da kullan'),
              value: _first != null,
              onChanged: (v) => setState(() => _first = v ? 360 : null),
            ),
            if (_first != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('En erken giriş'),
                trailing: Text(_time(_first!)),
                onTap: () => _pick(_first!, (v) => _first = v),
              ),
            const Text(
              'Son dönüş gece yarısından sonraysa o akşamın devamı olarak değerlendirilir.',
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Vazgeç'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(
          context,
          DormHours(
            earliestExit: _exit,
            latestEntry: _entry,
            earliestEntry: _first,
            enabled: _enabled,
          ),
        ),
        child: const Text('Uygula'),
      ),
    ],
  );
}
