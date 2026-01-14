//
//  MolyConsoleModels.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import Foundation

// MARK: - Overview Summary

struct OverviewSummary: Codable {
    let totalBalance: Double
    let thisMonthSpending: Double
    let savingsRate: Double
    let activeGoalsCount: Int
    let latestInsight: AIInsight?
    
    enum CodingKeys: String, CodingKey {
        case totalBalance = "total_balance"
        case thisMonthSpending = "this_month_spending"
        case savingsRate = "savings_rate"
        case activeGoalsCount = "active_goals_count"
        case latestInsight = "latest_insight"
    }
}

// MARK: - Account

struct Account: Codable, Identifiable {
    let id: UUID
    let bankName: String
    let accountType: AccountType
    let balance: Double
    let accountNumber: String?
    let lastUpdated: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case bankName = "bank_name"
        case accountType = "account_type"
        case balance
        case accountNumber = "account_number"
        case lastUpdated = "last_updated"
    }
    
    init(id: UUID, bankName: String, accountType: AccountType, balance: Double, accountNumber: String?, lastUpdated: Date?) {
        self.id = id
        self.bankName = bankName
        self.accountType = accountType
        self.balance = balance
        self.accountNumber = accountNumber
        self.lastUpdated = lastUpdated
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        bankName = try container.decode(String.self, forKey: .bankName)
        accountType = try container.decode(AccountType.self, forKey: .accountType)
        balance = try container.decode(Double.self, forKey: .balance)
        accountNumber = try container.decodeIfPresent(String.self, forKey: .accountNumber)
        
        if let dateString = try? container.decodeIfPresent(String.self, forKey: .lastUpdated) {
            let formatter = ISO8601DateFormatter()
            lastUpdated = formatter.date(from: dateString)
        } else {
            lastUpdated = nil
        }
    }
}

enum AccountType: String, Codable {
    case checking = "CHECKING"
    case savings = "SAVINGS"
    case investment = "INVESTMENT"
    case credit = "CREDIT"
    
    var displayName: String {
        rawValue.capitalized
    }
    
    var icon: String {
        switch self {
        case .checking:
            return "creditcard.fill"
        case .savings:
            return "banknote.fill"
        case .investment:
            return "chart.line.uptrend.xyaxis"
        case .credit:
            return "creditcard.trianglebadge.exclamationmark"
        }
    }
}

// MARK: - Goal

struct Goal: Codable, Identifiable {
    let id: UUID
    let name: String
    let targetAmount: Double
    let savedAmount: Double
    let targetDate: Date?
    let category: String?
    let isActive: Bool
    
    var progress: Double {
        guard targetAmount > 0 else { return 0 }
        return min(savedAmount / targetAmount, 1.0)
    }
    
    var progressPercentage: Double {
        progress * 100
    }
    
    var remainingAmount: Double {
        max(targetAmount - savedAmount, 0)
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case targetAmount = "target_amount"
        case savedAmount = "saved_amount"
        case targetDate = "target_date"
        case category
        case isActive = "is_active"
    }
    
    init(id: UUID, name: String, targetAmount: Double, savedAmount: Double, targetDate: Date?, category: String?, isActive: Bool) {
        self.id = id
        self.name = name
        self.targetAmount = targetAmount
        self.savedAmount = savedAmount
        self.targetDate = targetDate
        self.category = category
        self.isActive = isActive
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        targetAmount = try container.decode(Double.self, forKey: .targetAmount)
        savedAmount = try container.decode(Double.self, forKey: .savedAmount)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        isActive = try container.decode(Bool.self, forKey: .isActive)
        
        if let dateString = try? container.decodeIfPresent(String.self, forKey: .targetDate) {
            let formatter = ISO8601DateFormatter()
            targetDate = formatter.date(from: dateString)
        } else {
            targetDate = nil
        }
    }
}

// MARK: - AI Insight

struct AIInsight: Codable, Identifiable {
    let id: UUID
    let title: String
    let message: String
    let type: InsightType
    let priority: InsightPriority
    let createdAt: Date?
    let category: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case message
        case type
        case priority
        case createdAt = "created_at"
        case category
    }
    
    init(id: UUID, title: String, message: String, type: InsightType, priority: InsightPriority, createdAt: Date?, category: String?) {
        self.id = id
        self.title = title
        self.message = message
        self.type = type
        self.priority = priority
        self.createdAt = createdAt
        self.category = category
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        message = try container.decode(String.self, forKey: .message)
        type = try container.decode(InsightType.self, forKey: .type)
        priority = try container.decode(InsightPriority.self, forKey: .priority)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        
        if let dateString = try? container.decodeIfPresent(String.self, forKey: .createdAt) {
            let formatter = ISO8601DateFormatter()
            createdAt = formatter.date(from: dateString)
        } else {
            createdAt = nil
        }
    }
}

enum InsightType: String, Codable {
    case spendingAlert = "spending_alert"
    case goalProgress = "goal_progress"
    case investmentRecommendation = "investment_recommendation"
    case budgetTip = "budget_tip"
    case savingsOpportunity = "savings_opportunity"
    
    var displayName: String {
        switch self {
        case .spendingAlert:
            return "Spending Alert"
        case .goalProgress:
            return "Goal Progress"
        case .investmentRecommendation:
            return "Investment Tip"
        case .budgetTip:
            return "Budget Tip"
        case .savingsOpportunity:
            return "Savings Opportunity"
        }
    }
    
    var icon: String {
        switch self {
        case .spendingAlert:
            return "exclamationmark.triangle.fill"
        case .goalProgress:
            return "arrow.up.circle.fill"
        case .investmentRecommendation:
            return "chart.line.uptrend.xyaxis"
        case .budgetTip:
            return "lightbulb.fill"
        case .savingsOpportunity:
            return "dollarsign.circle.fill"
        }
    }
    
    var color: String {
        switch self {
        case .spendingAlert:
            return "yellow"
        case .goalProgress:
            return "green"
        case .investmentRecommendation:
            return "purple"
        case .budgetTip:
            return "blue"
        case .savingsOpportunity:
            return "green"
        }
    }
}

enum InsightPriority: String, Codable {
    case high = "high"
    case medium = "medium"
    case low = "low"
}

