//
//  AIInsightTabView.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import SwiftUI

struct AIInsightTabView: View {
    @ObservedObject var viewModel: MolyConsoleViewModel
    
    private let goldColor = Color(red: 0.831, green: 0.686, blue: 0.216)
    private let purpleColor = Color(red: 0.545, green: 0.361, blue: 0.965) // #8B5CF6
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Molytix AI Banner
                aiBanner
                
                if viewModel.isInsightsLoading {
                    ProgressView()
                        .tint(goldColor)
                        .padding(.top, 20)
                } else if let error = viewModel.insightsError {
                    errorState(error)
                } else if viewModel.aiInsights.isEmpty {
                    emptyState
                } else {
                    insightsContent
                }
            }
            .padding(20)
        }
        .refreshable {
            await viewModel.loadAIInsights()
        }
    }
    
    private var aiBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Molytix AI")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Personalized insights and recommendations based on your financial behavior.")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [purpleColor, purpleColor.opacity(0.8)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(12)
    }
    
    private var insightsContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Today's Insights")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            ForEach(viewModel.aiInsights) { insight in
                InsightCard(insight: insight)
            }
        }
    }
    
    private func errorState(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.red.opacity(0.7))
            
            Text("Unable to Load Insights")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            
            Text(error)
                .font(.system(size: 14))
                .foregroundColor(.gray.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button("Retry") {
                Task {
                    await viewModel.loadAIInsights()
                }
            }
            .buttonStyle(GoldButtonStyle())
            .padding(.top, 8)
        }
        .padding(.top, 40)
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No Insights Yet")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            
            Text("AI insights will appear here as you use the app")
                .font(.system(size: 14))
                .foregroundColor(.gray.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.top, 40)
    }
}

// MARK: - Insight Card

struct InsightCard: View {
    let insight: AIInsight
    
    private let goldColor = Color(red: 0.831, green: 0.686, blue: 0.216)
    
    var body: some View {
        GlassCard(padding: 20, cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: insight.type.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(colorForType(insight.type))
                    
                    Text(insight.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                
                Text(insight.message)
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(nil)
            }
        }
    }
    
    private func colorForType(_ type: InsightType) -> Color {
        switch type {
        case .spendingAlert:
            return .yellow
        case .goalProgress:
            return .green
        case .investmentRecommendation:
            return .purple
        case .budgetTip:
            return .blue
        case .savingsOpportunity:
            return .green
        }
    }
}

#Preview {
    let authService = AuthService()
    return AIInsightTabView(viewModel: MolyConsoleViewModel(authService: authService))
        .background(Color(red: 0.18, green: 0.18, blue: 0.18))
}

