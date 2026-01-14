package com.example.apk.auth

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import io.github.jan.supabase.gotrue.user.UserInfo
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.launch
import kotlinx.coroutines.delay

class AuthViewModel(
    context: Context? = null,
    private val authService: AuthService = try { AuthService(context) } catch (e: Exception) {
        android.util.Log.e("AuthViewModel", "Failed to create AuthService", e)
        throw RuntimeException("Failed to initialize authentication service: ${e.message}", e)
    }
) : ViewModel() {
    private val _user = MutableStateFlow<UserInfo?>(null)
    val user: StateFlow<UserInfo?> = _user.asStateFlow()

    private val _session = MutableStateFlow<Any?>(null) // Using Any? temporarily until Session type is resolved
    val session: StateFlow<Any?> = _session.asStateFlow()

    private val _isLoading = MutableStateFlow(true)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage.asStateFlow()

    val isAuthenticated: Boolean
        get() = _user.value != null

    val userEmail: String?
        get() = _user.value?.email

    init {
        initialize()
    }

    private fun initialize() {
        viewModelScope.launch {
            try {
                _user.value = authService.getCurrentUser()
                _session.value = authService.getCurrentSession()
            } catch (e: Exception) {
                android.util.Log.e("AuthViewModel", "Error during initialization", e)
                // Set error message but don't crash
                _errorMessage.value = "Initialization error: ${e.message}"
            } finally {
                _isLoading.value = false
            }

            // Listen to auth state changes
            try {
                authService.authStateChanges()
                    .catch { e ->
                        android.util.Log.e("AuthViewModel", "Error in auth state flow", e)
                        // Handle errors in auth state flow
                    }
                    .collect { authStateChange ->
                        when (authStateChange.event) {
                            AuthEvent.SIGNED_IN, AuthEvent.TOKEN_REFRESHED -> {
                                _user.value = authStateChange.user
                                _session.value = authStateChange.session
                            }
                            AuthEvent.SIGNED_OUT -> {
                                _user.value = null
                                _session.value = null
                            }
                            AuthEvent.USER_UPDATED -> {
                                _user.value = authStateChange.user
                            }
                            else -> {
                                // Handle other events if needed
                            }
                        }
                    }
            } catch (e: Exception) {
                android.util.Log.e("AuthViewModel", "Error setting up auth state listener", e)
            }
        }
    }

    fun signIn(email: String, password: String) {
        viewModelScope.launch {
            _isLoading.value = true
            _errorMessage.value = null
            try {
                android.util.Log.d("AuthViewModel", "Attempting sign in for: $email")
                val session = authService.signInWithEmail(email, password)
                _session.value = session
                
                // Small delay to ensure session is fully set
                delay(100)
                
                // Fetch current user from Supabase after sign-in
                val currentUser = authService.getCurrentUser()
                _user.value = currentUser
                
                if (currentUser != null) {
                    android.util.Log.d("AuthViewModel", "Sign in successful. User: ${currentUser.email}")
                } else {
                    android.util.Log.w("AuthViewModel", "Sign in completed but user is null")
                    _errorMessage.value = "Sign in completed but user information is not available"
                }
            } catch (e: Exception) {
                android.util.Log.e("AuthViewModel", "Sign in failed", e)
                _errorMessage.value = e.message ?: "Sign in failed: ${e.javaClass.simpleName}"
            } finally {
                _isLoading.value = false
            }
        }
    }

    fun signUp(email: String, password: String) {
        viewModelScope.launch {
            _isLoading.value = true
            _errorMessage.value = null
            try {
                android.util.Log.d("AuthViewModel", "Attempting sign up for: $email")
                val session = authService.signUpWithEmail(email, password)
                _session.value = session
                
                // Small delay to ensure session is fully set
                delay(100)
                
                // Fetch current user from Supabase after sign-up
                val currentUser = authService.getCurrentUser()
                _user.value = currentUser
                
                if (currentUser != null) {
                    android.util.Log.d("AuthViewModel", "Sign up successful. User: ${currentUser.email}")
                } else {
                    android.util.Log.w("AuthViewModel", "Sign up completed but user is null")
                    _errorMessage.value = "Registration completed but user information is not available"
                }
            } catch (e: Exception) {
                android.util.Log.e("AuthViewModel", "Sign up failed", e)
                _errorMessage.value = e.message ?: "Registration failed: ${e.javaClass.simpleName}"
            } finally {
                _isLoading.value = false
            }
        }
    }

    fun signInWithGoogle() {
        viewModelScope.launch {
            _isLoading.value = true
            _errorMessage.value = null
            try {
                android.util.Log.d("AuthViewModel", "Starting Google OAuth flow")
                val result = authService.signInWithGoogle()
                result.onFailure { e ->
                    android.util.Log.e("AuthViewModel", "Google sign in failed", e)
                    _errorMessage.value = e.message ?: "Google sign in failed"
                    _isLoading.value = false
                }
                // OAuth flow will complete via deep link, auth state listener will update session
                // Don't set loading to false here - wait for callback
            } catch (e: Exception) {
                android.util.Log.e("AuthViewModel", "Google sign in error", e)
                _errorMessage.value = e.message ?: "Google sign in failed"
                _isLoading.value = false
            }
        }
    }
    
    fun handleOAuthCallback(url: String) {
        viewModelScope.launch {
            _isLoading.value = true
            _errorMessage.value = null
            try {
                android.util.Log.d("AuthViewModel", "Handling OAuth callback: $url")
                val user = authService.handleOAuthCallback(url)
                if (user != null) {
                    _user.value = user
                    _session.value = authService.getCurrentSession()
                    android.util.Log.d("AuthViewModel", "OAuth callback successful. User: ${user.email}")
                } else {
                    android.util.Log.w("AuthViewModel", "OAuth callback completed but user is null")
                    _errorMessage.value = "OAuth sign in completed but user information is not available"
                }
            } catch (e: Exception) {
                android.util.Log.e("AuthViewModel", "Error handling OAuth callback", e)
                _errorMessage.value = e.message ?: "OAuth callback failed"
            } finally {
                _isLoading.value = false
            }
        }
    }

    fun signOut() {
        viewModelScope.launch {
            _isLoading.value = true
            try {
                authService.signOut()
                _user.value = null
                _session.value = null
            } catch (e: Exception) {
                _errorMessage.value = e.message ?: "Sign out failed"
            } finally {
                _isLoading.value = false
            }
        }
    }

    fun clearError() {
        _errorMessage.value = null
    }
}

