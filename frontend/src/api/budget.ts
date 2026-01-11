// BudgetPilot API client
import type { Session } from '@supabase/supabase-js'
import { env } from '../env'
import type {
  BudgetRecommendation,
  BudgetCommitRequest,
  CommittedBudget,
  BudgetVariance,
} from '../types/budget'

async function fetchWithAuth<T>(
  session: Session,
  endpoint: string,
  options?: RequestInit
): Promise<T> {
  const response = await fetch(`${env.apiBaseUrl}${endpoint}`, {
    ...options,
    headers: {
      Authorization: `Bearer ${session.access_token}`,
      'Content-Type': 'application/json',
      ...options?.headers,
    },
  })

  if (!response.ok) {
    let errorMessage = `Failed to ${options?.method ?? 'GET'} ${endpoint}: ${response.statusText}`
    
    try {
      const body = await response.json()
      if (response.status === 422 && body.detail) {
        if (Array.isArray(body.detail)) {
          const validationErrors = body.detail
            .map((err: any) => {
              const field = err.loc?.join('.') || 'unknown'
              const msg = err.msg || 'validation error'
              return `${field}: ${msg}`
            })
            .join(', ')
          errorMessage = `Validation error: ${validationErrors}`
        } else if (typeof body.detail === 'string') {
          errorMessage = body.detail
        }
      } else if (body.detail) {
        errorMessage = typeof body.detail === 'string' ? body.detail : JSON.stringify(body.detail)
      }
    } catch (parseError) {
      console.error('Failed to parse error response:', parseError)
      errorMessage = `HTTP ${response.status}: ${response.statusText}`
    }
    
    const error = new Error(errorMessage)
    ;(error as any).status = response.status
    throw error
  }

  return response.json()
}

export const fetchBudgetRecommendations = async (
  session: Session,
  month?: string
): Promise<{ recommendations: BudgetRecommendation[] }> => {
  const params = month ? `?month=${month}` : ''
  return fetchWithAuth<{ recommendations: BudgetRecommendation[] }>(
    session,
    `/v1/budget/recommendations${params}`
  )
}

export const commitBudget = async (
  session: Session,
  payload: BudgetCommitRequest
): Promise<{ status: string; budget: CommittedBudget }> => {
  return fetchWithAuth<{ status: string; budget: CommittedBudget }>(
    session,
    '/v1/budget/commit',
    {
      method: 'POST',
      body: JSON.stringify(payload),
    }
  )
}

export const fetchCommittedBudget = async (
  session: Session,
  month?: string
): Promise<{ status: string; budget: CommittedBudget | null }> => {
  const params = month ? `?month=${month}` : ''
  return fetchWithAuth<{ status: string; budget: CommittedBudget | null }>(
    session,
    `/v1/budget/commit${params}`
  )
}

export const fetchBudgetVariance = async (
  session: Session,
  month?: string
): Promise<{ status: string; aggregate: BudgetVariance | null }> => {
  const params = month ? `?month=${month}` : ''
  return fetchWithAuth<{ status: string; aggregate: BudgetVariance | null }>(
    session,
    `/v1/budget/variance${params}`
  )
}

