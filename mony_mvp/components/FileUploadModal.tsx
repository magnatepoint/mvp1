'use client'

import { useState, useRef } from 'react'
import type { Session } from '@supabase/supabase-js'
import { uploadStatementFile, isSupportedFileType, isPDFFile } from '@/lib/api/upload'
import { checkPDFPasswordProtectionSimple } from '@/lib/utils/pdfDetection'
import { glassCardPrimary, glassFilter } from '@/lib/theme/glass'
import type { UploadBatch } from '@/lib/api/upload'

interface FileUploadModalProps {
  session: Session
  isOpen: boolean
  onClose: () => void
  onUploadComplete?: () => void
}

export default function FileUploadModal({
  session,
  isOpen,
  onClose,
  onUploadComplete,
}: FileUploadModalProps) {
  const [selectedFile, setSelectedFile] = useState<File | null>(null)
  const [password, setPassword] = useState('')
  const [isPasswordProtected, setIsPasswordProtected] = useState(false)
  const [isCheckingPassword, setIsCheckingPassword] = useState(false)
  const [isUploading, setIsUploading] = useState(false)
  const [uploadProgress, setUploadProgress] = useState(0)
  const [error, setError] = useState<string | null>(null)
  const fileInputRef = useRef<HTMLInputElement>(null)

  if (!isOpen) return null

  const handleFileSelect = async (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0]
    if (!file) return

    // Validate file type
    if (!isSupportedFileType(file)) {
      setError('Unsupported file type. Please upload PDF, XLS, XLSX, or CSV files.')
      return
    }

    setSelectedFile(file)
    setError(null)
    setPassword('')

    // Check if PDF is password-protected
    if (isPDFFile(file)) {
      setIsCheckingPassword(true)
      try {
        const isProtected = await checkPDFPasswordProtectionSimple(file)
        setIsPasswordProtected(isProtected)
        if (isProtected) {
          setError(null) // Clear any previous errors
        }
      } catch (err) {
        console.error('Error checking PDF protection:', err)
        // Assume not protected if check fails
        setIsPasswordProtected(false)
      } finally {
        setIsCheckingPassword(false)
      }
    } else {
      setIsPasswordProtected(false)
    }
  }

  const handleUpload = async () => {
    if (!selectedFile) return

    // Validate password if PDF is protected
    if (isPDFFile(selectedFile) && isPasswordProtected && !password.trim()) {
      setError('Password is required for this PDF file.')
      return
    }

    setIsUploading(true)
    setError(null)
    setUploadProgress(0)

    try {
      const result = await uploadStatementFile(
        session,
        selectedFile,
        password.trim() || undefined,
        (progress) => {
          setUploadProgress(progress.percentage)
        }
      )

      // Log success in development
      if (process.env.NODE_ENV === 'development') {
        console.log('[Upload] Upload completed successfully:', result)
      }

      // Success - reset and close
      setSelectedFile(null)
      setPassword('')
      setIsPasswordProtected(false)
      setUploadProgress(0)
      onUploadComplete?.()
      onClose()
    } catch (err) {
      let errorMessage = 'Upload failed. Please try again.'
      
      if (err instanceof Error) {
        errorMessage = err.message
        
        // Provide more helpful messages for common errors
        if (err.message.includes('Network error') || err.message.includes('Unable to reach')) {
          errorMessage = 'Unable to connect to the server. Please check your internet connection and ensure the backend API is running.'
        } else if (err.message.includes('timeout') || err.message.includes('timed out')) {
          errorMessage = 'Upload timed out. The file may be too large. Please try again with a smaller file or check your internet connection.'
        } else if (err.message.includes('CORS')) {
          errorMessage = 'CORS error: Unable to connect to the server. Please check that the backend API is running and accessible.'
        } else if (err.message.includes('Authentication') || err.message.includes('session')) {
          errorMessage = 'Your session has expired. Please refresh the page and try again.'
        } else if (err.message.includes('No tabular data') || err.message.includes('scanned') || err.message.includes('image-based')) {
          errorMessage = 'This PDF cannot be processed because it appears to be scanned or image-based. We can only process PDFs with extractable text and tables. Please use the original digital PDF or manually enter transactions.'
        }
      }
      
      setError(errorMessage)
      console.error('[Upload] Upload error:', err)
    } finally {
      setIsUploading(false)
    }
  }

  const handleClose = () => {
    if (isUploading) return // Don't allow closing during upload
    setSelectedFile(null)
    setPassword('')
    setIsPasswordProtected(false)
    setError(null)
    setUploadProgress(0)
    onClose()
  }

  const formatFileSize = (bytes: number) => {
    if (bytes === 0) return '0 Bytes'
    const k = 1024
    const sizes = ['Bytes', 'KB', 'MB', 'GB']
    const i = Math.floor(Math.log(bytes) / Math.log(k))
    return Math.round(bytes / Math.pow(k, i) * 100) / 100 + ' ' + sizes[i]
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm">
      <div
        className={`relative ${glassCardPrimary} p-6 max-w-md w-full mx-4 max-h-[90vh] overflow-y-auto`}
      >
        {/* Close Button */}
        <button
          onClick={handleClose}
          disabled={isUploading}
          className="absolute top-4 right-4 p-2 rounded-lg hover:bg-white/10 transition-colors disabled:opacity-50"
        >
          <svg
            className="w-5 h-5"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M6 18L18 6M6 6l12 12"
            />
          </svg>
        </button>

        {/* Header */}
        <div className="mb-6">
          <h2 className="text-2xl font-bold mb-2">Upload Statement</h2>
          <p className="text-sm text-gray-400 mb-2">
            PDF, Excel (XLS/XLSX), or CSV — works on phone and desktop
          </p>
          <a
            href="/Monytix_Statement_Template.xlsx"
            download="Monytix_Statement_Template.xlsx"
            className="inline-flex items-center gap-2 text-sm text-[#D4AF37] hover:text-[#D4AF37]/80 transition-colors"
          >
            <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
            </svg>
            Download Excel template for manual entry
          </a>
        </div>

        {/* File Input */}
        <div className="mb-6">
          <input
            ref={fileInputRef}
            type="file"
            accept=".pdf,.xls,.xlsx,.csv,application/pdf,application/vnd.ms-excel,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet,text/csv"
            onChange={handleFileSelect}
            disabled={isUploading}
            className="hidden"
          />
          <button
            onClick={() => fileInputRef.current?.click()}
            disabled={isUploading || isCheckingPassword}
            className={`w-full ${glassFilter} p-6 border-2 border-dashed border-white/20 rounded-lg hover:border-white/30 transition-colors disabled:opacity-50 disabled:cursor-not-allowed min-h-[120px] touch-manipulation`}
            type="button"
          >
            <div className="flex flex-col items-center gap-3">
              <svg
                className="w-12 h-12 text-gray-400 shrink-0"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"
                />
              </svg>
              <div className="text-center">
                <p className="text-sm font-medium">
                  {selectedFile ? selectedFile.name : 'Tap or click to select file'}
                </p>
                {selectedFile && (
                  <p className="text-xs text-gray-500 mt-1">
                    {formatFileSize(selectedFile.size)}
                  </p>
                )}
              </div>
            </div>
          </button>
        </div>

        {/* Password Checking Indicator */}
        {isCheckingPassword && (
          <div className="mb-4 flex items-center gap-2 text-sm text-gray-400">
            <div className="animate-spin rounded-full h-4 w-4 border-t-2 border-b-2 border-white"></div>
            <span>Checking PDF protection...</span>
          </div>
        )}

        {/* Password Input (for PDF files) */}
        {selectedFile && isPDFFile(selectedFile) && (
          <div className="mb-6">
            <label className="block text-sm font-medium mb-2">
              {isPasswordProtected ? (
                <span className="flex items-center gap-2">
                  <svg
                    className="w-4 h-4 text-orange-400"
                    fill="currentColor"
                    viewBox="0 0 20 20"
                  >
                    <path
                      fillRule="evenodd"
                      d="M5 9V7a5 5 0 0110 0v2a2 2 0 012 2v5a2 2 0 01-2 2H5a2 2 0 01-2-2v-5a2 2 0 012-2zm8-2v2H7V7a3 3 0 016 0z"
                      clipRule="evenodd"
                    />
                  </svg>
                  PDF Password (required)
                </span>
              ) : (
                <span className="flex items-center gap-2">
                  <svg
                    className="w-4 h-4 text-gray-400"
                    fill="currentColor"
                    viewBox="0 0 20 20"
                  >
                    <path d="M10 2a5 5 0 00-5 5v2a2 2 0 00-2 2v5a2 2 0 002 2h10a2 2 0 002-2v-5a2 2 0 00-2-2H7V7a3 3 0 016 0v1h-1V7a1 1 0 10-2 0v1H8V7a5 5 0 015-5z" />
                  </svg>
                  PDF Password (optional)
                </span>
              )}
            </label>
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder={
                isPasswordProtected
                  ? 'Enter password to unlock PDF'
                  : 'Enter password if PDF is encrypted'
              }
              disabled={isUploading}
              className={`w-full ${glassFilter} px-4 py-3 rounded-lg text-foreground placeholder-gray-500 disabled:opacity-50`}
            />
            {isPasswordProtected && !password.trim() && (
              <p className="text-xs text-orange-400 mt-1">
                This PDF requires a password to open.
              </p>
            )}
          </div>
        )}

        {/* Error Message */}
        {error && (
          <div className="mb-4 p-3 rounded-lg bg-red-500/10 border border-red-500/20">
            <p className="text-sm text-red-400 font-medium mb-1">Upload Error</p>
            <p className="text-sm text-red-300">{error}</p>
            {error.toLowerCase().includes('scanned') || error.toLowerCase().includes('image-based') || error.toLowerCase().includes('no tabular data') ? (
              <div className="mt-2 p-2 bg-orange-500/10 border border-orange-500/20 rounded text-xs text-orange-300">
                <p className="font-medium mb-1">💡 Tip:</p>
                <p>This PDF appears to be scanned or image-based. We can only process PDFs with extractable text. Try:</p>
                <ul className="list-disc list-inside mt-1 space-y-1">
                  <li>Using the original digital PDF (not a scanned copy)</li>
                  <li>Converting the scanned PDF to text using OCR software first</li>
                  <li>Manually entering transactions if the PDF can't be processed</li>
                </ul>
              </div>
            ) : null}
          </div>
        )}

        {/* Upload Progress */}
        {isUploading && (
          <div className="mb-4">
            <div className="flex items-center justify-between mb-2">
              <span className="text-sm text-gray-400">Uploading...</span>
              <span className="text-sm text-gray-400">{Math.round(uploadProgress)}%</span>
            </div>
            <div className="w-full bg-gray-700/50 rounded-full h-2 overflow-hidden">
              <div
                className="bg-[#D4AF37] h-2 transition-all duration-300"
                style={{ width: `${uploadProgress}%` }}
              />
            </div>
          </div>
        )}

        {/* Actions */}
        <div className="flex gap-3">
          <button
            onClick={handleClose}
            disabled={isUploading}
            className="flex-1 px-4 py-3 rounded-lg bg-white/5 border border-white/10 hover:bg-white/10 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
          >
            Cancel
          </button>
          {error && !isUploading && (
            <button
              onClick={handleUpload}
              disabled={!selectedFile || isCheckingPassword}
              className="flex-1 px-4 py-3 rounded-lg bg-orange-500/20 border border-orange-500/30 text-orange-400 font-medium hover:bg-orange-500/30 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
            >
              Retry Upload
            </button>
          )}
          <button
            onClick={handleUpload}
            disabled={!selectedFile || isUploading || isCheckingPassword}
            className="flex-1 px-4 py-3 rounded-lg bg-[#D4AF37] text-black font-medium hover:bg-[#D4AF37]/90 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {isUploading ? 'Uploading...' : 'Upload'}
          </button>
        </div>
      </div>
    </div>
  )
}
