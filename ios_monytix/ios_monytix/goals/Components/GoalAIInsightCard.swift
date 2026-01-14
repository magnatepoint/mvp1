//
//  GoalAIInsightCard.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import SwiftUI

struct GoalAIInsightCard: View {
    let insight: AIInsight
    
    private var iconName: String {
        switch insight.type {
        case .goalProgress:
            return "trophy.fill"
        case .savingsOpportunity:
            return "lightbulb.fill"
        case .budgetTip:
            return "leaf.fill"
        case .spendingAlert:
            return "exclamationmark.triangle.fill"
        case .investmentRecommendation:
            return "info.circle.fill"
        }
    }
    
    private var iconColor: Color {
        switch insight.type {
        case .goalProgress:
            return Color(red: 0.831, green: 0.686, blue: 0.216) // Gold
        case .savingsOpportunity:
            return Color(red: 0.545, green: 0.361, blue: 0.965) // Purple
        case .budgetTip:
            return Color(red: 0.16, green: 0.725, blue: 0.506) // Green
        case .spendingAlert:
            return .red
        case .investmentRecommendation:
            return .blue
        }
    }
    
    var body: some View {
        GlassCard(padding: 16, cornerRadius: 16) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.2))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: iconName)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(iconColor)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 6) {
                    Text(insight.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(insight.message)
                        .font(.system(size: 14))
                        .foregroundColor(.gray.opacity(0.8))
                        .lineLimit(3)
                    
                    if let createdAt = insight.createdAt {
                        Text(relativeTimeString(from: createdAt))
                            .font(.system(size: 12))
                            .foregroundColor(.gray.opacity(0.6))
                            .padding(.top, 2)
                    }
                }
                
                Spacer()
            }
        }
    }
    
    private func relativeTimeString(from date: Date) -> String {
        let now = Date()
        let timeInterval = now.timeIntervalSince(date)
        
        if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            return "\(minutes) minute\(minutes == 1 ? "" : "s") ago"
        } else if timeInterval < 86400 {
            let hours = Int(timeInterval / 3600)
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        } else {
            let days = Int(timeInterval / 86400)
            return "\(days) day\(days == 1 ? "" : "s") ago"
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        GoalAIInsightCard(
            insight: AIInsight(
                id: UUID(),
                title: "Goal Achievement Rate",
                message: "You're on track to complete 75% of your goals this year!",
                type: .goalProgress,
                priority: .high,
                createdAt: Date().addingTimeInterval(-7200),
                category: nil
            )
        )
        
        GoalAIInsightCard(
            insight: AIInsight(
                id: UUID(),
                title: "Savings Optimization",
                message: "Consider increasing your emergency fund contribution by ₹5,000/month to reach your goal faster.",
                type: .savingsOpportunity,
                priority: .medium,
                createdAt: Date().addingTimeInterval(-86400),
                category: "Emergency Fund"
            )
        )
    }
    .padding()
    .background(Color(red: 0.18, green: 0.18, blue: 0.18))
}

