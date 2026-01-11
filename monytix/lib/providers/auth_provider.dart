import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService();
  
  User? _user;
  Session? _session;
  bool _isLoading = true;

  User? get user => _user;
  Session? get session => _session;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;

  AuthProvider() {
    _initialize();
  }

  void _initialize() {
    // Check for existing session
    _user = _authService.currentUser;
    _session = _authService.currentSession;
    
    if (_session != null) {
      _apiService.setAuthToken(_session!.accessToken);
    }
    
    _isLoading = false;
    notifyListeners();

    // Listen to auth state changes
    _authService.authStateChanges.listen((AuthState state) {
      debugPrint('Auth state changed: ${state.event}, has session: ${state.session != null}');
      
      _session = state.session;
      _user = state.session?.user;
      
      if (_session != null) {
        debugPrint('Setting auth token in ApiService. Token length: ${_session!.accessToken.length}');
        _apiService.setAuthToken(_session!.accessToken);
        debugPrint('Auth token set successfully');
      } else {
        debugPrint('No session, clearing auth token');
        _apiService.setAuthToken(null);
      }
      
      notifyListeners();
    });

    // Note: Supabase Flutter SDK automatically handles OAuth deep links
    // via Supabase.initialize() with the redirect URL configured
    // The auth state listener will automatically pick up session changes
    // No need to manually handle deep links for OAuth
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> signIn(String email, String password) async {
    try {
      final response = await _authService.signInWithEmail(
        email: email,
        password: password,
      );
      
      if (response.session != null) {
        _session = response.session;
        _user = response.session!.user;
        _apiService.setAuthToken(response.session!.accessToken);
        notifyListeners();
      } else {
        throw Exception('Sign in failed');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signUp(String email, String password) async {
    try {
      final response = await _authService.signUpWithEmail(
        email: email,
        password: password,
      );
      
      if (response.session != null) {
        _session = response.session;
        _user = response.session!.user;
        _apiService.setAuthToken(response.session!.accessToken);
        notifyListeners();
      } else {
        throw Exception('Registration failed');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      debugPrint('Starting Google OAuth sign in...');
      await _authService.signInWithGoogle();
      debugPrint('OAuth flow initiated. Waiting for session...');
      
      // Wait a bit for the OAuth callback to complete
      // The auth state listener will update the session automatically
      await Future.delayed(const Duration(seconds: 2));
      
      // Check if session was created
      final session = _authService.currentSession;
      if (session != null) {
        debugPrint('Session created after OAuth! User ID: ${session.user.id}');
        _session = session;
        _user = session.user;
        _apiService.setAuthToken(session.accessToken);
        notifyListeners();
      } else {
        debugPrint('No session yet after OAuth. Waiting for auth state change...');
      }
    } catch (e) {
      debugPrint('Error in signInWithGoogle: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    debugPrint('Signing out user...');
    try {
      await _authService.signOut();
      _user = null;
      _session = null;
      _apiService.setAuthToken(null);
      debugPrint('User signed out successfully');
      notifyListeners();
    } catch (e) {
      debugPrint('Error signing out: $e');
      // Even if sign out fails, clear local state
      _user = null;
      _session = null;
      _apiService.setAuthToken(null);
      notifyListeners();
      rethrow;
    }
  }
}

