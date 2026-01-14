//
//  AIInsightsTabView.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import SwiftUI

struct AIInsightsTabView: View {
    @ObservedObject var viewModel: GoalsViewModel
    
    private let goldColor = Color(red: 0.831, green: 0.686, blue: 0.216)
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("AI Insights")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                    
                    Text("Personalized recommendations and insights based on your goals")
                        .font(.system(size: 14))
                        .foregroundColor(.gray.opacity(0.7))
                        .padding(.horizontal, 20)
                }
                .padding(.top, 20)
                
                // Insights List
                if viewModel.isAIInsightsLoading {
                    ProgressView()
                        .tint(goldColor)
                        .padding(.top, 40)
                } else if viewModel.aiInsights.isEmpty {
                    emptyState
                } else {
                    ForEach(viewModel.aiInsights) { insight in
                        GoalAIInsightCard(insight: insight)
                            .padding(.horizontal, 20)
                    }
                }
            }
            .padding(.bottom, 20)
        }
        .refreshable {
            await viewModel.loadAIInsights()
        }
        .task {
            if viewModel.aiInsights.isEmpty {
                await viewModel.loadAIInsights()
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No Insights Yet")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            
            Text("AI insights will appear here as you progress with your goals.")
                .font(.system(size: 14))
                .foregroundColor(.gray.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.top, 60)
    }
}

#Preview {
    AIInsightsTabView(viewModel: GoalsViewModel(authService: AuthService()))
        .background(Color(red: 0.18, green: 0.18, blue: 0.18))
}

