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

final authRepositoryProvider = Provider((ref) => AuthRepository());
final profileRepositoryProvider = Provider((ref) => BusinessProfileRepository());

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
        merchantId: '', // Set by backend context
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
        );
    }
  }
}
