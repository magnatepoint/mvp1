package com.example.apk.auth

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material.icons.filled.VisibilityOff
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.apk.ui.theme.Charcoal
import com.example.apk.ui.theme.DarkCharcoal
import com.example.apk.ui.theme.Gold
import com.example.apk.ui.theme.TextPrimary

@Composable
fun LoginScreen(
    viewModel: AuthViewModel = viewModel(),
    onSignInSuccess: () -> Unit
) {
    var isSignIn by remember { mutableStateOf(true) }
    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var confirmPassword by remember { mutableStateOf("") }
    var showPassword by remember { mutableStateOf(false) }
    var showConfirmPassword by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }

    val uiState by viewModel.isLoading.collectAsStateWithLifecycle()
    val authError by viewModel.errorMessage.collectAsStateWithLifecycle()
    val user by viewModel.user.collectAsStateWithLifecycle()
    val isAuthenticated = user != null

    // Navigate when authenticated
    LaunchedEffect(isAuthenticated) {
        if (isAuthenticated) {
            onSignInSuccess()
        }
    }

    // Show error from ViewModel
    LaunchedEffect(authError) {
        authError?.let { errorMessage = it }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Charcoal)
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            Spacer(modifier = Modifier.height(40.dp))

            // Logo - using text for now, can be replaced with image asset
            Text(
                text = "monyTIX",
                fontSize = 32.sp,
                fontWeight = FontWeight.Bold,
                color = Gold,
                modifier = Modifier.padding(bottom = 16.dp)
            )

            // Tabs
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                TabButton(
                    title = "Sign in",
                    isActive = isSignIn,
                    onClick = { isSignIn = true },
                    modifier = Modifier.weight(1f)
                )
                TabButton(
                    title = "Register",
                    isActive = !isSignIn,
                    onClick = { isSignIn = false },
                    modifier = Modifier.weight(1f)
                )
            }

            Spacer(modifier = Modifier.height(16.dp))

            // Title
            Text(
                text = if (isSignIn) "Sign in" else "Register",
                fontSize = 28.sp,
                fontWeight = FontWeight.Bold,
                color = TextPrimary
            )

            Text(
                text = if (isSignIn)
                    "Secure entry into your AI fintech console"
                else
                    "Launch your AI fintech cockpit in under a minute",
                fontSize = 14.sp,
                color = TextPrimary.copy(alpha = 0.8f),
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(bottom = 16.dp)
            )

            // Email field
            OutlinedTextField(
                value = email,
                onValueChange = { email = it },
                label = { Text("Email") },
                leadingIcon = {
                    Icon(Icons.Default.Email, contentDescription = null, tint = TextPrimary.copy(alpha = 0.7f))
                },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email),
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
                colors = textFieldColors()
            )

            // Password field
            OutlinedTextField(
                value = password,
                onValueChange = { password = it },
                label = { Text("Password") },
                leadingIcon = {
                    Icon(Icons.Default.Lock, contentDescription = null, tint = TextPrimary.copy(alpha = 0.7f))
                },
                trailingIcon = {
                    IconButton(onClick = { showPassword = !showPassword }) {
                        Icon(
                            if (showPassword) Icons.Default.VisibilityOff else Icons.Default.Visibility,
                            contentDescription = if (showPassword) "Hide password" else "Show password",
                            tint = TextPrimary.copy(alpha = 0.7f)
                        )
                    }
                },
                visualTransformation = if (showPassword) VisualTransformation.None else PasswordVisualTransformation(),
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
                colors = textFieldColors()
            )

            // Confirm Password (only for registration)
            if (!isSignIn) {
                OutlinedTextField(
                    value = confirmPassword,
                    onValueChange = { confirmPassword = it },
                    label = { Text("Confirm Password") },
                    leadingIcon = {
                        Icon(Icons.Default.Lock, contentDescription = null, tint = TextPrimary.copy(alpha = 0.7f))
                    },
                    trailingIcon = {
                        IconButton(onClick = { showConfirmPassword = !showConfirmPassword }) {
                            Icon(
                                if (showConfirmPassword) Icons.Default.VisibilityOff else Icons.Default.Visibility,
                                contentDescription = if (showConfirmPassword) "Hide password" else "Show password",
                                tint = TextPrimary.copy(alpha = 0.7f)
                            )
                        }
                    },
                    visualTransformation = if (showConfirmPassword) VisualTransformation.None else PasswordVisualTransformation(),
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                    colors = textFieldColors()
                )
            }

            // Error message
            errorMessage?.let { error ->
                Text(
                    text = error,
                    color = MaterialTheme.colorScheme.error,
                    fontSize = 14.sp,
                    modifier = Modifier.padding(vertical = 8.dp)
                )
            }

            // Submit button
            Button(
                onClick = {
                    errorMessage = null
                    viewModel.clearError()
                    if (isSignIn) {
                        if (email.isNotEmpty() && password.isNotEmpty()) {
                            viewModel.signIn(email, password)
                        } else {
                            errorMessage = "Please fill in all fields"
                        }
                    } else {
                        if (email.isNotEmpty() && password.isNotEmpty() && confirmPassword.isNotEmpty()) {
                            if (password == confirmPassword) {
                                if (password.length >= 6) {
                                    viewModel.signUp(email, password)
                                } else {
                                    errorMessage = "Password must be at least 6 characters"
                                }
                            } else {
                                errorMessage = "Passwords do not match"
                            }
                        } else {
                            errorMessage = "Please fill in all fields"
                        }
                    }
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(50.dp),
                enabled = !uiState,
                colors = ButtonDefaults.buttonColors(
                    containerColor = Gold,
                    contentColor = Charcoal
                )
            ) {
                if (uiState) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(20.dp),
                        color = Charcoal,
                        strokeWidth = 2.dp
                    )
                } else {
                    Text(
                        text = if (isSignIn) "Continue" else "Register",
                        fontWeight = FontWeight.Bold
                    )
                }
            }

            Spacer(modifier = Modifier.height(8.dp))

            // Google sign-in button
            OutlinedButton(
                onClick = {
                    errorMessage = null
                    viewModel.clearError()
                    viewModel.signInWithGoogle()
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(50.dp),
                enabled = !uiState,
                colors = ButtonDefaults.outlinedButtonColors(
                    contentColor = TextPrimary
                ),
                border = androidx.compose.foundation.BorderStroke(
                    width = 1.dp,
                    color = TextPrimary.copy(alpha = 0.3f)
                )
            ) {
                Text(
                    text = "G",
                    fontSize = 20.sp,
                    fontWeight = FontWeight.Bold,
                    color = Color(0xFF4285F4),
                    modifier = Modifier.padding(end = 8.dp)
                )
                Text("Sign in with Google")
            }

            Spacer(modifier = Modifier.height(40.dp))
        }
    }
}

@Composable
fun TabButton(
    title: String,
    isActive: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Button(
        onClick = onClick,
        modifier = modifier.height(44.dp),
        colors = ButtonDefaults.buttonColors(
            containerColor = if (isActive) Gold.copy(alpha = 0.2f) else DarkCharcoal,
            contentColor = if (isActive) Gold else TextPrimary.copy(alpha = 0.7f)
        ),
        border = if (isActive) null else ButtonDefaults.outlinedButtonBorder(enabled = true).copy(
            width = 1.dp
        )
    ) {
        Text(
            text = title,
            fontSize = 16.sp,
            fontWeight = if (isActive) FontWeight.Bold else FontWeight.Normal
        )
    }
}

@Composable
fun textFieldColors() = OutlinedTextFieldDefaults.colors(
    focusedTextColor = TextPrimary,
    unfocusedTextColor = TextPrimary,
    focusedLabelColor = Gold,
    unfocusedLabelColor = TextPrimary.copy(alpha = 0.7f),
    focusedBorderColor = Gold,
    unfocusedBorderColor = TextPrimary.copy(alpha = 0.3f),
    focusedContainerColor = DarkCharcoal,
    unfocusedContainerColor = DarkCharcoal
)

