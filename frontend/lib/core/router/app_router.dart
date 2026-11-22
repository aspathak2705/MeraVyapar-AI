import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
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
import '../../features/intelligence/domain/grounded_insight_model.dart';
import '../../features/intelligence/presentation/merchant_assistant_screen.dart';
import '../../features/market_intelligence/data/market_intelligence_repository.dart';
import '../../features/voice/data/voice_repository.dart';
import '../../features/voice/services/audio_recording_service.dart';
import '../../features/voice/services/audio_playback_service.dart';
import '../../features/voice/presentation/voice_interaction_controller.dart';
import '../../features/actions/data/action_repository.dart';
import '../../features/home/presentation/home_shell_screen.dart';
import '../../features/transactions/presentation/canonical_transactions_screen.dart';
import '../../features/transactions/presentation/canonical_transaction_detail_screen.dart';
import '../../features/memory/presentation/financial_relationships_screen.dart';
import '../../features/memory/presentation/counterparty_detail_screen.dart';
import '../../features/memory/presentation/payment_promises_screen.dart';
import '../../features/events/presentation/receivables_screen.dart';
import '../../features/events/presentation/receivable_detail_screen.dart';
import '../../features/market_intelligence/presentation/relevant_market_signals_screen.dart';
import '../../features/market_intelligence/presentation/market_signal_detail_screen.dart';
import '../../features/market_intelligence/presentation/local_supplier_discovery_screen.dart';
import '../../features/market_intelligence/presentation/supplier_shortlist_screen.dart';
import '../../features/market_intelligence/domain/merchant_market_relevance_model.dart';
import '../../features/actions/data/local_action_repository.dart';
import '../../features/actions/presentation/action_center_screen.dart';
import '../../features/voice/services/wake_word_detector_service.dart';
import '../../features/voice/presentation/wake_word_controller.dart';
import '../../features/actions/presentation/action_detail_screen.dart';
import '../../features/actions/presentation/reminder_draft_screen.dart';
import '../../features/intelligence/presentation/unified_financial_intelligence_screen.dart';
import '../../features/capture/presentation/permission_settings_screen.dart';
import '../../features/procurement/presentation/procurement_dashboard_screen.dart';
import '../../features/intelligence/presentation/intelligent_reports_screen.dart';
import '../../features/onboarding/presentation/business_profile_screen.dart';
import '../../features/onboarding/data/local_business_profile_repository.dart';
import '../../features/onboarding/domain/merchant_business_profile.dart';
import '../../features/transactions/domain/statement_import_service.dart';
import '../../features/capture/data/device_evidence_capture.dart';
import '../../features/capture/domain/local_evidence_capture_service.dart';
import '../../core/database/local_database_service.dart';
import '../../core/money/money.dart';
import '../../features/intelligence/domain/local_financial_intelligence_engine.dart';
import '../localization/locale_provider.dart';
import '../../l10n/app_localizations.dart';

// --- Local Repository Providers ---
// Re-export canonical providers from feature data repositories
final localCanonicalTransactionRepositoryProvider =
    Provider((ref) => LocalCanonicalTransactionRepository());
final localEvidenceCaptureServiceProvider =
    Provider((ref) => LocalEvidenceCaptureService());

// --- Gateway / Unmigrated Providers ---
final evidenceRepositoryProvider = Provider((ref) => EvidenceRepository());
final captureRepositoryProvider = Provider((ref) => CaptureRepository());
final eventRepositoryProvider = Provider((ref) => EventRepository());
final intelligenceRepositoryProvider =
    Provider((ref) => IntelligenceRepository());
final marketIntelligenceRepositoryProvider =
    Provider((ref) => MarketIntelligenceRepository());
final voiceRepositoryProvider =
    Provider((ref) => VoiceRepository(baseUrl: Env.apiBaseUrl));
final actionRepositoryProvider =
    Provider((ref) => ActionRepository(baseUrl: Env.apiBaseUrl));
final audioRecordingServiceProvider =
    Provider<AudioRecordingService>((ref) => DeviceAudioRecordingService());
