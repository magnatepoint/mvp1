// Goals API client using fetch (matching existing pattern)
import type { Session } from '@supabase/supabase-js'
import { env } from '../env'
import type {
  GoalsSubmitRequest,
  GoalsSubmitResponse,
  GoalResponse,
  GoalsProgressResponse,
  GoalUpdateRequest,
  GoalCatalogItem,
  LifeContextRequest,
  GoalSignal,
  GoalSuggestion,
} from '../types/goals'

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
      
      // Handle FastAPI validation errors (422)
      if (response.status === 422 && body.detail) {
        if (Array.isArray(body.detail)) {
          // Pydantic validation errors
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
        } else if (typeof body.detail === 'object') {
          errorMessage = JSON.stringify(body.detail)
        }
      } else if (body.detail) {
        errorMessage = typeof body.detail === 'string' ? body.detail : JSON.stringify(body.detail)
      } else if (body.message) {
        errorMessage = typeof body.message === 'string' ? body.message : JSON.stringify(body.message)
      } else if (body.error) {
        errorMessage = typeof body.error === 'string' ? body.error : JSON.stringify(body.error)
      }
    } catch (parseError) {
      // If JSON parsing fails, use the status text
      console.error('Failed to parse error response:', parseError)
      errorMessage = `HTTP ${response.status}: ${response.statusText}`
    }
    
    const error = new Error(errorMessage)
    ;(error as any).status = response.status
    ;(error as any).response = response
    throw error
  }

  return response.json()
}

export const submitGoals = async (
  session: Session,
  payload: GoalsSubmitRequest
): Promise<GoalsSubmitResponse> => {
  return fetchWithAuth<GoalsSubmitResponse>(session, '/v1/goals/submit', {
    method: 'POST',
    body: JSON.stringify(payload),
  })
}

export const fetchGoals = async (session: Session): Promise<GoalResponse[]> => {
  return fetchWithAuth<GoalResponse[]>(session, '/v1/goals')
}

export const fetchGoal = async (session: Session, goalId: string): Promise<GoalResponse> => {
  return fetchWithAuth<GoalResponse>(session, `/v1/goals/${goalId}`)
}

export const updateGoal = async (
  session: Session,
  goalId: string,
  payload: GoalUpdateRequest
): Promise<GoalResponse> => {
  return fetchWithAuth<GoalResponse>(session, `/v1/goals/${goalId}`, {
    method: 'PUT',
    body: JSON.stringify(payload),
  })
}

export const deleteGoal = async (session: Session, goalId: string): Promise<void> => {
  await fetchWithAuth<void>(session, `/v1/goals/${goalId}`, {
    method: 'DELETE',
  })
}

export const fetchGoalsProgress = async (session: Session): Promise<GoalsProgressResponse> => {
  return fetchWithAuth<GoalsProgressResponse>(session, '/v1/goals/progress')
}

export const fetchGoalCatalog = async (session: Session): Promise<GoalCatalogItem[]> => {
  return fetchWithAuth<GoalCatalogItem[]>(session, '/v1/goals/catalog')
}

export const fetchRecommendedGoals = async (session: Session): Promise<GoalCatalogItem[]> => {
  return fetchWithAuth<GoalCatalogItem[]>(session, '/v1/goals/recommended')
}

export const fetchLifeContext = async (session: Session): Promise<LifeContextRequest | null> => {
  try {
    return await fetchWithAuth<LifeContextRequest>(session, '/v1/goals/context')
  } catch (err) {
    // 404 means no context exists yet
    if (err instanceof Error && err.message.includes('404')) {
      return null
    }
    throw err
  }
}

export const updateLifeContext = async (
  session: Session,
  context: LifeContextRequest
): Promise<{ status: string }> => {
  return fetchWithAuth<{ status: string }>(session, '/v1/goals/context', {
    method: 'PUT',
    body: JSON.stringify(context),
  })
}

export const fetchGoalSignals = async (session: Session): Promise<GoalSignal[]> => {
  return fetchWithAuth<GoalSignal[]>(session, '/v1/goals/signals')
}

export const fetchGoalSuggestions = async (session: Session): Promise<GoalSuggestion[]> => {
  return fetchWithAuth<GoalSuggestion[]>(session, '/v1/goals/suggestions')
}

export const updateGoalSuggestionStatus = async (
  session: Session,
  suggestionId: string,
  status: 'accepted' | 'dismissed'
): Promise<void> => {
  await fetchWithAuth<void>(session, `/v1/goals/suggestions/${suggestionId}`, {
    method: 'PATCH',
    body: JSON.stringify({ status }),
  })
}

