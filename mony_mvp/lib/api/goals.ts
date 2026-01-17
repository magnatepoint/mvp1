import type { Session } from '@supabase/supabase-js'
import { fetchWithAuth } from './client'
import type {
  GoalCatalogItem,
  GoalResponse,
  GoalProgressItem,
  GoalsProgressResponse,
  LifeContextRequest,
  GoalsSubmitRequest,
  GoalsSubmitResponse,
  GoalUpdateRequest,
} from '@/types/goals'

const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || 'https://api.monytix.ai'

// Fetch goal catalog
export async function fetchGoalCatalog(session: Session): Promise<GoalCatalogItem[]> {
  return fetchWithAuth<GoalCatalogItem[]>(session, '/v1/goals/catalog')
}

// Fetch recommended goals
export async function fetchRecommendedGoals(session: Session): Promise<GoalCatalogItem[]> {
  return fetchWithAuth<GoalCatalogItem[]>(session, '/v1/goals/recommended')
}

// Fetch all user goals
export async function fetchUserGoals(session: Session): Promise<GoalResponse[]> {
  return fetchWithAuth<GoalResponse[]>(session, '/v1/goals')
}

// Fetch a single goal
export async function getGoal(session: Session, goalId: string): Promise<GoalResponse> {
  return fetchWithAuth<GoalResponse>(session, `/v1/goals/${goalId}`)
}

// Fetch goals progress
export async function fetchGoalProgress(session: Session): Promise<GoalProgressItem[]> {
  try {
    const response = await fetchWithAuth<GoalsProgressResponse | GoalProgressItem[]>(
      session,
      '/v1/goals/progress'
    )
    // Handle case where backend returns array directly
    if (Array.isArray(response)) {
      return response
    }
    // Handle case where backend returns object with goals property
    if (response && typeof response === 'object' && 'goals' in response) {
      return response.goals
    }
    return []
  } catch (error) {
    console.error('Error fetching goal progress:', error)
    return []
  }
}

// Fetch life context
export async function fetchLifeContext(session: Session): Promise<LifeContextRequest | null> {
  try {
    return await fetchWithAuth<LifeContextRequest>(session, '/v1/goals/context')
  } catch (error) {
    // If context doesn't exist, return null
    if ((error as any)?.status === 404) {
      return null
    }
    throw error
  }
}

// Update life context
export async function updateLifeContext(
  session: Session,
  context: LifeContextRequest
): Promise<LifeContextRequest> {
  return fetchWithAuth<LifeContextRequest>(session, '/v1/goals/context', {
    method: 'PUT',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(context),
  })
}

// Submit goals (create goals with life context)
export async function submitGoals(
  session: Session,
  request: GoalsSubmitRequest
): Promise<GoalsSubmitResponse> {
  return fetchWithAuth<GoalsSubmitResponse>(session, '/v1/goals/submit', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(request),
  })
}

// Update a goal
export async function updateGoal(
  session: Session,
  goalId: string,
  updates: GoalUpdateRequest
): Promise<GoalResponse> {
  // Clean up the updates object - only include fields that are explicitly set
  const cleanedUpdates: Partial<GoalUpdateRequest> = {}
  
  if (updates.estimated_cost !== undefined) {
    cleanedUpdates.estimated_cost = updates.estimated_cost ?? null
  }
  if (updates.target_date !== undefined) {
    cleanedUpdates.target_date = updates.target_date ?? null
  }
  if (updates.current_savings !== undefined) {
    cleanedUpdates.current_savings = updates.current_savings ?? null
  }
  if (updates.importance !== undefined) {
    cleanedUpdates.importance = updates.importance ?? null
  }
  if (updates.notes !== undefined) {
    cleanedUpdates.notes = updates.notes ?? null
  }
  if (updates.is_must_have !== undefined) {
    cleanedUpdates.is_must_have = updates.is_must_have ?? null
  }
  if (updates.timeline_flexibility !== undefined) {
    cleanedUpdates.timeline_flexibility = updates.timeline_flexibility ?? null
  }
  if (updates.risk_profile_for_goal !== undefined) {
    cleanedUpdates.risk_profile_for_goal = updates.risk_profile_for_goal ?? null
  }
  
  return fetchWithAuth<GoalResponse>(session, `/v1/goals/${goalId}`, {
    method: 'PUT',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(cleanedUpdates),
  })
}
