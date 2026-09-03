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

final authRepositoryProvider = Provider((ref) => AuthRepository());
final profileRepositoryProvider = Provider((ref) => BusinessProfileRepository());
final evidenceRepositoryProvider = Provider((ref) => EvidenceRepository());
final canonicalTransactionRepositoryProvider = Provider((ref) => CanonicalTransactionRepository());

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
        );
    }
  }
}
