//
//  FinancialHealthCard.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import SwiftUI

struct FinancialHealthCard: View {
    let kpis: SpendSenseKPIs
    
    @State private var isVisible = false
    @State private var animatedScore: Double = 0
    
    private let goldColor = Color(red: 0.831, green: 0.686, blue: 0.216) // #D4AF37
    
    var body: some View {
        GlassCard(padding: 24, cornerRadius: 20) {
            VStack(spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Financial Health")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Overall financial wellness")
                            .font(.system(size: 14))
                            .foregroundColor(.gray.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    // Score Circle
                    ZStack {
                        Circle()
                            .stroke(healthStatusColor.opacity(0.3), lineWidth: 8)
                            .frame(width: 70, height: 70)
                        
                        Circle()
                            .trim(from: 0, to: animatedScore / 100)
                            .stroke(
                                healthStatusColor,
                                style: StrokeStyle(lineWidth: 8, lineCap: .round)
                            )
                            .frame(width: 70, height: 70)
                            .rotationEffect(.degrees(-90))
                            .animation(.spring(response: 1.2, dampingFraction: 0.7), value: animatedScore)
                        
                        VStack(spacing: 2) {
                            Text("\(Int(animatedScore))")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .contentTransition(.numericText())
                            
                            Text(healthStatusText)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(healthStatusColor)
                        }
                    }
                }
                
                // Metrics Row
                HStack(spacing: 16) {
                    MetricItem(
                        label: "Savings Rate",
                        value: savingsRate,
                        icon: "percent",
                        color: .blue
                    )
                    
                    MetricItem(
                        label: "Efficiency",
                        value: spendingEfficiency,
                        icon: "chart.line.uptrend.xyaxis",
                        color: .green
                    )
                }
                
                // Quick Insights
                if !quickInsights.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Quick Insights")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        
                        ForEach(quickInsights, id: \.self) { insight in
                            HStack(spacing: 8) {
                                Image(systemName: "lightbulb.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(goldColor)
                                
                                Text(insight)
                                    .font(.system(size: 13))
                                    .foregroundColor(.gray.opacity(0.9))
                            }
                        }
                    }
                    .padding(.top, 8)
                }
            }
        }
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 20)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                isVisible = true
            }
            
            withAnimation(.spring(response: 1.2, dampingFraction: 0.7).delay(0.2)) {
                animatedScore = financialHealthScore
            }
        }
        .onChange(of: financialHealthScore) { oldValue, newValue in
            withAnimation(.spring(response: 1.0, dampingFraction: 0.7)) {
                animatedScore = newValue
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var financialHealthScore: Double {
        let savingsRateScore = savingsRate
        let efficiencyScore = spendingEfficiency
        let stabilityScore = calculateStabilityScore()
        
        // Weighted formula: (savingsRate * 40) + (efficiency * 30) + (stability * 30)
        let score = (savingsRateScore * 0.4) + (efficiencyScore * 0.3) + (stabilityScore * 0.3)
        return min(100, max(0, score))
    }
    
    private var savingsRate: Double {
        guard let income = kpis.incomeAmount, income > 0,
              let assets = kpis.assetsAmount else {
            return 0
        }
        return min(100, (assets / income) * 100)
    }
    
    private var spendingEfficiency: Double {
        guard let needs = kpis.needsAmount,
              let wants = kpis.wantsAmount else {
            return 0
        }
        let totalExpenses = needs + wants
        guard totalExpenses > 0 else { return 0 }
        return (needs / totalExpenses) * 100
    }
    
    private func calculateStabilityScore() -> Double {
        // Simple stability score based on wants gauge
        // Lower wants ratio = higher stability
        if let gauge = kpis.wantsGauge {
            return max(0, 100 - (gauge.ratio * 100))
        }
        return 50 // Default middle score
    }
    
    private var healthStatusColor: Color {
        let score = financialHealthScore
        if score >= 80 {
            return .green
        } else if score >= 60 {
            return Color(red: 0.129, green: 0.588, blue: 0.953) // Blue
        } else if score >= 40 {
            return .orange
        } else {
            return .red
        }
    }
    
    private var healthStatusText: String {
        let score = financialHealthScore
        if score >= 80 {
            return "Excellent"
        } else if score >= 60 {
            return "Good"
        } else if score >= 40 {
            return "Fair"
        } else {
            return "Needs Attention"
        }
    }
    
    private var quickInsights: [String] {
        var insights: [String] = []
        
        if savingsRate >= 20 {
            insights.append("Great savings rate! Keep it up.")
        } else if savingsRate < 10 {
            insights.append("Consider increasing your savings rate.")
        }
        
        if spendingEfficiency >= 70 {
            insights.append("Excellent spending efficiency.")
        } else if spendingEfficiency < 50 {
            insights.append("Try to reduce wants spending.")
        }
        
        if let gauge = kpis.wantsGauge, gauge.thresholdCrossed {
            insights.append("Wants spending is above threshold.")
        }
        
        return Array(insights.prefix(3))
    }
}

// MARK: - Metric Item

struct MetricItem: View {
    let label: String
    let value: Double
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)
                
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.gray.opacity(0.8))
            }
            
            Text("\(String(format: "%.1f", value))%")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.15))
        )
    }
}

#Preview {
    FinancialHealthCard(
        kpis: SpendSenseKPIs(
            incomeAmount: 120000,
            needsAmount: 45000,
            wantsAmount: 30000,
            assetsAmount: 45000,
            wantsGauge: WantsGauge(
                ratio: 0.4,
                thresholdCrossed: false,
                label: "Good Balance"
            ),
            topCategories: nil
        )
    )
    .padding()
    .background(Color(red: 0.18, green: 0.18, blue: 0.18))
}

