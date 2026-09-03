import 'package:flutter/material.dart';
import '../domain/capture_setting_model.dart';

class CaptureSettingsScreen extends StatelessWidget {
  final String title;
  final String sourceType; // 'NOTIFICATION_CAPTURE' or 'SMS_CAPTURE'
  final List<CaptureSourceSettingModel> settings;
  final Function(String provider, bool enabled) onToggleSetting;

  const CaptureSettingsScreen({
    super.key,
    required this.title,
    required this.sourceType,
    required this.settings,
    required this.onToggleSetting,
  });

  static const List<Map<String, String>> defaultNotificationProviders = [
    {'id': 'gpay', 'name': 'Google Pay'},
    {'id': 'phonepe', 'name': 'PhonePe'},
    {'id': 'paytm', 'name': 'Paytm'},
    {'id': 'bank_apps', 'name': 'Banking Applications'},
  ];

  static const List<Map<String, String>> defaultSmsProviders = [
    {'id': 'bank_sms', 'name': 'Banking SMS Messages'},
    {'id': 'payment_sms', 'name': 'Payment Provider Messages'},
  ];

  @override
  Widget build(BuildContext context) {
    final providers = sourceType == 'NOTIFICATION_CAPTURE'
        ? defaultNotificationProviders
        : defaultSmsProviders;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Merchant Permission & Consent',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      sourceType == 'NOTIFICATION_CAPTURE'
                          ? 'MeraVyapar AI only processes transaction-related notifications from providers you explicitly enable. Promotional and reward alerts are automatically excluded.'
                          : 'MeraVyapar AI only detects banking and payment SMS messages for evidence ingestion. OTPs and marketing messages are automatically excluded.',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF1E40AF), height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Enabled Capture Providers',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 12),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: providers.length,
                itemBuilder: (context, index) {
                  final provider = providers[index];
                  final providerId = provider['id']!;
                  final providerName = provider['name']!;

                  final setting = settings.firstWhere(
                    (s) => s.providerIdentifier == providerId,
                    orElse: () => CaptureSourceSettingModel(
                      id: '',
                      merchantId: '',
                      sourceType: sourceType,
                      providerIdentifier: providerId,
                      enabled: true,
                    ),
                  );

                  return SwitchListTile(
                    title: Text(providerName, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('ID: $providerId', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    value: setting.enabled,
                    onChanged: (enabled) => onToggleSetting(providerId, enabled),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
