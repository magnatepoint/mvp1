//
//  SpendSenseModels.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import Foundation

// MARK: - KPIs
struct SpendSenseKPIs: Codable {
    let incomeAmount: Double?
    let needsAmount: Double?
    let wantsAmount: Double?
    let assetsAmount: Double?
    let wantsGauge: WantsGauge?
    let topCategories: [TopCategory]?
    
    enum CodingKeys: String, CodingKey {
        case incomeAmount = "income_amount"
        case needsAmount = "needs_amount"
        case wantsAmount = "wants_amount"
        case assetsAmount = "assets_amount"
        case wantsGauge = "wants_gauge"
        case topCategories = "top_categories"
    }
}

// MARK: - SpendSenseKPIs Extensions

extension SpendSenseKPIs {
    // Computed properties for trends (would ideally come from API)
    var incomeTrend: Double? { nil } // Month-over-month change
    var needsTrend: Double? { nil }
    var wantsTrend: Double? { nil }
    var assetsTrend: Double? { nil }
    
    // Helper to calculate financial health metrics
    func calculateSavingsRate() -> Double {
        guard let income = incomeAmount, income > 0,
              let assets = assetsAmount else {
            return 0
        }
        return min(100, (assets / income) * 100)
    }
    
    func calculateSpendingEfficiency() -> Double {
        guard let needs = needsAmount,
              let wants = wantsAmount else {
            return 0
        }
        let totalExpenses = needs + wants
        guard totalExpenses > 0 else { return 0 }
        return (needs / totalExpenses) * 100
    }
    
    func calculateFinancialHealthScore() -> Double {
        let savingsRate = calculateSavingsRate()
        let efficiency = calculateSpendingEfficiency()
        let stability = calculateStabilityScore()
        
        // Weighted formula: (savingsRate * 40) + (efficiency * 30) + (stability * 30)
        let score = (savingsRate * 0.4) + (efficiency * 0.3) + (stability * 0.3)
        return min(100, max(0, score))
    }
    
    private func calculateStabilityScore() -> Double {
        // Simple stability score based on wants gauge
        // Lower wants ratio = higher stability
        if let gauge = wantsGauge {
            return max(0, 100 - (gauge.ratio * 100))
        }
        return 50 // Default middle score
    }
}

struct WantsGauge: Codable {
    let ratio: Double
    let thresholdCrossed: Bool
    let label: String
    
    enum CodingKeys: String, CodingKey {
        case ratio
        case thresholdCrossed = "threshold_crossed"
        case label
    }
}

struct TopCategory: Codable, Identifiable {
    let id = UUID()
    let categoryName: String?
    let categoryCode: String?
    let share: Double?
    let changePct: Double?
    let spendAmount: Double?
    let txnCount: Int?
    
    enum CodingKeys: String, CodingKey {
        case categoryName = "category_name"
        case categoryCode = "category_code"
        case share
        case changePct = "change_pct"
        case spendAmount = "spend_amount"
        case txnCount = "txn_count"
    }
}

