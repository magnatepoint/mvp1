//
//  GoalOverviewTabView.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import SwiftUI

struct GoalOverviewTabView: View {
    @ObservedObject var viewModel: GoalsViewModel
    
    private let goldColor = Color(red: 0.831, green: 0.686, blue: 0.216)
    private let purpleColor = Color(red: 0.545, green: 0.361, blue: 0.965)
    private let greenColor = Color(red: 0.16, green: 0.725, blue: 0.506)
    private let redColor = Color(red: 0.937, green: 0.267, blue: 0.267)
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Your Progress Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Your Progress")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                    
                    // Metrics Grid (2x2)
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            ProgressMetricCard(
                                icon: "flag.fill",
                                value: "\(viewModel.activeGoalsCount)",
                                label: "Active Goals",
                                color: purpleColor
                            )
                            
                            ProgressMetricCard(
                                icon: "checkmark.circle.fill",
                                value: "\(viewModel.completedGoalsCount)",
                                label: "Completed",
                                color: greenColor
                            )
                        }
                        
                        HStack(spacing: 12) {
                            ProgressMetricCard(
                                icon: "chart.line.uptrend.xyaxis",
                                value: "\(String(format: "%.1f", viewModel.totalProgressPercentage))%",
                                label: "Total Progress",
                                color: goldColor
                            )
                            
                            ProgressMetricCard(
                                icon: "star.fill",
                                value: viewModel.goalAchieverLevel,
                                label: "Goal Achiever Level",
                                color: redColor
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.top, 20)
                
                // Active Goals Section
                if !viewModel.activeGoals.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Active Goals")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                        
                        ForEach(viewModel.activeGoals) { goal in
                            GoalListCard(
                                goal: goal,
                                progress: viewModel.progress.first { $0.goalId == goal.goalId.uuidString }
                            )
                            .padding(.horizontal, 20)
                        }
                    }
                } else if !viewModel.isGoalsLoading {
                    emptyState
                }
            }
            .padding(.bottom, 20)
        }
        .refreshable {
            await viewModel.loadGoals()
            await viewModel.loadProgress()
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "target")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No Active Goals")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            
            Text("Create your first goal to start tracking your progress.")
                .font(.system(size: 14))
                .foregroundColor(.gray.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.top, 40)
    }
}

#Preview {
    GoalOverviewTabView(viewModel: GoalsViewModel(authService: AuthService()))
        .background(Color(red: 0.18, green: 0.18, blue: 0.18))
}

