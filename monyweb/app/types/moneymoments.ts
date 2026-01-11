// MoneyMoments types

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
  title_template: string
  body_template: string
  cta_text?: string | null
  cta_deeplink?: string | null
  rule_name: string
}