final audioPlaybackServiceProvider =
    Provider<AudioPlaybackService>((ref) => DeviceAudioPlaybackService());

final voiceControllerProvider = StateNotifierProvider.autoDispose<
    VoiceInteractionController, VoiceInteractionState>((ref) {
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

final wakeWordEngineProvider =
    Provider<WakeWordDetectorEngine>((ref) => LocalAcousticWakeWordEngine());

final wakeWordControllerProvider =
    StateNotifierProvider<WakeWordController, WakeWordStateData>((ref) {
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
  final List<String> _navigationStack = ['/'];
  final Map<String, dynamic> _routeArgs = {};
  bool _isAssistantLoading = false;
  FinancialQueryResultModel? _lastAssistantResult;
  Timer? _renderKeepAliveTimer;

  @override
  void initState() {
    super.initState();
    _initLocalSession();
    _setupCaptureListeners();
    _startRenderKeepAlive();
  }

  void _startRenderKeepAlive() {
    // Free Render instances spin down after inactivity (~15 min).
    // Send lightweight health check probe every 50 seconds to keep gateway warm while merchant active.
    _renderKeepAliveTimer?.cancel();
    _renderKeepAliveTimer = Timer.periodic(const Duration(seconds: 50), (_) async {
      try {
        final client = ApiClient();
        await client.get('/health');
      } catch (_) {
        // Silently swallow keep-alive failures
      }
    });
  }

  void _setupCaptureListeners() {
    final capture = AndroidDeviceEvidenceCapture();

    // 1. Passive Financial Notification Listener
    capture.setNotificationHandler((data) async {
      final authRepo = ref.read(localAuthRepositoryProvider);
      final activeMerchantId = authRepo.activeMerchantId;
      if (activeMerchantId == null) {
        // App locked or unauthenticated merchant session: ignore unauthenticated mutation
        return;
      }

      final packageName = data['packageName'] as String? ?? 'unknown';
      final title = data['title'] as String? ?? '';
      final text = data['text'] as String? ?? '';
      final fullText = '$title $text'.trim();
      if (fullText.isEmpty) return;

      final captureService = ref.read(localEvidenceCaptureServiceProvider);
      final timestamp =
          data['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch;
      final sha256Hash = sha256
          .convert(utf8.encode('$packageName|$timestamp|$fullText'))
          .toString();

      await captureService.ingestEvidenceAndExtract(
        merchantId: activeMerchantId,
        filename: 'notif_${timestamp}.txt',
        mimeType: 'text/plain',
        fileSizeBytes: fullText.length,
        sha256Hash: sha256Hash,
        storageRelativePath: 'evidence/notif_${timestamp}.txt',
        sourceType: 'NOTIFICATION',
        rawText: fullText,
      );

      if (mounted) {
        setState(() {});
      }
    });

    // 2. Quick Entry Shade RemoteInput Listener
    final Set<String> processedQuickEntryRequests = <String>{};

    capture.setQuickEntryHandler((data) async {
      final requestId = data['requestId'] as String? ?? '';
      if (requestId.isNotEmpty &&
          processedQuickEntryRequests.contains(requestId)) {
        return; // Idempotency: prevent double entry from repeated intent
      }
      if (requestId.isNotEmpty) {
        processedQuickEntryRequests.add(requestId);
      }

      final text = data['text'] as String? ?? '';
      final defaultType = data['type'] as String? ?? 'CREDIT';
      if (text.isEmpty) {
        await capture.notifyQuickEntryFailure('Entry text was empty');
        return;
      }

      final authRepo = ref.read(localAuthRepositoryProvider);
      var activeMerchantId = authRepo.activeMerchantId;
      if (activeMerchantId == null) {
        // Fall back to configured local merchant if initialized
        final storedMerchantId = await authRepo.getStoredMerchantId();
        if (storedMerchantId != null) {
          activeMerchantId = storedMerchantId;
        } else {
          await capture.notifyQuickEntryFailure(
              'Unlock MeraVyapar app first to record entries');
          return;
        }
      }

      // Extract amount and parse description
      final amtMatch =
          RegExp(r'(?:Rs\.?|INR|₹)?\s*([\d,]+(?:\.\d{1,2})?)').firstMatch(text);
      if (amtMatch == null) {
        await capture
            .notifyQuickEntryFailure('No valid amount found in "$text"');
        return;
      }

      final amtStr = amtMatch.group(1)!.replaceAll(',', '');
      int amountMinor;
      try {
        amountMinor = Money.parseInrToPaise(amtStr);
      } on FormatException {
        await capture.notifyQuickEntryFailure('Invalid amount: $amtStr');
        return;
      }
      if (amountMinor <= 0) {
        await capture.notifyQuickEntryFailure('Invalid amount: $amtStr');
        return;
      }

      // Determine transaction direction
      String txType = defaultType;
      final lower = text.toLowerCase();
      if (lower.contains('expense') ||
          lower.contains('paid') ||
          lower.contains('debit')) {
        txType = 'DEBIT';
      } else if (lower.contains('income') ||
          lower.contains('received') ||
          lower.contains('credit')) {
        txType = 'CREDIT';
      }

      // Extract counterparty if present
      String? counterparty;
      final cpMatch = RegExp(r'(?:from|to|by)\s+([A-Za-z0-9\s]{2,25})',
              caseSensitive: false)
          .firstMatch(text);
      if (cpMatch != null) {
        counterparty = cpMatch.group(1)?.trim();
      }

      try {
        final txRepo = ref.read(localCanonicalTransactionRepositoryProvider);
        final idempotencyKey = requestId.isNotEmpty
            ? 'quick_entry_$requestId'
            : 'quick_${DateTime.now().millisecondsSinceEpoch}_$amountMinor';

        final tx = await txRepo.createTransaction(
          merchantId: activeMerchantId,
          amount: Money.formatPaise(amountMinor),
          transactionType: txType,
          paymentMode: 'CASH',
          counterpartyName: counterparty,
          description: 'Quick Entry: $text',
          sourceType: 'QUICK_ENTRY',
          idempotencyKey: idempotencyKey,
        );

        // Notify Android native confirmation shade to clear spinner and confirm
        await capture.notifyQuickEntrySuccess(tx.amount ?? amtStr, txType);

        if (mounted) {
          setState(() {});
        }
      } catch (e) {
        await capture
            .notifyQuickEntryFailure('Database error: ${e.toString()}');
      }
    });
  }

  @override
  void dispose() {
    _renderKeepAliveTimer?.cancel();
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
        _authStatus = hasMerchant
            ? LocalAuthStatus.locked
            : LocalAuthStatus.uninitialized;
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
      setState(
          () => _errorMessage = 'Please enter name and at least 4-digit PIN');
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
        AndroidDeviceEvidenceCapture().showQuickEntryNotification();
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
          // Show quick entry notification in Android shade upon successful merchant unlock
          AndroidDeviceEvidenceCapture().showQuickEntryNotification();
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
      _navigationStack.add(route);
      if (args != null) {
        _routeArgs.clear();
        _routeArgs.addAll(args);
      }
    });
  }

  void _popRoute() {
    setState(() {
      if (_navigationStack.length > 1) {
        _navigationStack.removeLast();
        _currentRoute = _navigationStack.last;
      } else {
        _currentRoute = '/';
        _navigationStack.clear();
        _navigationStack.add('/');
      }
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
                        color: isDark
                            ? AppColors.darkLavenderSurface
                            : AppColors.lightLavender,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        AppIcons.business,
                        size: 40,
                        color: isDark
                            ? AppColors.darkPrimaryPurple
                            : AppColors.primaryPurple,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('MeraVyapar AI',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    const Text('100% Private, On-Device Financial Intelligence',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13)),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                          labelText: 'Business Name',
                          hintText: 'e.g. Ramesh Kirana Store'),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _pinController,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Set 4-6 Digit Security PIN',
                          hintText: '••••'),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(_errorMessage!,
                          style:
                              const TextStyle(color: Colors.red, fontSize: 13)),
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
                        color: isDark
                            ? AppColors.darkLavenderSurface
                            : AppColors.lightLavender,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        AppIcons.lock,
                        size: 40,
                        color: isDark
                            ? AppColors.darkPrimaryPurple
                            : AppColors.primaryPurple,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Enter Security PIN',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    const Text(
                        'Your financial records remain encrypted on this phone.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13)),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _pinController,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Security PIN', hintText: '••••'),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(_errorMessage!,
                          style:
                              const TextStyle(color: Colors.red, fontSize: 13)),
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

    return PopScope(
      canPop: _currentRoute == '/',
      onPopInvoked: (didPop) {
        if (didPop) return;
        _popRoute();
      },
      child: _buildCurrentScreen(activeMerchantId),
    );
  }

  Widget _buildCurrentScreen(String merchantId) {
    switch (_currentRoute) {
      case '/intelligence':
        return UnifiedFinancialIntelligenceScreen(
          onBack: _popRoute,
          onNavigate: _navigateTo,
        );

      case '/reports':
        return IntelligentReportsScreen(
          merchantId: merchantId,
          onBack: _popRoute,
        );

      case '/assistant':
        final intelligenceRepo = ref.read(intelligenceRepositoryProvider);
        return Scaffold(
          appBar: AppBar(
            title: const Text('Nemotron AI Assistant'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _popRoute,
            ),
          ),
          body: MerchantAssistantScreen(
            isLoading: _isAssistantLoading,
            lastResult: _lastAssistantResult,
            initialQuery: _routeArgs['initial_question'],
            marketSignalTitle: _routeArgs['market_signal_title'],
            onQuerySubmit: (question) async {
              setState(() {
                _isAssistantLoading = true;
              });
              try {
                // Compute deterministic aggregates from local SQLite financial records
                final localFinEngine = LocalFinancialIntelligenceEngine();
                final pos = await localFinEngine.calculatePosition(merchantId: merchantId);
                final profileRepo = ref.read(localBusinessProfileRepositoryProvider);
                final authRepo = ref.read(localAuthRepositoryProvider);
                final profile = await profileRepo.getProfile(
                  merchantId: merchantId,
                  fallbackName: authRepo.currentSession?.displayName,
                );

                final attachedSignal = _routeArgs['signal'] as MerchantMarketRelevanceModel?;
                final marketSignalsList = <Map<String, dynamic>>[];
                if (attachedSignal != null) {
                  marketSignalsList.add({
                    'id': attachedSignal.id,
                    'title': attachedSignal.marketEvent?.title,
                    'summary': attachedSignal.marketEvent?.summary,
                    'price': attachedSignal.marketEvent?.price,
                    'rating': attachedSignal.marketEvent?.rating,
                    'location': attachedSignal.marketEvent?.location,
                    'source_name': attachedSignal.marketEvent?.source?.sourceName,
                    'source_url': attachedSignal.marketEvent?.source?.sourceUrl,
                    'relevance_explanation': attachedSignal.explanation,
                  });
                }

                final sanitizedContext = <String, dynamic>{
                  'business_name': profile.businessName,
                  'business_type': profile.businessType,
                  'business_category': profile.businessCategory,
                  'city': profile.city,
                  'state': profile.state,
                  'market_signals': marketSignalsList,
                  'computed_metrics': {
                    'total_inflows_paise': pos.totalInflowsPaise,
                    'total_outflows_paise': pos.totalOutflowsPaise,
                    'net_cash_movement_paise': pos.netCashMovementPaise,
                    'total_receivables_paise': pos.totalReceivablesPaise,
                    'total_overdue_receivables_paise': pos.totalOverdueReceivablesPaise,
                    'total_payables_paise': pos.totalPayablesPaise,
                    'open_promise_count': pos.openPromiseCount,
                    'overdue_promise_count': pos.overduePromiseCount,
                    'total_inflows_rupees': pos.totalInflowsPaise / 100,
                    'total_outflows_rupees': pos.totalOutflowsPaise / 100,
                    'net_cash_movement_rupees': pos.netCashMovementPaise / 100,
                    'total_receivables_rupees': pos.totalReceivablesPaise / 100,
                    'total_overdue_receivables_rupees': pos.totalOverdueReceivablesPaise / 100,
                    'total_payables_rupees': pos.totalPayablesPaise / 100,
                  },
                };

                final appLocale = ref.read(localeProvider);
                final result = await intelligenceRepo.queryIntelligence(
                  question: question,
                  sanitizedContext: sanitizedContext,
                  targetLanguage: appLocale.languageCode,
                );
                if (mounted) {
                  setState(() {
                    _lastAssistantResult = result;
                    _isAssistantLoading = false;
                  });
                }
              } catch (e) {
                if (mounted) {
                  setState(() {
                    _isAssistantLoading = false;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('AI Assistant Error: $e')),
                  );
                }
              }
            },
          ),
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
              onReceivableTap: (item) =>
                  _navigateTo('/receivables/detail', {'receivable': item}),
            );
          },
        );

      case '/receivables/detail':
        final item = _routeArgs['receivable'];
        return ReceivableDetailScreen(
          receivable: item,
          onBack: _popRoute,
          onReviewFollowUp: () {
            _navigateTo(
                '/actions/draft', {'promise_id': item.sourcePaymentPromiseId});
          },
          onCreateReminderDraft: () {
            _navigateTo(
                '/actions/draft', {'promise_id': item.sourcePaymentPromiseId});
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
              onTransactionTap: (tx) =>
                  _navigateTo('/transactions/detail', {'tx': tx}),
              onBack: _popRoute,
              onAddTransaction: () =>
                  _showManualEntryDialog(context, merchantId, txRepo),
              onImportStatement: () =>
                  _showStatementImportDialog(context, merchantId, txRepo),
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
              onBack: _popRoute,
              onCounterpartyTap: (cp) =>
                  _navigateTo('/relationships/detail', {'cp': cp}),
            );
          },
        );

      case '/relationships/detail':
        return CounterpartyDetailScreen(
          counterparty: _routeArgs['cp'],
          timeline: const [],
          onBack: _popRoute,
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
              onBack: _popRoute,
              onCreatePromise: (pData) async {
                await memRepo.createPaymentPromise(
                  merchantId: merchantId,
                  counterpartyName: pData['counterparty_name'] ?? 'Unknown',
                  amount: pData['amount'] ?? pData['promised_amount'] ?? '0',
                  direction: pData['direction'] ??
                      pData['promise_direction'] ??
                      'EXPECTED_INCOMING',
                  dueDate: pData['due_date'] ??
                      pData['due_at'] ??
                      DateTime.now().toUtc().toIso8601String(),
                  counterpartyId: pData['counterparty_id'],
                  notes: pData['notes'] ?? pData['description'],
                );
                setState(() {});
              },
              onFulfillPromise: (promiseId) async {
                await memRepo.fulfillPromise(
                    merchantId: merchantId, promiseId: promiseId);
                setState(() {});
              },
            );
          },
        );

      case '/market':
        final marketRepo = ref.read(marketIntelligenceRepositoryProvider);
        final profileRepo = ref.read(localBusinessProfileRepositoryProvider);
        final authRepo = ref.read(localAuthRepositoryProvider);
        final fallbackName = authRepo.currentSession?.displayName;

        return FutureBuilder<MerchantBusinessProfile?>(
          future: profileRepo.getProfile(
              merchantId: merchantId, fallbackName: fallbackName),
          builder: (context, snapshot) {
            final profile = snapshot.data;

            return RelevantMarketSignalsScreen(
              initialSignals: const [],
              merchantProfile: profile,
              onFetchSignals: ({
                String? query,
                String? category,
                String? businessType,
                String? city,
                String? state,
                String? engine,
                String? mapsType,
                String? placeId,
              }) =>
                  marketRepo.getRelevantSignals(
                    query: query,
                    category: category,
                    businessType: businessType,
                    city: city,
                    state: state,
                    engine: engine,
                    mapsType: mapsType,
                    placeId: placeId,
                  ),
              onBack: _popRoute,
              onOpenLocalSuppliers: () => _navigateTo('/market/suppliers'),
              onSignalTap: (sig) =>
                  _navigateTo('/market/detail', {'signal': sig}),
            );
          },
        );

      case '/market/detail':
        return MarketSignalDetailScreen(
          signal: _routeArgs['signal'],
          onBack: _popRoute,
          onAnalyzeWithFinancials: (sig) {
            final evTitle = sig.marketEvent?.title ?? 'Market Signal';
            _navigateTo('/assistant', {
              'signal': sig,
              'initial_question': 'How does "$evTitle" impact my business cashflow and payables?',
              'market_signal_title': evTitle,
            });
          },
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
          onBack: _popRoute,
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

      case '/market/suppliers':
        final marketRepo = ref.read(marketIntelligenceRepositoryProvider);
        final profileRepo = ref.read(localBusinessProfileRepositoryProvider);
        final authRepo = ref.read(localAuthRepositoryProvider);
        final fallbackName = authRepo.currentSession?.displayName;

        return FutureBuilder<MerchantBusinessProfile?>(
          future: profileRepo.getProfile(
              merchantId: merchantId, fallbackName: fallbackName),
          builder: (context, snapshot) {
            return LocalSupplierDiscoveryScreen(
              merchantId: merchantId,
              merchantProfile: snapshot.data,
              repository: marketRepo,
              onBack: _popRoute,
              onOpenShortlist: () => _navigateTo('/market/shortlist'),
            );
          },
        );

      case '/market/shortlist':
        return SupplierShortlistScreen(
          merchantId: merchantId,
          onBack: _popRoute,
          onExploreSuppliers: () => _navigateTo('/market/suppliers'),
        );

      default:
        return HomeShellScreen(
          onAddPaymentReceived: () => _showManualEntryDialog(context,
              merchantId, ref.read(localCanonicalTransactionRepositoryProvider),
              defaultType: 'CREDIT'),
          onAddExpense: () => _showManualEntryDialog(context, merchantId,
              ref.read(localCanonicalTransactionRepositoryProvider),
              defaultType: 'DEBIT'),
          onImportStatement: () => _showStatementImportDialog(
              context,
              merchantId,
              ref.read(localCanonicalTransactionRepositoryProvider)),
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
    final l10n = AppLocalizations.of(context);
    final amtCtrl = TextEditingController();
    final partyCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String txType = defaultType; // 'CREDIT' (Money In) or 'DEBIT' (Money Out)
    String paymentMode = 'CASH';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(l10n?.manualEntry ?? 'Add Manual Entry'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                      value: 'CREDIT',
                      label: Text(l10n != null ? '${l10n.moneyIn} (+)' : 'Income (+)'),
                    ),
                    ButtonSegment(
                      value: 'DEBIT',
                      label: Text(l10n != null ? '${l10n.moneyOut} (-)' : 'Expense (-)'),
                    ),
                  ],
                  selected: {txType},
                  onSelectionChanged: (val) {
                    setDialogState(() => txType = val.first);
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amtCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: '${l10n?.amount ?? 'Amount'} (₹)',
                    hintText: 'e.g. 500.00',
                    prefixText: '₹ ',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: partyCtrl,
                  decoration: InputDecoration(
                    labelText: l10n?.counterparty ?? 'Counterparty / Customer / Vendor',
                    hintText: 'e.g. Ramesh Kirana',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: paymentMode,
                  decoration: InputDecoration(labelText: l10n?.paymentMode ?? 'Payment Mode'),
                  items: [
                    DropdownMenuItem(value: 'CASH', child: Text(l10n?.cash ?? 'Cash')),
                    DropdownMenuItem(value: 'UPI', child: Text(l10n?.upi ?? 'UPI / QR')),
                    DropdownMenuItem(
                        value: 'BANK_TRANSFER',
                        child: Text(l10n?.bankTransfer ?? 'Bank Transfer / NEFT')),
                    DropdownMenuItem(value: 'CHEQUE', child: Text(l10n?.cheque ?? 'Cheque')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => paymentMode = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: InputDecoration(
                    labelText: '${l10n?.description ?? 'Notes / Description'} (Optional)',
                    hintText: 'e.g. Wholesale flour payment',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n?.cancel ?? 'Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final amtText = amtCtrl.text.trim();
                try {
                  if (Money.parseInrToPaise(amtText) <= 0) return;
                } on FormatException {
                  return;
                }

                await txRepo.createTransaction(
                  merchantId: merchantId,
                  amount: amtText,
                  transactionType: txType,
                  paymentMode: paymentMode,
                  counterpartyName: partyCtrl.text.trim().isEmpty
                      ? null
                      : partyCtrl.text.trim(),
                  description: descCtrl.text.trim().isEmpty
                      ? null
                      : descCtrl.text.trim(),
                  sourceType: 'MANUAL',
                );

                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
                if (mounted) {
                  ref.invalidate(financialPositionMetricsProvider);
                  ref.invalidate(cashFlowForecastProvider);
                  ref.invalidate(topCounterpartiesProvider);
                  setState(() {});
                }
              },
              child: Text(l10n?.save ?? 'Save Entry'),
            ),
          ],
        ),
      ),
    );
  }

  void _showStatementImportDialog(
    BuildContext context,
    String merchantId,
    LocalCanonicalTransactionRepository txRepo,
  ) {
    final statementService = StatementImportService(txRepo: txRepo);
    final captureService = AndroidDeviceEvidenceCapture();
    final rawTextCtrl = TextEditingController();
    String docName =
        'Statement_${DateTime.now().toIso8601String().substring(0, 10)}.csv';
    List<ExtractedStatementRecord> extractedRecords = [];
    bool isPreviewMode = false;
    bool isProcessing = false;
    bool showManualPaste = false;
    String? statusMessage;
    int totalCreditPaise = 0;
    int totalDebitPaise = 0;

    void updateTotals() {
      totalCreditPaise = 0;
      totalDebitPaise = 0;
      for (final rec in extractedRecords) {
        if (!rec.isSelected) continue;
        final int paise;
        try {
          paise = Money.parseInrToPaise(rec.amount);
        } on FormatException {
          continue;
        }
        if (rec.type == 'CREDIT') {
          totalCreditPaise += paise;
        } else {
          totalDebitPaise += paise;
        }
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.file_upload_outlined,
                  color: AppColors.primaryPurple),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isPreviewMode
                      ? 'Review Extracted Statement'
                      : 'Import Financial Statement',
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isPreviewMode) ...[
                    // Primary Document Picker Card
                    InkWell(
                      onTap: isProcessing
                          ? null
                          : () async {
                              setDialogState(() {
                                isProcessing = true;
                                statusMessage = null;
                              });

                              try {
                                final fileData =
                                    await captureService.pickDocument();
                                if (fileData == null) {
                                  setDialogState(() {
                                    isProcessing = false;
                                  });
                                  return;
                                }

                                final pickedName =
                                    fileData['fileName'] as String? ??
                                        'Imported_Statement';
                                final bytes =
                                    fileData['bytes'] as List<dynamic>?;
                                if (bytes == null || bytes.isEmpty) {
                                  setDialogState(() {
                                    isProcessing = false;
                                    statusMessage =
                                        'Could not read document contents';
                                  });
                                  return;
                                }

                                docName = pickedName;
                                final parseResult =
                                    statementService.parseDocumentBytes(
                                  bytes.cast<int>(),
                                  pickedName,
                                );

                                if (parseResult.records.isEmpty) {
                                  setDialogState(() {
                                    isProcessing = false;
                                    statusMessage =
                                        parseResult.diagnosticMessage ??
                                            'No transactions found in file';
                                  });
                                  return;
                                }

                                final evaluated =
                                    await statementService.detectDuplicates(
                                  merchantId: merchantId,
                                  candidates: parseResult.records,
                                );

                                setDialogState(() {
                                  extractedRecords = evaluated;
                                  updateTotals();
                                  isPreviewMode = true;
                                  isProcessing = false;
                                });
                              } catch (e) {
                                setDialogState(() {
                                  isProcessing = false;
                                  statusMessage =
                                      'Import error: ${e.toString()}';
                                });
                              }
                            },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3E8FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFFC084FC), width: 1.5),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: const BoxDecoration(
                                color: Color(0xFF7E22CE),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.file_present_rounded,
                                  color: Colors.white, size: 28),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'Choose PDF or CSV File',
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF581C87)),
                                  ),
                                  SizedBox(height: 3),
                                  Text(
                                    'Tap to select native bank statement from device storage (Storage Access Framework)',
                                    style: TextStyle(
                                        fontSize: 11, color: Color(0xFF7E22CE)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    if (statusMessage != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Text(
                          statusMessage!,
                          style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFB91C1C),
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Secondary Collapsible Text Paste
                    InkWell(
                      onTap: () {
                        setDialogState(() {
                          showManualPaste = !showManualPaste;
                        });
                      },
                      child: Row(
                        children: [
                          Icon(
                            showManualPaste
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            size: 18,
                            color: const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Or paste statement text manually',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),

                    if (showManualPaste) ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: rawTextCtrl,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Statement Text / Raw CSV',
                          hintText:
                              'Date,Description,Amount,Type\n2026-10-12,UPI/Rahul,1500.00,CREDIT\n2026-10-14,Wholesale Spices,420.00,DEBIT',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: isProcessing
                              ? null
                              : () async {
                                  final content = rawTextCtrl.text.trim();
                                  if (content.isEmpty) return;

                                  setDialogState(() => isProcessing = true);
                                  final parsed = statementService
                                      .parseStatementContent(content);
                                  if (parsed.isEmpty) {
                                    setDialogState(() {
                                      isProcessing = false;
                                      statusMessage =
                                          'No valid transaction records detected in pasted text';
                                    });
                                    return;
                                  }

                                  final evaluated =
                                      await statementService.detectDuplicates(
                                    merchantId: merchantId,
                                    candidates: parsed,
                                  );

                                  setDialogState(() {
                                    extractedRecords = evaluated;
                                    updateTotals();
                                    isPreviewMode = true;
                                    isProcessing = false;
                                  });
                                },
                          icon:
                              const Icon(Icons.arrow_forward_rounded, size: 16),
                          label: const Text('Parse Text'),
                        ),
                      ),
                    ],
                  ] else ...[
                    // Preview Summary Header
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Source: $docName',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 4),
                          Text(
                            'Detected: ${extractedRecords.length} records | Total Credit: +${Money.formatInr(totalCreditPaise)} | Total Debit: -${Money.formatInr(totalDebitPaise)}',
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFF475569)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...extractedRecords.map((rec) {
                      final isCredit = rec.type == 'CREDIT';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: rec.isPossibleDuplicate
                              ? const Color(0xFFFEF2F2)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: rec.isPossibleDuplicate
                                ? Colors.red.shade200
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: CheckboxListTile(
                          value: rec.isSelected,
                          onChanged: (val) {
                            setDialogState(() {
                              rec.isSelected = val ?? false;
                              updateTotals();
                            });
                          },
                          dense: true,
                          title: Row(
                            children: [
                              Text(
                                '${isCredit ? "+" : "-"} ₹${rec.amount}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isCredit
                                      ? AppColors.success
                                      : AppColors.error,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  rec.counterparty ?? rec.description,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Date: ${rec.date} • ${rec.description}',
                                  style: const TextStyle(fontSize: 11)),
                              if (rec.isPossibleDuplicate)
                                Text(
                                  '⚠ Possible Duplicate: ${rec.duplicateReason}',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.red.shade700,
                                      fontWeight: FontWeight.bold),
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isProcessing ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            if (isPreviewMode)
              FilledButton(
                onPressed: isProcessing
                    ? null
                    : () async {
                        setDialogState(() => isProcessing = true);
                        final count =
                            await statementService.persistConfirmedTransactions(
                          merchantId: merchantId,
                          confirmedRecords: extractedRecords,
                          sourceDocumentName: docName,
                        );

                        if (context.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(
                                    'Successfully imported $count transactions into private ledger')),
                          );
                          ref.invalidate(financialPositionMetricsProvider);
                          ref.invalidate(cashFlowForecastProvider);
                          ref.invalidate(topCounterpartiesProvider);
                          setState(() {});
                        }
                      },
                child: isProcessing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Confirm & Save'),
              ),
          ],
        ),
      ),
    );
  }
}
