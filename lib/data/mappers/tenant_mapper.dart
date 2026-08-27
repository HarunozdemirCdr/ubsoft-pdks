import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ubsoft_pdks/core/config/app_config.dart';
import 'package:ubsoft_pdks/data/mappers/firestore_converters.dart';
import 'package:ubsoft_pdks/domain/entities/tenant.dart';
import 'package:ubsoft_pdks/domain/enums/tenant_status.dart';

/// `tenants/{tid}` ↔ [Tenant].
abstract final class TenantMapper {
  static Tenant fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      fromMap(doc.data() ?? <String, dynamic>{}, id: doc.id);

  static Tenant fromMap(Map<String, dynamic> data, {required String id}) {
    final Map<String, dynamic> sub = data.nested('subscription');
    final Map<String, dynamic> settings = data.nested('settings');
    final Map<String, dynamic> counters = data.nested('counters');
    final SubscriptionPlan plan = SubscriptionPlan.fromKey(
      sub.strOrNull('plan'),
    );

    return Tenant(
      id: id,
      name: data.str('name'),
      slug: data.str('slug'),
      timezone: data.str('timezone', fallback: AppConfig.defaultTimezone),
      locale: data.str('locale', fallback: AppConfig.defaultLocale),
      status: TenantStatus.fromKey(data.strOrNull('status')),
      subscription: Subscription(
        plan: plan,
        startsAt: sub.dateTime('startsAt'),
        // Süre alanı okunamıyorsa hesap **kapalı** sayılır, açık değil.
        // Bozuk bir kaydın sonsuz erişim vermesi, para kapısındaki en pahalı
        // varsayılan olurdu.
        expiresAt:
            sub.dateTimeOrNull('expiresAt') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        maxUsers: sub.integer('maxUsers', fallback: plan.maxUsers),
        maxCheckpoints: sub.integer(
          'maxCheckpoints',
          fallback: plan.maxCheckpoints,
        ),
      ),
      settings: TenantSettings(
        defaultRadiusMeters: settings.integer(
          'defaultRadiusMeters',
          fallback: AppConfig.defaultRadiusMeters,
        ),
        requireLocation: settings.boolean('requireLocation', fallback: true),
        blockOutsideScans: settings.boolean('blockOutsideScans'),
        workStartMinutes: settings.integer(
          'workStartMinutes',
          fallback: AppConfig.defaultWorkStartMinutes,
        ),
        workEndMinutes: settings.integer(
          'workEndMinutes',
          fallback: AppConfig.defaultWorkEndMinutes,
        ),
        lateToleranceMinutes: settings.integer(
          'lateToleranceMinutes',
          fallback: AppConfig.defaultLateToleranceMinutes,
        ),
      ),
      counters: TenantCounters(
        userCount: counters.integer('userCount'),
        checkpointCount: counters.integer('checkpointCount'),
      ),
      createdAt: data.dateTime('createdAt'),
      updatedAt: data.dateTimeOrNull('updatedAt'),
      createdBy: data.strOrNull('createdBy'),
    );
  }

  static Map<String, Object?> toCreateMap(Tenant tenant) => <String, Object?>{
    'name': tenant.name.trim(),
    'slug': tenant.slug.trim(),
    'timezone': tenant.timezone,
    'locale': tenant.locale,
    'status': tenant.status.key,
    'subscription': subscriptionMap(tenant.subscription),
    'settings': settingsMap(tenant.settings),
    'counters': <String, Object?>{'userCount': 0, 'checkpointCount': 0},
    'createdAt': FirestoreWrite.serverTime,
    'updatedAt': FirestoreWrite.serverTime,
    if (tenant.createdBy != null) 'createdBy': tenant.createdBy,
  };

  static Map<String, Object?> subscriptionMap(Subscription value) =>
      <String, Object?>{
        'plan': value.plan.key,
        'startsAt': Timestamp.fromDate(value.startsAt),
        'expiresAt': Timestamp.fromDate(value.expiresAt),
        'maxUsers': value.maxUsers,
        'maxCheckpoints': value.maxCheckpoints,
      };

  static Map<String, Object?> settingsMap(TenantSettings value) =>
      <String, Object?>{
        'defaultRadiusMeters': value.defaultRadiusMeters,
        'requireLocation': value.requireLocation,
        'blockOutsideScans': value.blockOutsideScans,
        'workStartMinutes': value.workStartMinutes,
        'workEndMinutes': value.workEndMinutes,
        'lateToleranceMinutes': value.lateToleranceMinutes,
      };
}
