//
//  TransactionRow.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import SwiftUI

struct TransactionRow: View {
    let transaction: Transaction
    let onTap: (() -> Void)?
    
    init(transaction: Transaction, onTap: (() -> Void)? = nil) {
        self.transaction = transaction
        self.onTap = onTap
    }
    
    var body: some View {
        Button(action: {
            onTap?()
        }) {
            HStack(spacing: 16) {
                // Avatar with category color
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    categoryColor.opacity(0.4),
                                    categoryColor.opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                    
                    // Merchant initial or icon
                    if let initial = merchantInitial {
                        Text(initial)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(categoryColor)
                    } else {
                        Image(systemName: merchantIcon)
                            .foregroundColor(categoryColor)
                            .font(.system(size: 20, weight: .semibold))
                    }
                }
                
                // Content
                VStack(alignment: .leading, spacing: 6) {
                    Text(transaction.displayMerchant)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        // Category badge
                        HStack(spacing: 4) {
                            Circle()
                                .fill(categoryColor)
                                .frame(width: 6, height: 6)
                            
                            Text(transaction.displayCategory)
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(.gray.opacity(0.8))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(categoryColor.opacity(0.15))
                        )
                        
                        Text("•")
                            .foregroundColor(.gray.opacity(0.5))
                        
                        Text(formatDate(transaction.txnDate))
                            .font(.system(size: 13))
                            .foregroundColor(.gray.opacity(0.7))
                    }
                }
                
                Spacer()
                
                // Amount
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(transaction.isDebit ? "-" : "+")\(formatCurrency(abs(transaction.amount)))")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(
                            transaction.isDebit
                                ? Color(red: 0.957, green: 0.263, blue: 0.212)
                                : Color(red: 0.298, green: 0.686, blue: 0.314)
                        )
                    
                    if abs(transaction.amount) > 10000 {
                        Text("Large")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.gray.opacity(0.6))
                    }
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .frame(minHeight: 72)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Helpers
    
    private var categoryColor: Color {
        let category = transaction.displayCategory.lowercased()
        if category.contains("food") || category.contains("dining") {
            return Color(red: 1.0, green: 0.596, blue: 0.0) // Orange
        } else if category.contains("shopping") {
            return Color(red: 0.612, green: 0.153, blue: 0.690) // Purple
        } else if category.contains("transport") || category.contains("travel") {
            return Color(red: 0.129, green: 0.588, blue: 0.953) // Blue
        } else if category.contains("entertainment") {
            return Color(red: 0.957, green: 0.263, blue: 0.212) // Red
        } else if category.contains("income") {
            return Color(red: 0.298, green: 0.686, blue: 0.314) // Green
        } else {
            return Color(red: 0.831, green: 0.686, blue: 0.216) // Gold
        }
    }
    
    private var merchantIcon: String {
        let merchant = transaction.displayMerchant.lowercased()
        if merchant.contains("amazon") {
            return "cart.fill"
        } else if merchant.contains("netflix") || merchant.contains("spotify") {
            return "tv.fill"
        } else if merchant.contains("uber") || merchant.contains("ola") {
            return "car.fill"
        } else if merchant.contains("zomato") || merchant.contains("swiggy") {
            return "fork.knife"
        } else {
            return transaction.isDebit ? "arrow.down" : "arrow.up"
        }
    }
    
    private var merchantInitial: String? {
        let merchant = transaction.displayMerchant
        if let firstChar = merchant.first, firstChar.isLetter {
            return String(firstChar).uppercased()
        }
        return nil
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "INR"
        formatter.currencySymbol = "₹"
        formatter.maximumFractionDigits = 0
        
        return formatter.string(from: NSNumber(value: amount)) ?? "₹0"
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "d MMM"
            return displayFormatter.string(from: date)
        }
        
        return dateString
    }
}

#Preview {
    VStack(spacing: 0) {
        TransactionRow(
            transaction: Transaction(
                merchant: "Amazon",
                merchantNameNorm: nil,
                description: nil,
                category: "Shopping",
                categoryCode: nil,
                subcategory: "Electronics",
                subcategoryCode: nil,
                amount: 2500,
                direction: "debit",
                txnDate: "2026-01-05"
            )
        )
        
        Divider()
            .background(Color.gray.opacity(0.2))
        
        TransactionRow(
            transaction: Transaction(
                merchant: "Salary",
                merchantNameNorm: nil,
                description: nil,
                category: "Income",
                categoryCode: nil,
                subcategory: nil,
                subcategoryCode: nil,
                amount: 50000,
                direction: "credit",
                txnDate: "2026-01-01"
            )
        )
    }
    .padding()
    .background(Color(red: 0.18, green: 0.18, blue: 0.18))
}

