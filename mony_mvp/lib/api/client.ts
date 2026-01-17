import type { Session } from '@supabase/supabase-js'

const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || 'https://api.monytix.ai'
const REQUEST_TIMEOUT = 10000 // 10 seconds

export async function fetchWithAuth<T>(
  session: Session,
  endpoint: string,
  options?: RequestInit
): Promise<T> {
  // Validate session token before making request
  if (!session?.access_token) {
    throw new Error('Authentication required. Please log in again.')
  }

  // Construct full URL
  const fullUrl = `${API_BASE_URL}${endpoint}`
  
  // Log API URL for debugging (always log in case of issues)
  if (process.env.NODE_ENV === 'development' || !process.env.NEXT_PUBLIC_API_URL) {
    console.log(`[API] ${options?.method || 'GET'} ${fullUrl}`)
    if (!process.env.NEXT_PUBLIC_API_URL) {
      console.warn('[API] NEXT_PUBLIC_API_URL not set, using default:', API_BASE_URL)
    }
  }

  try {
    // Create abort controller for timeout
    const controller = new AbortController()
    const timeoutId = setTimeout(() => controller.abort(), REQUEST_TIMEOUT)

    try {
      const response = await fetch(fullUrl, {
        ...options,
        signal: controller.signal,
        headers: {
          Authorization: `Bearer ${session.access_token}`,
          'Content-Type': 'application/json',
          ...options?.headers,
        },
      })

      clearTimeout(timeoutId)

      if (!response.ok) {
        let errorMessage = `Failed to ${options?.method ?? 'GET'} ${endpoint}: ${response.statusText}`
        
        // Categorize error by status code
        if (response.status === 401 || response.status === 403) {
          errorMessage = 'Your session has expired. Please refresh the page and try again.'
        } else if (response.status === 404) {
          errorMessage = 'The requested resource was not found. It may have been deleted.'
        } else if (response.status >= 500) {
          errorMessage = 'Server error. Please try again later or contact support if the problem persists.'
        }
        
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
          } else if (body.detail && (response.status < 500 || response.status >= 600)) {
            // Use server error message for non-5xx errors
            errorMessage = typeof body.detail === 'string' ? body.detail : JSON.stringify(body.detail)
          }
        } catch (parseError) {
          // If we can't parse the error response, use the categorized message
          if (process.env.NODE_ENV === 'development') {
            console.error('Failed to parse error response:', parseError)
          }
        }
        
        const error = new Error(errorMessage)
        ;(error as any).status = response.status
        ;(error as any).isNetworkError = false
        throw error
      }

      return response.json()
    } catch (fetchError: any) {
      clearTimeout(timeoutId)
      
      // Handle abort (timeout)
      if (fetchError.name === 'AbortError' || fetchError.message?.includes('timeout')) {
        const timeoutError = new Error(
          'Request timed out. The server is taking too long to respond. Please try again.'
        )
        ;(timeoutError as any).isNetworkError = true
        ;(timeoutError as any).isTimeout = true
        throw timeoutError
      }
      
      throw fetchError
    }
  } catch (error: any) {
    // Handle network errors (CORS, connectivity, etc.)
    if (error instanceof TypeError && error.message === 'Failed to fetch') {
      // Check if it's a CORS error or connectivity issue
      const isCorsError = error.message.includes('CORS') || 
                         (typeof window !== 'undefined' && !navigator.onLine)
      
      const networkError = new Error(
        isCorsError
          ? 'CORS error: Unable to connect to the server. Please check your internet connection and ensure the API server is running.'
          : 'Network error: Unable to reach the server. Please check your internet connection and try again.'
      )
      ;(networkError as any).isNetworkError = true
      ;(networkError as any).isCorsError = isCorsError
      
      if (process.env.NODE_ENV === 'development') {
        console.error('[API Error]', {
          endpoint,
          url: fullUrl,
          error: error.message,
          isCorsError,
          online: typeof window !== 'undefined' ? navigator.onLine : 'unknown',
        })
      }
      
      throw networkError
    }
    
    // Re-throw other errors (including our custom errors)
    throw error
  }
}

export async function validateSession(session: Session): Promise<{ user_id: string; email?: string | null }> {
  return fetchWithAuth(session, '/auth/session')
}
