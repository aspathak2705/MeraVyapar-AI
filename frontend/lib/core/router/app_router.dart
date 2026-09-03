import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/env.dart';
import '../presentation/configuration_required_screen.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/domain/auth_state.dart';
import '../../features/auth/presentation/auth_screen.dart';
import '../../features/onboarding/data/business_profile_repository.dart';
import '../../features/onboarding/domain/business_profile_model.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/home/presentation/home_shell_screen.dart';
import '../../features/evidence/data/evidence_repository.dart';
import '../../features/evidence/domain/evidence_model.dart';
import '../../features/evidence/domain/transaction_candidate_model.dart';
import '../../features/evidence/presentation/manual_entry_screen.dart';
import '../../features/evidence/presentation/file_upload_screen.dart';
import '../../features/evidence/presentation/evidence_history_screen.dart';
import '../../features/transactions/data/canonical_transaction_repository.dart';
import '../../features/transactions/domain/canonical_transaction_model.dart';
import '../../features/transactions/presentation/canonical_transactions_screen.dart';
import '../../features/transactions/presentation/canonical_transaction_detail_screen.dart';
import '../../features/capture/data/capture_repository.dart';
import '../../features/capture/domain/capture_setting_model.dart';
import '../../features/capture/presentation/capture_center_screen.dart';
import '../../features/capture/presentation/capture_settings_screen.dart';
import '../../features/memory/data/memory_repository.dart';
import '../../features/memory/domain/counterparty_model.dart';
import '../../features/memory/domain/payment_promise_model.dart';
import '../../features/memory/presentation/financial_relationships_screen.dart';
import '../../features/memory/presentation/counterparty_detail_screen.dart';
import '../../features/memory/presentation/payment_promises_screen.dart';

final authRepositoryProvider = Provider((ref) => AuthRepository());
final profileRepositoryProvider = Provider((ref) => BusinessProfileRepository());
final evidenceRepositoryProvider = Provider((ref) => EvidenceRepository());
final canonicalTransactionRepositoryProvider = Provider((ref) => CanonicalTransactionRepository());
final captureRepositoryProvider = Provider((ref) => CaptureRepository());
final memoryRepositoryProvider = Provider((ref) => MemoryRepository());

class AppRouter extends ConsumerStatefulWidget {
  const AppRouter({super.key});

  @override
  ConsumerState<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends ConsumerState<AppRouter> {
  AuthStatus _status = AuthStatus.unauthenticated;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (Env.isConfigured) {
      _checkInitialSession();
    }
  }

