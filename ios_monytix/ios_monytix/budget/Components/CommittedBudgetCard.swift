//
//  CommittedBudgetCard.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import SwiftUI

struct CommittedBudgetCard: View {
    let committedBudget: CommittedBudget
    
    private let goldColor = Color(red: 0.831, green: 0.686, blue: 0.216)
    
    var body: some View {
        GlassCard(padding: 20, cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    Text("Your Committed Budget")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text("✓")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.green)
                }
                
                // Budget Summary
                VStack(spacing: 12) {
                    BudgetSummaryRow(
                        label: "Needs",
                        percentage: committedBudget.allocNeedsPct,
                        color: .blue
                    )
                    
                    BudgetSummaryRow(
                        label: "Wants",
                        percentage: committedBudget.allocWantsPct,
                        color: .orange
                    )
                    
                    BudgetSummaryRow(
                        label: "Savings",
                        percentage: committedBudget.allocAssetsPct,
                        color: .green
                    )
                }
                
                // Allocation Bar
                BudgetAllocationBar(
                    needsPct: committedBudget.allocNeedsPct,
                    wantsPct: committedBudget.allocWantsPct,
                    savingsPct: committedBudget.allocAssetsPct
                )
                
                // Goal Allocations
                if !committedBudget.goalAllocations.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Goal Allocations")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        
                        ForEach(committedBudget.goalAllocations) { allocation in
                            HStack {
                                Text(allocation.goalName ?? allocation.goalId.prefix(8) + "...")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray.opacity(0.8))
                                
                                Spacer()
                                
                                Text(formatCurrency(allocation.plannedAmount))
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(12)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                
                // Committed Date
                if let committedDate = parseDate(committedBudget.committedAt) {
                    Text("Committed on \(formatDate(committedDate))")
                        .font(.system(size: 12))
                        .foregroundColor(.gray.opacity(0.6))
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
    
    private func parseDate(_ dateString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime]
        return formatter.date(from: dateString)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - Budget Summary Row

struct BudgetSummaryRow: View {
    let label: String
    let percentage: Double
    let color: Color
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray.opacity(0.7))
            
            Spacer()
            
            Text("\(Int(percentage * 100))%")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(color)
        }
    }
}

#Preview {
    CommittedBudgetCard(
        committedBudget: CommittedBudget(
            userId: "123",
            month: "2025-01",
            planCode: "balanced",
            allocNeedsPct: 0.5,
            allocWantsPct: 0.3,
            allocAssetsPct: 0.2,
            notes: nil,
            committedAt: "2025-01-15T00:00:00Z",
            goalAllocations: []
        )
    )
    .padding()
    .background(Color(red: 0.18, green: 0.18, blue: 0.18))
}

