'use client'

import { useEffect, useState } from 'react'
import type { Session } from '@supabase/supabase-js'
import { fetchGoals, transformGoals } from '@/lib/api/console'
import type { Goal } from '@/types/console'
import { glassCardPrimary } from '@/lib/theme/glass'

interface GoalsTabProps {
  session: Session
}

export default function GoalsTab({ session }: GoalsTabProps) {
  const [goals, setGoals] = useState<Goal[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const loadGoals = async () => {
    setLoading(true)
    setError(null)
    try {
      const goalsData = await fetchGoals(session)
      setGoals(transformGoals(goalsData))
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load goals')
      console.error('Error loading goals:', err)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    loadGoals()
  }, [session])

  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('en-IN', {
      style: 'currency',
      currency: 'INR',
      maximumFractionDigits: 0,
    }).format(amount)
  }

  if (loading && goals.length === 0 && !error) {
    return (
      <div className="max-w-7xl mx-auto space-y-4">
        <h2 className="text-xl font-bold text-white mb-4">Goals</h2>
        <div className="space-y-4">
          {[1, 2, 3].map((i) => (
            <div key={i} className={`${glassCardPrimary} p-6 animate-pulse`}>
              <div className="flex justify-between items-start mb-3">
                <div className="h-5 bg-white/10 rounded w-1/3" />
                <div className="h-5 bg-white/10 rounded w-20" />
              </div>
              <div className="h-2 bg-white/10 rounded w-full" />
              <div className="h-4 bg-white/10 rounded w-1/4 mt-3" />
            </div>
          ))}
        </div>
      </div>
    )
  }

  if (error) {
    return (
      <div className="flex flex-col items-center justify-center py-20 gap-4">
        <div className="text-red-400 text-center">
          <p className="text-lg font-bold mb-2">Unable to Load Goals</p>
          <p className="text-sm">{error}</p>
        </div>
        <button
          onClick={loadGoals}
          className="px-6 py-2 bg-[#D4AF37] text-black rounded-lg font-medium hover:bg-[#D4AF37]/90 transition-colors"
        >
          Retry
        </button>
      </div>
    )
  }

  if (goals.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center py-20 gap-4">
        <span className="text-5xl">🎯</span>
        <p className="text-lg font-semibold text-white">No Goals</p>
        <p className="text-sm text-gray-400">Create your first financial goal to get started</p>
      </div>
    )
  }

  return (
    <div className="max-w-7xl mx-auto space-y-4">
      <h2 className="text-xl font-bold text-white mb-4">Your Goals</h2>
      {goals.map((goal) => (
        <GoalCard key={goal.id} goal={goal} />
      ))}
    </div>
  )

  function GoalCard({ goal }: { goal: Goal }) {
    const progress = goal.target_amount > 0 ? (goal.saved_amount / goal.target_amount) * 100 : 0
    const remaining = Math.max(goal.target_amount - goal.saved_amount, 0)

    return (
      <div className={`${glassCardPrimary} p-6`}>
        <div className="flex items-start justify-between mb-4">
          <div className="flex-1">
            <h3 className="text-lg font-bold text-white mb-1">{goal.name}</h3>
            {goal.category && (
              <p className="text-sm text-gray-400">{goal.category}</p>
            )}
          </div>
          {goal.is_active && (
            <span className="px-3 py-1 bg-green-500/20 text-green-400 rounded-full text-xs font-medium">
              Active
            </span>
          )}
        </div>

        <div className="mb-4">
          <div className="flex items-center justify-between mb-2">
            <span className="text-sm text-gray-400">Progress</span>
            <span className="text-sm font-semibold text-white">{progress.toFixed(1)}%</span>
          </div>
          <div className="bg-gray-700/50 rounded-full h-3 overflow-hidden">
            <div
              className="bg-[#D4AF37] h-full transition-all"
              style={{ width: `${Math.min(progress, 100)}%` }}
            />
          </div>
        </div>

        <div className="grid grid-cols-3 gap-4 text-sm">
          <div>
            <p className="text-gray-400 mb-1">Saved</p>
            <p className="text-white font-semibold">{formatCurrency(goal.saved_amount)}</p>
          </div>
          <div>
            <p className="text-gray-400 mb-1">Target</p>
            <p className="text-white font-semibold">{formatCurrency(goal.target_amount)}</p>
          </div>
          <div>
            <p className="text-gray-400 mb-1">Remaining</p>
            <p className="text-white font-semibold">{formatCurrency(remaining)}</p>
          </div>
        </div>
      </div>
    )
  }
}
