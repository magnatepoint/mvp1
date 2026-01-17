'use client'

import { useState } from 'react'
import type { Session } from '@supabase/supabase-js'
import { submitGoals } from '@/lib/api/goals'
import type { LifeContextRequest, SelectedGoal, GoalDetailRequest } from '@/types/goals'
import { glassCardSecondary } from '@/lib/theme/glass'

interface ReviewStepProps {
  session: Session
  lifeContext: LifeContextRequest
  selectedGoals: SelectedGoal[]
  onBack: () => void
  onComplete: () => void
  onClose: () => void
}

export default function ReviewStep({
  session,
  lifeContext,
  selectedGoals,
  onBack,
  onComplete,
  onClose,
}: ReviewStepProps) {
  const [submitting, setSubmitting] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('en-IN', {
      style: 'currency',
      currency: 'INR',
      maximumFractionDigits: 0,
    }).format(amount)
  }

  const formatDate = (dateString: string | null) => {
    if (!dateString) return 'Not set'
    try {
      return new Date(dateString).toLocaleDateString('en-IN', {
        year: 'numeric',
        month: 'long',
        day: 'numeric',
      })
    } catch {
      return dateString
    }
  }

  const handleSubmit = async () => {
    setSubmitting(true)
    setError(null)

    try {
      // Convert SelectedGoal[] to GoalDetailRequest[]
      const goalDetails: GoalDetailRequest[] = selectedGoals.map((goal) => ({
        goal_category: goal.goal_category,
        goal_name: goal.goal_name,
        estimated_cost: goal.estimated_cost,
        target_date: goal.target_date,
        current_savings: goal.current_savings,
        importance: goal.importance,
        notes: goal.notes || null,
      }))

      await submitGoals(session, {
        context: lifeContext,
        selected_goals: goalDetails,
      })

      onComplete()
      onClose()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to submit goals')
      console.error('Error submitting goals:', err)
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-bold text-white mb-2">Review & Submit</h2>
        <p className="text-sm text-gray-400">
          Review your information before submitting your goals.
        </p>
      </div>

      <div className="space-y-6 max-h-[60vh] overflow-y-auto pr-2">
        {/* Life Context Summary */}
        <div className={`${glassCardSecondary} p-4 space-y-2`}>
          <h3 className="text-lg font-semibold text-white mb-3">Life Context</h3>
          <div className="grid grid-cols-2 gap-2 text-sm">
            <div>
              <span className="text-gray-400">Age Band:</span>
              <span className="text-white ml-2">{lifeContext.age_band}</span>
            </div>
            <div>
              <span className="text-gray-400">Employment:</span>
              <span className="text-white ml-2 capitalize">{lifeContext.employment.replace('_', ' ')}</span>
            </div>
            <div>
              <span className="text-gray-400">Housing:</span>
              <span className="text-white ml-2 capitalize">{lifeContext.housing.replace('_', ' ')}</span>
            </div>
            <div>
              <span className="text-gray-400">Region:</span>
              <span className="text-white ml-2">{lifeContext.region_code}</span>
            </div>
            {lifeContext.monthly_investible_capacity && (
              <div>
                <span className="text-gray-400">Monthly Capacity:</span>
                <span className="text-white ml-2">
                  {formatCurrency(lifeContext.monthly_investible_capacity)}
                </span>
              </div>
            )}
          </div>
        </div>

        {/* Goals Summary */}
        <div className="space-y-3">
          <h3 className="text-lg font-semibold text-white">Selected Goals ({selectedGoals.length})</h3>
          {selectedGoals.map((goal, index) => (
            <div key={index} className={`${glassCardSecondary} p-4 space-y-2`}>
              <div className="flex items-start justify-between">
                <div className="flex-1">
                  <h4 className="text-base font-semibold text-white">{goal.goal_name}</h4>
                  <p className="text-sm text-gray-400">{goal.goal_category}</p>
                </div>
              </div>
              <div className="grid grid-cols-2 gap-2 text-sm pt-2 border-t border-white/10">
                <div>
                  <span className="text-gray-400">Target Amount:</span>
                  <span className="text-white ml-2">{formatCurrency(goal.estimated_cost)}</span>
                </div>
                <div>
                  <span className="text-gray-400">Current Savings:</span>
                  <span className="text-white ml-2">{formatCurrency(goal.current_savings)}</span>
                </div>
                <div>
                  <span className="text-gray-400">Target Date:</span>
                  <span className="text-white ml-2">{formatDate(goal.target_date)}</span>
                </div>
                <div>
                  <span className="text-gray-400">Importance:</span>
                  <span className="text-white ml-2">{goal.importance}/5</span>
                </div>
                {goal.notes && (
                  <div className="col-span-2">
                    <span className="text-gray-400">Notes:</span>
                    <span className="text-white ml-2">{goal.notes}</span>
                  </div>
                )}
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Error Message */}
      {error && (
        <div className="p-3 rounded-lg bg-red-500/10 border border-red-500/20">
          <p className="text-sm text-red-400">{error}</p>
        </div>
      )}

      {/* Navigation Buttons */}
      <div className="flex gap-3 pt-4 border-t border-white/10">
        <button
          onClick={onBack}
          disabled={submitting}
          className="flex-1 px-4 py-3 rounded-lg bg-white/5 border border-white/10 hover:bg-white/10 transition-colors text-white disabled:opacity-50"
        >
          Back
        </button>
        <button
          onClick={handleSubmit}
          disabled={submitting}
          className={`flex-1 px-4 py-3 rounded-lg font-medium transition-colors ${
            submitting
              ? 'bg-[#D4AF37]/50 text-black/50 cursor-not-allowed'
              : 'bg-[#D4AF37] text-black hover:bg-[#D4AF37]/90'
          }`}
        >
          {submitting ? 'Submitting...' : 'Submit Goals'}
        </button>
      </div>
    </div>
  )
}
