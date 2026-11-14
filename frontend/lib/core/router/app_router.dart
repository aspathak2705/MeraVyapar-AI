import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/env.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
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
import '../../features/transactions/presentation/canonical_transactions_screen.dart';
import '../../features/transactions/presentation/canonical_transaction_detail_screen.dart';
import '../../features/memory/presentation/financial_relationships_screen.dart';
import '../../features/memory/presentation/payment_promises_screen.dart';
import '../../features/events/presentation/receivables_screen.dart';
import '../../features/events/presentation/receivable_detail_screen.dart';
import '../../features/market_intelligence/presentation/relevant_market_signals_screen.dart';
import '../../features/market_intelligence/presentation/market_signal_detail_screen.dart';
import '../../features/actions/data/local_action_repository.dart';
import '../../features/actions/presentation/action_center_screen.dart';
import '../../features/voice/services/wake_word_detector_service.dart';
import '../../features/voice/presentation/wake_word_controller.dart';
import '../../features/actions/presentation/action_detail_screen.dart';
import '../../features/actions/presentation/reminder_draft_screen.dart';
import '../../features/intelligence/presentation/unified_financial_intelligence_screen.dart';
import '../../features/capture/presentation/permission_settings_screen.dart';
import '../../features/procurement/presentation/procurement_dashboard_screen.dart';
import '../../features/onboarding/presentation/business_profile_screen.dart';
import '../../core/database/local_database_service.dart';

// --- Local Repository Providers ---
// Re-export single canonical localAuthRepositoryProvider from local_auth_repository.dart
// (Do not declare a second localAuthRepositoryProvider instance here)
final localCanonicalTransactionRepositoryProvider = Provider((ref) => LocalCanonicalTransactionRepository());
final localMemoryRepositoryProvider = Provider((ref) => LocalMemoryRepository());
final localActionRepositoryProvider = Provider((ref) => LocalActionRepository());

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
    actionRepository: ref.watch(localActionRepositoryProvider),
    authToken: token,
  );
});

final wakeWordEngineProvider = Provider<WakeWordDetectorEngine>((ref) => LocalAcousticWakeWordEngine());

