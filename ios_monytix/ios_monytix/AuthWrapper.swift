//
//  AuthWrapper.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import SwiftUI

struct AuthWrapper: View {
    @StateObject private var authManager = AuthManager()
    
    private let charcoalColor = Color(red: 0.18, green: 0.18, blue: 0.18) // #2E2E2E
    
    var body: some View {
        Group {
            if authManager.isLoading {
                // Loading state
                VStack {
                    ProgressView()
                        .tint(Color(red: 0.831, green: 0.686, blue: 0.216))
                    Text("Loading...")
                        .foregroundColor(.white)
                        .padding(.top, 16)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(charcoalColor)
                .environmentObject(authManager)
            } else if authManager.isAuthenticated {
                // Main content when authenticated
                ContentView()
                    .environmentObject(authManager)
            } else {
                // Login screen when not authenticated
                LoginView()
                    .environmentObject(authManager)
            }
        }
    }
}

#Preview {
    AuthWrapper()
}

