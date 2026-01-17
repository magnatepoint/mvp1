import type { Session } from '@supabase/supabase-js'

const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || 'https://api.monytix.ai'
const UPLOAD_TIMEOUT = 60000 // 60 seconds for file uploads

export interface UploadProgress {
  loaded: number
  total: number
  percentage: number
}

export interface UploadBatch {
  upload_id: string
  user_id: string
  source_type: string
  status: string
  created_at: string
}

/**
 * Upload a statement file (PDF, XLS, XLSX, CSV) to the backend
 */
export async function uploadStatementFile(
  session: Session,
  file: File,
  password?: string,
  onProgress?: (progress: UploadProgress) => void
): Promise<UploadBatch> {
  // Validate session
  if (!session?.access_token) {
    throw new Error('Authentication required. Please log in again.')
  }

  const formData = new FormData()
  formData.append('file', file)
  
  if (password && password.trim()) {
    formData.append('password', password.trim())
  }

  // Normalize URL to prevent double slashes
  const baseUrl = API_BASE_URL.endsWith('/') ? API_BASE_URL.slice(0, -1) : API_BASE_URL
  const endpoint = `${baseUrl}/v1/spendsense/uploads/file`

  // Development logging
  if (process.env.NODE_ENV === 'development') {
    console.log('[Upload] Starting upload:', {
      filename: file.name,
      size: file.size,
      type: file.type,
      endpoint,
    })
  }

  return new Promise((resolve, reject) => {
    const xhr = new XMLHttpRequest()
    let timeoutId: NodeJS.Timeout | null = null

    // Set timeout
    xhr.timeout = UPLOAD_TIMEOUT

    // Track upload progress
    xhr.upload.addEventListener('progress', (e) => {
      if (e.lengthComputable && onProgress) {
        const percentage = (e.loaded / e.total) * 100
        onProgress({
          loaded: e.loaded,
          total: e.total,
          percentage,
        })
        
        if (process.env.NODE_ENV === 'development') {
          console.log(`[Upload] Progress: ${Math.round(percentage)}%`)
        }
      }
    })

    xhr.addEventListener('load', () => {
      if (timeoutId) {
        clearTimeout(timeoutId)
        timeoutId = null
      }

      if (xhr.status >= 200 && xhr.status < 300) {
        try {
          const response = JSON.parse(xhr.responseText)
          
          if (process.env.NODE_ENV === 'development') {
            console.log('[Upload] Success:', response)
          }
          
          resolve(response)
        } catch (err) {
          const parseError = new Error('Failed to parse upload response from server')
          if (process.env.NODE_ENV === 'development') {
            console.error('[Upload] Parse error:', err, 'Response:', xhr.responseText)
          }
          reject(parseError)
        }
      } else {
        let errorMessage = `Upload failed: ${xhr.statusText} (${xhr.status})`
        
        // Categorize error by status code
        if (xhr.status === 401 || xhr.status === 403) {
          errorMessage = 'Your session has expired. Please refresh the page and try again.'
        } else if (xhr.status === 400) {
          errorMessage = 'Invalid file or request. Please check the file format and try again.'
        } else if (xhr.status === 413) {
          errorMessage = 'File is too large. Please upload a smaller file.'
        } else if (xhr.status >= 500) {
          errorMessage = 'Server error. Please try again later or contact support if the problem persists.'
        }
        
        try {
          const errorBody = JSON.parse(xhr.responseText)
          if (errorBody.detail) {
            const detail = errorBody.detail
            errorMessage = typeof detail === 'string' 
              ? detail 
              : JSON.stringify(detail)
          }
        } catch {
          // Use the categorized error message if parsing fails
        }
        
        if (process.env.NODE_ENV === 'development') {
          console.error('[Upload] Server error:', {
            status: xhr.status,
            statusText: xhr.statusText,
            response: xhr.responseText,
          })
        }
        
        reject(new Error(errorMessage))
      }
    })

    xhr.addEventListener('error', () => {
      if (timeoutId) {
        clearTimeout(timeoutId)
        timeoutId = null
      }

      // Check if it's a network error or CORS error
      const isNetworkError = !xhr.responseURL || xhr.status === 0
      const isCorsError = xhr.status === 0 && xhr.readyState === 4

      let errorMessage = 'Network error during upload'
      
      if (isCorsError) {
        errorMessage = 'CORS error: Unable to connect to the server. Please check your internet connection and ensure the API server is running.'
      } else if (isNetworkError) {
        errorMessage = 'Network error: Unable to reach the server. Please check your internet connection and try again.'
      }

      if (process.env.NODE_ENV === 'development') {
        console.error('[Upload] Network error:', {
          readyState: xhr.readyState,
          status: xhr.status,
          responseURL: xhr.responseURL,
          isCorsError,
          isNetworkError,
        })
      }

      reject(new Error(errorMessage))
    })

    xhr.addEventListener('timeout', () => {
      if (timeoutId) {
        clearTimeout(timeoutId)
        timeoutId = null
      }

      const timeoutError = new Error(
        'Upload timed out. The file may be too large or the server is taking too long to respond. Please try again with a smaller file.'
      )
      
      if (process.env.NODE_ENV === 'development') {
        console.error('[Upload] Timeout after', UPLOAD_TIMEOUT, 'ms')
      }
      
      reject(timeoutError)
    })

    xhr.addEventListener('abort', () => {
      if (timeoutId) {
        clearTimeout(timeoutId)
        timeoutId = null
      }

      if (process.env.NODE_ENV === 'development') {
        console.log('[Upload] Aborted by user')
      }

      reject(new Error('Upload was cancelled'))
    })

    // Set up request
    try {
      xhr.open('POST', endpoint)
      xhr.setRequestHeader('Authorization', `Bearer ${session.access_token}`)
      
      // Send request
      xhr.send(formData)
      
      // Set a backup timeout (in case xhr.timeout doesn't work in all browsers)
      timeoutId = setTimeout(() => {
        if (xhr.readyState !== XMLHttpRequest.DONE) {
          xhr.abort()
          reject(new Error(
            'Upload timed out. The file may be too large or the server is taking too long to respond. Please try again.'
          ))
        }
      }, UPLOAD_TIMEOUT)
    } catch (err) {
      if (timeoutId) {
        clearTimeout(timeoutId)
      }
      
      const setupError = err instanceof Error 
        ? err 
        : new Error('Failed to initiate upload request')
      
      if (process.env.NODE_ENV === 'development') {
        console.error('[Upload] Setup error:', setupError)
      }
      
      reject(setupError)
    }
  })
}

/**
 * Check if a file is a PDF
 */
export function isPDFFile(file: File): boolean {
  return file.type === 'application/pdf' || file.name.toLowerCase().endsWith('.pdf')
}

/**
 * Check if a file is an Excel file (XLS, XLSX)
 */
export function isExcelFile(file: File): boolean {
  const name = file.name.toLowerCase()
  return (
    file.type === 'application/vnd.ms-excel' ||
    file.type === 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' ||
    name.endsWith('.xls') ||
    name.endsWith('.xlsx')
  )
}

/**
 * Check if a file is a CSV file
 */
export function isCSVFile(file: File): boolean {
  return file.type === 'text/csv' || file.name.toLowerCase().endsWith('.csv')
}

/**
 * Check if file type is supported
 */
export function isSupportedFileType(file: File): boolean {
  return isPDFFile(file) || isExcelFile(file) || isCSVFile(file)
}
