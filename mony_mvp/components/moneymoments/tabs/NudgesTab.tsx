'use client'

import { useState } from 'react'
import type { Session } from '@supabase/supabase-js'
import type { Nudge, MoneyMoment, ProgressMetrics } from '@/types/moneymoments'
import { evaluateNudges, processNudges, computeSignal } from '@/lib/api/moneymoments'
import ProgressMetricCard from '../components/ProgressMetricCard'
import NudgeCard from '../components/NudgeCard'

interface NudgesTabProps {
  session: Session
  nudges: Nudge[]
  moments: MoneyMoment[]
  progressMetrics: ProgressMetrics
  isLoading: boolean
  error: string | null
  onRetry: () => void
  onNudgesUpdated: () => void
}

export default function NudgesTab({
  session,
  nudges,
  moments,
  progressMetrics,
  isLoading,
  error,
  onRetry,
  onNudgesUpdated,
}: NudgesTabProps) {
  const [isEvaluating, setIsEvaluating] = useState(false)
  const [isProcessing, setIsProcessing] = useState(false)
  const [actionError, setActionError] = useState<string | null>(null)

  const handleEvaluateAndDeliver = async () => {
    setIsEvaluating(true)
    setIsProcessing(false)
    setActionError(null)

    try {
      // Optionally compute signal first (non-critical if it fails)
      try {
        await computeSignal(session)
      } catch (err) {
        console.warn('Signal computation failed (may not be critical):', err)
      }

      // Evaluate nudges
      const evalResponse = await evaluateNudges(session)
      console.log('Evaluation complete:', evalResponse)

      // Process and deliver nudges
      setIsProcessing(true)
      const processResponse = await processNudges(session, 10)
      console.log('Processing complete:', processResponse)

      // Reload nudges
      onNudgesUpdated()
    } catch (err) {
      console.error('Error evaluating/processing nudges:', err)
      setActionError(err instanceof Error ? err.message : 'Failed to evaluate and deliver nudges')
    } finally {
      setIsEvaluating(false)
      setIsProcessing(false)
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
          <p className="text-lg font-bold mb-2">Unable to Load Nudges</p>
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

  return (
    <div className="space-y-6 pb-6">
      {/* Progress Metrics Section */}
      <div className="space-y-4 px-4">
        <h2 className="text-xl font-bold text-white">Your Progress</h2>
        <div className="grid grid-cols-2 gap-3">
          <ProgressMetricCard
            icon="flame.fill"
            value={`${progressMetrics.streak} days`}
            label="Streak"
            color="red"
          />
          <ProgressMetricCard
            icon="bell.fill"
            value={`${progressMetrics.nudgesCount}`}
            label="Nudges"
            color="blue"
          />
          <ProgressMetricCard
            icon="checkmark.circle.fill"
            value={`${progressMetrics.habitsCount}`}
            label="Habits"
            color="green"
          />
          <ProgressMetricCard
            icon="banknote.fill"
            value={new Intl.NumberFormat('en-IN', {
              style: 'currency',
              currency: 'INR',
              maximumFractionDigits: 0,
            }).format(progressMetrics.savedAmount)}
            label="Saved"
            color="brown"
          />
        </div>
      </div>

      {/* Active Nudges Section */}
      <div className="space-y-4 px-4">
        <h2 className="text-xl font-bold text-white">Active Nudges</h2>
        {nudges.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-20 gap-4 px-4">
            <span className="text-5xl">🔔</span>
            <p className="text-lg font-semibold text-white">No Nudges Yet</p>
            <p className="text-sm text-gray-400 text-center px-8">
              Nudges are personalized recommendations based on your spending. Evaluate and deliver
              nudges to get started.
            </p>
            {actionError && (
              <div className="text-red-400 text-sm text-center px-8">{actionError}</div>
            )}
            <button
              onClick={handleEvaluateAndDeliver}
              disabled={isEvaluating || isProcessing}
              className={`w-full max-w-md py-3 rounded-xl font-semibold transition-colors ${
                isEvaluating || isProcessing
                  ? 'bg-[#D4AF37]/50 text-black/50 cursor-not-allowed'
                  : 'bg-[#D4AF37] text-black hover:bg-[#D4AF37]/90'
              }`}
            >
              {isEvaluating || isProcessing ? (
                <span className="flex items-center justify-center gap-2">
                  <div className="w-4 h-4 border-2 border-black/30 border-t-black rounded-full animate-spin" />
                  Processing...
                </span>
              ) : (
                <span className="flex items-center justify-center gap-2">
                  <span>🔔</span>
                  Evaluate & Deliver Nudges
                </span>
              )}
            </button>
          </div>
        ) : (
          <div className="space-y-4">
            {nudges.map((nudge) => (
              <NudgeCard key={nudge.delivery_id} nudge={nudge} session={session} />
            ))}
          </div>
        )}
      </div>
    </div>
  )
}
