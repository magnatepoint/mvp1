'use client'

import { useState } from 'react'
import type { Session } from '@supabase/supabase-js'
import { deleteAllData } from '@/lib/api/settings'
import type { DeleteDataResponse } from '@/types/settings'

interface DeleteDataModalProps {
  isOpen: boolean
  session: Session
  onClose: () => void
  onSuccess: () => void
}

export default function DeleteDataModal({
  isOpen,
  session,
  onClose,
  onSuccess,
}: DeleteDataModalProps) {
  const [isDeleting, setIsDeleting] = useState(false)
  const [error, setError] = useState<string | null>(null)

  if (!isOpen) return null

  const handleDelete = async () => {
    setIsDeleting(true)
    setError(null)

    try {
      const result = await deleteAllData(session)
      console.log('Data deleted:', result)
      onSuccess()
      // Close modal and reload page after a short delay
      setTimeout(() => {
        window.location.reload()
      }, 2000)
    } catch (err) {
      console.error('Error deleting data:', err)
      setError(err instanceof Error ? err.message : 'Failed to delete data')
    } finally {
      setIsDeleting(false)
    }
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm">
      <div className="bg-[#2E2E2E] rounded-2xl p-6 max-w-md w-full mx-4 border border-white/20">
        <h3 className="text-xl font-bold text-white mb-2">Delete All Data</h3>
        <p className="text-sm text-gray-300 mb-6">
          This will permanently delete all your transaction data, goals, budgets, and moments. This
          action cannot be undone. Are you sure you want to continue?
        </p>

        {error && (
          <div className="mb-4 p-3 rounded-lg bg-red-500/20 border border-red-500/50">
            <p className="text-sm text-red-400">{error}</p>
          </div>
        )}

        <div className="flex gap-3">
          <button
            onClick={onClose}
            disabled={isDeleting}
            className="flex-1 py-3 px-4 rounded-xl font-semibold bg-white/10 text-white hover:bg-white/20 transition-colors disabled:opacity-50"
          >
            Cancel
          </button>
          <button
            onClick={handleDelete}
            disabled={isDeleting}
            className={`flex-1 py-3 px-4 rounded-xl font-semibold transition-colors ${
              isDeleting
                ? 'bg-red-500/50 text-white/50 cursor-not-allowed'
                : 'bg-red-500 text-white hover:bg-red-600'
            }`}
          >
            {isDeleting ? (
              <span className="flex items-center justify-center gap-2">
                <div className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                Deleting...
              </span>
            ) : (
              'Delete'
            )}
          </button>
        </div>
      </div>
    </div>
  )
}
