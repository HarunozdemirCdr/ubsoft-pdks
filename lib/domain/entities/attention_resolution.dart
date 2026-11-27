import 'package:equatable/equatable.dart';

/// Dikkat Edilmesi Gerekenler ekranından yönetici tarafından "Çözüldü" olarak
/// kapatılan bir olayın kalıcı denetim kaydı (log).
///
/// Kapatılan olay aktif uyarı listesinden düşer ancak öğrencinin geçmişinde ve
/// raporlarında çözüm notuyla birlikte kalıcı olarak saklanır.
class AttentionResolution extends Equatable {
  const AttentionResolution({
    required this.id,
    required this.incidentKey,
    required this.userId,
    required this.userName,
    required this.kind,
    required this.title,
    required this.resolutionNote,
    required this.resolvedBy,
    required this.resolvedAt,
    this.room = '',
    this.summary = '',
    this.eventId = '',
    this.dateKey = '',
    this.resolvedByName = '',
  });

  final String id;
  final String incidentKey;
  final String userId;
  final String userName;
  final String room;
  final String kind;
  final String title;
  final String summary;
  final String resolutionNote;
  final String eventId;
  final String dateKey;
  final String resolvedBy;
  final String resolvedByName;
  final DateTime resolvedAt;

  @override
  List<Object?> get props => <Object?>[
    id,
    incidentKey,
    userId,
    userName,
    room,
    kind,
    title,
    summary,
    resolutionNote,
    eventId,
    dateKey,
    resolvedBy,
    resolvedByName,
    resolvedAt,
  ];
}
