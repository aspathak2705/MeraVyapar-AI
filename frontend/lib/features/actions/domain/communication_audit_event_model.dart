class CommunicationAuditEvent {
  final String id;
  final String communicationActionId;
  final String eventType;
  final String? previousStatus;
  final String newStatus;
  final String actorType;
  final Map<String, dynamic> metadataInfo;
  final DateTime occurredAt;

  CommunicationAuditEvent({
    required this.id,
    required this.communicationActionId,
    required this.eventType,
    this.previousStatus,
    required this.newStatus,
    required this.actorType,
    required this.metadataInfo,
    required this.occurredAt,
  });

  factory CommunicationAuditEvent.fromJson(Map<String, dynamic> json) {
    return CommunicationAuditEvent(
      id: json['id'] as String,
      communicationActionId: json['communication_action_id'] as String,
      eventType: json['event_type'] as String,
      previousStatus: json['previous_status'] as String?,
      newStatus: json['new_status'] as String,
      actorType: json['actor_type'] as String? ?? 'MERCHANT',
      metadataInfo: (json['metadata_info'] as Map<String, dynamic>?) ?? {},
      occurredAt: DateTime.parse(json['occurred_at'] as String),
    );
  }
}
