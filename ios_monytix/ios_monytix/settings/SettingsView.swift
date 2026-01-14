//
//  SettingsView.swift
//  ios_monytix
//
//  Created by santosh on 10/01/26.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel: SettingsViewModel
    @State private var showDeleteConfirmation = false
    @State private var showDeleteSuccess = false
    @State private var showSignOutConfirmation = false
    
    private let goldColor = Color(red: 0.831, green: 0.686, blue: 0.216)
    private let charcoalColor = Color(red: 0.18, green: 0.18, blue: 0.18)
    private let darkCharcoalColor = Color(red: 0.15, green: 0.15, blue: 0.15)
    
    init() {
        let authService = AuthService()
        _viewModel = StateObject(wrappedValue: SettingsViewModel(authService: authService))
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Account Section
                    accountSection
                    
                    // Preferences Section
                    preferencesSection
                    
                    // Data Management Section
                    dataManagementSection
                    
                    // About Section
                    aboutSection
                    
                    // Sign Out Section
                    signOutSection
                }
                .padding(20)
            }
            .background(charcoalColor)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .alert("Delete All Data", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    Task {
                        await viewModel.deleteAllData()
                        if viewModel.deleteError == nil {
                            showDeleteSuccess = true
                        }
                    }
                }
            } message: {
                Text("This will permanently delete all your transaction data, goals, budgets, and moments. This action cannot be undone. Are you sure you want to continue?")
            }
            .alert("Data Deleted", isPresented: $showDeleteSuccess) {
                Button("OK") {
                    // Optionally sign out after deletion
                }
            } message: {
                Text("All your data has been successfully deleted.")
            }
            .alert("Sign Out", isPresented: $showSignOutConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    Task {
                        try? await authManager.signOut()
                    }
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
        }
        .task {
            await viewModel.loadUserInfo()
        }
    }
    
    // MARK: - Account Section
    
    private var accountSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(goldColor)
                    
                    Text("Account")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Divider()
                    .background(Color.gray.opacity(0.3))
                
                // Email
                HStack {
                    Text("Email")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Text(authManager.userEmail ?? "Not available")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                }
                
                // User ID
                if let userId = viewModel.userId {
                    HStack {
                        Text("User ID")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                        
                        Spacer()
                        
                        Text(String(userId.prefix(8)) + "...")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray.opacity(0.7))
                    }
                }
            }
        }
    }
    
    // MARK: - Preferences Section
    
    private var preferencesSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 24))
                        .foregroundColor(goldColor)
                    
                    Text("Preferences")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Divider()
                    .background(Color.gray.opacity(0.3))
                
                // Notifications (placeholder for future)
                SettingsRow(
                    icon: "bell.fill",
                    title: "Notifications",
                    subtitle: "Manage notification preferences",
                    action: {
                        // Future: Open notification settings
                    }
                )
                
                // Currency (placeholder for future)
                SettingsRow(
                    icon: "dollarsign.circle.fill",
                    title: "Currency",
                    subtitle: "INR (Indian Rupee)",
                    action: {
                        // Future: Change currency
                    }
                )
                
                // Theme (placeholder for future)
                SettingsRow(
                    icon: "paintbrush.fill",
                    title: "Theme",
                    subtitle: "Dark",
                    action: {
                        // Future: Change theme
                    }
                )
            }
        }
    }
    
    // MARK: - Data Management Section
    
    private var dataManagementSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "externaldrive.fill")
                        .font(.system(size: 24))
                        .foregroundColor(goldColor)
                    
                    Text("Data Management")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Divider()
                    .background(Color.gray.opacity(0.3))
                
                // Delete All Data
                Button(action: {
                    showDeleteConfirmation = true
                }) {
                    HStack {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.red)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Delete All Data")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.red)
                            
                            Text("Permanently delete all your data")
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        if viewModel.isDeleting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .red))
                        }
                    }
                    .padding(.vertical, 8)
                }
                .disabled(viewModel.isDeleting)
                
                if let error = viewModel.deleteError {
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundColor(.red)
                        .padding(.top, 4)
                }
            }
        }
    }
    
    // MARK: - About Section
    
    private var aboutSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(goldColor)
                    
                    Text("About")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Divider()
                    .background(Color.gray.opacity(0.3))
                
                // App Version
                HStack {
                    Text("App Version")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Text("1.0.0")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                }
                
                // Build Number
                HStack {
                    Text("Build")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                }
            }
        }
    }
    
    // MARK: - Sign Out Section
    
    private var signOutSection: some View {
        Button(action: {
            showSignOutConfirmation = true
        }) {
            HStack {
                Spacer()
                Text("Sign Out")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.vertical, 16)
            .background(Color.red.opacity(0.2))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.red.opacity(0.5), lineWidth: 1)
            )
        }
    }
}

// MARK: - Settings Row Component

struct SettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void
    
    private let goldColor = Color(red: 0.831, green: 0.686, blue: 0.216)
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(goldColor)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                    
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gray.opacity(0.5))
            }
            .padding(.vertical, 8)
        }
    }
}


#Preview {
    SettingsView()
        .environmentObject(AuthManager())
}

