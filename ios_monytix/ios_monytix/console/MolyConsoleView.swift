//
//  MolyConsoleView.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import SwiftUI

enum MolyConsoleTab: String, CaseIterable {
    case overview = "Overview"
    case accounts = "Accounts"
    case spending = "Spending"
    case goals = "Goals"
    case aiInsight = "AI Insight"
    
    var icon: String {
        switch self {
        case .overview:
            return "chart.bar.fill"
        case .accounts:
            return "creditcard.fill"
        case .spending:
            return "dollarsign.circle.fill"
        case .goals:
            return "target"
        case .aiInsight:
            return "sparkles"
        }
    }
}

struct MolyConsoleView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel: MolyConsoleViewModel
    @State private var selectedTab: MolyConsoleTab = .overview
    var isSelected: Bool

    private let goldColor = Color(red: 0.831, green: 0.686, blue: 0.216) // #D4AF37
    private let charcoalColor = Color(red: 0.18, green: 0.18, blue: 0.18) // #2E2E2E
    
    init(isSelected: Bool = true) {
        self.isSelected = isSelected
        let authService = AuthService()
        _viewModel = StateObject(wrappedValue: MolyConsoleViewModel(authService: authService))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Welcome Banner
                WelcomeBanner(username: authManager.userEmail)
                
                // Custom Tab Bar
                customTabBar
                
                // Tab Content
                tabContent
            }
            .background(charcoalColor)
            .navigationTitle("MolyConsole")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: {
                            Task {
                                await refreshCurrentTab()
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
        }
        .task(id: isSelected) {
            guard isSelected else { return }
            await loadInitialData()
        }
    }
    
    private var customTabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(MolyConsoleTab.allCases, id: \.self) { tab in
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedTab = tab
                        }
                    }) {
                        VStack(spacing: 6) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 18, weight: selectedTab == tab ? .semibold : .regular))
                                .foregroundColor(selectedTab == tab ? goldColor : .gray.opacity(0.7))
                            
                            Text(tab.rawValue)
                                .font(.system(size: 12, weight: selectedTab == tab ? .semibold : .regular))
                                .foregroundColor(selectedTab == tab ? goldColor : .gray.opacity(0.7))
                            
                            // Indicator
                            Circle()
                                .fill(goldColor)
                                .frame(width: 6, height: 6)
                                .opacity(selectedTab == tab ? 1 : 0)
                        }
                        .frame(width: 80)
                        .padding(.vertical, 12)
                    }
                }
            }
            .padding(.horizontal, 8)
        }
        .background(charcoalColor)
        .overlay(
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 1),
            alignment: .bottom
        )
    }
    
    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .overview:
            OverviewTabView(viewModel: viewModel)
                .transition(.opacity.combined(with: .move(edge: .leading)))
        case .accounts:
            AccountsTabView(viewModel: viewModel)
                .transition(.opacity.combined(with: .move(edge: .trailing)))
        case .spending:
            SpendingTabView(viewModel: viewModel)
                .transition(.opacity.combined(with: .move(edge: .trailing)))
        case .goals:
            GoalsTabView(viewModel: viewModel)
                .transition(.opacity.combined(with: .move(edge: .trailing)))
        case .aiInsight:
            AIInsightTabView(viewModel: viewModel)
                .transition(.opacity.combined(with: .move(edge: .trailing)))
        }
    }
    
    private func loadInitialData() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await viewModel.loadOverview()
            }
            group.addTask {
                await viewModel.loadAccounts()
            }
            group.addTask {
                await viewModel.loadSpending()
            }
            group.addTask {
                await viewModel.loadGoals()
            }
            group.addTask {
                await viewModel.loadAIInsights()
            }
        }
    }
    
    private func refreshCurrentTab() async {
        switch selectedTab {
        case .overview:
            await viewModel.loadOverview()
        case .accounts:
            await viewModel.loadAccounts()
        case .spending:
            await viewModel.loadSpending()
        case .goals:
            await viewModel.loadGoals()
        case .aiInsight:
            await viewModel.loadAIInsights()
        }
    }
}

#Preview {
    MolyConsoleView(isSelected: true)
        .environmentObject(AuthManager())
}

