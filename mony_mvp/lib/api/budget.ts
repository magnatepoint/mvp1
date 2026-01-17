import type { Session } from '@supabase/supabase-js'
import { fetchWithAuth } from './client'
import type {
  BudgetRecommendation,
  BudgetRecommendationsResponse,
  CommittedBudget,
  CommittedBudgetResponse,
  BudgetCommitRequest,
  BudgetCommitResponse,
  BudgetVariance,
  BudgetVarianceResponse,
} from '@/types/budget'

const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || 'https://api.monytix.ai'

// Fetch budget recommendations
export async function fetchBudgetRecommendations(
  session: Session,
  month?: string
): Promise<BudgetRecommendation[]> {
  const endpoint = month
    ? `/v1/budget/recommendations?month=${month}`
    : '/v1/budget/recommendations'
  const response = await fetchWithAuth<BudgetRecommendationsResponse>(session, endpoint)
  return response.recommendations || []
}

// Fetch committed budget
export async function fetchCommittedBudget(
  session: Session,
  month?: string
): Promise<CommittedBudget | null> {
  try {
    const endpoint = month ? `/v1/budget/commit?month=${month}` : '/v1/budget/commit'
    const response = await fetchWithAuth<CommittedBudgetResponse>(session, endpoint)
    // Backend returns status "no_commitment" if no budget is committed
    if (response.status === 'no_commitment' || !response.budget) {
      return null
    }
    return response.budget
  } catch (error) {
    // If no commitment exists, backend might return 404
    if ((error as any)?.status === 404) {
      return null
    }
    console.error('Error fetching committed budget:', error)
    return null
  }
}

// Commit to a budget plan
export async function commitBudget(
  session: Session,
  request: BudgetCommitRequest
): Promise<CommittedBudget> {
  const response = await fetchWithAuth<BudgetCommitResponse>(session, '/v1/budget/commit', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(request),
  })
  return response.budget
}

// Fetch budget variance (optional, for future use)
export async function fetchBudgetVariance(
  session: Session,
  month?: string
): Promise<BudgetVariance | null> {
  try {
    const endpoint = month ? `/v1/budget/variance?month=${month}` : '/v1/budget/variance'
    const response = await fetchWithAuth<BudgetVarianceResponse>(session, endpoint)
    if (response.status === 'no_data') {
      return null
    }
    return response.aggregate || null
  } catch (error) {
    console.error('Error fetching budget variance:', error)
    return null
  }
}
