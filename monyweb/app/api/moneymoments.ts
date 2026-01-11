// MoneyMoments API client
import type { Session } from '@supabase/supabase-js'
import { env } from '../env'
import type { MoneyMoment, Nudge } from '../types/moneymoments'

async function fetchWithAuth<T>(
  session: Session,
  endpoint: string,
  options?: RequestInit
): Promise<T> {
  try {
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
  } catch (error) {
    // Handle network errors (CORS, connection refused, etc.)
    if (error instanceof TypeError && error.message === 'Failed to fetch') {
      const networkError = new Error(
        `Network error: Unable to connect to ${env.apiBaseUrl}. Please ensure the backend server is running.`
      )
      ;(networkError as any).isNetworkError = true
      throw networkError
    }
    throw error
  }
}

export const fetchMoneyMoments = async (
  session: Session,
  month?: string
): Promise<{ moments: MoneyMoment[] }> => {
  const params = month ? `?month=${month}` : ''
  return fetchWithAuth<{ moments: MoneyMoment[] }>(
    session,
    `/v1/moneymoments/moments${params}`
  )
}

export const computeMoneyMoments = async (
  session: Session,
  targetMonth?: string
): Promise<{ status: string; moments: MoneyMoment[]; count: number }> => {
  const params = targetMonth ? `?target_month=${targetMonth}` : ''
  return fetchWithAuth<{ status: string; moments: MoneyMoment[]; count: number }>(
    session,
    `/v1/moneymoments/moments/compute${params}`,
    {
      method: 'POST',
    }
  )
}

export const fetchNudges = async (
  session: Session,
  limit: number = 20
): Promise<{ nudges: Nudge[] }> => {
  return fetchWithAuth<{ nudges: Nudge[] }>(
    session,
    `/v1/moneymoments/nudges?limit=${limit}`
  )
}

export const logNudgeInteraction = async (
  session: Session,
  deliveryId: string,
  eventType: 'view' | 'click' | 'dismiss',
  metadata?: Record<string, any>
): Promise<{ status: string }> => {
  return fetchWithAuth<{ status: string }>(
    session,
    `/v1/moneymoments/nudges/${deliveryId}/interact`,
    {
      method: 'POST',
      body: JSON.stringify({ event_type: eventType, metadata }),
    }
  )
}

export const evaluateNudges = async (
  session: Session,
  asOfDate?: string
): Promise<{ status: string; count: number; candidates?: any[] }> => {
  const params = asOfDate ? `?as_of_date=${asOfDate}` : ''
  return fetchWithAuth<{ status: string; count: number; candidates?: any[] }>(
    session,
    `/v1/moneymoments/nudges/evaluate${params}`,
    {
      method: 'POST',
    }
  )
}

export const processNudges = async (
  session: Session,
  limit: number = 10
): Promise<{ status: string; delivered: any[]; count: number }> => {
  return fetchWithAuth<{ status: string; delivered: any[]; count: number }>(
    session,
    `/v1/moneymoments/nudges/process?limit=${limit}`,
    {
      method: 'POST',
    }
  )
}

export const computeSignal = async (
  session: Session,
  asOfDate?: string
): Promise<{ status: string; signal: any }> => {
  const params = asOfDate ? `?as_of_date=${asOfDate}` : ''
  return fetchWithAuth<{ status: string; signal: any }>(
    session,
    `/v1/moneymoments/signals/compute${params}`,
    {
      method: 'POST',
    }
  )
}

