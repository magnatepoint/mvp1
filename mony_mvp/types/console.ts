// Console Types

export interface OverviewSummary {
  total_balance: number
  this_month_spending: number
  savings_rate: number
  active_goals_count: number
  latest_insight?: AIInsight
}

export interface Account {
  id: string
  bank_name: string
  account_type: AccountType
  balance: number
  account_number?: string | null
  last_updated?: string | null
}

export enum AccountType {
  CHECKING = 'CHECKING',
  SAVINGS = 'SAVINGS',
  INVESTMENT = 'INVESTMENT',
  CREDIT = 'CREDIT',
}

export interface CategorySpending {
  id?: string
  category: string
  amount: number
  percentage: number
  transaction_count: number
}

export interface Goal {
  id: string
  name: string
  target_amount: number
  saved_amount: number
  target_date?: string | null
  category?: string | null
  is_active: boolean
}

export interface AIInsight {
  id: string
  title: string
  message: string
  type: InsightType
  priority: InsightPriority
  created_at?: string | null
  category?: string | null
}

export enum InsightType {
  SPENDING_ALERT = 'spending_alert',
  GOAL_PROGRESS = 'goal_progress',
  INVESTMENT_RECOMMENDATION = 'investment_recommendation',
  BUDGET_TIP = 'budget_tip',
  SAVINGS_OPPORTUNITY = 'savings_opportunity',
}

export enum InsightPriority {
  HIGH = 'high',
  MEDIUM = 'medium',
  LOW = 'low',
}

// Backend API Response Types
export interface SpendSenseKPI {
  month?: string | null
  income_amount: number
  needs_amount: number
  wants_amount: number
  assets_amount: number
  /** All debits for the month (for "This Month" spending). Backend may omit; fallback to needs+wants. */
  total_debits_amount?: number
  top_categories: CategorySpendKPI[]
  wants_gauge?: WantsGauge | null
  best_month?: BestMonthSnapshot | null
  recent_loot_drop?: LootDropSummary | null
}

export interface CategorySpendKPI {
  category_code: string
  category_name: string
  txn_count: number
  spend_amount: number
  income_amount: number
  delta_pct?: number | null
}

export interface WantsGauge {
  ratio: number
  label: string
  threshold_crossed: boolean
}

export interface BestMonthSnapshot {
  month: string
  net_amount: number
  delta_pct?: number | null
  is_current_best: boolean
}

export interface LootDropSummary {
  batch_id: string
  occurred_at: string
  transactions_unlocked: number
  rarity: string
}

export interface InsightsResponse {
  time_series: TimeSeriesPoint[]
  category_breakdown: CategoryBreakdownItem[]
  spending_trends: SpendingTrend[]
  recurring_transactions: RecurringTransaction[]
  spending_patterns: SpendingPattern[]
  top_merchants: any[]
  anomalies?: any[] | null
}

export interface TimeSeriesPoint {
  date: string
  value: number
  label?: string | null
}

export interface CategoryBreakdownItem {
  category_code: string
  category_name: string
  amount: number
  percentage: number
  transaction_count: number
  avg_transaction: number
}

export interface SpendingTrend {
  period: string
  income: number
  expenses: number
  net: number
  needs: number
  wants: number
  assets: number
}

export interface RecurringTransaction {
  merchant_name: string
  category_code: string
  category_name: string
  subcategory_code?: string | null
  subcategory_name?: string | null
  frequency: string
  avg_amount: number
  last_occurrence: string
  next_expected?: string | null
  transaction_count: number
  total_amount: number
}

export interface SpendingPattern {
  day_of_week?: string | null
  time_of_day?: string | null
  amount: number
  transaction_count: number
}

export interface GoalResponse {
  goal_id: string
  user_id: string
  goal_name: string
  target_amount: number
  saved_amount: number
  target_date?: string | null
  category?: string | null
  is_active: boolean
  created_at: string
  updated_at: string
}

export interface GoalProgressItem {
  goal_id: string
  goal_name: string
  progress_pct: number
  current_savings_close: number
  remaining_amount: number
  projected_completion_date?: string | null
  milestones: number[]
}

export interface GoalsProgressResponse {
  goals: GoalProgressItem[]
}
