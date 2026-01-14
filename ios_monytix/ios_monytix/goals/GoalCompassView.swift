//
//  GoalCompassView.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import SwiftUI

struct GoalCompassView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel: GoalsViewModel
    @State private var showQuestionnaire = false
    @State private var hasGoals = false
    @State private var isLoading = true
    
    private let goldColor = Color(red: 0.831, green: 0.686, blue: 0.216)
    private let charcoalColor = Color(red: 0.18, green: 0.18, blue: 0.18)
    
    init() {
        let authService = AuthService()
        _viewModel = StateObject(wrappedValue: GoalsViewModel(authService: authService))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                charcoalColor.ignoresSafeArea()
                
                if isLoading {
                    ProgressView()
                        .tint(goldColor)
                } else if showQuestionnaire {
                    questionnaireView
                } else {
                    progressView
                }
            }
            .navigationTitle("GoalCompass")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !showQuestionnaire && hasGoals {
                        Button(action: {
                            showQuestionnaire = true
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(goldColor)
                        }
                    }
                }
            }
        }
        .task {
            await checkUserGoals()
        }
    }
    
    private var questionnaireView: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("Set Your Financial Goals")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                
                Text(hasGoals
                     ? "Add new goals to track your financial progress."
                     : "Tell us about yourself and your financial aspirations. We'll help you prioritize and track your progress.")
                    .font(.system(size: 16))
                    .foregroundColor(.gray.opacity(0.7))
                
                if hasGoals {
                    Button(action: {
                        showQuestionnaire = false
                    }) {
                        HStack {
                            Image(systemName: "arrow.left")
                            Text("Back to Progress")
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(goldColor)
                    }
                    .padding(.top, 8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(charcoalColor)
            
            GoalsStepperView(viewModel: viewModel) {
                // On completion
                showQuestionnaire = false
                hasGoals = true
                Task {
                    await viewModel.loadProgress()
                }
            }
        }
    }
    
    private var progressView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Goal Progress Tracking")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Monitor your financial goals, track milestones, and see projected completion dates.")
                        .font(.system(size: 16))
                        .foregroundColor(.gray.opacity(0.7))
                    
                    Button(action: {
                        showQuestionnaire = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add New Goal")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(goldColor)
                        .cornerRadius(12)
                    }
                    .padding(.top, 12)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                
                // Progress Cards
                if viewModel.isProgressLoading {
                    ProgressView()
                        .tint(goldColor)
                        .padding(.top, 40)
                } else if let error = viewModel.progressError {
                    errorState(error)
                } else if viewModel.progress.isEmpty {
                    emptyState
                } else {
                    ForEach(viewModel.progress) { goalProgress in
                        GoalProgressCard(goalProgress: goalProgress)
                            .padding(.horizontal, 20)
                    }
                }
            }
            .padding(.bottom, 20)
        }
        .refreshable {
            await viewModel.loadProgress()
        }
    }
    
    private func errorState(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.red.opacity(0.7))
            
            Text("Unable to Load Progress")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            
            Text(error)
                .font(.system(size: 14))
                .foregroundColor(.gray.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button("Retry") {
                Task {
                    await viewModel.loadProgress()
                }
            }
            .buttonStyle(GoldButtonStyle())
            .padding(.top, 8)
        }
        .padding(.top, 60)
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "target")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No Goals Yet")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            
            Text("Set up your financial goals first to start tracking progress.")
                .font(.system(size: 14))
                .foregroundColor(.gray.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button("Set Up Goals") {
                showQuestionnaire = true
            }
            .buttonStyle(GoldButtonStyle())
            .padding(.top, 8)
        }
        .padding(.top, 60)
    }
    
    private func checkUserGoals() async {
        isLoading = true
        defer { isLoading = false }
        
        hasGoals = await viewModel.hasGoals()
        if hasGoals {
            await viewModel.loadProgress()
        } else {
            showQuestionnaire = true
        }
    }
}

#Preview {
    GoalCompassView()
        .environmentObject(AuthManager())
}

