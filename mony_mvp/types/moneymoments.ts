// MoneyMoments Types

export interface MoneyMoment {
  user_id: string
  month: string
  habit_id: string
  value: number
  label: string
  insight_text: string
  confidence: number
  created_at: string
}

export interface Nudge {
  delivery_id: string
  user_id: string
  rule_id: string
  template_code: string
  channel: string
  sent_at: string
  send_status: string
  metadata_json: Record<string, any>
  title_template?: string | null
  body_template?: string | null
  title?: string | null // Rendered title
  body?: string | null // Rendered body
  cta_text?: string | null
  cta_deeplink?: string | null
  rule_name: string
}

export interface ProgressMetrics {
  streak: number
  nudgesCount: number
  habitsCount: number
  savedAmount: number
}

export interface Habit {
  id: string // Using habit_id as identifier
  habitId: string
  name: string
  description: string
  priority: 'high' | 'medium' | 'low'
  frequency: 'daily' | 'weekly' | 'monthly'
  currentStreak: number
  targetStreak: number
  icon: string
  createdAt?: Date
}

export interface AIInsight {
  id: string
  type: 'progress' | 'suggestion' | 'milestone'
  message: string
  timestamp: Date
  icon: string
}

// API Response Types

export interface MoneyMomentsResponse {
  moments: MoneyMoment[]
}

export interface ComputeMomentsResponse {
  status: string
  moments: MoneyMoment[]
  count: number
  message?: string | null
}

export interface NudgesResponse {
  nudges: Nudge[]
}

export interface NudgeInteractionResponse {
  status: string
}

export interface EvaluateNudgesResponse {
  status: string
  count: number
  candidates?: string[]
}

export interface ProcessNudgesResponse {
  status: string
  delivered: Nudge[]
  count: number
}

export interface ComputeSignalResponse {
  status: string
  signal?: Record<string, any> | null
}