// MARK: - Transaction
struct Transaction: Codable, Identifiable {
    let id: UUID
    let merchant: String?
    let merchantNameNorm: String?
    let description: String?
    let category: String?
    let categoryCode: String?
    let subcategory: String?
    let subcategoryCode: String?
    let amount: Double
    let direction: String // "debit" or "credit"
    let txnDate: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case merchant
        case merchantNameNorm = "merchant_name_norm"
        case description
        case category
        case categoryCode = "category_code"
        case subcategory
        case subcategoryCode = "subcategory_code"
        case amount
        case direction
        case txnDate = "txn_date"
    }
    
    init(
        id: UUID = UUID(),
        merchant: String? = nil,
        merchantNameNorm: String? = nil,
        description: String? = nil,
        category: String? = nil,
        categoryCode: String? = nil,
        subcategory: String? = nil,
        subcategoryCode: String? = nil,
        amount: Double,
        direction: String,
        txnDate: String
    ) {
        self.id = id
        self.merchant = merchant
        self.merchantNameNorm = merchantNameNorm
        self.description = description
        self.category = category
        self.categoryCode = categoryCode
        self.subcategory = subcategory
        self.subcategoryCode = subcategoryCode
        self.amount = amount
        self.direction = direction
        self.txnDate = txnDate
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Try to decode UUID, if fails generate one
        if let uuidString = try? container.decode(String.self, forKey: .id),
           let uuid = UUID(uuidString: uuidString) {
            self.id = uuid
        } else {
            self.id = UUID()
        }
        self.merchant = try? container.decode(String.self, forKey: .merchant)
        self.merchantNameNorm = try? container.decode(String.self, forKey: .merchantNameNorm)
        self.description = try? container.decode(String.self, forKey: .description)
        self.category = try? container.decode(String.self, forKey: .category)
        self.categoryCode = try? container.decode(String.self, forKey: .categoryCode)
        self.subcategory = try? container.decode(String.self, forKey: .subcategory)
        self.subcategoryCode = try? container.decode(String.self, forKey: .subcategoryCode)
        
        // Handle amount as number or string
        if let amountDouble = try? container.decode(Double.self, forKey: .amount) {
            self.amount = amountDouble
        } else if let amountString = try? container.decode(String.self, forKey: .amount),
                  let amountDouble = Double(amountString) {
            self.amount = amountDouble
        } else {
            self.amount = 0.0
        }
        
        self.direction = try container.decode(String.self, forKey: .direction)
        self.txnDate = try container.decode(String.self, forKey: .txnDate)
    }
    
    var displayMerchant: String {
        merchant ?? merchantNameNorm ?? description ?? "Transaction"
    }
    
    var displayCategory: String {
        category ?? categoryCode ?? "Uncategorized"
    }
    
    var isDebit: Bool {
        direction == "debit"
    }
}

struct TransactionResponse: Codable {
    let transactions: [Transaction]
    let total: Int
}

// MARK: - Insights
struct Insights: Codable {
    let categoryBreakdown: [CategoryBreakdown]?
    let recurringTransactions: [RecurringTransaction]?
    
    enum CodingKeys: String, CodingKey {
        case categoryBreakdown = "category_breakdown"
        case recurringTransactions = "recurring_transactions"
    }
}

struct CategoryBreakdown: Codable, Identifiable {
    let id = UUID()
    let categoryName: String
    let amount: Double
    let percentage: Double
    let transactionCount: Int
    
    enum CodingKeys: String, CodingKey {
        case categoryName = "category_name"
        case amount
        case percentage
        case transactionCount = "transaction_count"
    }
}

struct SubcategoryBreakdown: Identifiable {
    let id = UUID()
    let subcategoryName: String
    let amount: Double
    let percentage: Double
    let transactionCount: Int
}

struct RecurringTransaction: Codable, Identifiable {
    let id = UUID()
    let merchantName: String
    let categoryName: String?
    let frequency: String
    let avgAmount: Double
    
    enum CodingKeys: String, CodingKey {
        case merchantName = "merchant_name"
        case categoryName = "category_name"
        case frequency
        case avgAmount = "avg_amount"
    }
}

// MARK: - Chart Data
struct ChartData: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
    let color: ChartColor
}

enum ChartColor {
    case green
    case orange
    case purple
    case blue
    case red
    
    var swiftUIColor: Color {
        switch self {
        case .green: return Color(red: 0.298, green: 0.686, blue: 0.314) // #4CAF50
        case .orange: return Color(red: 1.0, green: 0.596, blue: 0.0) // #FF9800
        case .purple: return Color(red: 0.612, green: 0.153, blue: 0.690) // #9C27B0
        case .blue: return Color(red: 0.129, green: 0.588, blue: 0.953) // #2196F3
        case .red: return Color(red: 0.957, green: 0.263, blue: 0.212) // #F44336
        }
    }
}

import SwiftUI

