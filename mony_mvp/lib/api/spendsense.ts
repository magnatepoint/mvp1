import type { Session } from '@supabase/supabase-js'
import { fetchWithAuth } from './client'
import type {
  SpendSenseKPIs,
  Transaction,
  TransactionCreate,
  TransactionUpdate,
  TransactionListResponse,
  AvailableMonthsResponse,
  Category,
  Subcategory,
} from '@/types/spendsense'
import type { InsightsResponse } from '@/types/console'

const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || 'https://api.monytix.ai'

// Fetch KPIs from backend
export async function fetchKPIs(session: Session, month?: string): Promise<SpendSenseKPIs> {
  const endpoint = month ? `/v1/spendsense/kpis?month=${month}` : '/v1/spendsense/kpis'
  return fetchWithAuth<SpendSenseKPIs>(session, endpoint)
}

// Fetch available months
export async function fetchAvailableMonths(session: Session): Promise<string[]> {
  const response = await fetchWithAuth<AvailableMonthsResponse>(
    session,
    '/v1/spendsense/kpis/available-months'
  )
  return response.data || []
}

// Fetch transactions
export async function fetchTransactions(
  session: Session,
  options?: {
    limit?: number
    offset?: number
    search?: string
    category_code?: string
    subcategory_code?: string
    channel?: string
    direction?: 'debit' | 'credit'
    start_date?: string
    end_date?: string
  }
): Promise<TransactionListResponse> {
  const params = new URLSearchParams()
  if (options?.limit) params.append('limit', options.limit.toString())
  if (options?.offset) params.append('offset', options.offset.toString())
  if (options?.search) params.append('search', options.search)
  if (options?.category_code) params.append('category_code', options.category_code)
  if (options?.subcategory_code) params.append('subcategory_code', options.subcategory_code)
  if (options?.channel) params.append('channel', options.channel)
  if (options?.direction) params.append('direction', options.direction)
  if (options?.start_date) params.append('start_date', options.start_date)
  if (options?.end_date) params.append('end_date', options.end_date)

  const endpoint = `/v1/spendsense/transactions${params.toString() ? `?${params.toString()}` : ''}`
  return fetchWithAuth<TransactionListResponse>(session, endpoint)
}

// Fetch insights (reuses the same endpoint as console)
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

// Create a manual transaction
export async function createTransaction(
  session: Session,
  data: TransactionCreate
): Promise<Transaction> {
  return fetchWithAuth<Transaction>(session, '/v1/spendsense/transactions', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(data),
  })
}

// Update a transaction
export async function updateTransaction(
  session: Session,
  txnId: string,
  updates: TransactionUpdate
): Promise<Transaction> {
  // Clean up the updates object - only include fields that are explicitly set (not undefined)
  // Omit txn_type if it's not provided, as it's not used in the frontend
  const cleanedUpdates: Partial<TransactionUpdate> = {}
  
  if (updates.category_code !== undefined) {
    cleanedUpdates.category_code = updates.category_code ?? null
  }
  if (updates.subcategory_code !== undefined) {
    cleanedUpdates.subcategory_code = updates.subcategory_code ?? null
  }
  if (updates.merchant_name !== undefined) {
    cleanedUpdates.merchant_name = updates.merchant_name ?? null
  }
  if (updates.channel !== undefined) {
    cleanedUpdates.channel = updates.channel ?? null
  }
  // Only include txn_type if it's explicitly provided (frontend doesn't use this field)
  if (updates.txn_type !== undefined) {
    cleanedUpdates.txn_type = updates.txn_type ?? null
  }
  
  // Debug logging in development
  if (process.env.NODE_ENV === 'development') {
    console.log('[Transaction Update] Sending update:', {
      txnId,
      cleanedUpdates,
      originalUpdates: updates,
    })
  }
  
  return fetchWithAuth<Transaction>(session, `/v1/spendsense/transactions/${txnId}`, {
    method: 'PUT',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(cleanedUpdates),
  })
}

// Delete a transaction
export async function deleteTransaction(session: Session, txnId: string): Promise<void> {
  await fetchWithAuth(session, `/v1/spendsense/transactions/${txnId}`, {
    method: 'DELETE',
  })
}

// Fetch all categories
export async function fetchCategories(session: Session): Promise<Category[]> {
  return fetchWithAuth<Category[]>(session, '/v1/spendsense/categories')
}

// Fetch subcategories (optionally filtered by category)
export async function fetchSubcategories(
  session: Session,
  categoryCode?: string
): Promise<Subcategory[]> {
  const endpoint = categoryCode
    ? `/v1/spendsense/subcategories?category_code=${categoryCode}`
    : '/v1/spendsense/subcategories'
  return fetchWithAuth<Subcategory[]>(session, endpoint)
}

// Fetch channel options (from backend: distinct from user's txns + standard list)
export async function fetchChannels(session: Session): Promise<string[]> {
  return fetchWithAuth<string[]>(session, '/v1/spendsense/channels')
}

// Refresh KPI materialized views
export async function refreshKPIs(session: Session): Promise<void> {
  await fetchWithAuth(session, '/v1/spendsense/kpis/refresh', {
    method: 'POST',
  })
}
