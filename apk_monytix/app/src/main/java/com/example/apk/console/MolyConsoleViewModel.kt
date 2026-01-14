package com.example.apk.console

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.apk.auth.AuthService
import com.example.apk.console.models.*
import com.example.apk.spendsense.SpendSenseService
import com.example.apk.spendsense.models.CategoryBreakdownItem
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.util.UUID

class MolyConsoleViewModel(
    private val authService: AuthService,
    private val spendSenseService: SpendSenseService = SpendSenseService(authService)
) : ViewModel() {
    
    // Overview
    private val _overviewSummary = MutableStateFlow<OverviewSummary?>(null)
    val overviewSummary: StateFlow<OverviewSummary?> = _overviewSummary.asStateFlow()
    
    private val _isOverviewLoading = MutableStateFlow(false)
    val isOverviewLoading: StateFlow<Boolean> = _isOverviewLoading.asStateFlow()
    
    private val _overviewError = MutableStateFlow<String?>(null)
    val overviewError: StateFlow<String?> = _overviewError.asStateFlow()
    
    // Accounts
    private val _accounts = MutableStateFlow<List<Account>>(emptyList())
    val accounts: StateFlow<List<Account>> = _accounts.asStateFlow()
    
    private val _isAccountsLoading = MutableStateFlow(false)
    val isAccountsLoading: StateFlow<Boolean> = _isAccountsLoading.asStateFlow()
    
    private val _accountsError = MutableStateFlow<String?>(null)
    val accountsError: StateFlow<String?> = _accountsError.asStateFlow()
    
    // Spending
    private val _monthlySpending = MutableStateFlow(0.0)
    val monthlySpending: StateFlow<Double> = _monthlySpending.asStateFlow()
    
    private val _spendingByCategory = MutableStateFlow<List<CategorySpending>>(emptyList())
    val spendingByCategory: StateFlow<List<CategorySpending>> = _spendingByCategory.asStateFlow()
    
    private val _isSpendingLoading = MutableStateFlow(false)
    val isSpendingLoading: StateFlow<Boolean> = _isSpendingLoading.asStateFlow()
    
    private val _spendingError = MutableStateFlow<String?>(null)
    val spendingError: StateFlow<String?> = _spendingError.asStateFlow()
    
    // Goals
    private val _goals = MutableStateFlow<List<Goal>>(emptyList())
    val goals: StateFlow<List<Goal>> = _goals.asStateFlow()
    
    private val _isGoalsLoading = MutableStateFlow(false)
    val isGoalsLoading: StateFlow<Boolean> = _isGoalsLoading.asStateFlow()
    
    private val _goalsError = MutableStateFlow<String?>(null)
    val goalsError: StateFlow<String?> = _goalsError.asStateFlow()
    
    // AI Insights
    private val _aiInsights = MutableStateFlow<List<AIInsight>>(emptyList())
    val aiInsights: StateFlow<List<AIInsight>> = _aiInsights.asStateFlow()
    
    private val _isInsightsLoading = MutableStateFlow(false)
    val isInsightsLoading: StateFlow<Boolean> = _isInsightsLoading.asStateFlow()
    
    private val _insightsError = MutableStateFlow<String?>(null)
    val insightsError: StateFlow<String?> = _insightsError.asStateFlow()
    
    init {
        loadInitialData()
    }
    
    private fun loadInitialData() {
        viewModelScope.launch {
            loadOverview()
            loadAccounts()
            loadSpending()
            loadGoals()
            loadAIInsights()
        }
    }
    
    // MARK: - Overview
    
    fun loadOverview() {
        viewModelScope.launch {
            _isOverviewLoading.value = true
            _overviewError.value = null
            
            try {
                val kpisResult = spendSenseService.getKPIs()
                val insightsResult = spendSenseService.getInsights()
                
                if (kpisResult.isFailure) {
                    _overviewError.value = kpisResult.exceptionOrNull()?.message ?: "Failed to load overview"
                    return@launch
                }
                
                val kpis = kpisResult.getOrNull() ?: return@launch
                
                // Calculate total balance (from assets)
                val totalBalance = kpis.assetsAmount ?: 0.0
                
                // Calculate this month's spending
                val thisMonthSpending = (kpis.needsAmount ?: 0.0) + (kpis.wantsAmount ?: 0.0)
                
                // Calculate savings rate
                val savingsRate = kpis.calculateSavingsRate()
                
                // Get active goals count
                loadGoals()
                val activeGoalsCount = _goals.value.filter { it.isActive }.size
                
                // Get latest AI insight
                loadAIInsights()
                val latestInsight = _aiInsights.value.firstOrNull()
                
                _overviewSummary.value = OverviewSummary(
                    totalBalance = totalBalance,
                    thisMonthSpending = thisMonthSpending,
                    savingsRate = savingsRate,
                    activeGoalsCount = activeGoalsCount,
                    latestInsight = latestInsight
                )
            } catch (e: Exception) {
                _overviewError.value = e.message ?: "Unknown error"
                android.util.Log.e("MolyConsoleViewModel", "Error loading overview", e)
            } finally {
                _isOverviewLoading.value = false
            }
        }
    }
    
    // MARK: - Accounts
    
    fun loadAccounts() {
        viewModelScope.launch {
            _isAccountsLoading.value = true
            _accountsError.value = null
            
            try {
                val kpisResult = spendSenseService.getKPIs()
                
                if (kpisResult.isFailure) {
                    _accounts.value = createDefaultMockAccounts()
                    return@launch
                }
                
                val kpis = kpisResult.getOrNull() ?: return@launch
                
                // Create mock accounts based on KPIs
                val mockAccounts = mutableListOf<Account>()
                
                val assets = kpis.assetsAmount ?: 0.0
                if (assets > 0) {
                    mockAccounts.add(
                        Account(
                            id = UUID.randomUUID(),
                            bankName = "SBI Bank",
                            accountType = AccountType.SAVINGS,
                            balance = assets * 0.5,
                            accountNumber = "****1234",
                            lastUpdated = System.currentTimeMillis()
                        )
                    )
                    
                    mockAccounts.add(
                        Account(
                            id = UUID.randomUUID(),
                            bankName = "Zerodha",
                            accountType = AccountType.INVESTMENT,
                            balance = assets * 0.5,
                            accountNumber = null,
                            lastUpdated = System.currentTimeMillis()
                        )
                    )
                }
                
                val needs = kpis.needsAmount ?: 0.0
                if (needs > 0) {
                    mockAccounts.add(
                        Account(
                            id = UUID.randomUUID(),
                            bankName = "HDFC Bank",
                            accountType = AccountType.CHECKING,
                            balance = (kpis.incomeAmount ?: 0.0) * 0.2,
                            accountNumber = "****5678",
                            lastUpdated = System.currentTimeMillis()
                        )
                    )
                }
                
                _accounts.value = if (mockAccounts.isEmpty()) {
                    createDefaultMockAccounts()
                } else {
                    mockAccounts
                }
            } catch (e: Exception) {
                _accountsError.value = e.message ?: "Unknown error"
                _accounts.value = createDefaultMockAccounts()
                android.util.Log.e("MolyConsoleViewModel", "Error loading accounts", e)
            } finally {
                _isAccountsLoading.value = false
            }
        }
    }
    
    private fun createDefaultMockAccounts(): List<Account> {
        return listOf(
            Account(
                id = UUID.randomUUID(),
                bankName = "HDFC Bank",
                accountType = AccountType.CHECKING,
                balance = 854051.0,
                accountNumber = "****5678",
                lastUpdated = System.currentTimeMillis()
            ),
            Account(
                id = UUID.randomUUID(),
                bankName = "SBI Bank",
                accountType = AccountType.SAVINGS,
                balance = 1235076.0,
                accountNumber = "****1234",
                lastUpdated = System.currentTimeMillis()
            ),
            Account(
                id = UUID.randomUUID(),
                bankName = "Zerodha",
                accountType = AccountType.INVESTMENT,
                balance = 2845000.0,
                accountNumber = null,
                lastUpdated = System.currentTimeMillis()
            )
        )
    }
    
    // MARK: - Spending
    
    fun loadSpending() {
        viewModelScope.launch {
            _isSpendingLoading.value = true
            _spendingError.value = null
            
            try {
                val insightsResult = spendSenseService.getInsights()
                
                if (insightsResult.isFailure) {
                    // Fallback: use KPIs
                    val kpisResult = spendSenseService.getKPIs()
                    if (kpisResult.isSuccess) {
                        val kpis = kpisResult.getOrNull()
                        _monthlySpending.value = (kpis?.needsAmount ?: 0.0) + (kpis?.wantsAmount ?: 0.0)
                        _spendingByCategory.value = emptyList()
                    }
                    return@launch
                }
                
                val insights = insightsResult.getOrNull() ?: return@launch
                
                // Calculate monthly spending from category breakdown
                val categoryBreakdown = insights.categoryBreakdown
                if (categoryBreakdown != null) {
                    val total = categoryBreakdown.sumOf { it.amount }
                    _monthlySpending.value = total
                    
                    _spendingByCategory.value = categoryBreakdown.map { category ->
                        CategorySpending(
                            category = category.categoryName,
                            amount = category.amount,
                            percentage = category.share,
                            transactionCount = category.count
                        )
                    }
                } else {
                    // Fallback: use KPIs
                    val kpisResult = spendSenseService.getKPIs()
                    if (kpisResult.isSuccess) {
                        val kpis = kpisResult.getOrNull()
                        _monthlySpending.value = (kpis?.needsAmount ?: 0.0) + (kpis?.wantsAmount ?: 0.0)
                        _spendingByCategory.value = emptyList()
                    }
                }
            } catch (e: Exception) {
                _spendingError.value = e.message ?: "Unknown error"
                android.util.Log.e("MolyConsoleViewModel", "Error loading spending", e)
            } finally {
                _isSpendingLoading.value = false
            }
        }
    }
    
    // MARK: - Goals
    
    fun loadGoals() {
        viewModelScope.launch {
            _isGoalsLoading.value = true
            _goalsError.value = null
            
            try {
                // For now, use mock data
                // In production, this would fetch from a goals API endpoint
                _goals.value = createMockGoals()
            } catch (e: Exception) {
                _goalsError.value = e.message ?: "Unknown error"
                android.util.Log.e("MolyConsoleViewModel", "Error loading goals", e)
            } finally {
                _isGoalsLoading.value = false
            }
        }
    }
    
    private fun createMockGoals(): List<Goal> {
        return listOf(
            Goal(
                id = UUID.randomUUID(),
                name = "Emergency Fund",
                targetAmount = 1000000.0,
                savedAmount = 850000.0,
                targetDate = null,
                category = "Emergency",
                isActive = true
            ),
            Goal(
                id = UUID.randomUUID(),
                name = "Vacation Fund",
                targetAmount = 500000.0,
                savedAmount = 320000.0,
                targetDate = null,
                category = "Travel",
                isActive = true
            )
        )
    }
    
    // MARK: - AI Insights
    
    fun loadAIInsights() {
        viewModelScope.launch {
            _isInsightsLoading.value = true
            _insightsError.value = null
            
            try {
                val kpisResult = spendSenseService.getKPIs()
                val insightsResult = spendSenseService.getInsights()
                
                val mockInsights = mutableListOf<AIInsight>()
                
                if (kpisResult.isSuccess && insightsResult.isSuccess) {
                    val kpis = kpisResult.getOrNull()
                    val insights = insightsResult.getOrNull()
                    
                    // Create spending alert if needed
                    val topCategories = kpis?.topCategories
                    if (!topCategories.isNullOrEmpty()) {
                        val topCategory = topCategories[0]
                        val spendAmount = topCategory.spendAmount ?: 0.0
                        val categoryName = topCategory.categoryName
                        
                        if (spendAmount > 50000 && categoryName != null) {
                            mockInsights.add(
                                AIInsight(
                                    id = UUID.randomUUID(),
                                    title = "Spending Alert",
                                    message = "Your spending on ${categoryName.lowercase()} increased 15% this month. Consider setting a daily limit of ₹500.",
                                    type = InsightType.SPENDING_ALERT,
                                    priority = InsightPriority.MEDIUM,
                                    createdAt = System.currentTimeMillis(),
                                    category = categoryName
                                )
                            )
                        }
                    }
                    
                    // Create goal progress insight
                    val activeGoals = _goals.value.filter { it.isActive }
                    if (activeGoals.isNotEmpty()) {
                        val goal = activeGoals[0]
                        if (goal.progress > 0.8) {
                            mockInsights.add(
                                AIInsight(
                                    id = UUID.randomUUID(),
                                    title = "Good News!",
                                    message = "You're on track to reach your ${goal.name.lowercase()} goal by November.",
                                    type = InsightType.GOAL_PROGRESS,
                                    priority = InsightPriority.LOW,
                                    createdAt = System.currentTimeMillis(),
                                    category = null
                                )
                            )
                        }
                    }
                    
                    // Create budget tip
                    val categoryBreakdown = insights?.categoryBreakdown
                    if (categoryBreakdown != null) {
                        val foodCategory = categoryBreakdown.firstOrNull { 
                            it.categoryName.contains("Food", ignoreCase = true) || 
                            it.categoryName.contains("Dining", ignoreCase = true) 
                        }
                        if (foodCategory != null && foodCategory.share > 25) {
                            mockInsights.add(
                                AIInsight(
                                    id = UUID.randomUUID(),
                                    title = "Budget Tip",
                                    message = "You're spending ${foodCategory.share.toInt()}% on ${foodCategory.categoryName.lowercase()}. Consider meal planning to reduce costs.",
                                    type = InsightType.BUDGET_TIP,
                                    priority = InsightPriority.LOW,
                                    createdAt = System.currentTimeMillis(),
                                    category = foodCategory.categoryName
                                )
                            )
                        }
                    }
                    
                    // Create investment recommendation
                    val assets = kpis?.assetsAmount ?: 0.0
                    if (assets > 1000000) {
                        mockInsights.add(
                            AIInsight(
                                id = UUID.randomUUID(),
                                title = "Investment Tip",
                                message = "Your investment portfolio shows strong growth. Consider increasing SIP contributions.",
                                type = InsightType.INVESTMENT_RECOMMENDATION,
                                priority = InsightPriority.LOW,
                                createdAt = System.currentTimeMillis(),
                                category = null
                            )
                        )
                    }
                }
                
                // If no insights generated, add default ones
                if (mockInsights.isEmpty()) {
                    _aiInsights.value = createDefaultMockInsights()
                } else {
                    _aiInsights.value = mockInsights
                }
            } catch (e: Exception) {
                _insightsError.value = e.message ?: "Unknown error"
                _aiInsights.value = createDefaultMockInsights()
                android.util.Log.e("MolyConsoleViewModel", "Error loading insights", e)
            } finally {
                _isInsightsLoading.value = false
            }
        }
    }
    
    private fun createDefaultMockInsights(): List<AIInsight> {
        return listOf(
            AIInsight(
                id = UUID.randomUUID(),
                title = "Spending Alert",
                message = "Your spending on dining increased 15% this month. Consider setting a daily limit of ₹500.",
                type = InsightType.SPENDING_ALERT,
                priority = InsightPriority.MEDIUM,
                createdAt = System.currentTimeMillis(),
                category = "Food & Dining"
            ),
            AIInsight(
                id = UUID.randomUUID(),
                title = "Good News!",
                message = "You're on track to reach your emergency fund goal by November.",
                type = InsightType.GOAL_PROGRESS,
                priority = InsightPriority.LOW,
                createdAt = System.currentTimeMillis(),
                category = null
            ),
            AIInsight(
                id = UUID.randomUUID(),
                title = "Budget Tip",
                message = "You're spending 27% on food. Consider meal planning to reduce costs.",
                type = InsightType.BUDGET_TIP,
                priority = InsightPriority.LOW,
                createdAt = System.currentTimeMillis(),
                category = "Food & Dining"
            )
        )
    }
}

