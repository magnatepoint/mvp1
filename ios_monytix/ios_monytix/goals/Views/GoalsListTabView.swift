//
//  GoalsListTabView.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import SwiftUI

struct GoalsListTabView: View {
    @ObservedObject var viewModel: GoalsViewModel
    
    @State private var selectedFilter: GoalStatus? = nil
    
    private let goldColor = Color(red: 0.831, green: 0.686, blue: 0.216)
    
    private var filteredGoals: [GoalResponse] {
        viewModel.goals(byStatus: selectedFilter)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Filter Tabs
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        FilterChip(
                            title: "All",
                            isSelected: selectedFilter == nil,
                            action: { selectedFilter = nil }
                        )
                        
                        FilterChip(
                            title: "Active",
                            isSelected: selectedFilter == .active,
                            action: { selectedFilter = .active }
                        )
                        
                        FilterChip(
                            title: "Completed",
                            isSelected: selectedFilter == .completed,
                            action: { selectedFilter = .completed }
                        )
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.top, 20)
                
                // Goals List
                if viewModel.isGoalsLoading {
                    ProgressView()
                        .tint(goldColor)
                        .padding(.top, 40)
                } else if filteredGoals.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 16) {
                        if selectedFilter == .completed {
                            Text("Completed Goals")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 20)
                        }
                        
                        ForEach(filteredGoals) { goal in
                            GoalListCard(
                                goal: goal,
                                progress: viewModel.progress.first { $0.goalId == goal.goalId.uuidString }
                            )
                            .padding(.horizontal, 20)
                        }
                    }
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
            Image(systemName: selectedFilter == .completed ? "checkmark.circle" : "target")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.5))
            
            Text(selectedFilter == .completed ? "No Completed Goals" : "No Goals")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            
            Text(selectedFilter == .completed 
                 ? "Complete your first goal to see it here."
                 : "Create your first goal to start tracking your progress.")
                .font(.system(size: 14))
                .foregroundColor(.gray.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.top, 60)
    }
}

#Preview {
    GoalsListTabView(viewModel: GoalsViewModel(authService: AuthService()))
        .background(Color(red: 0.18, green: 0.18, blue: 0.18))
}

