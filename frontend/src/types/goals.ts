// TypeScript types matching Pydantic models

export type RiskProfile = 'conservative' | 'balanced' | 'aggressive'

export type TimelineFlexibility = 'rigid' | 'somewhat_flexible' | 'flexible'

export type ReviewFrequency = 'monthly' | 'quarterly' | 'yearly'

export interface LifeContextRequest {
  age_band: '18-24' | '25-34' | '35-44' | '45-54' | '55+'
  dependents_spouse: boolean
  dependents_children_count: number
  dependents_parents_care: boolean
  housing: 'rent' | 'own_mortgage' | 'own_nomortgage' | 'living_with_parents'
  employment: 'salaried' | 'self_employed' | 'student' | 'homemaker' | 'retired'
  income_regularity: 'very_stable' | 'stable' | 'variable'
  region_code: string
  emergency_opt_out: boolean
  monthly_investible_capacity?: number | null
  total_monthly_emi_obligations?: number | null
  risk_profile_overall?: RiskProfile | null
  review_frequency?: ReviewFrequency | null
  notify_on_drift?: boolean
  auto_adjust_on_income_change?: boolean
}

export interface GoalDetailRequest {
  goal_category: string
  goal_name: string
  estimated_cost: number
  target_date?: string | null // YYYY-MM-DD
  current_savings: number
  importance: number // 1–5
  notes?: string | null
  risk_profile_for_goal?: RiskProfile | null
  is_must_have: boolean
  timeline_flexibility?: TimelineFlexibility | null
}

export interface GoalsSubmitRequest {
  context: LifeContextRequest
  selected_goals: GoalDetailRequest[]
}

export interface GoalResponse {
  goal_id: string
  goal_category: string
  goal_name: string
  goal_type: string
  linked_txn_type?: string | null
  estimated_cost: number
  target_date?: string | null
  current_savings: number
  importance?: number | null
  priority_rank?: number | null
  status: string
  notes?: string | null
  created_at: string // ISO
  updated_at: string // ISO
}

export interface GoalsSubmitResponse {
  goals_created: { goal_id: string; priority_rank: number | null }[]
}

export interface GoalUpdateRequest {
  estimated_cost?: number | null
  target_date?: string | null
  current_savings?: number | null
  importance?: number | null
  notes?: string | null
  is_must_have?: boolean | null
  timeline_flexibility?: TimelineFlexibility | null
  risk_profile_for_goal?: RiskProfile | null
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

export interface GoalCatalogItem {
  goal_category: string
  goal_name: string
  default_horizon: string
  policy_linked_txn_type: string
  is_mandatory_flag: boolean
  suggested_min_amount_formula: string | null
  display_order: number
}

export interface GoalSignal {
  id: string
  goal_id?: string | null
  signal_type: string
  severity: 'info' | 'warning' | 'critical' | string
  message: string
  meta: Record<string, any>
  created_at: string
}

export interface GoalSuggestion {
  id: string
  goal_id?: string | null
  suggestion_type: string
  title: string
  description: string
  action_payload: Record<string, any>
  status: 'open' | 'accepted' | 'dismissed' | string
  created_at: string
  updated_at: string
}
