//
//  RecurringTransactionCard.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import SwiftUI

struct RecurringTransactionCard: View {
    let transaction: RecurringTransaction
    let index: Int
    let onTap: (() -> Void)?
    
    @State private var isVisible = false
    
    private let goldColor = Color(red: 0.831, green: 0.686, blue: 0.216) // #D4AF37
    
    init(
        transaction: RecurringTransaction,
        index: Int,
        onTap: (() -> Void)? = nil
    ) {
        self.transaction = transaction
        self.index = index
        self.onTap = onTap
    }
    
    var body: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            onTap?()
        }) {
            GlassCard(padding: 20, cornerRadius: 16) {
                HStack(spacing: 16) {
                    // Frequency Icon
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        goldColor.opacity(0.4),
                                        goldColor.opacity(0.2)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 56, height: 56)
                        
                        Image(systemName: frequencyIcon)
                            .foregroundColor(goldColor)
                            .font(.system(size: 26, weight: .semibold))
                    }
                    
                    // Content
                    VStack(alignment: .leading, spacing: 12) {
                        // Merchant Name
                        Text(transaction.merchantName)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        // Category and Frequency
                        HStack(spacing: 6) {
                            if let category = transaction.categoryName {
                                Text(category)
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray.opacity(0.7))
                                
                                Text("•")
                                    .foregroundColor(.gray.opacity(0.5))
                            }
                            
                            HStack(spacing: 4) {
                                Image(systemName: frequencyIcon)
                                    .font(.system(size: 12))
                                
                                Text(transaction.frequency)
                                    .font(.system(size: 14))
                            }
                            .foregroundColor(.gray.opacity(0.7))
                        }
                        
                        // Amount and Impact
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Average Amount")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray.opacity(0.6))
                                
                                Text(formatCurrency(transaction.avgAmount))
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Monthly Impact")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray.opacity(0.6))
                                
                                Text(formatCurrency(monthlyImpact))
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(goldColor)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.gray.opacity(0.5))
                }
            }
            .frame(minHeight: 100)
        }
        .buttonStyle(PlainButtonStyle())
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 10)
        .onAppear {
            let delay = Double(index) * 0.05
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(delay)) {
                isVisible = true
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var frequencyIcon: String {
        let freq = transaction.frequency.lowercased()
        if freq.contains("daily") {
            return "sun.max.fill"
        } else if freq.contains("weekly") {
            return "calendar.badge.clock"
        } else if freq.contains("monthly") {
            return "calendar"
        } else if freq.contains("yearly") || freq.contains("annual") {
            return "calendar.badge.exclamationmark"
        } else {
            return "repeat"
        }
    }
    
    private var monthlyImpact: Double {
        let freq = transaction.frequency.lowercased()
        if freq.contains("daily") {
            return transaction.avgAmount * 30
        } else if freq.contains("weekly") {
            return transaction.avgAmount * 4
        } else if freq.contains("monthly") {
            return transaction.avgAmount
        } else if freq.contains("yearly") || freq.contains("annual") {
            return transaction.avgAmount / 12
        } else {
            return transaction.avgAmount
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "INR"
        formatter.currencySymbol = "₹"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "₹0"
    }
}

#Preview {
    VStack(spacing: 16) {
        RecurringTransactionCard(
            transaction: RecurringTransaction(
                merchantName: "Netflix",
                categoryName: "Entertainment",
                frequency: "Monthly",
                avgAmount: 799
            ),
            index: 0
        )
        
        RecurringTransactionCard(
            transaction: RecurringTransaction(
                merchantName: "Amazon Prime",
                categoryName: "Shopping",
                frequency: "Yearly",
                avgAmount: 1499
            ),
            index: 1
        )
    }
    .padding()
    .background(Color(red: 0.18, green: 0.18, blue: 0.18))
}

