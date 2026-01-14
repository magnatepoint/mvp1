//
//  MoneyMomentCard.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import SwiftUI

struct MoneyMomentCard: View {
    let moment: MoneyMoment
    
    private let goldColor = Color(red: 0.831, green: 0.686, blue: 0.216) // #D4AF37
    
    var body: some View {
        GlassCard(padding: 20, cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 16) {
                // Header with icon and confidence badge
                HStack(alignment: .top) {
                    // Icon based on habit_id
                    iconView
                        .frame(width: 40, height: 40)
                    
                    Spacer()
                    
                    // Confidence badge
                    confidenceBadge
                }
                
                // Label
                Text(moment.label)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                // Insight text
                Text(moment.insightText)
                    .font(.system(size: 14))
                    .foregroundColor(.gray.opacity(0.9))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Value and habit ID
                HStack {
                    // Value
                    Text(formattedValue)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(goldColor)
                    
                    Spacer()
                    
                    // Habit ID
                    Text(moment.habitId.replacingOccurrences(of: "_", with: " "))
                        .font(.system(size: 12))
                        .foregroundColor(.gray.opacity(0.7))
                        .textCase(.uppercase)
                }
            }
        }
    }
    
    // MARK: - Icon View
    
    private var iconView: some View {
        Group {
            if moment.habitId.contains("burn_rate") || moment.habitId.contains("spend_to_income") {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.orange)
            } else if moment.habitId.contains("micro") || moment.habitId.contains("cash") {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
            } else {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.yellow)
            }
        }
        .font(.system(size: 24))
    }
    
    // MARK: - Confidence Badge
    
    private var confidenceBadge: some View {
        let confidenceColor = getConfidenceColor(moment.confidence)
        let confidenceText = "\(Int(moment.confidence * 100))%"
        
        return Text(confidenceText)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(confidenceColor)
            )
    }
    
    private func getConfidenceColor(_ confidence: Double) -> Color {
        if confidence >= 0.7 {
            return .green
        } else if confidence >= 0.5 {
            return .yellow
        } else {
            return .orange
        }
    }
    
    // MARK: - Formatted Value
    
    private var formattedValue: String {
        if moment.habitId.contains("ratio") || moment.habitId.contains("share") {
            return "\(Int(moment.value * 100))%"
        } else if moment.habitId.contains("count") {
            return "\(Int(moment.value))"
        } else {
            // Currency format
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = "INR"
            formatter.currencySymbol = "₹"
            formatter.maximumFractionDigits = 0
            return formatter.string(from: NSNumber(value: moment.value)) ?? "₹\(Int(moment.value))"
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        MoneyMomentCard(moment: MoneyMoment(
            id: "test1",
            userId: "user123",
            month: "2025-01",
            habitId: "wants_share_30d",
            value: 0.35,
            label: "High Wants Spending",
            insightText: "You're spending 35% of your income on wants, which is above the recommended 20%.",
            confidence: 0.85,
            createdAt: "2025-01-15T10:00:00Z"
        ))
        
        MoneyMomentCard(moment: MoneyMoment(
            id: "test2",
            userId: "user123",
            month: "2025-01",
            habitId: "dining_txn_7d",
            value: 12,
            label: "Frequent Dining",
            insightText: "You've dined out 12 times in the past week.",
            confidence: 0.65,
            createdAt: "2025-01-15T10:00:00Z"
        ))
    }
    .padding()
    .background(Color(red: 0.18, green: 0.18, blue: 0.18))
}

