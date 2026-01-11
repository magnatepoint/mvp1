import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  Supabase get _supabase => Supabase.instance;

  // Get current user
  User? get currentUser => _supabase.client.auth.currentUser;
  
  // Get current session
  Session? get currentSession => _supabase.client.auth.currentSession;
  
  // Check if user is authenticated
  bool get isAuthenticated => currentUser != null;

  // Sign in with email and password
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await _supabase.client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // Sign up with email and password
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    return await _supabase.client.auth.signUp(
      email: email,
      password: password,
    );
  }

  // Sign in with Google
  Future<bool> signInWithGoogle() async {
    try {
      debugPrint('Starting Google OAuth flow...');
      await _supabase.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.monytix://login-callback/',
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
      debugPrint('OAuth flow initiated. Waiting for callback...');
      // The OAuth flow will complete via deep link callback
      // The auth state listener will handle the session update
      return true;
    } catch (e) {
      debugPrint('OAuth sign in error: $e');
      return false;
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _supabase.client.auth.signOut();
  }

  // Listen to auth state changes
  Stream<AuthState> get authStateChanges => _supabase.client.auth.onAuthStateChange;
}

