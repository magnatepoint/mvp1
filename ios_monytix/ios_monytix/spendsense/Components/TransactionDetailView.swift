//
//  TransactionDetailView.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import SwiftUI

struct TransactionDetailView: View {
    let transaction: Transaction
    @Binding var isPresented: Bool
    
    @State private var notes: String = ""
    
    private let goldColor = Color(red: 0.831, green: 0.686, blue: 0.216)
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Transaction Header
                    transactionHeader
                    
                    // Details
                    detailsSection
                    
                    // Notes Section
                    notesSection
                }
                .padding(20)
            }
            .background(Color(red: 0.18, green: 0.18, blue: 0.18))
            .navigationTitle("Transaction Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                    .foregroundColor(goldColor)
                }
            }
        }
    }
    
    // MARK: - Views
    
    private var transactionHeader: some View {
        GlassCard(padding: 24, cornerRadius: 20) {
            VStack(spacing: 20) {
                // Icon
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
                        .frame(width: 70, height: 70)
                    
                    Image(systemName: merchantIcon)
                        .foregroundColor(categoryColor)
                        .font(.system(size: 32, weight: .semibold))
                }
                
                // Amount
                Text("\(transaction.isDebit ? "-" : "+")\(formatCurrency(abs(transaction.amount)))")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(
                        transaction.isDebit
                            ? Color(red: 0.957, green: 0.263, blue: 0.212)
                            : Color(red: 0.298, green: 0.686, blue: 0.314)
                    )
                
                // Merchant
                Text(transaction.displayMerchant)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
    }
    
    private var detailsSection: some View {
        GlassCard(padding: 20, cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Details")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                VStack(spacing: 12) {
                    detailRow(label: "Date", value: formatFullDate(transaction.txnDate))
                    Divider().background(Color.gray.opacity(0.2))
                    detailRow(label: "Category", value: transaction.displayCategory)
                    if let subcategory = transaction.subcategory ?? transaction.subcategoryCode {
                        Divider().background(Color.gray.opacity(0.2))
                        detailRow(label: "Subcategory", value: subcategory)
                    }
                    Divider().background(Color.gray.opacity(0.2))
                    detailRow(label: "Type", value: transaction.isDebit ? "Debit" : "Credit")
                    if let description = transaction.description {
                        Divider().background(Color.gray.opacity(0.2))
                        detailRow(label: "Description", value: description)
                    }
                }
            }
        }
    }
    
    private var notesSection: some View {
        GlassCard(padding: 20, cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Notes")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                TextField("Add a note...", text: $notes, axis: .vertical)
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.15))
                    )
                    .lineLimit(3...6)
            }
        }
    }
    
    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.gray.opacity(0.8))
            
            Spacer()
            
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
        }
    }
    
    // MARK: - Helpers
    
    private var categoryColor: Color {
        let category = transaction.displayCategory.lowercased()
        if category.contains("food") || category.contains("dining") {
            return Color(red: 1.0, green: 0.596, blue: 0.0)
        } else if category.contains("shopping") {
            return Color(red: 0.612, green: 0.153, blue: 0.690)
        } else if category.contains("transport") {
            return Color(red: 0.129, green: 0.588, blue: 0.953)
        } else if category.contains("income") {
            return Color(red: 0.298, green: 0.686, blue: 0.314)
        } else {
            return goldColor
        }
    }
    
    private var merchantIcon: String {
        let merchant = transaction.displayMerchant.lowercased()
        if merchant.contains("amazon") {
            return "cart.fill"
        } else if merchant.contains("netflix") {
            return "tv.fill"
        } else if merchant.contains("uber") {
            return "car.fill"
        } else {
            return transaction.isDebit ? "arrow.down" : "arrow.up"
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
    
    private func formatFullDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "EEEE, MMM d, yyyy"
            return displayFormatter.string(from: date)
        }
        
        return dateString
    }
}

#Preview {
    TransactionDetailView(
        transaction: Transaction(
            merchant: "Amazon",
            merchantNameNorm: nil,
            description: "Online purchase",
            category: "Shopping",
            categoryCode: nil,
            subcategory: "Electronics",
            subcategoryCode: nil,
            amount: 2500,
            direction: "debit",
            txnDate: "2026-01-05"
        ),
        isPresented: .constant(true)
    )
}

