//
//  GoalTrackerView.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import SwiftUI

enum GoalTrackerTab: String, CaseIterable {
    case overview = "Overview"
    case goals = "Goals"
    case aiInsights = "AI Insights"
    
    var icon: String {
        switch self {
        case .overview:
            return "square.grid.2x2"
        case .goals:
            return "flag.fill"
        case .aiInsights:
            return "magnifyingglass"
        }
    }
}

struct GoalTrackerView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel: GoalsViewModel
    @State private var selectedTab: GoalTrackerTab = .overview
    @State private var showStepper = false
    @State private var hasGoals = false
    @State private var isLoading = true
    var isSelected: Bool

    private let goldColor = Color(red: 0.831, green: 0.686, blue: 0.216)
    private let charcoalColor = Color(red: 0.18, green: 0.18, blue: 0.18)

    init(isSelected: Bool = true) {
        self.isSelected = isSelected
        let authService = AuthService()
        _viewModel = StateObject(wrappedValue: GoalsViewModel(authService: authService))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                charcoalColor.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Welcome Banner
                    GoalTrackerWelcomeBanner(username: authManager.userEmail)
                        .padding(.bottom, 8)
                    
                    // Custom Tab Bar
                    customTabBar
                    
                    // Tab Content
                    tabContent
                }
            }
            .navigationTitle("GoalTracker")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showStepper = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(goldColor)
                            .font(.system(size: 24))
                    }
                }
            }
        }
        .sheet(isPresented: $showStepper) {
            GoalsStepperView(viewModel: viewModel) {
                showStepper = false
                Task {
                    await refreshData()
                }
            }
        }
        .task(id: isSelected) {
            guard isSelected else { return }
            await checkUserGoals()
        }
    }

    private var customTabBar: some View {
        HStack(spacing: 0) {
            ForEach(GoalTrackerTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = tab
                    }
                }) {
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 16, weight: selectedTab == tab ? .bold : .medium))
                            
                            Text(tab.rawValue)
                                .font(.system(size: 14, weight: selectedTab == tab ? .bold : .medium))
                        }
                        .foregroundColor(selectedTab == tab ? .black : .gray.opacity(0.7))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedTab == tab ? Color.white : Color.clear)
                        )
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(charcoalColor)
    }
    
    @ViewBuilder
    private var tabContent: some View {
        if isLoading {
            ProgressView()
                .tint(goldColor)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if !hasGoals && selectedTab == .overview {
            // Show stepper if no goals
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Image(systemName: "target")
                        .font(.system(size: 64))
                        .foregroundColor(.gray.opacity(0.5))
                    
                    Text("No Goals Yet")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Set up your financial goals first to start tracking progress.")
                        .font(.system(size: 16))
                        .foregroundColor(.gray.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding(.top, 60)
                
                Button(action: {
                    showStepper = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Set Up Goals")
                    }
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(goldColor)
                    .cornerRadius(12)
                }
            }
        } else {
            switch selectedTab {
            case .overview:
                GoalOverviewTabView(viewModel: viewModel)
                    .transition(.opacity.combined(with: .move(edge: .leading)))
            case .goals:
                GoalsListTabView(viewModel: viewModel)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            case .aiInsights:
                AIInsightsTabView(viewModel: viewModel)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
        }
    }
    
    private func checkUserGoals() async {
        isLoading = true
        defer { isLoading = false }
        
        hasGoals = await viewModel.hasGoals()
        if hasGoals {
            await refreshData()
        }
    }
    
    private func refreshData() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await viewModel.loadGoals() }
            group.addTask { await viewModel.loadProgress() }
            group.addTask { await viewModel.loadAIInsights() }
        }
    }
}

#Preview {
    GoalTrackerView(isSelected: true)
        .environmentObject(AuthManager())
}

