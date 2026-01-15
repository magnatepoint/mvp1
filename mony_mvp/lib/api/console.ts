import type { Session } from '@supabase/supabase-js'
import { fetchWithAuth } from './client'
import type {
  SpendSenseKPI,
  InsightsResponse,
  GoalResponse,
  GoalProgressItem,
  GoalsProgressResponse,
  OverviewSummary,
  Account,
  CategorySpending,
  Goal,
  AIInsight,
} from '@/types/console'

const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || 'https://api.monytix.ai'

// Fetch KPIs from backend
export async function fetchKPIs(session: Session, month?: string): Promise<SpendSenseKPI> {
  const endpoint = month ? `/v1/spendsense/kpis?month=${month}` : '/v1/spendsense/kpis'
  return fetchWithAuth<SpendSenseKPI>(session, endpoint)
}

// Fetch insights from backend
export async function fetchInsights(
  session: Session,
  startDate?: string,
  endDate?: string
): Promise<InsightsResponse> {
  let endpoint = '/v1/spendsense/insights'
  const params = new URLSearchParams()
  if (startDate) params.append('start_date', startDate)
  if (endDate) params.append('end_date', endDate)
  if (params.toString()) endpoint += `?${params.toString()}`
  return fetchWithAuth<InsightsResponse>(session, endpoint)
}

// Fetch goals from backend
export async function fetchGoals(session: Session): Promise<GoalProgressItem[]> {
  const response = await fetchWithAuth<GoalsProgressResponse>(session, '/v1/goals/progress')
  return response.goals || []
}

// Calculate savings rate from KPIs
export function calculateSavingsRate(kpis: SpendSenseKPI): number {
  const income = kpis.income_amount || 0
  if (income === 0) return 0
  const expenses = (kpis.needs_amount || 0) + (kpis.wants_amount || 0)
  const savings = income - expenses
  return (savings / income) * 100
}

// Check if KPIs indicate no transaction data
export function hasNoTransactionData(kpis: SpendSenseKPI): boolean {
  // Backend sets month=None when there are no transactions - this is the most reliable check
  if (kpis.month === null || kpis.month === undefined) {
    return true
  }
  
  // Additional check: if all amounts are zero and no categories, there's no transaction data
  const hasIncome = (kpis.income_amount || 0) > 0
  const hasNeeds = (kpis.needs_amount || 0) > 0
  const hasWants = (kpis.wants_amount || 0) > 0
  const hasAssets = (kpis.assets_amount || 0) > 0
  const hasCategories = kpis.top_categories && kpis.top_categories.length > 0
  
  return !hasIncome && !hasNeeds && !hasWants && !hasAssets && !hasCategories
}

// Transform backend data to console models
export function transformToOverviewSummary(
  kpis: SpendSenseKPI,
  goals: Goal[],
  latestInsight?: AIInsight
): OverviewSummary | null {
  // Return null if there's no transaction data
  if (hasNoTransactionData(kpis)) {
    return null
  }

  const totalBalance = kpis.assets_amount || 0
  const thisMonthSpending = (kpis.needs_amount || 0) + (kpis.wants_amount || 0)
  const savingsRate = calculateSavingsRate(kpis)
  const activeGoalsCount = goals.filter((g) => g.is_active).length

  return {
    total_balance: totalBalance,
    this_month_spending: thisMonthSpending,
    savings_rate: savingsRate,
    active_goals_count: activeGoalsCount,
    latest_insight: latestInsight,
  }
}

// Transform goals from backend format
export function transformGoals(goals: GoalProgressItem[]): Goal[] {
  if (!Array.isArray(goals)) {
    console.warn('transformGoals received non-array:', goals)
    return []
  }
  
  return goals.map((g) => {
    // Calculate target_amount from current_savings + remaining_amount
    const target_amount = g.current_savings_close + g.remaining_amount
    
    return {
      id: g.goal_id,
      name: g.goal_name,
      target_amount: target_amount,
      saved_amount: g.current_savings_close,
      target_date: g.projected_completion_date || null,
      category: null, // GoalProgressItem doesn't have category
      is_active: true, // Assume active if returned from progress endpoint
    }
  })
}

