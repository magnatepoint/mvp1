// Goals Types

export interface GoalCatalogItem {
  goal_category: string
  goal_name: string
  default_horizon: string
  policy_linked_txn_type: string
  is_mandatory_flag: boolean
  suggested_min_amount_formula: string | null
  display_order: number
}

export interface GoalResponse {
  goal_id: string
  goal_category: string
  goal_name: string
  goal_type: string
  linked_txn_type: string | null
  estimated_cost: number
  target_date: string | null
  current_savings: number
  importance: number | null
  priority_rank: number | null
  status: string
  notes: string | null
  created_at: string
  updated_at: string
}

export interface GoalProgressItem {
  goal_id: string
  goal_name: string
  progress_pct: number
  current_savings_close: number
  remaining_amount: number
  projected_completion_date: string | null
  milestones: number[]
}

export interface GoalsProgressResponse {
  goals: GoalProgressItem[]
}

export type RiskProfile = 'conservative' | 'balanced' | 'aggressive'
export type TimelineFlexibility = 'rigid' | 'somewhat_flexible' | 'flexible'
export type ReviewFrequency = 'monthly' | 'quarterly' | 'yearly'

export interface LifeContextRequest {
  age_band: string // '18-24' | '25-34' | '35-44' | '45-54' | '55+'
  dependents_spouse: boolean
  dependents_children_count: number
  dependents_parents_care: boolean
  housing: string // 'rent' | 'own_mortgage' | 'own_nomortgage' | 'living_with_parents'
  employment: string // 'salaried' | 'self_employed' | 'student' | 'homemaker' | 'retired'
  income_regularity: string // 'very_stable' | 'stable' | 'variable'
  region_code: string // e.g., 'IN-KA', 'IN-TG'
  emergency_opt_out: boolean
  monthly_investible_capacity?: number | null
  total_monthly_emi_obligations?: number | null
  risk_profile_overall?: RiskProfile | null
  review_frequency?: ReviewFrequency | null
  notify_on_drift?: boolean | null
  auto_adjust_on_income_change?: boolean | null
}

export interface SelectedGoal {
  goal_category: string
  goal_name: string
  estimated_cost: number
  target_date: string | null // YYYY-MM-DD format
  current_savings: number
  importance: number // 1-5
  notes?: string | null
}

export interface GoalDetailRequest {
  goal_category: string
  goal_name: string
  estimated_cost: number
  target_date: string | null
  current_savings: number
  importance: number
  notes?: string | null
}

export interface GoalsSubmitRequest {
  context: LifeContextRequest
  selected_goals: GoalDetailRequest[]
}

export interface GoalCreatedItem {
  goal_id: string
  priority_rank: number | null
}

export interface GoalsSubmitResponse {
  goals_created: GoalCreatedItem[]
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

export type GoalStatus = 'active' | 'completed' | 'archived'

export type AIInsightType = 'goalProgress' | 'savingsOpportunity' | 'budgetTip'
export type AIInsightPriority = 'low' | 'medium' | 'high'

export interface AIInsight {
  id: string
  title: string
  message: string
  type: AIInsightType
  priority: AIInsightPriority
  createdAt?: string | null
  category?: string | null
}

// Indian States for region code dropdown
export const INDIAN_STATES = [
  { code: 'IN-AP', name: 'Andhra Pradesh' },
  { code: 'IN-AR', name: 'Arunachal Pradesh' },
  { code: 'IN-AS', name: 'Assam' },
  { code: 'IN-BR', name: 'Bihar' },
  { code: 'IN-CT', name: 'Chhattisgarh' },
  { code: 'IN-GA', name: 'Goa' },
  { code: 'IN-GJ', name: 'Gujarat' },
  { code: 'IN-HR', name: 'Haryana' },
  { code: 'IN-HP', name: 'Himachal Pradesh' },
  { code: 'IN-JK', name: 'Jammu & Kashmir' },
  { code: 'IN-JH', name: 'Jharkhand' },
  { code: 'IN-KA', name: 'Karnataka' },
  { code: 'IN-KL', name: 'Kerala' },
  { code: 'IN-MP', name: 'Madhya Pradesh' },
  { code: 'IN-MH', name: 'Maharashtra' },
  { code: 'IN-MN', name: 'Manipur' },
  { code: 'IN-ML', name: 'Meghalaya' },
  { code: 'IN-MZ', name: 'Mizoram' },
  { code: 'IN-NL', name: 'Nagaland' },
  { code: 'IN-OR', name: 'Odisha' },
  { code: 'IN-PB', name: 'Punjab' },
  { code: 'IN-RJ', name: 'Rajasthan' },
  { code: 'IN-SK', name: 'Sikkim' },
  { code: 'IN-TN', name: 'Tamil Nadu' },
  { code: 'IN-TG', name: 'Telangana' },
  { code: 'IN-TR', name: 'Tripura' },
  { code: 'IN-UP', name: 'Uttar Pradesh' },
  { code: 'IN-UT', name: 'Uttarakhand' },
  { code: 'IN-WB', name: 'West Bengal' },
  { code: 'IN-AN', name: 'Andaman & Nicobar' },
  { code: 'IN-CH', name: 'Chandigarh' },
  { code: 'IN-DH', name: 'Dadra & Nagar Haveli' },
  { code: 'IN-DL', name: 'Delhi' },
  { code: 'IN-LD', name: 'Lakshadweep' },
  { code: 'IN-PY', name: 'Puducherry' },
] as const
