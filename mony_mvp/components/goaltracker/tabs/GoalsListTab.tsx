'use client'

import { useState, useEffect } from 'react'
import type { Session } from '@supabase/supabase-js'
import { fetchUserGoals, fetchGoalProgress } from '@/lib/api/goals'
import type { GoalResponse, GoalProgressItem, GoalStatus } from '@/types/goals'
import FilterChip from '../components/FilterChip'
import GoalListCard from '../components/GoalListCard'

interface GoalsListTabProps {
  session: Session
}

export default function GoalsListTab({ session }: GoalsListTabProps) {
  const [goals, setGoals] = useState<GoalResponse[]>([])
  const [progress, setProgress] = useState<GoalProgressItem[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [selectedFilter, setSelectedFilter] = useState<GoalStatus | null>(null)

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
      setError(err instanceof Error ? err.message : 'Failed to load goals')
      console.error('Error loading goals:', err)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    loadData()
  }, [session])

  const filteredGoals = selectedFilter
    ? goals.filter((g) => g.status.toLowerCase() === selectedFilter)
    : goals

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
          <p className="text-lg font-bold mb-2">Unable to Load Goals</p>
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
    <div className="space-y-5 pb-6">
      {/* Filter Tabs */}
      <div className="px-4 pt-4">
        <div className="flex gap-3 overflow-x-auto scrollbar-hide pb-2">
          <FilterChip
            title="All"
            isSelected={selectedFilter === null}
            action={() => setSelectedFilter(null)}
          />
          <FilterChip
            title="Active"
            isSelected={selectedFilter === 'active'}
            action={() => setSelectedFilter('active')}
          />
          <FilterChip
            title="Completed"
            isSelected={selectedFilter === 'completed'}
            action={() => setSelectedFilter('completed')}
          />
        </div>
      </div>

      {/* Goals List */}
      {filteredGoals.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-20 gap-4">
          <span className="text-5xl">
            {selectedFilter === 'completed' ? '✅' : '🎯'}
          </span>
          <p className="text-lg font-semibold text-white">
            {selectedFilter === 'completed' ? 'No Completed Goals' : 'No Goals'}
          </p>
          <p className="text-sm text-gray-400 text-center px-8">
            {selectedFilter === 'completed'
              ? 'Complete your first goal to see it here.'
              : 'Create your first goal to start tracking your progress.'}
          </p>
        </div>
      ) : (
        <div className="space-y-3 px-4">
          {selectedFilter === 'completed' && (
            <h2 className="text-xl font-bold text-white">Completed Goals</h2>
          )}
          {filteredGoals.map((goal) => {
            const goalProgress = progress.find((p) => p.goal_id === goal.goal_id)
            return <GoalListCard key={goal.goal_id} goal={goal} progress={goalProgress} />
          })}
        </div>
      )}
    </div>
  )
}
