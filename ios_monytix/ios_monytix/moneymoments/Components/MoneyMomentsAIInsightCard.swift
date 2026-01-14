//
//  MoneyMomentsAIInsightCard.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import SwiftUI

struct MoneyMomentsAIInsightCard: View {
    let insight: MoneyMomentsAIInsight
    
    private let goldColor = Color(red: 0.831, green: 0.686, blue: 0.216) // #D4AF37
    
    var body: some View {
        GlassCard(padding: 20, cornerRadius: 16) {
            HStack(alignment: .top, spacing: 16) {
                // Icon
                Image(systemName: insight.icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(goldColor)
                    .frame(width: 40, height: 40)
                
                // Content
                VStack(alignment: .leading, spacing: 8) {
                    // Type/Title
                    Text(insight.type.rawValue)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    
                    // Message
                    Text(insight.message)
                        .font(.system(size: 14))
                        .foregroundColor(.gray.opacity(0.9))
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    // Timestamp
                    Text(insight.relativeTime)
                        .font(.system(size: 12))
                        .foregroundColor(.gray.opacity(0.7))
                }
                
                Spacer()
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        MoneyMomentsAIInsightCard(insight: MoneyMomentsAIInsight(
            id: "test1",
            type: .progress,
            message: "You've maintained a 12-day streak. Keep up the momentum!",
            timestamp: Date().addingTimeInterval(-7200), // 2 hours ago
            icon: "trophy.fill"
        ))
        
        MoneyMomentsAIInsightCard(insight: MoneyMomentsAIInsight(
            id: "test2",
            type: .suggestion,
            message: "Consider setting up automatic bill payments to avoid late fees",
            timestamp: Date().addingTimeInterval(-86400), // 1 day ago
            icon: "lightbulb.fill"
        ))
        
        MoneyMomentsAIInsightCard(insight: MoneyMomentsAIInsight(
            id: "test3",
            type: .milestone,
            message: "You've saved ₹8,500 through your smart habits this month!",
            timestamp: Date().addingTimeInterval(-259200), // 3 days ago
            icon: "leaf.fill"
        ))
    }
    .padding()
    .background(Color(red: 0.18, green: 0.18, blue: 0.18))
}

