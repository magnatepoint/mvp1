package com.example.apk.console.models

import java.util.UUID

// MARK: - Overview Summary
data class OverviewSummary(
    val totalBalance: Double,
    val thisMonthSpending: Double,
    val savingsRate: Double,
    val activeGoalsCount: Int,
    val latestInsight: AIInsight?
)

// MARK: - Account
data class Account(
    val id: UUID,
    val bankName: String,
    val accountType: AccountType,
    val balance: Double,
    val accountNumber: String?,
    val lastUpdated: Long? // Unix timestamp
) {
    val displayName: String
        get() = accountType.displayName
}

enum class AccountType {
    CHECKING,
    SAVINGS,
    INVESTMENT,
    CREDIT;
    
    val displayName: String
        get() = name.lowercase().replaceFirstChar { it.uppercase() }
}

// MARK: - Goal
data class Goal(
    val id: UUID,
    val name: String,
    val targetAmount: Double,
    val savedAmount: Double,
    val targetDate: Long?, // Unix timestamp
    val category: String?,
    val isActive: Boolean
) {
    val progress: Double
        get() = if (targetAmount > 0) {
            (savedAmount / targetAmount).coerceIn(0.0, 1.0)
        } else {
            0.0
        }
    
    val progressPercentage: Double
        get() = progress * 100
    
    val remainingAmount: Double
        get() = (targetAmount - savedAmount).coerceAtLeast(0.0)
}

// MARK: - AI Insight
data class AIInsight(
    val id: UUID,
    val title: String,
    val message: String,
    val type: InsightType,
    val priority: InsightPriority,
    val createdAt: Long?, // Unix timestamp
    val category: String?
)

enum class InsightType {
    SPENDING_ALERT,
    GOAL_PROGRESS,
    INVESTMENT_RECOMMENDATION,
    BUDGET_TIP,
    SAVINGS_OPPORTUNITY;
    
    val displayName: String
        get() = when (this) {
            SPENDING_ALERT -> "Spending Alert"
            GOAL_PROGRESS -> "Goal Progress"
            INVESTMENT_RECOMMENDATION -> "Investment Tip"
            BUDGET_TIP -> "Budget Tip"
            SAVINGS_OPPORTUNITY -> "Savings Opportunity"
        }
}

enum class InsightPriority {
    HIGH,
    MEDIUM,
    LOW
}

// MARK: - Category Spending
data class CategorySpending(
    val id: UUID = UUID.randomUUID(),
    val category: String,
    val amount: Double,
    val percentage: Double,
    val transactionCount: Int
)

