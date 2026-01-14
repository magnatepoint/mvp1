package com.example.apk.spendsense.models

import com.google.gson.annotations.SerializedName

// MARK: - KPIs
data class SpendSenseKPIs(
    @SerializedName("income_amount") val incomeAmount: Double? = null,
    @SerializedName("needs_amount") val needsAmount: Double? = null,
    @SerializedName("wants_amount") val wantsAmount: Double? = null,
    @SerializedName("assets_amount") val assetsAmount: Double? = null,
    @SerializedName("wants_gauge") val wantsGauge: WantsGauge? = null,
    @SerializedName("top_categories") val topCategories: List<TopCategory>? = null
) {
    fun calculateSavingsRate(): Double {
        val income = incomeAmount ?: return 0.0
        val assets = assetsAmount ?: return 0.0
        if (income <= 0) return 0.0
        return minOf(100.0, (assets / income) * 100)
    }

    fun calculateSpendingEfficiency(): Double {
        val needs = needsAmount ?: return 0.0
        val wants = wantsAmount ?: return 0.0
        val totalExpenses = needs + wants
        if (totalExpenses <= 0) return 0.0
        return (needs / totalExpenses) * 100
    }

    fun calculateFinancialHealthScore(): Double {
        val savingsRate = calculateSavingsRate()
        val efficiency = calculateSpendingEfficiency()
        val stability = calculateStabilityScore()
        val score = (savingsRate * 0.4) + (efficiency * 0.3) + (stability * 0.3)
        return minOf(100.0, maxOf(0.0, score))
    }

    private fun calculateStabilityScore(): Double {
        val gauge = wantsGauge ?: return 50.0
        return maxOf(0.0, 100.0 - (gauge.ratio * 100))
    }
}

data class WantsGauge(
    val ratio: Double,
    @SerializedName("threshold_crossed") val thresholdCrossed: Boolean,
    val label: String
)

data class TopCategory(
    @SerializedName("category_name") val categoryName: String? = null,
    @SerializedName("category_code") val categoryCode: String? = null,
    val share: Double? = null,
    @SerializedName("change_pct") val changePct: Double? = null,
    @SerializedName("spend_amount") val spendAmount: Double? = null,
    @SerializedName("txn_count") val txnCount: Int? = null
)

// MARK: - Transaction
data class Transaction(
    val id: String,
    val merchant: String? = null,
    @SerializedName("merchant_name_norm") val merchantNameNorm: String? = null,
    val description: String? = null,
    val category: String? = null,
    @SerializedName("category_code") val categoryCode: String? = null,
    val subcategory: String? = null,
    @SerializedName("subcategory_code") val subcategoryCode: String? = null,
    val amount: Double,
    val direction: String, // "debit" or "credit"
    @SerializedName("txn_date") val txnDate: String
)

// MARK: - Insights
data class Insights(
    @SerializedName("time_series") val timeSeries: List<TimeSeriesPoint>? = null,
    @SerializedName("category_breakdown") val categoryBreakdown: List<CategoryBreakdownItem>? = null,
    @SerializedName("spending_trends") val spendingTrends: List<SpendingTrend>? = null,
    @SerializedName("recurring_transactions") val recurringTransactions: List<RecurringTransaction>? = null,
    @SerializedName("spending_patterns") val spendingPatterns: List<SpendingPattern>? = null,
    @SerializedName("top_merchants") val topMerchants: List<TopMerchant>? = null,
    val anomalies: List<Anomaly>? = null
)

data class TimeSeriesPoint(
    val date: String,
    val amount: Double,
    val count: Int
)

data class CategoryBreakdownItem(
    @SerializedName("category_code") val categoryCode: String,
    @SerializedName("category_name") val categoryName: String,
    val amount: Double,
    val share: Double,
    val count: Int,
    val subcategories: List<SubcategoryBreakdown>? = null
)

data class SubcategoryBreakdown(
    @SerializedName("subcategory_code") val subcategoryCode: String,
    @SerializedName("subcategory_name") val subcategoryName: String,
    val amount: Double,
    val share: Double,
    val count: Int
)

data class SpendingTrend(
    val period: String,
    val change: Double,
    val direction: String // "up", "down", "stable"
)

data class RecurringTransaction(
    val merchant: String,
    val amount: Double,
    val frequency: String,
    val lastDate: String
)

data class SpendingPattern(
    @SerializedName("time_of_day") val timeOfDay: String? = null,
    val amount: Double,
    @SerializedName("transaction_count") val transactionCount: Int
)

data class TopMerchant(
    val merchant: String,
    val amount: Double,
    val count: Int
)

data class Anomaly(
    val date: String,
    val amount: Double,
    val description: String
)

// MARK: - API Responses
data class TransactionListResponse(
    val transactions: List<Transaction>,
    val total: Int,
    val page: Int,
    @SerializedName("page_size") val pageSize: Int
)

data class AvailableMonthsResponse(
    val data: List<String>
)