// Transform category breakdown to CategorySpending
export function transformCategorySpending(
  categoryBreakdown: any[]
): CategorySpending[] {
  return categoryBreakdown.map((cat, index) => ({
    id: `cat-${index}`,
    category: cat.category_name,
    amount: cat.amount,
    percentage: cat.percentage,
    transaction_count: cat.transaction_count,
  }))
}

// Generate mock accounts from KPIs (until accounts API is available)
export function generateMockAccounts(kpis: SpendSenseKPI): Account[] {
  // If there's no transaction data, return empty array
  if (hasNoTransactionData(kpis)) {
    return []
  }

  const accounts: Account[] = []
  const assets = kpis.assets_amount || 0

  if (assets > 0) {
    accounts.push({
      id: '1',
      bank_name: 'SBI Bank',
      account_type: 'SAVINGS' as any,
      balance: assets * 0.5,
      account_number: '****1234',
      last_updated: new Date().toISOString(),
    })

    accounts.push({
      id: '2',
      bank_name: 'Zerodha',
      account_type: 'INVESTMENT' as any,
      balance: assets * 0.5,
      account_number: null,
      last_updated: new Date().toISOString(),
    })
  }

  const income = kpis.income_amount || 0
  if (income > 0) {
    accounts.push({
      id: '3',
      bank_name: 'HDFC Bank',
      account_type: 'CHECKING' as any,
      balance: income * 0.2,
      account_number: '****5678',
      last_updated: new Date().toISOString(),
    })
  }

  // Return empty array if no real data - don't show mock accounts
  return accounts
}

// Generate AI insights from KPIs and insights data
export function generateAIInsights(
  kpis: SpendSenseKPI,
  insights: InsightsResponse,
  goals: Goal[]
): AIInsight[] {
  const aiInsights: AIInsight[] = []

  // Spending alert
  if (kpis.top_categories && kpis.top_categories.length > 0) {
    const topCategory = kpis.top_categories[0]
    if (topCategory.spend_amount > 50000) {
      aiInsights.push({
        id: '1',
        title: 'Spending Alert',
        message: `Your spending on ${topCategory.category_name.toLowerCase()} increased 15% this month. Consider setting a daily limit of ₹500.`,
        type: 'spending_alert' as any,
        priority: 'medium' as any,
        created_at: new Date().toISOString(),
        category: topCategory.category_name,
      })
    }
  }

  // Goal progress
  const activeGoal = goals.find((g) => g.is_active)
  if (activeGoal) {
    const progress = activeGoal.saved_amount / activeGoal.target_amount
    if (progress > 0.8) {
      aiInsights.push({
        id: '2',
        title: 'Good News!',
        message: `You're on track to reach your ${activeGoal.name.toLowerCase()} goal soon.`,
        type: 'goal_progress' as any,
        priority: 'low' as any,
        created_at: new Date().toISOString(),
        category: null,
      })
    }
  }

  // Budget tip
  if (insights.category_breakdown && insights.category_breakdown.length > 0) {
    const foodCategory = insights.category_breakdown.find(
      (cat) => cat.category_name.includes('Food') || cat.category_name.includes('Dining')
    )
    if (foodCategory && foodCategory.percentage > 25) {
      aiInsights.push({
        id: '3',
        title: 'Budget Tip',
        message: `You're spending ${foodCategory.percentage.toFixed(0)}% on ${foodCategory.category_name.toLowerCase()}. Consider meal planning to reduce costs.`,
        type: 'budget_tip' as any,
        priority: 'low' as any,
        created_at: new Date().toISOString(),
        category: foodCategory.category_name,
      })
    }
  }

  // Investment recommendation
  if (kpis.assets_amount && kpis.assets_amount > 1000000) {
    aiInsights.push({
      id: '4',
      title: 'Investment Tip',
      message: 'Your investment portfolio shows strong growth. Consider increasing SIP contributions.',
      type: 'investment_recommendation' as any,
      priority: 'low' as any,
      created_at: new Date().toISOString(),
      category: null,
    })
  }

  // Return empty array if no real insights - don't show mock insights
  return aiInsights
}
