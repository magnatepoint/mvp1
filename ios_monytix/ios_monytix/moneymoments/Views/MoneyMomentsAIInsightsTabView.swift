//
//  MoneyMomentsAIInsightsTabView.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import SwiftUI

struct MoneyMomentsAIInsightsTabView: View {
    @ObservedObject var viewModel: MoneyMomentsViewModel
    
    private let goldColor = Color(red: 0.831, green: 0.686, blue: 0.216) // #D4AF37
    private let charcoalColor = Color(red: 0.18, green: 0.18, blue: 0.18) // #2E2E2E
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Recent Insights Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Recent Insights")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                    
                    if viewModel.isMomentsLoading || viewModel.isNudgesLoading {
                        ProgressView()
                            .tint(goldColor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                    } else if viewModel.aiInsights.isEmpty {
                        emptyState
                    } else {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.aiInsights) { insight in
                                MoneyMomentsAIInsightCard(insight: insight)
                                    .padding(.horizontal, 20)
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 20)
        }
        .background(charcoalColor)
    }
    
    private var emptyState: some View {
        GlassCard {
            VStack(spacing: 12) {
                Image(systemName: "lightbulb.slash")
                    .font(.system(size: 48))
                    .foregroundColor(.gray.opacity(0.5))
                
                Text("No insights yet")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text("AI insights will appear here based on your spending patterns")
                    .font(.system(size: 14))
                    .foregroundColor(.gray.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .padding(.horizontal, 20)
        }
    }
}

#Preview {
    MoneyMomentsAIInsightsTabView(viewModel: MoneyMomentsViewModel(authService: AuthService()))
        .background(Color(red: 0.18, green: 0.18, blue: 0.18))
}

