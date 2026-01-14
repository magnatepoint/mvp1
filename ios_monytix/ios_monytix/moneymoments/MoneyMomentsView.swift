//
//  MoneyMomentsView.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import SwiftUI

enum MoneyMomentsTab: String, CaseIterable {
    case nudges = "Nudges"
    case habits = "Habits"
    case aiInsights = "AI Insights"
    
    var icon: String {
        switch self {
        case .nudges: return "bell.fill"
        case .habits: return "arrow.triangle.2.circlepath"
        case .aiInsights: return "lightbulb.fill"
        }
    }
}

struct MoneyMomentsView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel: MoneyMomentsViewModel
    @State private var selectedTab: MoneyMomentsTab = .nudges
    
    private let goldColor = Color(red: 0.831, green: 0.686, blue: 0.216) // #D4AF37
    private let charcoalColor = Color(red: 0.18, green: 0.18, blue: 0.18) // #2E2E2E
    
    init() {
        let authService = AuthService()
        _viewModel = StateObject(wrappedValue: MoneyMomentsViewModel(authService: authService))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Welcome Banner
                MoneyMomentsWelcomeBanner(username: authManager.userEmail)
                
                // Custom Tab Bar
                customTabBar
                
                // Tab Content
                tabContent
            }
            .background(charcoalColor)
            .navigationTitle("MoneyMoments")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: {
                            Task {
                                await viewModel.loadAll()
                            }
                        }) {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        
                        Divider()
                        
                        Button(role: .destructive, action: {
                            Task {
                                try? await authManager.signOut()
                            }
                        }) {
                            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(goldColor)
                    }
                }
            }
            .task {
                await viewModel.loadAll()
            }
        }
    }
    
    // MARK: - Custom Tab Bar
    
    private var customTabBar: some View {
        HStack(spacing: 0) {
            ForEach(MoneyMomentsTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = tab
                    }
                }) {
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 16, weight: selectedTab == tab ? .semibold : .regular))
                            Text(tab.rawValue)
                                .font(.system(size: 16, weight: selectedTab == tab ? .bold : .medium))
                        }
                        .foregroundColor(selectedTab == tab ? goldColor : .gray.opacity(0.7))
                        
                        // Indicator
                        Rectangle()
                            .fill(goldColor)
                            .frame(height: 3)
                            .cornerRadius(1.5)
                            .opacity(selectedTab == tab ? 1 : 0)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
            }
        }
        .background(charcoalColor)
        .overlay(
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 1),
            alignment: .bottom
        )
    }
    
    // MARK: - Tab Content
    
    private var tabContent: some View {
        Group {
            switch selectedTab {
            case .nudges:
                NudgesTabView(viewModel: viewModel)
            case .habits:
                HabitsTabView(viewModel: viewModel)
            case .aiInsights:
                MoneyMomentsAIInsightsTabView(viewModel: viewModel)
            }
        }
    }
}

#Preview {
    MoneyMomentsView()
        .environmentObject(AuthManager())
}
