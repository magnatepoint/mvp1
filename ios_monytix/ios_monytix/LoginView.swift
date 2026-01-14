//
//  LoginView.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import SwiftUI
import UIKit
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var isSignIn = true
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showPassword = false
    @State private var showConfirmPassword = false
    @State private var errorMessage: String?
    
    private let goldColor = Color(red: 0.831, green: 0.686, blue: 0.216) // #D4AF37
    private let charcoalColor = Color(red: 0.18, green: 0.18, blue: 0.18) // #2E2E2E
    private let darkCharcoalColor = Color(red: 0.15, green: 0.15, blue: 0.15) // #262626
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Logo
                    if let image = UIImage(named: "monytix") {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 200, height: 80)
                            .padding(.top, 40)
                    } else {
                        // Fallback if image not found
                        Text("monyTIX")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(goldColor)
                            .padding(.top, 40)
                    }
                    
                    Spacer().frame(height: 32)
                    
                    // Tabs
                    HStack(spacing: 12) {
                        TabButton(
                            title: "Sign in",
                            isActive: isSignIn,
                            action: { isSignIn = true }
                        )
                        TabButton(
                            title: "Register",
                            isActive: !isSignIn,
                            action: { isSignIn = false }
                        )
                    }
                    .padding(.horizontal, 24)
                    
                    Spacer().frame(height: 32)
                    
                    // Title
                    Text(isSignIn ? "Sign in" : "Register")
                        .font(.system(size: 28, weight: .bold))
                        .padding(.horizontal, 24)
                    
                    Spacer().frame(height: 8)
                    
                    Text(isSignIn
                         ? "Secure entry into your AI fintech console"
                         : "Launch your AI fintech cockpit in under a minute")
                        .font(.system(size: 14))
                        .foregroundColor(.gray.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    
                    Spacer().frame(height: 32)
                    
                    // Form
                    VStack(spacing: 16) {
                        // Email field
                        TextField("Email", text: $email)
                            .textFieldStyle(CustomTextFieldStyle(icon: "envelope"))
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                        
                        // Password field
                        HStack {
                            Image(systemName: "lock")
                                .foregroundColor(.gray.opacity(0.7))
                                .frame(width: 20)
                            if showPassword {
                                TextField("Password", text: $password)
                                    .foregroundColor(.white)
                            } else {
                                SecureField("Password", text: $password)
                                    .foregroundColor(.white)
                            }
                            Button(action: { showPassword.toggle() }) {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                                    .foregroundColor(.gray.opacity(0.7))
                            }
                        }
                        .padding()
                        .background(darkCharcoalColor)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        
                        // Confirm Password (only for registration)
                        if !isSignIn {
                            HStack {
                                Image(systemName: "lock")
                                    .foregroundColor(.gray.opacity(0.7))
                                    .frame(width: 20)
                                if showConfirmPassword {
                                    TextField("Confirm Password", text: $confirmPassword)
                                        .foregroundColor(.white)
                                } else {
                                    SecureField("Confirm Password", text: $confirmPassword)
                                        .foregroundColor(.white)
                                }
                                Button(action: { showConfirmPassword.toggle() }) {
                                    Image(systemName: showConfirmPassword ? "eye.slash" : "eye")
                                        .foregroundColor(.gray.opacity(0.7))
                                }
                            }
                            .padding()
                            .background(darkCharcoalColor)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    // Error message
                    if let errorMessage = errorMessage ?? authManager.errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                            .padding(.horizontal, 24)
                            .padding(.top, 16)
                    }
                    
                    Spacer().frame(height: 16)
                    
                    // Submit button
                    Button(action: handleSubmit) {
                        if authManager.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                        } else {
                            Text(isSignIn ? "Continue" : "Register")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                        }
                    }
                    .buttonStyle(GoldButtonStyle())
                    .disabled(authManager.isLoading)
                    .padding(.horizontal, 24)
                    
                    Spacer().frame(height: 16)
                    
                    // Google sign-in button
                    Button(action: handleGoogleSignIn) {
                        HStack {
                            Text("G")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.blue)
                            Text("Sign in with Google")
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                    }
                    .buttonStyle(OutlinedButtonStyle())
                    .disabled(authManager.isLoading)
                    .padding(.horizontal, 24)
                    
                    Spacer().frame(height: 12)
                    
                    // Apple Sign In button
                    SignInWithAppleButton(
                        onRequest: { request in
                            request.requestedScopes = [.fullName, .email]
                        },
                        onCompletion: handleAppleSignIn
                    )
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 50)
                    .frame(maxWidth: 375) // Internal constraint caps width at 375; avoid efficient infinite width on large devices
                    .cornerRadius(12)
                    .disabled(authManager.isLoading)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
            .background(charcoalColor)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func handleSubmit() {
        errorMessage = nil
        
        // Validation
        guard !email.isEmpty else {
            errorMessage = "Please enter your email"
            return
        }
        
        guard email.contains("@") else {
            errorMessage = "Please enter a valid email"
            return
        }
        
        guard !password.isEmpty else {
            errorMessage = "Please enter your password"
            return
        }
        
        guard password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters"
            return
        }
        
        if !isSignIn {
            guard !confirmPassword.isEmpty else {
                errorMessage = "Please confirm your password"
                return
            }
            
            guard password == confirmPassword else {
                errorMessage = "Passwords do not match"
                return
            }
        }
        
        Task {
            do {
                if isSignIn {
                    try await authManager.signIn(email: email, password: password)
                } else {
                    try await authManager.signUp(email: email, password: password)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    private func handleGoogleSignIn() {
        errorMessage = nil
        Task {
            do {
                try await authManager.signInWithGoogle()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        errorMessage = nil
        
        switch result {
        case .success(let authorization):
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let identityToken = appleIDCredential.identityToken,
                  let idTokenString = String(data: identityToken, encoding: .utf8) else {
                errorMessage = "Apple Sign In failed"
                return
            }
            
            Task {
                do {
                    try await authManager.signInWithApple(idToken: idTokenString)
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
            
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }
}

// Custom TextField Style
struct CustomTextFieldStyle: TextFieldStyle {
    let icon: String
    private let darkCharcoalColor = Color(red: 0.15, green: 0.15, blue: 0.15) // #262626
    
    func _body(configuration: TextField<Self._Label>) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.gray.opacity(0.7))
                .frame(width: 20)
            configuration
                .foregroundColor(.white)
        }
        .padding()
        .background(darkCharcoalColor)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
}

// Gold Button Style
struct GoldButtonStyle: ButtonStyle {
    private let goldColor = Color(red: 0.831, green: 0.686, blue: 0.216)
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(goldColor)
            .foregroundColor(.black)
            .cornerRadius(12)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

// Outlined Button Style
struct OutlinedButtonStyle: ButtonStyle {
    private let darkCharcoalColor = Color(red: 0.15, green: 0.15, blue: 0.15) // #262626
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(darkCharcoalColor)
            .foregroundColor(.white)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.4), lineWidth: 1)
            )
            .cornerRadius(12)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

// Tab Button
struct TabButton: View {
    let title: String
    let isActive: Bool
    let action: () -> Void
    
    private let goldColor = Color(red: 0.831, green: 0.686, blue: 0.216)
    private let darkCharcoalColor = Color(red: 0.15, green: 0.15, blue: 0.15) // #262626
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: isActive ? .bold : .regular))
                .foregroundColor(isActive ? goldColor : .gray.opacity(0.7))
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(isActive ? goldColor.opacity(0.2) : darkCharcoalColor)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isActive ? goldColor : Color.gray.opacity(0.3), lineWidth: 1)
                )
        }
    }
}

#Preview {
    LoginView()
}

