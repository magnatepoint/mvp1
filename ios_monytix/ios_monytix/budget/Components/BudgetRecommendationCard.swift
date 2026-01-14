//
//  BudgetRecommendationCard.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import SwiftUI

struct BudgetRecommendationCard: View {
    let recommendation: BudgetRecommendation
    let isCommitted: Bool
    let isCommitting: Bool
    let onCommit: () -> Void
    
    private let goldColor = Color(red: 0.831, green: 0.686, blue: 0.216)
    
    var body: some View {
        GlassCard(padding: 20, cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(recommendation.name)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                        
                        if let description = recommendation.description {
                            Text(description)
                                .font(.system(size: 14))
                                .foregroundColor(.gray.opacity(0.7))
                                .lineLimit(2)
                        }
                    }
                    
                    Spacer()
                    
                    // Score Badge
                    VStack(spacing: 4) {
                        Text("Score")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.gray.opacity(0.7))
                        
                        Text(String(format: "%.2f", recommendation.score))
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(goldColor)
                    }
                    .padding(8)
                    .background(goldColor.opacity(0.2))
                    .cornerRadius(8)
                }
                
                // Allocation Bar
                BudgetAllocationBar(
                    needsPct: recommendation.needsBudgetPct,
                    wantsPct: recommendation.wantsBudgetPct,
                    savingsPct: recommendation.savingsBudgetPct
                )
                
                // Recommendation Reason
                Text(recommendation.recommendationReason)
                    .font(.system(size: 13))
                    .foregroundColor(.gray.opacity(0.8))
                    .lineLimit(3)
                
                // Goal Preview
                if let goalPreview = recommendation.goalPreview, !goalPreview.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Goal Allocation Preview")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                        
                        ForEach(goalPreview.prefix(3)) { goal in
                            HStack {
                                Text(goal.goalName)
                                    .font(.system(size: 13))
                                    .foregroundColor(.gray.opacity(0.8))
                                
                                Spacer()
                                
                                Text(formatCurrency(goal.allocationAmount))
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .padding(12)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                
                // Commit Button or Committed Badge
                if isCommitted {
                    HStack {
                        Spacer()
                        Text("✓ Committed")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.green)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.green.opacity(0.2))
                            .cornerRadius(8)
                    }
                } else {
                    Button(action: onCommit) {
                        HStack {
                            if isCommitting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                    .scaleEffect(0.8)
                            }
                            
                            Text(isCommitting ? "Committing..." : "Commit to This Plan")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(goldColor)
                        .cornerRadius(12)
                    }
                    .disabled(isCommitting)
                }
            }
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "₹"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "₹0"
    }
}

#Preview {
    VStack(spacing: 16) {
        BudgetRecommendationCard(
            recommendation: BudgetRecommendation(
                planCode: "balanced",
                name: "Balanced Plan",
                description: "A balanced approach to budgeting",
                needsBudgetPct: 0.5,
                wantsBudgetPct: 0.3,
                savingsBudgetPct: 0.2,
                score: 8.5,
                recommendationReason: "Based on your spending patterns, this plan provides a good balance.",
                goalPreview: nil
            ),
            isCommitted: false,
            isCommitting: false,
            onCommit: {}
        )
    }
    .padding()
    .background(Color(red: 0.18, green: 0.18, blue: 0.18))
}

