import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../core/config/env.dart';
import '../../../l10n/app_localizations.dart';
import '../../capture/data/device_evidence_capture.dart';

class PermissionSettingsScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const PermissionSettingsScreen({super.key, this.onBack});

  @override
  State<PermissionSettingsScreen> createState() => _PermissionSettingsScreenState();
}

class _PermissionSettingsScreenState extends State<PermissionSettingsScreen> {
  final DeviceEvidenceCapture _capture = AndroidDeviceEvidenceCapture();
  Map<String, PermissionLifecycleStatus> _statuses = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refreshStatuses();
  }

  Future<void> _refreshStatuses() async {
    setState(() => _isLoading = true);
    final statusMap = await _capture.getDetailedPermissionStatus();
    if (mounted) {
      setState(() {
        _statuses = statusMap;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.permissionSettings ?? 'Device Permissions & Privacy'),
        leading: widget.onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: l10n?.back ?? 'Back',
                onPressed: widget.onBack,
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n?.runReconciliationPass ?? 'Refresh Status',
            onPressed: _refreshStatuses,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Privacy Architecture Banner
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Row(
                            children: [
                              Icon(Icons.shield_outlined, color: Color(0xFF1D4ED8), size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Local Privacy Guarantee',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E3A8A),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Text(
                            'MeraVyapar AI operates entirely on-device with SQLite as canonical truth. No SMS reading, contacts, camera, or broad storage permissions are requested. Every financial mutation requires explicit merchant review.',
                            style: TextStyle(fontSize: 13, color: Color(0xFF1E40AF), height: 1.4),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                    const Text(
                      'Access Management',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 12),

                    // 1. Microphone Access
                    _buildPermissionTile(
                      icon: Icons.mic_rounded,
                      title: 'Microphone (Voice Assistant)',
                      description: 'Used for Hindi, Marathi, and English voice commands to record credit entries. Audio is never recorded in the background.',
                      status: _statuses['RECORD_AUDIO'] ?? PermissionLifecycleStatus.notRequested,
                      onRequest: () async {
                        await _capture.requestFeaturePermission('RECORD_AUDIO');
                        await _refreshStatuses();
                      },
                      onOpenSettings: () => _capture.openAppSettings(),
                    ),

                    const SizedBox(height: 12),

                    // 2. Financial Notification Listener
                    _buildPermissionTile(
                      icon: Icons.notifications_active_outlined,
                      title: 'Notification Access (Payment Capture)',
                      description: 'Passively captures transaction alerts from UPI & banking apps. Filtered strictly for financial keywords (UPI, credited, debited, bank).',
                      status: _statuses['NOTIFICATION_LISTENER'] ?? PermissionLifecycleStatus.denied,
                      isSpecialAccess: true,
                      onRequest: () async {
                        await _capture.openNotificationListenerSettings();
                      },
                      onOpenSettings: () => _capture.openNotificationListenerSettings(),
                    ),

                    const SizedBox(height: 12),

                    // 3. Post Notifications (Android 13+)
                    _buildPermissionTile(
                      icon: Icons.notifications_outlined,
                      title: 'App Notifications & Quick Entry Shade',
                      description: 'Allows MeraVyapar to maintain ongoing quick-entry tile in notification shade (+ Add Income, - Add Expense) and due reminders.',
                      status: _statuses['POST_NOTIFICATIONS'] ?? PermissionLifecycleStatus.notRequested,
                      onRequest: () async {
                        final res = await _capture.requestFeaturePermission('POST_NOTIFICATIONS');
                        if (res == PermissionLifecycleStatus.granted) {
                          await _capture.showQuickEntryNotification();
                        }
                        await _refreshStatuses();
                      },
                      onOpenSettings: () => _capture.openAppSettings(),
                    ),

                    const SizedBox(height: 12),

                    // 4. Internet Connectivity
                    _buildConnectivityTile(
                      icon: Icons.wifi,
                      title: 'Internet Connectivity',
                      description: 'Used solely for optional cloud services (Gnani STT/TTS proxy, SerpApi market signals). Offline core ledger works 100% without internet.',
                      status: _statuses['INTERNET'] ?? PermissionLifecycleStatus.denied,
                    ),

                    const SizedBox(height: 12),

                    // 5. SMS Permission Policy Status
                    _buildSmsPolicyTile(),

                    const SizedBox(height: 12),

                    // 6. Encrypted Backup File Access
                    _buildBackupAccessTile(),

                    const SizedBox(height: 12),

                    // 7. Backend Connection Status (Production Gateway Diagnostic)
                    _buildBackendDiagnosticTile(),

                    const SizedBox(height: 24),
                    Center(
                      child: TextButton.icon(
                        icon: const Icon(Icons.settings, size: 16),
                        label: const Text('Open Android System Settings for MeraVyapar'),
                        onPressed: () => _capture.openAppSettings(),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildPermissionTile({
    required IconData icon,
    required String title,
    required String description,
    required PermissionLifecycleStatus status,
    required VoidCallback onRequest,
    required VoidCallback onOpenSettings,
    bool isSpecialAccess = false,
  }) {
    Color badgeColor;
    String badgeText;
    Color textColor;

    switch (status) {
      case PermissionLifecycleStatus.granted:
        badgeColor = const Color(0xFFDCFCE7);
        badgeText = 'Granted';
        textColor = const Color(0xFF166534);
        break;
      case PermissionLifecycleStatus.permanentlyDenied:
        badgeColor = const Color(0xFFFEE2E2);
        badgeText = 'Settings Needed';
        textColor = const Color(0xFF991B1B);
        break;
      case PermissionLifecycleStatus.denied:
        badgeColor = const Color(0xFFFEF3C7);
        badgeText = isSpecialAccess ? 'Disabled' : 'Denied';
        textColor = const Color(0xFF92400E);
        break;
      case PermissionLifecycleStatus.notRequested:
        badgeColor = const Color(0xFFF1F5F9);
        badgeText = 'Not Requested';
        textColor = const Color(0xFF475569);
        break;
      case PermissionLifecycleStatus.unsupported:
        badgeColor = const Color(0xFFF1F5F9);
        badgeText = 'N/A';
        textColor = const Color(0xFF64748B);
        break;
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFF4338CA), size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.35),
            ),
            const SizedBox(height: 12),
            if (status != PermissionLifecycleStatus.granted)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (status == PermissionLifecycleStatus.permanentlyDenied || isSpecialAccess)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.open_in_new, size: 14),
                      label: Text(isSpecialAccess ? 'Enable Access' : 'Open Settings'),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: onOpenSettings,
                    )
                  else
                    ElevatedButton.icon(
                      icon: const Icon(Icons.check, size: 14),
                      label: const Text('Request Access'),
                      style: ElevatedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        backgroundColor: const Color(0xFF4338CA),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: onRequest,
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectivityTile({
    required IconData icon,
    required String title,
    required String description,
    required PermissionLifecycleStatus status,
  }) {
    final isOnline = status == PermissionLifecycleStatus.granted;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: isOnline ? const Color(0xFF16A34A) : const Color(0xFF64748B), size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isOnline ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isOnline ? 'Online' : 'Offline Mode',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isOnline ? const Color(0xFF166534) : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.35),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackupAccessTile() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.folder_shared_outlined, color: Color(0xFF4338CA), size: 22),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Encrypted Backup Access',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'On-Demand Only',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF166534),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Uses Android Storage Access Framework (SAF). Only accesses files you explicitly pick for export or restore. Broad storage access (MANAGE_EXTERNAL_STORAGE) is prohibited.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.35),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmsPolicyTile() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.sms_outlined, color: Color(0xFFD97706), size: 22),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'SMS Ingestion & Google Play Policy',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Play Policy Gated',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF92400E),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Under Google Play Store Permissions Policy, general financial/expense tracking apps are not eligible for broad READ_SMS or RECEIVE_SMS permissions unless registered as default SMS handler. Passive capture operates strictly via authorized Notification Listener, user-selected Statement Import, and Quick Entry shade.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.35),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackendDiagnosticTile() {
    return _BackendDiagnosticCard();
  }
}

class _BackendDiagnosticCard extends StatefulWidget {
  @override
  State<_BackendDiagnosticCard> createState() => _BackendDiagnosticCardState();
}

class _BackendDiagnosticCardState extends State<_BackendDiagnosticCard> {
  bool _isTesting = false;
  String? _status;
  Color _statusColor = const Color(0xFF64748B);
  String? _details;

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _status = 'Testing connection...';
      _statusColor = const Color(0xFFD97706);
      _details = null;
    });

    try {
      final uri = Uri.parse('${Env.apiBaseUrl}/health');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        final data = body['data'] as Map<String, dynamic>? ?? {};
        final service = data['service'] ?? 'meravyapar-api';
        final status = data['status'] ?? 'healthy';
        final version = data['version'] ?? '1.0.0';

        setState(() {
          _isTesting = false;
          _status = 'CONNECTED (HTTP 200)';
          _statusColor = const Color(0xFF166534);
          _details = 'Service: $service | Status: $status | Version: $version\nGateway: ${Env.apiBaseUrl}';
        });
      } else {
        setState(() {
          _isTesting = false;
          _status = 'SERVER ERROR (HTTP ${response.statusCode})';
          _statusColor = const Color(0xFFDC2626);
          _details = 'Endpoint returned status code ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _isTesting = false;
        _status = 'CONNECTION FAILED';
        _statusColor = const Color(0xFFDC2626);
        _details = 'Error: ${e.toString()}\nEnsure device has active internet connectivity.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.cloud_done_outlined, color: Color(0xFF2563EB), size: 22),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Production AI Cloud Gateway',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                if (_status != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor == const Color(0xFF166534)
                          ? const Color(0xFFDCFCE7)
                          : const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _status!,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _statusColor,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Configured Gateway URL: ${Env.apiBaseUrl}',
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Color(0xFF475569)),
            ),
            const SizedBox(height: 6),
            const Text(
              'Connects to the deployed Render gateway for optional cloud services (Gnani Speech, SerpApi Market Research, and NVIDIA Nemotron). Core ledger remains 100% private and offline.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.35),
            ),
            if (_details != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  _details!,
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Color(0xFF334155)),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _isTesting ? null : _testConnection,
                icon: _isTesting
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.wifi_tethering, size: 16),
                label: const Text('Test Backend Connection'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
