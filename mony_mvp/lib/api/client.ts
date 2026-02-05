import type { Session } from '@supabase/supabase-js'

// Validate API URL - should not contain paths like /auth/callback
const rawApiUrl = process.env.NEXT_PUBLIC_API_URL || 'https://api.monytix.ai'
let API_BASE_URL = rawApiUrl.split('/').slice(0, 3).join('/') // Remove any paths, keep only protocol://host
// Ensure no trailing slash
API_BASE_URL = API_BASE_URL.endsWith('/') ? API_BASE_URL.slice(0, -1) : API_BASE_URL

// Check if API URL is incorrectly configured
const urlObj = new URL(API_BASE_URL)
const isWrongHostname = urlObj.hostname === 'mvp.monytix.ai' || urlObj.hostname.includes('mvp.monytix.ai')
const hasPath = rawApiUrl !== API_BASE_URL

// If hostname is wrong, use the correct default API URL
if (isWrongHostname) {
  console.error('[API] ⚠️ CRITICAL: NEXT_PUBLIC_API_URL points to frontend domain instead of API domain!')
  console.error('[API] Current value:', rawApiUrl)
  console.error('[API] Using fallback: https://api.monytix.ai')
  console.error('[API] Fix in Cloudflare Pages → Settings → Environment Variables')
  console.error('[API] Set NEXT_PUBLIC_API_URL to: https://api.monytix.ai')
  API_BASE_URL = 'https://api.monytix.ai'
} else if (hasPath) {
  console.warn('[API] ⚠️ NEXT_PUBLIC_API_URL contains a path (auto-stripped)')
  console.warn('[API] Current value:', rawApiUrl)
  console.warn('[API] Using:', API_BASE_URL)
  console.warn('[API] Fix in Cloudflare Pages → Settings → Environment Variables')
}

const REQUEST_TIMEOUT = 45000 // 45 seconds (Overview KPIs/insights can be slow with large datasets)

export async function fetchWithAuth<T>(
  session: Session,
  endpoint: string,
  options?: RequestInit
): Promise<T> {
  // Validate session token before making request
  if (!session?.access_token) {
    throw new Error('Authentication required. Please log in again.')
  }

  // Construct full URL - normalize to prevent double slashes
  const baseUrl = API_BASE_URL.endsWith('/') ? API_BASE_URL.slice(0, -1) : API_BASE_URL
  const endpointPath = endpoint.startsWith('/') ? endpoint : `/${endpoint}`
  const fullUrl = `${baseUrl}${endpointPath}`
  
  // Always log API calls for debugging (helps diagnose production issues)
  console.log(`[API] ${options?.method || 'GET'} ${fullUrl}`)
  if (!process.env.NEXT_PUBLIC_API_URL) {
    console.warn('[API] ⚠️ NEXT_PUBLIC_API_URL not set, using default:', API_BASE_URL)
    console.warn('[API] Set this in Cloudflare Pages → Settings → Environment Variables')
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
        
        // Always log network errors with full details for debugging
        console.error('[API Error] Failed to fetch', {
          endpoint,
          url: fullUrl,
          apiBaseUrl: API_BASE_URL,
          envVarSet: !!process.env.NEXT_PUBLIC_API_URL,
          error: error.message,
          isCorsError,
          online: typeof window !== 'undefined' ? navigator.onLine : 'unknown',
        })
        
        const networkError = new Error(
          isCorsError
            ? `CORS error: Unable to connect to ${API_BASE_URL}. Check backend CORS configuration and FRONTEND_ORIGIN environment variable.`
            : `Network error: Unable to reach ${API_BASE_URL}. Check if the API is running and accessible.`
        )
        ;(networkError as any).isNetworkError = true
        ;(networkError as any).isCorsError = isCorsError
        
        throw networkError
      }
    
    // Re-throw other errors (including our custom errors)
    throw error
  }
}

export async function validateSession(session: Session): Promise<{ user_id: string; email?: string | null }> {
  return fetchWithAuth(session, '/auth/session')
}
