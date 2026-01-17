import type { Session } from '@supabase/supabase-js'
import { fetchWithAuth } from './client'
import type {
  MoneyMoment,
  MoneyMomentsResponse,
  ComputeMomentsResponse,
  Nudge,
  NudgesResponse,
  NudgeInteractionResponse,
  EvaluateNudgesResponse,
  ProcessNudgesResponse,
  ComputeSignalResponse,
} from '@/types/moneymoments'

// Fetch money moments
export async function fetchMoneyMoments(
  session: Session,
  month?: string,
  allMonths: boolean = false
): Promise<MoneyMoment[]> {
  const params = new URLSearchParams()
  if (month) {
    params.append('month', month)
  }
  if (allMonths) {
    params.append('all_months', 'true')
  }
  const queryString = params.toString()
  const endpoint = queryString ? `/v1/moneymoments/moments?${queryString}` : '/v1/moneymoments/moments'
  const response = await fetchWithAuth<MoneyMomentsResponse>(session, endpoint)
  return response.moments || []
}

// Compute money moments
export async function computeMoneyMoments(
  session: Session,
  targetMonth?: string
): Promise<ComputeMomentsResponse> {
  const params = new URLSearchParams()
  if (targetMonth) {
    params.append('target_month', targetMonth)
  }
  const queryString = params.toString()
  const endpoint = queryString
    ? `/v1/moneymoments/moments/compute?${queryString}`
    : '/v1/moneymoments/moments/compute'
  return fetchWithAuth<ComputeMomentsResponse>(session, endpoint, {
    method: 'POST',
  })
}

// Fetch nudges
export async function fetchNudges(session: Session, limit: number = 20): Promise<Nudge[]> {
  const endpoint = `/v1/moneymoments/nudges?limit=${limit}`
  const response = await fetchWithAuth<NudgesResponse>(session, endpoint)
  return response.nudges || []
}

// Log nudge interaction
export async function logNudgeInteraction(
  session: Session,
  deliveryId: string,
  eventType: 'view' | 'click' | 'dismiss',
  metadata?: Record<string, any>
): Promise<void> {
  await fetchWithAuth<NudgeInteractionResponse>(
    session,
    `/v1/moneymoments/nudges/${deliveryId}/interact`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        event_type: eventType,
        metadata: metadata || null,
      }),
    }
  )
}

// Evaluate nudges (optional)
export async function evaluateNudges(
  session: Session,
  asOfDate?: string
): Promise<EvaluateNudgesResponse> {
  const params = new URLSearchParams()
  if (asOfDate) {
    params.append('as_of_date', asOfDate)
  }
  const queryString = params.toString()
  const endpoint = queryString
    ? `/v1/moneymoments/nudges/evaluate?${queryString}`
    : '/v1/moneymoments/nudges/evaluate'
  return fetchWithAuth<EvaluateNudgesResponse>(session, endpoint, {
    method: 'POST',
  })
}

// Process nudges (optional)
export async function processNudges(
  session: Session,
  limit: number = 10
): Promise<ProcessNudgesResponse> {
  const endpoint = `/v1/moneymoments/nudges/process?limit=${limit}`
  return fetchWithAuth<ProcessNudgesResponse>(session, endpoint, {
    method: 'POST',
  })
}

// Compute signal (optional)
export async function computeSignal(
  session: Session,
  asOfDate?: string
): Promise<ComputeSignalResponse> {
  const params = new URLSearchParams()
  if (asOfDate) {
    params.append('as_of_date', asOfDate)
  }
  const queryString = params.toString()
  const endpoint = queryString
    ? `/v1/moneymoments/signals/compute?${queryString}`
    : '/v1/moneymoments/signals/compute'
  return fetchWithAuth<ComputeSignalResponse>(session, endpoint, {
    method: 'POST',
  })
}
