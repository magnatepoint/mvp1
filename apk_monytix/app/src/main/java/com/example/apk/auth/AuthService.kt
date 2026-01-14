package com.example.apk.auth

import com.example.apk.config.Config
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.createSupabaseClient
import android.content.Context
import io.github.jan.supabase.gotrue.Auth
import io.github.jan.supabase.gotrue.auth // Extension property for supabase.auth
import io.github.jan.supabase.gotrue.providers.builtin.Email
import io.github.jan.supabase.gotrue.user.UserInfo
import io.github.jan.supabase.postgrest.Postgrest
import kotlinx.coroutines.flow.Flow

class AuthService(private val context: Context? = null) {
    val supabase: SupabaseClient by lazy {
        try {
            createSupabaseClient(
                supabaseUrl = Config.SUPABASE_URL,
                supabaseKey = Config.SUPABASE_ANON_KEY
            ) {
                install(Auth) {
                    // Configure auth options if needed
                }
                install(Postgrest)
            }
        } catch (e: Exception) {
            // Log error and rethrow to prevent silent failures
            android.util.Log.e("AuthService", "Failed to initialize Supabase client", e)
            throw RuntimeException("Failed to initialize Supabase: ${e.message}", e)
        }
    }

    // Get current user
    suspend fun getCurrentUser(): UserInfo? {
        return try {
            val user = supabase.auth.currentUserOrNull()
            android.util.Log.d("AuthService", "Current user: ${user?.email ?: "null"}")
            user
        } catch (e: Exception) {
            android.util.Log.e("AuthService", "Error getting current user", e)
            null
        }
    }

    // Get current session
    suspend fun getCurrentSession() = try {
        supabase.auth.currentSessionOrNull()
    } catch (e: Exception) {
        null
    }

    // Check if user is authenticated
    suspend fun isAuthenticated(): Boolean {
        return getCurrentUser() != null
    }

    // Sign in with email and password
    suspend fun signInWithEmail(email: String, password: String) = try {
        android.util.Log.d("AuthService", "Signing in with email: $email")
        val session = supabase.auth.signInWith(Email) {
            this.email = email
            this.password = password
        }
        android.util.Log.d("AuthService", "Sign in successful")
        session
    } catch (e: Exception) {
        android.util.Log.e("AuthService", "Sign in error", e)
        throw e
    }

    // Sign up with email and password
    suspend fun signUpWithEmail(email: String, password: String) = try {
        android.util.Log.d("AuthService", "Signing up with email: $email")
        val session = supabase.auth.signUpWith(Email) {
            this.email = email
            this.password = password
        }
        android.util.Log.d("AuthService", "Sign up successful")
        session
    } catch (e: Exception) {
        android.util.Log.e("AuthService", "Sign up error", e)
        throw e
    }

    // Sign in with Google
    suspend fun signInWithGoogle(redirectUrl: String = Config.OAUTH_REDIRECT_URL): Result<Unit> {
        return try {
            android.util.Log.d("AuthService", "Starting Google OAuth flow with redirect: $redirectUrl")
            
            if (context == null) {
                return Result.failure(Exception("Context is required for OAuth flow"))
            }
            
            // Build OAuth URL manually since SDK OAuth API may not be available
            val oauthUrl = "${Config.SUPABASE_URL}/auth/v1/authorize?" +
                    "provider=google&" +
                    "redirect_to=${java.net.URLEncoder.encode(redirectUrl, "UTF-8")}"
            
            android.util.Log.d("AuthService", "Opening OAuth URL: $oauthUrl")
            
            // Open browser for OAuth
            val intent = android.content.Intent(android.content.Intent.ACTION_VIEW, android.net.Uri.parse(oauthUrl))
            intent.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
            
            android.util.Log.d("AuthService", "OAuth flow initiated successfully")
            Result.success(Unit)
        } catch (e: Exception) {
            android.util.Log.e("AuthService", "OAuth sign-in error", e)
            Result.failure(e)
        }
    }

    // Sign out
    suspend fun signOut() {
        supabase.auth.signOut()
    }

    // Listen to auth state changes
    fun authStateChanges(): Flow<AuthStateChange> {
        // TODO: Implement auth state changes listener when Supabase SDK API is available
        return kotlinx.coroutines.flow.flowOf(
            AuthStateChange(
                event = AuthEvent.UNKNOWN,
                session = null,
                user = null
            )
        )
    }

    // Handle OAuth callback URL
    suspend fun handleOAuthCallback(url: String): UserInfo? {
        return try {
            android.util.Log.d("AuthService", "Handling OAuth callback: $url")
            
            val uri = android.net.Uri.parse(url)
            val code = uri.getQueryParameter("code")
            val error = uri.getQueryParameter("error")
            val errorDescription = uri.getQueryParameter("error_description")
            
            if (error != null) {
                android.util.Log.e("AuthService", "OAuth error: $error - $errorDescription")
                return null
            }
            
            // For now, just check if we have a session after callback
            // The browser OAuth flow should have completed
            // In a production app, you'd exchange the code here using Supabase REST API
            kotlinx.coroutines.delay(500) // Small delay to allow session to be set
            
            val user = supabase.auth.currentUserOrNull()
            if (user != null) {
                android.util.Log.d("AuthService", "OAuth callback handled successfully. User: ${user.email}")
            } else {
                android.util.Log.w("AuthService", "OAuth callback completed but user is null. Code: $code")
                android.util.Log.w("AuthService", "Note: OAuth code exchange needs to be implemented")
            }
            user
        } catch (e: Exception) {
            android.util.Log.e("AuthService", "Error handling OAuth callback", e)
            null
        }
    }
}

enum class AuthEvent {
    SIGNED_IN,
    SIGNED_OUT,
    USER_UPDATED,
    TOKEN_REFRESHED,
    UNKNOWN
}

data class AuthStateChange(
    val event: AuthEvent,
    val session: Any?, // Using Any? temporarily until Session type is resolved
    val user: UserInfo?
)
