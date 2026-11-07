import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/env.dart';
import '../presentation/configuration_required_screen.dart';
import '../../features/auth/data/local_auth_repository.dart';
import '../../features/transactions/data/local_canonical_transaction_repository.dart';
import '../../features/memory/data/local_memory_repository.dart';
import '../../features/events/data/event_repository.dart';
import '../../features/evidence/data/evidence_repository.dart';
import '../../features/capture/data/capture_repository.dart';
import '../../features/intelligence/data/intelligence_repository.dart';
import '../../features/market_intelligence/data/market_intelligence_repository.dart';
import '../../features/voice/data/voice_repository.dart';
import '../../features/voice/services/audio_recording_service.dart';
import '../../features/voice/services/audio_playback_service.dart';
import '../../features/voice/presentation/voice_interaction_controller.dart';
import '../../features/voice/presentation/voice_assistant_sheet.dart';
import '../../features/actions/data/action_repository.dart';
import '../../features/home/presentation/home_shell_screen.dart';
import '../../features/evidence/presentation/manual_entry_screen.dart';
import '../../features/evidence/presentation/file_upload_screen.dart';
import '../../features/evidence/presentation/evidence_history_screen.dart';
import '../../features/transactions/presentation/canonical_transactions_screen.dart';
import '../../features/transactions/presentation/canonical_transaction_detail_screen.dart';
import '../../features/capture/presentation/capture_center_screen.dart';
import '../../features/capture/presentation/capture_settings_screen.dart';
import '../../features/memory/presentation/financial_relationships_screen.dart';
import '../../features/memory/presentation/counterparty_detail_screen.dart';
import '../../features/memory/presentation/payment_promises_screen.dart';
import '../../features/events/presentation/important_events_screen.dart';
import '../../features/events/presentation/event_detail_screen.dart';
import '../../features/events/presentation/receivables_screen.dart';
import '../../features/events/presentation/receivable_detail_screen.dart';
import '../../features/intelligence/presentation/merchant_assistant_screen.dart';
import '../../features/market_intelligence/presentation/relevant_market_signals_screen.dart';
import '../../features/market_intelligence/presentation/market_signal_detail_screen.dart';
import '../../features/actions/presentation/action_center_screen.dart';
import '../../features/actions/presentation/action_detail_screen.dart';
import '../../features/actions/presentation/reminder_draft_screen.dart';
import '../../core/database/local_database_service.dart';

// --- Local Repository Providers ---
final localAuthRepositoryProvider = Provider((ref) => LocalAuthRepository());
final localCanonicalTransactionRepositoryProvider = Provider((ref) => LocalCanonicalTransactionRepository());
final localMemoryRepositoryProvider = Provider((ref) => LocalMemoryRepository());

// --- Gateway / Unmigrated Providers ---
final evidenceRepositoryProvider = Provider((ref) => EvidenceRepository());
final captureRepositoryProvider = Provider((ref) => CaptureRepository());
final eventRepositoryProvider = Provider((ref) => EventRepository());
final intelligenceRepositoryProvider = Provider((ref) => IntelligenceRepository());
final marketIntelligenceRepositoryProvider = Provider((ref) => MarketIntelligenceRepository());
final voiceRepositoryProvider = Provider((ref) => VoiceRepository(baseUrl: Env.apiBaseUrl));
final actionRepositoryProvider = Provider((ref) => ActionRepository(baseUrl: Env.apiBaseUrl));
final audioRecordingServiceProvider = Provider<AudioRecordingService>((ref) => DeviceAudioRecordingService());
final audioPlaybackServiceProvider = Provider<AudioPlaybackService>((ref) => DeviceAudioPlaybackService());

final voiceControllerProvider = StateNotifierProvider.autoDispose<VoiceInteractionController, VoiceInteractionState>((ref) {
  final authRepo = ref.watch(localAuthRepositoryProvider);
  final token = authRepo.activeMerchantId ?? '';
  return VoiceInteractionController(
    voiceRepository: ref.watch(voiceRepositoryProvider),
    recordingService: ref.watch(audioRecordingServiceProvider),
    playbackService: ref.watch(audioPlaybackServiceProvider),
    actionRepository: ref.watch(actionRepositoryProvider),
    authToken: token,
  );
});

class AppRouter extends ConsumerStatefulWidget {
  const AppRouter({super.key});

