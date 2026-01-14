package com.example.apk

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import androidx.compose.foundation.layout.*
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.apk.auth.AuthViewModel
import com.example.apk.auth.AuthViewModelFactory
import com.example.apk.auth.LoginScreen
import com.example.apk.ui.theme.ApkTheme
import com.example.apk.ui.theme.Charcoal
import com.example.apk.ui.theme.Gold
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {
    private val authViewModel: AuthViewModel by viewModels { 
        AuthViewModelFactory(applicationContext) 
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        try {
            enableEdgeToEdge()
            
            // Handle OAuth deep link if app was opened via intent
            handleIntent(intent)
            
            setContent {
                ApkTheme {
                    AuthWrapper(
                        authViewModel = authViewModel,
                        onOAuthCallback = { uri ->
                            handleOAuthCallback(uri)
                        }
                    )
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Error in onCreate", e)
            // Show error screen instead of crashing
            setContent {
                ApkTheme {
                    Box(
                        modifier = Modifier.fillMaxSize(),
                        contentAlignment = Alignment.Center
                    ) {
                        Column(
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.spacedBy(16.dp)
                        ) {
                            Text(
                                text = "App initialization error",
                                color = androidx.compose.ui.graphics.Color.White
                            )
                            Text(
                                text = e.message ?: "Unknown error",
                                color = androidx.compose.ui.graphics.Color.White.copy(alpha = 0.7f)
                            )
                        }
                    }
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        intent?.data?.let { uri ->
            if (uri.scheme == "com.example.apk" && uri.host == "login-callback") {
                handleOAuthCallback(uri)
            }
        }
    }

    private fun handleOAuthCallback(uri: Uri) {
        android.util.Log.d("MainActivity", "Received OAuth callback: $uri")
        authViewModel.handleOAuthCallback(uri.toString())
    }
}

@Composable
fun AuthWrapper(
    authViewModel: AuthViewModel = viewModel(),
    onOAuthCallback: (Uri) -> Unit = {}
) {
    val isLoading by authViewModel.isLoading.collectAsStateWithLifecycle()
    val user by authViewModel.user.collectAsStateWithLifecycle()
    val isAuthenticated = user != null

    when {
        isLoading -> {
            // Loading state
            Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = Alignment.Center
            ) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    CircularProgressIndicator(
                        color = Gold
                    )
                    Text(
                        text = "Loading...",
                        color = androidx.compose.ui.graphics.Color.White
                    )
                }
            }
        }
        isAuthenticated -> {
            // Main content when authenticated
            com.example.apk.MainScreen(authViewModel = authViewModel)
        }
        else -> {
            // Login screen when not authenticated
            LoginScreen(
                viewModel = authViewModel,
                onSignInSuccess = {
                    // Navigation will happen automatically via state change
                }
            )
        }
    }
}
