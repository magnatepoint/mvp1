//
//  GoalProgressCard.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import SwiftUI

struct GoalProgressCard: View {
    let goalProgress: GoalProgress
    
    private let goldColor = Color(red: 0.831, green: 0.686, blue: 0.216)
    
    var body: some View {
        GlassCard(padding: 20, cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    Text(goalProgress.goalName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text("\(String(format: "%.1f", goalProgress.progressPct))%")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(goldColor)
                }
                
                // Progress Bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 16)
                        
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    colors: [goldColor, goldColor.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * min(goalProgress.progressPct / 100, 1.0), height: 16)
                    }
                }
                .frame(height: 16)
                
                // Details
                VStack(alignment: .leading, spacing: 12) {
                    ProgressRow(
                        label: "Current Savings",
                        value: formatCurrency(goalProgress.currentSavingsClose)
                    )
                    
                    ProgressRow(
                        label: "Remaining",
                        value: formatCurrency(goalProgress.remainingAmount)
                    )
                    
                    ProgressRow(
                        label: "Projected Completion",
                        value: formatDate(goalProgress.projectedCompletionDate)
                    )
                }
                
                // Milestones
                if !goalProgress.milestones.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Milestones Achieved")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray.opacity(0.7))
                        
                        HStack(spacing: 8) {
                            ForEach(goalProgress.milestones, id: \.self) { milestone in
                                MilestoneBadge(percentage: milestone)
                            }
                        }
                    }
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
    
    private func formatDate(_ dateString: String?) -> String {
        guard let dateString = dateString else {
            return "Calculating..."
        }
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .long
            displayFormatter.timeStyle = .none
            return displayFormatter.string(from: date)
        }
        
        return dateString
    }
}

// MARK: - Progress Row

struct ProgressRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.gray.opacity(0.7))
            
            Spacer()
            
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Milestone Badge

struct MilestoneBadge: View {
    let percentage: Int
    
    private let goldColor = Color(red: 0.831, green: 0.686, blue: 0.216)
    
    var body: some View {
        Text("\(percentage)%")
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.black)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(goldColor)
            .cornerRadius(16)
    }
}

#Preview {
    GoalProgressCard(
        goalProgress: GoalProgress(
            goalId: "123",
            goalName: "Emergency Fund",
            progressPct: 85.0,
            currentSavingsClose: 850000,
            remainingAmount: 150000,
            projectedCompletionDate: "2024-11-15",
            milestones: [25, 50, 75]
        )
    )
    .padding()
    .background(Color(red: 0.18, green: 0.18, blue: 0.18))
}