  @override
  ConsumerState<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends ConsumerState<AppRouter> {
  LocalAuthStatus _authStatus = LocalAuthStatus.uninitialized;
  bool _isLoading = false;
  String? _errorMessage;
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  // Navigation State
  String _currentRoute = '/';
  final Map<String, dynamic> _routeArgs = {};

  @override
  void initState() {
    super.initState();
    _initLocalSession();
  }

  @override
  void dispose() {
    _pinController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _initLocalSession() async {
    setState(() => _isLoading = true);
    try {
      await LocalDatabaseService.instance.initialize();
      final authRepo = ref.read(localAuthRepositoryProvider);
      final hasMerchant = await authRepo.hasLocalMerchant();
      setState(() {
        _authStatus = hasMerchant ? LocalAuthStatus.locked : LocalAuthStatus.uninitialized;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Local initialization failed: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleRegister() async {
    final name = _nameController.text.trim();
    final pin = _pinController.text.trim();
    if (name.isEmpty || pin.length < 4) {
      setState(() => _errorMessage = 'Please enter name and at least 4-digit PIN');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final authRepo = ref.read(localAuthRepositoryProvider);
      await authRepo.registerLocalMerchant(displayName: name, pin: pin);
      _pinController.clear();
      setState(() {
        _authStatus = LocalAuthStatus.authenticated;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '$e';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleUnlock() async {
    final pin = _pinController.text.trim();
    if (pin.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final authRepo = ref.read(localAuthRepositoryProvider);
      final success = await authRepo.authenticateWithPin(pin);
      _pinController.clear();
      setState(() {
        if (success) {
          _authStatus = LocalAuthStatus.authenticated;
          _errorMessage = null;
        } else {
          _errorMessage = 'Invalid PIN. Please try again.';
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '$e';
        _isLoading = false;
      });
    }
  }

  void _navigateTo(String route, [Map<String, dynamic>? args]) {
    setState(() {
      _currentRoute = route;
      if (args != null) {
        _routeArgs.clear();
        _routeArgs.addAll(args);
      }
    });
  }

  void _popRoute() {
    setState(() {
      _currentRoute = '/';
      _routeArgs.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_authStatus == LocalAuthStatus.uninitialized) {
      return Scaffold(
        appBar: AppBar(title: const Text('Setup Local Merchant Profile')),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.storefront, size: 64, color: Colors.blue),
              const SizedBox(height: 16),
              const Text('MeraVyapar AI Local-First', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('All financial records remain private on your device.', textAlign: TextAlign.center),
              const SizedBox(height: 24),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Business Name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Set 4-6 Digit Security PIN', border: OutlineInputBorder()),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _handleRegister,
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                child: const Text('Create Private Merchant Profile'),
              ),
            ],
          ),
        ),
      );
    }

    if (_authStatus == LocalAuthStatus.locked) {
      return Scaffold(
        appBar: AppBar(title: const Text('Unlock MeraVyapar AI')),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 64, color: Colors.blue),
              const SizedBox(height: 16),
              const Text('Enter Security PIN', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: _pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Security PIN', border: OutlineInputBorder()),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _handleUnlock,
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                child: const Text('Unlock Device Ledger'),
              ),
            ],
          ),
        ),
      );
    }

    // Authenticated: Render Main Navigation
    final authRepo = ref.read(localAuthRepositoryProvider);
    final activeMerchantId = authRepo.activeMerchantId ?? 'local_merchant';

    return _buildCurrentScreen(activeMerchantId);
  }

  Widget _buildCurrentScreen(String merchantId) {
    switch (_currentRoute) {
      case '/transactions':
        final txRepo = ref.read(localCanonicalTransactionRepositoryProvider);
        return FutureBuilder(
          future: txRepo.getCanonicalTransactions(merchantId: merchantId),
          builder: (context, snapshot) {
            final txs = snapshot.data ?? [];
            return CanonicalTransactionsScreen(
              transactions: txs,
              isLoading: snapshot.connectionState == ConnectionState.waiting,
              onRunReconciliation: () {},
              onTransactionTap: (tx) => _navigateTo('/transactions/detail', {'tx': tx}),
            );
          },
        );

      case '/transactions/detail':
        return CanonicalTransactionDetailScreen(
          transaction: _routeArgs['tx'],
          onBack: _popRoute,
        );

      case '/relationships':
        final memRepo = ref.read(localMemoryRepositoryProvider);
        return FutureBuilder(
          future: memRepo.getCounterparties(merchantId: merchantId),
          builder: (context, snapshot) {
            final cps = snapshot.data ?? [];
            return FinancialRelationshipsScreen(
              counterparties: cps,
              onCounterpartyTap: (cp) => _navigateTo('/relationships/detail', {'cp': cp}),
            );
          },
        );

      case '/promises':
        final memRepo = ref.read(localMemoryRepositoryProvider);
        return FutureBuilder(
          future: Future.wait([
            memRepo.getPaymentPromises(merchantId: merchantId),
            memRepo.getCounterparties(merchantId: merchantId),
          ]),
          builder: (context, snapshot) {
            final data = snapshot.data;
            final promises = data != null ? data[0] as List<dynamic> : [];
            final counterparties = data != null ? data[1] as List<dynamic> : [];
            return PaymentPromisesScreen(
              promises: promises.cast(),
              counterparties: counterparties.cast(),
              onCreatePromise: (pData) async {
                await memRepo.createPaymentPromise(
                  merchantId: merchantId,
                  counterpartyName: pData['counterparty_name'] ?? 'Unknown',
                  amount: pData['amount'] ?? '0',
                  direction: pData['direction'] ?? 'EXPECTED_INCOMING',
                  dueDate: pData['due_date'] ?? DateTime.now().toUtc().toIso8601String(),
                );
                setState(() {});
              },
              onFulfillPromise: (promiseId) async {
                await memRepo.fulfillPromise(merchantId: merchantId, promiseId: promiseId);
                setState(() {});
              },
            );
          },
        );

      default:
        return HomeShellScreen(
          onOpenVoiceAssistant: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (ctx) => VoiceAssistantSheet(
                controllerProvider: voiceControllerProvider,
                onNavigateToRoute: _navigateTo,
              ),
            );
          },
          onNavigateToRoute: _navigateTo,
        );
    }
  }
}
