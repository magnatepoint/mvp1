import type { Session } from '@supabase/supabase-js'

const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || 'https://api.monytix.ai'

export async function fetchWithAuth<T>(
  session: Session,
  endpoint: string,
  options?: RequestInit
): Promise<T> {
  const response = await fetch(`${API_BASE_URL}${endpoint}`, {
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

export async function validateSession(session: Session): Promise<{ user_id: string; email?: string | null }> {
  return fetchWithAuth(session, '/auth/session')
}
