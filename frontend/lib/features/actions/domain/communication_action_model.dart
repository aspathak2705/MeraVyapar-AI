enum ActionType {
  paymentReminder,
  paymentRequest,
  followUpNote;

  String toServerString() {
    switch (this) {
      case ActionType.paymentReminder:
        return 'PAYMENT_REMINDER';
      case ActionType.paymentRequest:
        return 'PAYMENT_REQUEST';
      case ActionType.followUpNote:
        return 'FOLLOW_UP_NOTE';
    }
  }

  static ActionType fromString(String val) {
    switch (val.toUpperCase()) {
      case 'PAYMENT_REMINDER':
        return ActionType.paymentReminder;
      case 'PAYMENT_REQUEST':
        return ActionType.paymentRequest;
      case 'FOLLOW_UP_NOTE':
        return ActionType.followUpNote;
      default:
        return ActionType.paymentReminder;
    }
  }
}

enum CommunicationChannel {
  whatsApp,
  sms,
  email,
  manual;

  String toServerString() {
    switch (this) {
      case CommunicationChannel.whatsApp:
        return 'WHATSAPP';
      case CommunicationChannel.sms:
        return 'SMS';
      case CommunicationChannel.email:
        return 'EMAIL';
      case CommunicationChannel.manual:
        return 'MANUAL';
    }
  }

  static CommunicationChannel fromString(String val) {
    switch (val.toUpperCase()) {
      case 'WHATSAPP':
        return CommunicationChannel.whatsApp;
      case 'SMS':
        return CommunicationChannel.sms;
      case 'EMAIL':
        return CommunicationChannel.email;
      default:
        return CommunicationChannel.manual;
    }
  }
}

enum ActionStatus {
  draft,
  readyForReview,
  confirmedByMerchant,
  dispatchRequested,
  sent,
  failed,
  cancelled;

  static ActionStatus fromString(String val) {
    switch (val.toUpperCase()) {
      case 'DRAFT':
        return ActionStatus.draft;
      case 'READY_FOR_REVIEW':
        return ActionStatus.readyForReview;
      case 'CONFIRMED_BY_MERCHANT':
        return ActionStatus.confirmedByMerchant;
      case 'DISPATCH_REQUESTED':
        return ActionStatus.dispatchRequested;
      case 'SENT':
        return ActionStatus.sent;
      case 'FAILED':
        return ActionStatus.failed;
      case 'CANCELLED':
        return ActionStatus.cancelled;
      default:
        return ActionStatus.draft;
    }
  }

  String toDisplayString() {
    switch (this) {
      case ActionStatus.draft:
        return 'Draft';
      case ActionStatus.readyForReview:
        return 'Ready for Review';
      case ActionStatus.confirmedByMerchant:
        return 'Confirmed';
      case ActionStatus.dispatchRequested:
        return 'Dispatch Requested';
      case ActionStatus.sent:
        return 'Sent';
      case ActionStatus.failed:
        return 'Failed';
      case ActionStatus.cancelled:
        return 'Cancelled';
    }
  }
}

class CommunicationAction {
  final String id;
  final String merchantId;
  final ActionType actionType;
  final CommunicationChannel channel;
  final ActionStatus status;
  final String draftContent;
  final String? finalContent;
  final String? targetEntityId;
  final String? targetEntityType;
  final String? promiseId;
  final String idempotencyKey;
  final String? providerMessageId;
  final String? providerName;
  final String? deliveryMode;
  final bool externalDeliveryConfirmed;
  final String? errorCode;
  final String? errorMessage;
  final DateTime? confirmedAt;
  final DateTime? sentAt;
  final DateTime createdAt;

  CommunicationAction({
    required this.id,
    required this.merchantId,
    required this.actionType,
    required this.channel,
    required this.status,
    required this.draftContent,
    this.finalContent,
    this.targetEntityId,
    this.targetEntityType,
    this.promiseId,
    required this.idempotencyKey,
    this.providerMessageId,
    this.providerName,
    this.deliveryMode,
    this.externalDeliveryConfirmed = false,
    this.errorCode,
    this.errorMessage,
    this.confirmedAt,
    this.sentAt,
    required this.createdAt,
  });

  factory CommunicationAction.fromJson(Map<String, dynamic> json) {
    return CommunicationAction(
      id: json['id'] as String,
      merchantId: json['merchant_id'] as String,
      actionType: ActionType.fromString(json['action_type'] as String),
      channel: CommunicationChannel.fromString(json['channel'] as String),
      status: ActionStatus.fromString(json['status'] as String),
      draftContent: json['draft_content'] as String,
      finalContent: json['final_content'] as String?,
      targetEntityId: json['target_entity_id'] as String?,
      targetEntityType: json['target_entity_type'] as String?,
      promiseId: json['promise_id'] as String?,
      idempotencyKey: json['idempotency_key'] as String? ?? '',
      providerMessageId: json['provider_message_id'] as String?,
      providerName: json['provider_name'] as String?,
      deliveryMode: json['delivery_mode'] as String?,
      externalDeliveryConfirmed: json['external_delivery_confirmed'] as bool? ?? false,
      errorCode: json['error_code'] as String?,
      errorMessage: json['error_message'] as String?,
      confirmedAt: json['confirmed_at'] != null ? DateTime.parse(json['confirmed_at'] as String) : null,
      sentAt: json['sent_at'] != null ? DateTime.parse(json['sent_at'] as String) : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
