// SpendSense Types

export interface SpendSenseKPIs {
  month?: string | null
  income_amount?: number | null
  needs_amount?: number | null
  wants_amount?: number | null
  assets_amount?: number | null
  wants_gauge?: WantsGauge | null
  top_categories?: TopCategory[] | null
}

export interface WantsGauge {
  ratio: number
  threshold_crossed: boolean
  label: string
}

export interface TopCategory {
  category_code: string
  category_name: string
  txn_count: number
  spend_amount?: number | null
  income_amount?: number | null
  delta_pct?: number | null
}

export interface Transaction {
  txn_id: string
  txn_date: string
  merchant: string | null
  category: string | null
  subcategory: string | null
  bank_code: string | null
  channel: string | null
  amount: number
  direction: string
}

export interface TransactionListResponse {
  transactions: Transaction[]
  total: number
  page: number
  page_size: number
}

export interface CategoryBreakdown {
  category_code: string
  category_name: string
  amount: number
  percentage: number
  transaction_count: number
  avg_transaction: number
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

export interface AvailableMonthsResponse {
  data: string[]
}

export interface TransactionCreate {
  txn_date: string // YYYY-MM-DD format
  merchant_name: string
  description?: string | null
  amount: number
  direction: 'debit' | 'credit'
  category_code?: string | null
  subcategory_code?: string | null
  channel?: string | null
  account_ref?: string | null
}

export interface TransactionUpdate {
  category_code?: string | null
  subcategory_code?: string | null
  txn_type?: string | null
  merchant_name?: string | null
  channel?: string | null
}

export interface Category {
  category_code: string
  category_name: string
  is_custom: boolean
  txn_type?: string | null
}

export interface Subcategory {
  subcategory_code: string
  subcategory_name: string
  category_code: string
  is_custom: boolean
}
