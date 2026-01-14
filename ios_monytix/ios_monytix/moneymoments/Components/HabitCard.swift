//
//  HabitCard.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import SwiftUI

struct HabitCard: View {
    let habit: Habit
    
    private let goldColor = Color(red: 0.831, green: 0.686, blue: 0.216) // #D4AF37
    
    var body: some View {
        GlassCard(padding: 20, cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 16) {
                // Header with icon and badges
                HStack(alignment: .top) {
                    // Icon
                    Image(systemName: habit.icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(goldColor)
                        .frame(width: 40, height: 40)
                    
                    Spacer()
                    
                    // Priority badge
                    Text(habit.priority.rawValue)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(habit.priority.color)
                        )
                    
                    // Frequency tag
                    Text(habit.frequency.rawValue)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.gray.opacity(0.8))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.gray.opacity(0.2))
                        )
                }
                
                // Description
                Text(habit.description)
                    .font(.system(size: 14))
                    .foregroundColor(.gray.opacity(0.9))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Progress bar
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("\(habit.currentStreak) day streak")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Text(habit.displayProgress)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gray.opacity(0.7))
                    }
                    
                    // Progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 8)
                            
                            // Progress
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [goldColor, goldColor.opacity(0.7)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * habit.progressPercentage, height: 8)
                        }
                    }
                    .frame(height: 8)
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        HabitCard(habit: Habit(
            id: "test1",
            habitId: "morning_money_check",
            name: "Morning Money Check",
            description: "Check your account balance and daily budget every morning",
            priority: .high,
            frequency: .daily,
            currentStreak: 15,
            targetStreak: 30,
            icon: "sun.max.fill",
            createdAt: Date()
        ))
        
        HabitCard(habit: Habit(
            id: "test2",
            habitId: "no_spend_days",
            name: "No-Spend Days",
            description: "Have at least 2 no-spend days per week",
            priority: .medium,
            frequency: .weekly,
            currentStreak: 8,
            targetStreak: 30,
            icon: "xmark.circle.fill",
            createdAt: Date()
        ))
    }
    .padding()
    .background(Color(red: 0.18, green: 0.18, blue: 0.18))
}

