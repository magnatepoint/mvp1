'use client'

import { useState, useEffect } from 'react'
import type { Session } from '@supabase/supabase-js'
import { fetchUserGoals, fetchGoalProgress } from '@/lib/api/goals'
import type { GoalResponse, GoalProgressItem } from '@/types/goals'
import ProgressMetricCard from '../components/ProgressMetricCard'
import GoalListCard from '../components/GoalListCard'

interface OverviewTabProps {
  session: Session
}

export default function OverviewTab({ session }: OverviewTabProps) {
  const [goals, setGoals] = useState<GoalResponse[]>([])
  const [progress, setProgress] = useState<GoalProgressItem[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const loadData = async () => {
    setLoading(true)
    setError(null)
    try {
      const [goalsData, progressData] = await Promise.all([
        fetchUserGoals(session),
        fetchGoalProgress(session),
      ])
      setGoals(goalsData)
      setProgress(progressData)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load data')
      console.error('Error loading overview data:', err)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    loadData()
  }, [session])

  const activeGoals = goals.filter((g) => g.status.toLowerCase() === 'active')
  const completedGoals = goals.filter((g) => g.status.toLowerCase() === 'completed')

  const totalProgressPercentage =
    progress.length > 0
      ? progress.reduce((sum, p) => sum + p.progress_pct, 0) / progress.length
      : 0

  const goalAchieverLevel = (() => {
    const completionRate = goals.length > 0 ? (completedGoals.length / goals.length) * 100 : 0
    const avgProgress = totalProgressPercentage

    if (completionRate >= 80 && avgProgress >= 80) return 'Expert'
    if (completionRate >= 60 && avgProgress >= 60) return 'Advanced'
    if (completionRate >= 40 && avgProgress >= 40) return 'Intermediate'
    return 'Beginner'
  })()

  if (loading) {
    return (
      <div className="flex items-center justify-center py-20">
        <div className="animate-spin rounded-full h-12 w-12 border-t-2 border-b-2 border-[#D4AF37]"></div>
      </div>
    )
  }

  if (error) {
    return (
      <div className="flex flex-col items-center justify-center py-20 gap-4">
        <div className="text-red-400 text-center">
          <p className="text-lg font-bold mb-2">Unable to Load Data</p>
          <p className="text-sm">{error}</p>
        </div>
        <button
          onClick={loadData}
          className="px-6 py-2 bg-[#D4AF37] text-black rounded-lg font-medium hover:bg-[#D4AF37]/90 transition-colors"
        >
          Retry
        </button>
      </div>
    )
  }

  return (
    <div className="space-y-6 pb-6">
      {/* Your Progress Section */}
      <div className="space-y-4">
        <h2 className="text-xl font-bold text-white px-4">Your Progress</h2>

        {/* Metrics Grid (2x2) */}
        <div className="grid grid-cols-2 gap-3 px-4">
          <ProgressMetricCard
            icon="🎯"
            value={activeGoals.length.toString()}
            label="Active Goals"
            color="#8B5CF6"
          />
          <ProgressMetricCard
            icon="✅"
            value={completedGoals.length.toString()}
            label="Completed"
            color="#28B67E"
          />
          <ProgressMetricCard
            icon="📈"
            value={`${totalProgressPercentage.toFixed(1)}%`}
            label="Total Progress"
            color="#D4AF37"
          />
          <ProgressMetricCard
            icon="⭐"
            value={goalAchieverLevel}
            label="Goal Achiever Level"
            color="#EF4444"
          />
        </div>
      </div>

      {/* Active Goals Section */}
      {activeGoals.length > 0 ? (
        <div className="space-y-4">
          <h2 className="text-xl font-bold text-white px-4">Active Goals</h2>
          <div className="space-y-3 px-4">
            {activeGoals.map((goal) => {
              const goalProgress = progress.find((p) => p.goal_id === goal.goal_id)
              return <GoalListCard key={goal.goal_id} goal={goal} progress={goalProgress} />
            })}
          </div>
        </div>
      ) : (
        <div className="flex flex-col items-center justify-center py-20 gap-4">
          <span className="text-5xl">🎯</span>
          <p className="text-lg font-semibold text-white">No Active Goals</p>
          <p className="text-sm text-gray-400 text-center px-8">
            Create your first goal to start tracking your progress.
          </p>
        </div>
      )}
    </div>
  )
}
