// Budget Types

export interface GoalAllocationPreview {
  goal_id: string
  goal_name: string
  allocation_pct: number
  allocation_amount: number
}

export interface BudgetRecommendation {
  plan_code: string
  name: string
  description: string | null
  needs_budget_pct: number
  wants_budget_pct: number
  savings_budget_pct: number
  score: number
  recommendation_reason: string
  goal_preview: GoalAllocationPreview[] | null
}

export interface BudgetRecommendationsResponse {
  recommendations: BudgetRecommendation[]
}

export interface GoalAllocation {
  ubcga_id: string
  user_id: string
  month: string
  goal_id: string
  goal_name: string | null
  weight_pct: number
  planned_amount: number
  created_at: string
}

export interface CommittedBudget {
  user_id: string
  month: string
  plan_code: string
  alloc_needs_pct: number
  alloc_wants_pct: number
  alloc_assets_pct: number
  notes: string | null
  committed_at: string
  goal_allocations: GoalAllocation[]
}

export interface BudgetCommitRequest {
  plan_code: string
  month?: string | null // YYYY-MM-DD format
  goal_allocations?: Record<string, number> | null
  notes?: string | null
}

export interface BudgetCommitResponse {
  status: string
  budget: CommittedBudget
}

export interface CommittedBudgetResponse {
  status: string
  budget: CommittedBudget | null
}

export interface BudgetVariance {
  user_id: string
  month: string
  income_amt: number
  needs_amt: number
  planned_needs_amt: number
  variance_needs_amt: number
  wants_amt: number
  planned_wants_amt: number
  variance_wants_amt: number
  assets_amt: number
  planned_assets_amt: number
  variance_assets_amt: number
  computed_at: string
}

export interface BudgetVarianceResponse {
  status: string
  aggregate: BudgetVariance | null
}