  Future<void> _checkInitialSession() async {
    setState(() => _isLoading = true);
    final authRepo = ref.read(authRepositoryProvider);

    if (authRepo.currentUser != null) {
      final isCompleted = await authRepo.isProfileCompleted();
      setState(() {
        _status = isCompleted ? AuthStatus.authenticated : AuthStatus.onboardingRequired;
        _isLoading = false;
      });
    } else {
      setState(() {
        _status = AuthStatus.unauthenticated;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleAuthSubmit(String email, String password, bool isSignUp) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authRepo = ref.read(authRepositoryProvider);
    try {
      if (isSignUp) {
        await authRepo.signUp(email, password);
      } else {
        await authRepo.signIn(email, password);
      }

      final isCompleted = await authRepo.isProfileCompleted();
      setState(() {
        _status = isCompleted ? AuthStatus.authenticated : AuthStatus.onboardingRequired;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _handleOnboardingSubmit(Map<String, String> profileData) async {
    setState(() => _isLoading = true);
    final profileRepo = ref.read(profileRepositoryProvider);

    try {
      final model = BusinessProfileModel(
        merchantId: '',
        businessName: profileData['business_name']!,
        businessType: profileData['business_type'],
        phoneNumber: profileData['phone_number'],
        city: profileData['city'],
        state: profileData['state'],
      );

      await profileRepo.saveProfile(model);
      setState(() {
        _status = AuthStatus.authenticated;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _handleSignOut() async {
    final authRepo = ref.read(authRepositoryProvider);
    await authRepo.signOut();
    setState(() {
      _status = AuthStatus.unauthenticated;
    });
  }

  void _openManualEntry(BuildContext context, String direction) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ManualEntryScreen(
          initialDirection: direction,
          onSubmit: (data) async {
            final repo = ref.read(evidenceRepositoryProvider);
            await repo.submitManualEvidence(
              amount: data['amount']!,
              transactionType: data['transaction_type']!,
              description: data['description'],
              counterpartyName: data['counterparty_name'],
              paymentMode: data['payment_mode'],
            );
            if (context.mounted) {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Financial evidence recorded successfully')),
              );
            }
          },
        ),
      ),
    );
  }

  void _openFileUpload(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FileUploadScreen(
          onUploadPressed: () {
            if (context.mounted) {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Payment proof queued for evidence processing')),
              );
            }
          },
        ),
      ),
    );
  }

  void _openHistory(BuildContext context) async {
    final repo = ref.read(evidenceRepositoryProvider);
    List<EvidenceModel> list = [];
    List<TransactionCandidateModel> cands = [];
    try {
      list = await repo.getEvidenceList();
      cands = await repo.getCandidateList();
    } catch (_) {}

    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => EvidenceHistoryScreen(
            evidenceList: list,
            candidateList: cands,
          ),
        ),
      );
    }
  }

  void _openCanonicalTransactions(BuildContext context) async {
    final repo = ref.read(canonicalTransactionRepositoryProvider);
    List<CanonicalTransactionModel> list = [];
    try {
      list = await repo.getCanonicalTransactions();
    } catch (_) {}

    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (ctx) => CanonicalTransactionsScreen(
            transactions: list,
            onRunReconciliation: () async {
              await repo.runReconciliation();
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Reconciliation pass complete')),
                );
              }
            },
            onTransactionTap: (tx) {
              Navigator.of(ctx).push(
                MaterialPageRoute(
                  builder: (_) => CanonicalTransactionDetailScreen(transaction: tx),
                ),
              );
            },
          ),
        ),
      );
    }
  }

  void _openCaptureSettings(BuildContext context, String title, String sourceType) async {
    final repo = ref.read(captureRepositoryProvider);
    List<CaptureSourceSettingModel> settings = [];
    try {
      settings = await repo.getCaptureSettings();
    } catch (_) {}

    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (ctx) => StatefulBuilder(
            builder: (ctxState, setModalState) {
              return CaptureSettingsScreen(
                title: title,
                sourceType: sourceType,
                settings: settings,
                onToggleSetting: (provider, enabled) async {
                  await repo.updateCaptureSetting(
                    sourceType: sourceType,
                    providerIdentifier: provider,
                    enabled: enabled,
                  );
                  final updated = await repo.getCaptureSettings();
                  setModalState(() {
                    settings = updated;
                  });
                },
              );
            },
          ),
        ),
      );
    }
  }

  void _openCaptureCenter(BuildContext context) {
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CaptureCenterScreen(
          isAndroidPlatform: isAndroid,
          onAddManual: () => _openManualEntry(context, 'MONEY_OUT'),
          onShareProof: () => _openFileUpload(context),
          onOpenNotificationSettings: () => _openCaptureSettings(
            context, 'Payment Notification Settings', 'NOTIFICATION_CAPTURE'
          ),
          onOpenSmsSettings: () => _openCaptureSettings(
            context, 'Banking SMS Settings', 'SMS_CAPTURE'
          ),
        ),
      ),
    );
  }

  void _openRelationships(BuildContext context) async {
    final repo = ref.read(memoryRepositoryProvider);
    List<CounterpartyModel> cps = [];
    try {
      cps = await repo.getCounterparties();
    } catch (_) {}

    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (ctx) => FinancialRelationshipsScreen(
            counterparties: cps,
            onCounterpartyTap: (cp) async {
              List<FinancialRelationshipEventModel> timeline = [];
              try {
                timeline = await repo.getCounterpartyTimeline(cp.id);
              } catch (_) {}
              if (ctx.mounted) {
                Navigator.of(ctx).push(
                  MaterialPageRoute(
                    builder: (_) => CounterpartyDetailScreen(counterparty: cp, timeline: timeline),
                  ),
                );
              }
            },
          ),
        ),
      );
    }
  }

  void _openPromises(BuildContext context) async {
    final repo = ref.read(memoryRepositoryProvider);
    List<PaymentPromiseModel> promises = [];
    List<CounterpartyModel> cps = [];
    try {
      promises = await repo.getPaymentPromises();
      cps = await repo.getCounterparties();
    } catch (_) {}

    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (ctx) => StatefulBuilder(
            builder: (ctxState, setModalState) {
              return PaymentPromisesScreen(
                promises: promises,
                counterparties: cps,
                onCreatePromise: (data) async {
                  await repo.createPaymentPromise(
                    counterpartyId: data['counterparty_id'],
                    description: data['description']!,
                    promisedAmount: data['promised_amount']!,
                    promiseDirection: data['promise_direction']!,
                    dueAt: data['due_at']!,
                  );
                  final updated = await repo.getPaymentPromises();
                  setModalState(() {
                    promises = updated;
                  });
                },
                onFulfillPromise: (promiseId) async {
                  await repo.fulfillPromise(promiseId);
                  final updated = await repo.getPaymentPromises();
                  setModalState(() {
                    promises = updated;
                  });
                },
              );
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!Env.isConfigured) {
      return const ConfigurationRequiredScreen();
    }

    if (_isLoading && _status == AuthStatus.unauthenticated) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    switch (_status) {
      case AuthStatus.unauthenticated:
        return AuthScreen(
          onSubmit: _handleAuthSubmit,
          isLoading: _isLoading,
          errorMessage: _errorMessage,
        );
      case AuthStatus.onboardingRequired:
        return OnboardingScreen(
          onSubmit: _handleOnboardingSubmit,
          isLoading: _isLoading,
        );
      case AuthStatus.authenticated:
        return HomeShellScreen(
          onSignOut: _handleSignOut,
          onAddPaymentReceived: () => _openManualEntry(context, 'MONEY_IN'),
          onAddExpense: () => _openManualEntry(context, 'MONEY_OUT'),
          onUploadProof: () => _openFileUpload(context),
          onViewHistory: () => _openHistory(context),
          onViewReconciledTransactions: () => _openCanonicalTransactions(context),
          onOpenCaptureCenter: () => _openCaptureCenter(context),
          onOpenRelationships: () => _openRelationships(context),
          onOpenPromises: () => _openPromises(context),
        );
    }
  }
}
