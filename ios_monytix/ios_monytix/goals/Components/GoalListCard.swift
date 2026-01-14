//
//  GoalListCard.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import SwiftUI

struct GoalListCard: View {
    let goal: GoalResponse
    let progress: GoalProgress?
    
    private let goldColor = Color(red: 0.831, green: 0.686, blue: 0.216)
    
    private var isCompleted: Bool {
        goal.status.lowercased() == "completed"
    }
    
    private var priorityTag: String? {
        guard let priorityRank = goal.priorityRank else { return nil }
        if priorityRank <= 2 {
            return "HIGH"
        } else if priorityRank <= 4 {
            return "MEDIUM"
        } else {
            return "LOW"
        }
    }
    
    private var goalIcon: String {
        switch goal.goalCategory.lowercased() {
        case "emergency":
            return "shield.fill"
        case "retirement":
            return "building.2.fill"
        case "education":
            return "book.fill"
        case "healthcare":
            return "cross.case.fill"
        case "vacation", "travel":
            return "airplane"
        case "home", "housing":
            return "house.fill"
        case "vehicle", "car":
            return "car.fill"
        default:
            return "target"
        }
    }
    
    private var goalIconColor: Color {
        switch goal.goalCategory.lowercased() {
        case "emergency":
            return .green
        case "retirement":
            return .blue
        case "education":
            return .purple
        case "healthcare":
            return .red
        case "vacation", "travel":
            return .orange
        case "home", "housing":
            return .brown
        case "vehicle", "car":
            return .red
        default:
            return goldColor
        }
    }
    
    var body: some View {
        GlassCard(padding: 16, cornerRadius: 16) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(goalIconColor.opacity(0.2))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: goalIcon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(goalIconColor)
                }
                
                // Goal Info
                VStack(alignment: .leading, spacing: 6) {
                    Text(goal.goalName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    if let notes = goal.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.system(size: 13))
                            .foregroundColor(.gray.opacity(0.7))
                            .lineLimit(2)
                    } else {
                        Text(goal.goalCategory)
                            .font(.system(size: 13))
                            .foregroundColor(.gray.opacity(0.7))
                    }
                    
                    if isCompleted, let updatedAt = parseDate(goal.updatedAt) {
                        Text("Completed on \(formatDate(updatedAt))")
                            .font(.system(size: 12))
                            .foregroundColor(.green.opacity(0.8))
                            .padding(.top, 2)
                    }
                }
                
                Spacer()
                
                // Status Tag
                if isCompleted {
                    Text("COMPLETED")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green)
                        .cornerRadius(8)
                } else if let priority = priorityTag {
                    Text(priority)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(priorityColor(priority))
                        .cornerRadius(8)
                }
            }
        }
    }
    
    private func priorityColor(_ priority: String) -> Color {
        switch priority {
        case "HIGH":
            return .red
        case "MEDIUM":
            return .orange
        case "LOW":
            return .blue
        default:
            return .gray
        }
    }
    
    private func parseDate(_ dateString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime]
        return formatter.date(from: dateString)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter.string(from: date)
    }
}

#Preview {
    VStack(spacing: 16) {
        GoalListCard(
            goal: GoalResponse(
                goalId: UUID(),
                goalCategory: "Emergency",
                goalName: "Emergency Fund",
                goalType: "user_defined",
                linkedTxnType: "assets",
                estimatedCost: 1000000,
                targetDate: nil,
                currentSavings: 850000,
                importance: 5,
                priorityRank: 1,
                status: "active",
                notes: "Build 6 months of living expenses",
                createdAt: "",
                updatedAt: ""
            ),
            progress: nil
        )
        
        GoalListCard(
            goal: GoalResponse(
                goalId: UUID(),
                goalCategory: "Electronics",
                goalName: "New Laptop",
                goalType: "user_defined",
                linkedTxnType: "wants",
                estimatedCost: 150000,
                targetDate: nil,
                currentSavings: 150000,
                importance: 3,
                priorityRank: nil,
                status: "completed",
                notes: "MacBook Pro for work",
                createdAt: "",
                updatedAt: "2024-01-15T00:00:00Z"
            ),
            progress: nil
        )
    }
    .padding()
    .background(Color(red: 0.18, green: 0.18, blue: 0.18))
}