final wakeWordControllerProvider = StateNotifierProvider<WakeWordController, WakeWordStateData>((ref) {
  return WakeWordController(
    detectorEngine: ref.watch(wakeWordEngineProvider),
    recordingService: ref.watch(audioRecordingServiceProvider),
    voiceController: ref.watch(voiceControllerProvider.notifier),
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
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Scaffold(
        appBar: AppBar(title: const Text('Setup Merchant Profile')),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkLavenderSurface : AppColors.lightLavender,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        AppIcons.business,
                        size: 40,
                        color: isDark ? AppColors.darkPrimaryPurple : AppColors.primaryPurple,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('MeraVyapar AI', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    const Text('100% Private, On-Device Financial Intelligence', textAlign: TextAlign.center, style: TextStyle(fontSize: 13)),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Business Name', hintText: 'e.g. Ramesh Kirana Store'),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _pinController,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Set 4-6 Digit Security PIN', hintText: '••••'),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                    ],
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _handleRegister,
                      child: const Text('Create Private Merchant Profile'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (_authStatus == LocalAuthStatus.locked) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Scaffold(
        appBar: AppBar(title: const Text('Unlock MeraVyapar')),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkLavenderSurface : AppColors.lightLavender,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        AppIcons.lock,
                        size: 40,
                        color: isDark ? AppColors.darkPrimaryPurple : AppColors.primaryPurple,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Enter Security PIN', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    const Text('Your financial records remain encrypted on this phone.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13)),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _pinController,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Security PIN', hintText: '••••'),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                    ],
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _handleUnlock,
                      child: const Text('Unlock Device Ledger'),
                    ),
                  ],
                ),
              ),
            ),
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
      case '/intelligence':
        return UnifiedFinancialIntelligenceScreen(
          onBack: _popRoute,
          onNavigate: _navigateTo,
        );

      case '/receivables':
        final eventRepo = ref.read(eventRepositoryProvider);
        return FutureBuilder(
          future: eventRepo.getPrioritizedReceivables(merchantId: merchantId),
          builder: (context, snapshot) {
            final items = snapshot.data ?? [];
            return ReceivablesScreen(
              receivables: items,
              onBack: _popRoute,
              onReceivableTap: (item) => _navigateTo('/receivables/detail', {'receivable': item}),
            );
          },
        );

      case '/receivables/detail':
        final item = _routeArgs['receivable'];
        return ReceivableDetailScreen(
          receivable: item,
          onBack: _popRoute,
          onReviewFollowUp: () {
            _navigateTo('/actions/draft', {'promise_id': item.sourcePaymentPromiseId});
          },
          onCreateReminderDraft: () {
            _navigateTo('/actions/draft', {'promise_id': item.sourcePaymentPromiseId});
          },
        );

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
              onAddTransaction: () => _showManualEntryDialog(context, merchantId, txRepo),
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
                  amount: pData['amount'] ?? pData['promised_amount'] ?? '0',
                  direction: pData['direction'] ?? pData['promise_direction'] ?? 'EXPECTED_INCOMING',
                  dueDate: pData['due_date'] ?? pData['due_at'] ?? DateTime.now().toUtc().toIso8601String(),
                  counterpartyId: pData['counterparty_id'],
                  notes: pData['notes'] ?? pData['description'],
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

      case '/market':
        final marketRepo = ref.read(marketIntelligenceRepositoryProvider);
        return FutureBuilder(
          future: marketRepo.getRelevantSignals(),
          builder: (context, snapshot) {
            final signals = snapshot.data ?? [];
            return RelevantMarketSignalsScreen(
              signals: signals,
              onRefresh: () => setState(() {}),
              onBack: _popRoute,
              onSignalTap: (sig) => _navigateTo('/market/detail', {'signal': sig}),
            );
          },
        );

      case '/market/detail':
        return MarketSignalDetailScreen(
          signal: _routeArgs['signal'],
          onBack: _popRoute,
        );

      case '/actions':
        final localActionRepo = ref.read(localActionRepositoryProvider);
        return ActionCenterScreen(
          actionRepository: localActionRepo,
          authToken: merchantId,
          onBack: _popRoute,
        );

      case '/actions/draft':
        final localActionRepo = ref.read(localActionRepositoryProvider);
        return ReminderDraftScreen(
          actionRepository: localActionRepo,
          promiseId: _routeArgs['promise_id'] ?? '',
          authToken: merchantId,
          onBack: _popRoute,
        );

      case '/actions/detail':
        final localActionRepo = ref.read(localActionRepositoryProvider);
        return ActionDetailScreen(
          actionRepository: localActionRepo,
          actionId: _routeArgs['action_id'] ?? '',
          authToken: merchantId,
        );

      case '/settings/permissions':
        return PermissionSettingsScreen(
          onBack: _popRoute,
        );

      case '/settings/profile':
        return BusinessProfileScreen(
          merchantId: merchantId,
          onBack: _popRoute,
        );

      case '/procurement':
        return ProcurementDashboardScreen(
          merchantId: merchantId,
          onBack: _popRoute,
        );

      default:
        return HomeShellScreen(
          onAddPaymentReceived: () => _showManualEntryDialog(context, merchantId, ref.read(localCanonicalTransactionRepositoryProvider), defaultType: 'CREDIT'),
          onAddExpense: () => _showManualEntryDialog(context, merchantId, ref.read(localCanonicalTransactionRepositoryProvider), defaultType: 'DEBIT'),
          onOpenVoiceAssistant: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (ctx) => VoiceAssistantSheet(
                autoDisposeControllerProvider: voiceControllerProvider,
                wakeWordProvider: wakeWordControllerProvider,
                onNavigateToRoute: _navigateTo,
              ),
            );
          },
          onNavigateToRoute: _navigateTo,
        );
    }
  }

  void _showManualEntryDialog(
    BuildContext context,
    String merchantId,
    LocalCanonicalTransactionRepository txRepo, {
    String defaultType = 'CREDIT',
  }) {
    final amtCtrl = TextEditingController();
    final partyCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String txType = defaultType; // 'CREDIT' (Money In) or 'DEBIT' (Money Out)
    String paymentMode = 'CASH';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Manual Entry'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'CREDIT', label: Text('Income (+)')),
                    ButtonSegment(value: 'DEBIT', label: Text('Expense (-)')),
                  ],
                  selected: {txType},
                  onSelectionChanged: (val) {
                    setDialogState(() => txType = val.first);
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amtCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Amount (₹)',
                    hintText: 'e.g. 500.00',
                    prefixText: '₹ ',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: partyCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Counterparty / Customer / Vendor',
                    hintText: 'e.g. Ramesh Kirana',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: paymentMode,
                  decoration: const InputDecoration(labelText: 'Payment Mode'),
                  items: const [
                    DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                    DropdownMenuItem(value: 'UPI', child: Text('UPI / QR')),
                    DropdownMenuItem(value: 'BANK_TRANSFER', child: Text('Bank Transfer / NEFT')),
                    DropdownMenuItem(value: 'CHEQUE', child: Text('Cheque')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => paymentMode = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Notes / Description (Optional)',
                    hintText: 'e.g. Wholesale flour payment',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final amtText = amtCtrl.text.trim();
                final parsedAmt = double.tryParse(amtText);
                if (parsedAmt == null || parsedAmt <= 0) return;

                final navigator = Navigator.of(context);
                await txRepo.createTransaction(
                  merchantId: merchantId,
                  amount: amtText,
                  transactionType: txType,
                  paymentMode: paymentMode,
                  counterpartyName: partyCtrl.text.trim().isEmpty ? null : partyCtrl.text.trim(),
                  description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                  sourceType: 'MANUAL',
                );

                if (mounted) {
                  navigator.pop();
                  setState(() {});
                }
              },
              child: const Text('Save Entry'),
            ),
          ],
        ),
      ),
    );
  }
}
