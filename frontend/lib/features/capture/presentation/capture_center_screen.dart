import 'package:flutter/material.dart';

class CaptureCenterScreen extends StatelessWidget {
  final bool isAndroidPlatform;
  final VoidCallback onAddManual;
  final VoidCallback onShareProof;
  final VoidCallback onOpenNotificationSettings;
  final VoidCallback onOpenSmsSettings;

  const CaptureCenterScreen({
    super.key,
    required this.isAndroidPlatform,
    required this.onAddManual,
    required this.onShareProof,
    required this.onOpenNotificationSettings,
    required this.onOpenSmsSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Evidence Capture Center'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Financial Evidence Sources',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
              ),
              const SizedBox(height: 8),
              const Text(
                'MeraVyapar AI observes financial evidence strictly with explicit merchant consent. Captured evidence is processed into transaction candidates.',
                style: TextStyle(color: Color(0xFF64748B), height: 1.4),
              ),
              const SizedBox(height: 24),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.add_circle, color: Color(0xFF166534)),
                  title: const Text('Manual Entry'),
                  subtitle: const Text('Record payments received or expenses sent'),
                  onTap: onAddManual,
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.receipt_long, color: Color(0xFF2563EB)),
                  title: const Text('Share / Upload Payment Proof'),
                  subtitle: const Text('Share payment screenshots, receipts, or text'),
                  onTap: onShareProof,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Mobile Evidence Ingestion',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
              ),
              const SizedBox(height: 12),
              if (!isAndroidPlatform)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFCD34D)),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.info_outline, color: Color(0xFFD97706)),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Passive Notification and SMS capture are unsupported on this platform.',
                          style: TextStyle(fontSize: 13, color: Color(0xFF92400E)),
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.notifications_active, color: Color(0xFFD97706)),
                    title: const Text('Connect Payment Notifications'),
                    subtitle: const Text('Observe payment alerts from selected providers'),
                    onTap: onOpenNotificationSettings,
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.sms, color: Color(0xFF7C3AED)),
                    title: const Text('Connect Banking SMS'),
                    subtitle: const Text('Detect bank transaction messages with consent'),
                    onTap: onOpenSmsSettings,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
