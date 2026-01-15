import type { Session } from '@supabase/supabase-js'

const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || 'https://api.monytix.ai'

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
  const formData = new FormData()
  formData.append('file', file)
  
  if (password && password.trim()) {
    formData.append('password', password.trim())
  }

  return new Promise((resolve, reject) => {
    const xhr = new XMLHttpRequest()

    // Track upload progress
    xhr.upload.addEventListener('progress', (e) => {
      if (e.lengthComputable && onProgress) {
        const percentage = (e.loaded / e.total) * 100
        onProgress({
          loaded: e.loaded,
          total: e.total,
          percentage,
        })
      }
    })

    xhr.addEventListener('load', () => {
      if (xhr.status >= 200 && xhr.status < 300) {
        try {
          const response = JSON.parse(xhr.responseText)
          resolve(response)
        } catch (err) {
          reject(new Error('Failed to parse upload response'))
        }
      } else {
        let errorMessage = `Upload failed: ${xhr.statusText}`
        try {
          const errorBody = JSON.parse(xhr.responseText)
          if (errorBody.detail) {
            errorMessage = typeof errorBody.detail === 'string' 
              ? errorBody.detail 
              : JSON.stringify(errorBody.detail)
          }
        } catch {
          // Ignore parse errors
        }
        reject(new Error(errorMessage))
      }
    })

    xhr.addEventListener('error', () => {
      reject(new Error('Network error during upload'))
    })

    xhr.addEventListener('abort', () => {
      reject(new Error('Upload was cancelled'))
    })

    xhr.open('POST', `${API_BASE_URL}/v1/spendsense/uploads/file`)
    xhr.setRequestHeader('Authorization', `Bearer ${session.access_token}`)
    xhr.send(formData)
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
