import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/api/api_client.dart';

class AuthRepository {
  final SupabaseClient? _supabase;
  final ApiClient _apiClient;

  AuthRepository({
    SupabaseClient? supabase,
    ApiClient? apiClient,
  })  : _supabase = supabase ?? _getSupabaseClientSafely(),
        _apiClient = apiClient ?? ApiClient();

  static SupabaseClient? _getSupabaseClientSafely() {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  User? get currentUser {
    try {
      return _supabase?.auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  Session? get currentSession {
    try {
      return _supabase?.auth.currentSession;
    } catch (_) {
      return null;
    }
  }

  Future<AuthResponse> signUp(String email, String password) async {
    if (_supabase == null) {
      throw Exception("Supabase is not initialized. Environment configuration required.");
    }
    final res = await _supabase!.auth.signUp(
      email: email,
      password: password,
    );
    if (res.user != null) {
      await _initializeBackendMerchant(res.user!.id);
    }
    return res;
  }

  Future<AuthResponse> signIn(String email, String password) async {
    if (_supabase == null) {
      throw Exception("Supabase is not initialized. Environment configuration required.");
    }
    final res = await _supabase!.auth.signInWithPassword(
      email: email,
      password: password,
    );
    if (res.user != null) {
      await _initializeBackendMerchant(res.user!.id);
    }
    return res;
  }

  Future<void> signOut() async {
    try {
      await _supabase?.auth.signOut();
    } catch (_) {}
  }

  Future<Map<String, dynamic>> _initializeBackendMerchant(String userId) async {
    return await _apiClient.post('/merchants/initialize');
  }

  Future<bool> isProfileCompleted() async {
    try {
      final res = await _apiClient.get('/business-profile/me');
      final data = res['data'];
      return data != null && (data['onboarding_completed'] == true);
    } catch (_) {
      return false;
    }
  }
}
