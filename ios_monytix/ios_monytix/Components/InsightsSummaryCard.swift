//
//  InsightsSummaryCard.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import SwiftUI

struct InsightsSummaryCard: View {
    let insights: Insights
    
    @State private var isVisible = false
    
    private let goldColor = Color(red: 0.831, green: 0.686, blue: 0.216) // #D4AF37
    
    var body: some View {
        GlassCard(padding: 24, cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Key Insights")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Your spending patterns")
                            .font(.system(size: 14))
                            .foregroundColor(.gray.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 28))
                        .foregroundColor(goldColor)
                }
                
                // Quick Stats
                if let breakdown = insights.categoryBreakdown, !breakdown.isEmpty {
                    HStack(spacing: 16) {
                        QuickStatItem(
                            label: "Categories",
                            value: "\(breakdown.count)",
                            icon: "square.grid.2x2",
                            color: .blue
                        )
                        
                        QuickStatItem(
                            label: "Top Category",
                            value: topCategoryName,
                            icon: "star.fill",
                            color: goldColor
                        )
                    }
                }
                
                // Key Takeaways
                if !keyTakeaways.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Takeaways")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        
                        ForEach(keyTakeaways, id: \.self) { takeaway in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.green)
                                    .padding(.top, 2)
                                
                                Text(takeaway)
                                    .font(.system(size: 13))
                                    .foregroundColor(.gray.opacity(0.9))
                                    .fixedSize(horizontal: false, vertical: true)
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
        }
    }
    
    // MARK: - Computed Properties
    
    private var topCategoryName: String {
        guard let breakdown = insights.categoryBreakdown,
              let top = breakdown.max(by: { $0.amount < $1.amount }) else {
            return "N/A"
        }
        return top.categoryName
    }
    
    private var keyTakeaways: [String] {
        var takeaways: [String] = []
        
        if let breakdown = insights.categoryBreakdown, !breakdown.isEmpty {
            let topCategory = breakdown.max(by: { $0.amount < $1.amount })!
            let topPercentage = topCategory.percentage
            
            if topPercentage > 40 {
                takeaways.append("\(topCategory.categoryName) accounts for \(String(format: "%.1f", topPercentage))% of spending")
            }
            
            if breakdown.count > 5 {
                takeaways.append("Spending is spread across \(breakdown.count) categories")
            }
        }
        
        if let recurring = insights.recurringTransactions, !recurring.isEmpty {
            let totalRecurring = recurring.reduce(0) { $0 + $1.avgAmount }
            takeaways.append("\(recurring.count) recurring transactions totaling ₹\(Int(totalRecurring))")
        }
        
        return Array(takeaways.prefix(3))
    }
}

// MARK: - Quick Stat Item

struct QuickStatItem: View {
    let label: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)
                
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray.opacity(0.8))
            }
            
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
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
    InsightsSummaryCard(
        insights: Insights(
            categoryBreakdown: [
                CategoryBreakdown(
                    categoryName: "Food & Dining",
                    amount: 15000,
                    percentage: 35.5,
                    transactionCount: 42
                ),
                CategoryBreakdown(
                    categoryName: "Shopping",
                    amount: 8500,
                    percentage: 20.2,
                    transactionCount: 18
                )
            ],
            recurringTransactions: [
                RecurringTransaction(
                    merchantName: "Netflix",
                    categoryName: "Entertainment",
                    frequency: "Monthly",
                    avgAmount: 799
                )
            ]
        )
    )
    .padding()
    .background(Color(red: 0.18, green: 0.18, blue: 0.18))
}

