'use client'

import { useState, useMemo } from 'react'
import type { GoalCatalogItem, SelectedGoal } from '@/types/goals'
import FilterChip from '../components/FilterChip'
import { glassFilter } from '@/lib/theme/glass'

interface GoalSelectionStepProps {
  catalog: GoalCatalogItem[]
  recommendedGoals: GoalCatalogItem[]
  selectedGoals: SelectedGoal[]
  onAddGoal: (goal: GoalCatalogItem) => void
  onRemoveGoal: (index: number) => void
  onNext: () => void
  onBack: () => void
}

type GoalHorizon = 'short_term' | 'medium_term' | 'long_term' | null

export default function GoalSelectionStep({
  catalog,
  recommendedGoals,
  selectedGoals,
  onAddGoal,
  onRemoveGoal,
  onNext,
  onBack,
}: GoalSelectionStepProps) {
  const [filter, setFilter] = useState<GoalHorizon>(null)

  const selectedGoalKeys = useMemo(() => {
    return new Set(selectedGoals.map((g) => `${g.goal_category}:${g.goal_name}`))
  }, [selectedGoals])

  const filteredGoals = useMemo(() => {
    // Filter out recommended goals from main catalog
    const nonRecommended = catalog.filter(
      (goal) =>
        !recommendedGoals.some(
          (rec) => rec.goal_category === goal.goal_category && rec.goal_name === goal.goal_name
        )
    )

    if (filter) {
      return nonRecommended.filter((goal) => goal.default_horizon === filter)
    }
    return nonRecommended
  }, [catalog, recommendedGoals, filter])

  const toggleGoal = (goal: GoalCatalogItem) => {
    const key = `${goal.goal_category}:${goal.goal_name}`
    if (selectedGoalKeys.has(key)) {
      // Remove goal
      const index = selectedGoals.findIndex(
        (g) => g.goal_category === goal.goal_category && g.goal_name === goal.goal_name
      )
      if (index !== -1) {
        onRemoveGoal(index)
      }
    } else {
      // Add goal
      onAddGoal(goal)
    }
  }

  const selectAllRecommended = () => {
    recommendedGoals.forEach((goal) => {
      const key = `${goal.goal_category}:${goal.goal_name}`
      if (!selectedGoalKeys.has(key)) {
        onAddGoal(goal)
      }
    })
  }

  const horizonDisplayName = (horizon: string) => {
    switch (horizon) {
      case 'short_term':
        return 'Short Term'
      case 'medium_term':
        return 'Medium Term'
      case 'long_term':
        return 'Long Term'
      default:
        return horizon
    }
  }

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-bold text-white mb-2">Select Your Goals</h2>
        <p className="text-sm text-gray-400">Choose one or more financial goals to track.</p>
      </div>

      <div className="space-y-6 max-h-[60vh] overflow-y-auto pr-2">
        {/* Recommended Goals Section */}
        {recommendedGoals.length > 0 && (
          <div className="space-y-3">
            <div className="flex items-center justify-between">
              <h3 className="text-lg font-bold text-white">Recommended for You</h3>
              <button
                onClick={selectAllRecommended}
                className="text-sm font-medium text-[#D4AF37] hover:text-[#D4AF37]/80"
              >
                Select All
              </button>
            </div>
            {recommendedGoals.map((goal) => {
              const key = `${goal.goal_category}:${goal.goal_name}`
              const isSelected = selectedGoalKeys.has(key)
              return (
                <GoalCatalogCard
                  key={key}
                  goal={goal}
                  isSelected={isSelected}
                  onToggle={() => toggleGoal(goal)}
                />
              )
            })}
          </div>
        )}

        {/* Filter */}
        <div>
          <div className="flex gap-3 overflow-x-auto scrollbar-hide pb-2">
            <FilterChip
              title="All"
              isSelected={filter === null}
              action={() => setFilter(null)}
            />
            <FilterChip
              title="Short Term"
              isSelected={filter === 'short_term'}
              action={() => setFilter('short_term')}
            />
            <FilterChip
              title="Medium Term"
              isSelected={filter === 'medium_term'}
              action={() => setFilter('medium_term')}
            />
            <FilterChip
              title="Long Term"
              isSelected={filter === 'long_term'}
              action={() => setFilter('long_term')}
            />
          </div>
        </div>

        {/* All Goals */}
        <div className="space-y-3">
          <h3 className="text-lg font-bold text-white">All Goals</h3>
          {filteredGoals.length === 0 ? (
            <p className="text-sm text-gray-400">No goals found for this filter.</p>
          ) : (
            filteredGoals.map((goal) => {
              const key = `${goal.goal_category}:${goal.goal_name}`
              const isSelected = selectedGoalKeys.has(key)
              return (
                <GoalCatalogCard
                  key={key}
                  goal={goal}
                  isSelected={isSelected}
                  onToggle={() => toggleGoal(goal)}
                />
              )
            })
          )}
        </div>
      </div>

      {/* Navigation Buttons */}
      <div className="flex gap-3 pt-4 border-t border-white/10">
        <button
          onClick={onBack}
          className="flex-1 px-4 py-3 rounded-lg bg-white/5 border border-white/10 hover:bg-white/10 transition-colors text-white"
        >
          Back
        </button>
        <button
          onClick={onNext}
          disabled={selectedGoals.length === 0}
          className={`flex-1 px-4 py-3 rounded-lg font-medium transition-colors ${
            selectedGoals.length === 0
              ? 'bg-[#D4AF37]/50 text-black/50 cursor-not-allowed'
              : 'bg-[#D4AF37] text-black hover:bg-[#D4AF37]/90'
          }`}
        >
          Next
        </button>
      </div>
    </div>
  )
}

// Goal Catalog Card Component
interface GoalCatalogCardProps {
  goal: GoalCatalogItem
  isSelected: boolean
  onToggle: () => void
}

function GoalCatalogCard({ goal, isSelected, onToggle }: GoalCatalogCardProps) {
  const horizonDisplayName = (horizon: string) => {
    switch (horizon) {
      case 'short_term':
        return 'Short Term'
      case 'medium_term':
        return 'Medium Term'
      case 'long_term':
        return 'Long Term'
      default:
        return horizon
    }
  }

  return (
    <button
      onClick={onToggle}
      className={`w-full text-left p-4 rounded-xl transition-all ${
        isSelected
          ? 'bg-white/20 border-2 border-[#D4AF37]'
          : 'bg-white/10 border-2 border-transparent hover:bg-white/15'
      }`}
    >
      <div className="flex items-center gap-4">
        {/* Checkbox */}
        <div
          className={`w-6 h-6 rounded-full flex items-center justify-center border-2 ${
            isSelected
              ? 'bg-[#D4AF37] border-[#D4AF37]'
              : 'border-gray-400 bg-transparent'
          }`}
        >
          {isSelected && (
            <svg className="w-4 h-4 text-black" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={3} d="M5 13l4 4L19 7" />
            </svg>
          )}
        </div>

        {/* Goal Info */}
        <div className="flex-1 min-w-0">
          <h4 className="text-base font-semibold text-white mb-1">{goal.goal_name}</h4>
          <div className="flex items-center gap-2 text-sm text-gray-400">
            <span>{goal.goal_category}</span>
            <span>•</span>
            <span>{horizonDisplayName(goal.default_horizon)}</span>
          </div>
        </div>
      </div>
    </button>
  )
}
