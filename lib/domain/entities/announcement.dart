import 'package:equatable/equatable.dart';
import 'package:ubsoft_pdks/domain/entities/app_user.dart';

/// Yurt duyurusu — genel, kat bazlı veya oda bazlı hedeflenebilir.
class DormAnnouncement extends Equatable {
  const DormAnnouncement({
    required this.id,
    required this.title,
    required this.body,
    required this.createdBy,
    required this.createdAt,
    this.createdByName = '',
    this.targetType = 'all',
    this.targetValue = '',
    this.priority = 'normal',
  });

  final String id;
  final String title;
  final String body;
  final String createdBy;
  final String createdByName;
  final DateTime createdAt;

  /// `all` (Genel) | `floor` (Kat) | `room` (Oda).
  final String targetType;

  /// Kat numarası (ör. `'2'`) veya oda numarası (ör. `'201'`).
  final String targetValue;

  /// `normal` | `urgent`.
  final String priority;

  bool get isUrgent => priority == 'urgent';

  String get targetLabel => switch (targetType) {
    'floor' => '${targetValue.trim()}. Kat',
    'room' => 'Oda ${targetValue.trim()}',
    _ => 'Genel Duyuru',
  };

  /// Oda numarasından kat numarasını çıkarır (`'201'` -> `'2'`, `'404'` -> `'4'`).
  static String floorOfRoom(String room) {
    final String digits = room.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length >= 3) return digits.substring(0, digits.length - 2);
    if (digits.isNotEmpty) return digits[0];
    return '';
  }

  /// Bu duyuru verilen kullanıcıyı ilgilendiriyor mu?
  bool appliesTo(AppUser user) {
    if (user.role.isAdmin || user.role.isSuperAdmin) return true;
    final String target = targetValue.trim().toLowerCase();
    return switch (targetType) {
      'all' => true,
      'room' =>
        target.isNotEmpty && user.room.trim().toLowerCase() == target,
      'floor' =>
        target.isNotEmpty &&
            floorOfRoom(user.room).toLowerCase() == target,
      _ => true,
    };
  }

  @override
  List<Object?> get props => <Object?>[
    id,
    title,
    body,
    createdBy,
    createdByName,
    createdAt,
    targetType,
    targetValue,
    priority,
  ];
}
