'use client'

import type { Session } from '@supabase/supabase-js'
import type { MoneyMoment } from '@/types/moneymoments'
import MoneyMomentCard from '../components/MoneyMomentCard'
import HabitCard from '../components/HabitCard'
import { computeMoneyMoments } from '@/lib/api/moneymoments'
import { useState } from 'react'

interface HabitsTabProps {
  session: Session
  moments: MoneyMoment[]
  isLoading: boolean
  error: string | null
  onRetry: () => void
  onMomentsUpdated: () => void
}

export default function HabitsTab({
  session,
  moments,
  isLoading,
  error,
  onRetry,
  onMomentsUpdated,
}: HabitsTabProps) {
  const [isComputing, setIsComputing] = useState(false)
  const [computeError, setComputeError] = useState<string | null>(null)

  const handleComputeMoments = async () => {
    setIsComputing(true)
    setComputeError(null)
    try {
      // Compute for past 12 months
      const now = new Date()
      const months: string[] = []
      for (let i = 0; i < 12; i++) {
        const date = new Date(now.getFullYear(), now.getMonth() - i, 1)
        const monthStr = date.toISOString().slice(0, 7) // YYYY-MM format
        months.push(monthStr)
      }

      // Compute moments for each month sequentially
      let successCount = 0
      for (const month of months) {
        try {
          await computeMoneyMoments(session, month)
          successCount++
        } catch (err) {
          console.error(`Error computing moments for ${month}:`, err)
          // Continue with other months
        }
      }

      if (successCount > 0) {
        // Reload moments
        onMomentsUpdated()
      } else {
        setComputeError('Failed to compute moments for any month. Please check your transaction data.')
      }
    } catch (err) {
      console.error('Error computing moments:', err)
      setComputeError(err instanceof Error ? err.message : 'Failed to compute moments')
    } finally {
      setIsComputing(false)
    }
  }

  if (isLoading) {
    return (
      <div className="flex items-center justify-center py-20">
        <div className="animate-spin rounded-full h-12 w-12 border-t-2 border-b-2 border-[#D4AF37]"></div>
      </div>
    )
  }

  if (error) {
    return (
      <div className="flex flex-col items-center justify-center py-20 gap-4 px-4">
        <div className="text-red-400 text-center">
          <p className="text-lg font-bold mb-2">Unable to Load Habits</p>
          <p className="text-sm">{error}</p>
        </div>
        <button
          onClick={onRetry}
          className="px-6 py-2 bg-[#D4AF37] text-black rounded-lg font-medium hover:bg-[#D4AF37]/90 transition-colors"
        >
          Retry
        </button>
      </div>
    )
  }

  if (moments.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center py-20 gap-4 px-4">
        <span className="text-5xl">📊</span>
        <p className="text-lg font-semibold text-white">No Habits Tracked Yet</p>
        <p className="text-sm text-gray-400 text-center px-8">
          Habits are derived from your spending moments. Compute moments to start tracking your
          habits.
        </p>
        {computeError && (
          <div className="text-red-400 text-sm text-center px-8">{computeError}</div>
        )}
        <button
          onClick={handleComputeMoments}
          disabled={isComputing}
          className={`px-6 py-3 rounded-xl font-semibold transition-colors ${
            isComputing
              ? 'bg-[#D4AF37]/50 text-black/50 cursor-not-allowed'
              : 'bg-[#D4AF37] text-black hover:bg-[#D4AF37]/90'
          }`}
        >
          {isComputing ? (
            <span className="flex items-center gap-2">
              <div className="w-4 h-4 border-2 border-black/30 border-t-black rounded-full animate-spin" />
              Computing...
            </span>
          ) : (
            'Compute Moments for Past 12 Months'
          )}
        </button>
      </div>
    )
  }

  return (
    <div className="space-y-6 pb-6">
      <div className="space-y-4 px-4">
        <h2 className="text-xl font-bold text-white">Your Habits</h2>
        <div className="space-y-4">
          {moments.map((moment) => (
            <MoneyMomentCard key={`${moment.habit_id}-${moment.month}`} moment={moment} />
          ))}
        </div>
      </div>
    </div>
  )
}
