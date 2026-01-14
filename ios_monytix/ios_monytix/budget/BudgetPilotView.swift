//
//  BudgetPilotView.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import SwiftUI

struct BudgetPilotView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel: BudgetViewModel
    
    private let goldColor = Color(red: 0.831, green: 0.686, blue: 0.216)
    private let charcoalColor = Color(red: 0.18, green: 0.18, blue: 0.18)
    
    init() {
        let authService = AuthService()
        _viewModel = StateObject(wrappedValue: BudgetViewModel(authService: authService))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                charcoalColor.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text("BudgetPilot")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Smart budget recommendations tailored to your spending patterns and goals")
                                .font(.system(size: 16))
                                .foregroundColor(.gray.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        
                        // Committed Budget Section
                        if viewModel.isCommittedLoading {
                            ProgressView()
                                .tint(goldColor)
                                .padding(.vertical, 20)
                        } else if let committed = viewModel.committedBudget {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Your Committed Budget")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                
                                CommittedBudgetCard(committedBudget: committed)
                                    .padding(.horizontal, 20)
                            }
                        }
                        // No committed budget - don't show anything, just show recommendations
                        
                        // Recommendations Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text(viewModel.committedBudget != nil ? "Other Recommendations" : "Recommended Budget Plans")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                            
                            if viewModel.isRecommendationsLoading {
                                ProgressView()
                                    .tint(goldColor)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 40)
                            } else if let error = viewModel.recommendationsError {
                                errorState(error)
                            } else if viewModel.recommendations.isEmpty {
                                emptyState
                            } else {
                                ForEach(viewModel.recommendations) { recommendation in
                                    BudgetRecommendationCard(
                                        recommendation: recommendation,
                                        isCommitted: viewModel.committedBudget?.planCode == recommendation.planCode,
                                        isCommitting: viewModel.isCommitting,
                                        onCommit: {
                                            Task {
                                                let success = await viewModel.commitToPlan(planCode: recommendation.planCode)
                                                if success {
                                                    await viewModel.loadCommittedBudget()
                                                }
                                            }
                                        }
                                    )
                                    .padding(.horizontal, 20)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("BudgetPilot")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await viewModel.loadRecommendations()
                            await viewModel.loadCommittedBudget()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(goldColor)
                    }
                }
            }
        }
        .task {
            await loadInitialData()
        }
    }
    
    private func loadInitialData() async {
        await viewModel.loadRecommendations()
        await viewModel.loadCommittedBudget()
    }
    
    private func errorState(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.red.opacity(0.7))
            
            Text("Unable to Load Recommendations")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            
            Text(error)
                .font(.system(size: 14))
                .foregroundColor(.gray.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button("Retry") {
                Task {
                    await viewModel.loadRecommendations()
                }
            }
            .buttonStyle(GoldButtonStyle())
            .padding(.top, 8)
        }
        .padding(.vertical, 40)
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.pie")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No Recommendations Available")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            
            Text("Budget recommendations will appear here once you have spending data and goals set up.")
                .font(.system(size: 14))
                .foregroundColor(.gray.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.vertical, 40)
    }
}

#Preview {
    BudgetPilotView()
        .environmentObject(AuthManager())
}

