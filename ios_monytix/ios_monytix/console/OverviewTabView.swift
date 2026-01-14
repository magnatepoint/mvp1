//
//  OverviewTabView.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import SwiftUI

struct OverviewTabView: View {
    @ObservedObject var viewModel: MolyConsoleViewModel
    
    private let goldColor = Color(red: 0.831, green: 0.686, blue: 0.216) // #D4AF37
    private let charcoalColor = Color(red: 0.18, green: 0.18, blue: 0.18) // #2E2E2E
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if viewModel.isOverviewLoading {
                    ProgressView()
                        .tint(goldColor)
                        .padding(.top, 40)
                } else if let error = viewModel.overviewError {
                    errorState(error)
                } else if let summary = viewModel.overviewSummary {
                    overviewContent(summary)
                } else {
                    emptyState
                }
            }
            .padding(20)
        }
        .refreshable {
            await viewModel.loadOverview()
        }
    }
    
    private func overviewContent(_ summary: OverviewSummary) -> some View {
        VStack(spacing: 20) {
            // Quick Overview Section
            Text("Quick Overview")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Summary Cards Grid
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ], spacing: 16) {
                // Total Balance
                SummaryCard(
                    title: "Total Balance",
                    value: formatCurrency(summary.totalBalance),
                    color: .green,
                    icon: "dollarsign.circle.fill"
                )
                
                // This Month
                SummaryCard(
                    title: "This Month",
                    value: formatCurrency(summary.thisMonthSpending),
                    color: .red,
                    icon: "calendar"
                )
                
                // Savings Rate
                SummaryCard(
                    title: "Savings Rate",
                    value: "\(String(format: "%.1f", summary.savingsRate))%",
                    color: .green,
                    icon: "chart.line.uptrend.xyaxis"
                )
                
                // Active Goals
                SummaryCard(
                    title: "Active Goals",
                    value: "\(summary.activeGoalsCount)",
                    color: goldColor,
                    icon: "target"
                )
            }
            
            // AI Insight Card
            if let insight = summary.latestInsight {
                AIInsightCard(insight: insight)
            }
        }
    }
    
    private func errorState(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.red.opacity(0.7))
            
            Text("Unable to Load Overview")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            
            Text(error)
                .font(.system(size: 14))
                .foregroundColor(.gray.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button("Retry") {
                Task {
                    await viewModel.loadOverview()
                }
            }
            .buttonStyle(GoldButtonStyle())
            .padding(.top, 8)
        }
        .padding(.top, 60)
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No Overview Data")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            
            Text("Upload statements to see your financial overview")
                .font(.system(size: 14))
                .foregroundColor(.gray.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.top, 60)
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "₹"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "₹0"
    }
}

// MARK: - Summary Card

struct SummaryCard: View {
    let title: String
    let value: String
    let color: Color
    let icon: String
    
    var body: some View {
        GlassCard(padding: 16, cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(color)
                    
                    Spacer()
                }
                
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray.opacity(0.7))
                
                Text(value)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }
        }
    }
}

// MARK: - AI Insight Card

struct AIInsightCard: View {
    let insight: AIInsight
    
    private let goldColor = Color(red: 0.831, green: 0.686, blue: 0.216)
    
    var body: some View {
        GlassCard(padding: 20, cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: insight.type.icon)
                        .font(.system(size: 20))
                        .foregroundColor(colorForType(insight.type))
                    
                    Text("AI Insight")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.gray.opacity(0.7))
                    
                    Spacer()
                }
                
                Text(insight.message)
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                    .lineLimit(3)
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
    OverviewTabView(viewModel: MolyConsoleViewModel(authService: AuthService()))
        .background(Color(red: 0.18, green: 0.18, blue: 0.18))
}

