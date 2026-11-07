class VoiceStatusModel {
  final String sttProvider;
  final String ttsProvider;
  final bool sttConfigured;
  final bool ttsConfigured;
  final String defaultLanguage;
  final String defaultVoice;
  final List<String> supportedLanguages;

  const VoiceStatusModel({
    required this.sttProvider,
    required this.ttsProvider,
    required this.sttConfigured,
    required this.ttsConfigured,
    required this.defaultLanguage,
    required this.defaultVoice,
    required this.supportedLanguages,
  });

  factory VoiceStatusModel.fromJson(Map<String, dynamic> json) {
    return VoiceStatusModel(
      sttProvider: json['stt_provider'] as String? ?? 'Gnani Prisma',
      ttsProvider: json['tts_provider'] as String? ?? 'Gnani Timbre',
      sttConfigured: json['stt_configured'] as bool? ?? false,
      ttsConfigured: json['tts_configured'] as bool? ?? false,
      defaultLanguage: json['default_language'] as String? ?? 'hi-IN',
      defaultVoice: json['default_voice'] as String? ?? 'Nalini',
      supportedLanguages: (json['supported_languages'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const ['hi-IN', 'mr-IN', 'en-IN'],
    );
  }
}

class VoiceCandidateActionModel {
  final String actionType;
  final String promiseId;
  final String counterpartyName;
  final String amount;
  final String channel;
  final String endpoint;

  const VoiceCandidateActionModel({
    required this.actionType,
    required this.promiseId,
    required this.counterpartyName,
    required this.amount,
    required this.channel,
    required this.endpoint,
  });

  factory VoiceCandidateActionModel.fromJson(Map<String, dynamic> json) {
    return VoiceCandidateActionModel(
      actionType: json['action_type'] as String? ?? '',
      promiseId: json['promise_id'] as String? ?? '',
      counterpartyName: json['counterparty_name'] as String? ?? '',
      amount: json['amount'] as String? ?? '',
      channel: json['channel'] as String? ?? 'WHATSAPP',
      endpoint: json['endpoint'] as String? ?? '/api/v1/actions/draft-reminder',
    );
  }

  Map<String, dynamic> toJson() => {
        'action_type': actionType,
        'promise_id': promiseId,
        'counterparty_name': counterpartyName,
        'amount': amount,
        'channel': channel,
        'endpoint': endpoint,
      };
}

class VoiceInteractionModel {
  final bool success;
  final String transcript;
  final String languageCode;
  final String intent;
  final String responseText;
  final bool confirmationRequired;
  final VoiceCandidateActionModel? candidateAction;
  final String? audioBase64;
  final String ttsStatus;
  final Map<String, dynamic> metadata;

  const VoiceInteractionModel({
    required this.success,
    required this.transcript,
    required this.languageCode,
    required this.intent,
    required this.responseText,
    required this.confirmationRequired,
    this.candidateAction,
    this.audioBase64,
    required this.ttsStatus,
    this.metadata = const {},
  });

  factory VoiceInteractionModel.fromJson(Map<String, dynamic> json) {
    return VoiceInteractionModel(
      success: json['success'] as bool? ?? false,
      transcript: json['transcript'] as String? ?? '',
      languageCode: json['language_code'] as String? ?? 'hi-IN',
      intent: json['intent'] as String? ?? 'UNKNOWN',
      responseText: json['response_text'] as String? ?? '',
      confirmationRequired: json['confirmation_required'] as bool? ?? false,
      candidateAction: json['candidate_action'] != null
          ? VoiceCandidateActionModel.fromJson(
              json['candidate_action'] as Map<String, dynamic>)
          : null,
      audioBase64: json['audio_base64'] as String?,
      ttsStatus: json['tts_status'] as String? ?? 'NOT_REQUESTED',
      metadata: json['metadata'] as Map<String, dynamic>? ?? const {},
    );
  }
}
