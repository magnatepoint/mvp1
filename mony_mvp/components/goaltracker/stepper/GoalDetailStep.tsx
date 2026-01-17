'use client'

import { useState, useEffect } from 'react'
import type { GoalCatalogItem, SelectedGoal } from '@/types/goals'
import { glassFilter } from '@/lib/theme/glass'

interface GoalDetailStepProps {
  catalog: GoalCatalogItem[]
  selectedGoals: SelectedGoal[]
  currentGoalIndex: number
  onUpdateGoal: (index: number, goal: SelectedGoal) => void
  onNextGoal: () => void
  onPreviousGoal: () => void
  onNext: () => void
  onBack: () => void
}

export default function GoalDetailStep({
  catalog,
  selectedGoals,
  currentGoalIndex,
  onUpdateGoal,
  onNextGoal,
  onPreviousGoal,
  onNext,
  onBack,
}: GoalDetailStepProps) {
  const currentGoal = selectedGoals[currentGoalIndex]
  const catalogItem = catalog.find(
    (item) =>
      item.goal_category === currentGoal.goal_category &&
      item.goal_name === currentGoal.goal_name
  )

  const [formData, setFormData] = useState({
    estimated_cost: currentGoal.estimated_cost > 0 ? currentGoal.estimated_cost.toString() : '',
    target_date: currentGoal.target_date || '',
    has_target_date: !!currentGoal.target_date,
    current_savings: currentGoal.current_savings > 0 ? currentGoal.current_savings.toString() : '0',
    importance: currentGoal.importance,
    notes: currentGoal.notes || '',
  })

  const [errors, setErrors] = useState<Record<string, string>>({})

  useEffect(() => {
    // Update form when goal changes
    const goal = selectedGoals[currentGoalIndex]
    if (goal) {
      setFormData({
        estimated_cost: goal.estimated_cost > 0 ? goal.estimated_cost.toString() : '',
        target_date: goal.target_date || '',
        has_target_date: !!goal.target_date,
        current_savings: goal.current_savings > 0 ? goal.current_savings.toString() : '0',
        importance: goal.importance,
        notes: goal.notes || '',
      })
      setErrors({})
    }
  }, [currentGoalIndex, selectedGoals])

  const defaultTargetDate = () => {
    const date = new Date()
    if (catalogItem) {
      switch (catalogItem.default_horizon) {
        case 'short_term':
          date.setFullYear(date.getFullYear() + 1)
          break
        case 'medium_term':
          date.setFullYear(date.getFullYear() + 3)
          break
        case 'long_term':
          date.setFullYear(date.getFullYear() + 7)
          break
      }
    }
    return date.toISOString().split('T')[0]
  }

  const validate = (): boolean => {
    const newErrors: Record<string, string> = {}

    const cost = parseFloat(formData.estimated_cost)
    if (!formData.estimated_cost || isNaN(cost) || cost <= 0) {
      newErrors.estimated_cost = 'Estimated cost must be greater than 0'
    }

    if (formData.importance < 1 || formData.importance > 5) {
      newErrors.importance = 'Importance must be between 1 and 5'
    }

    setErrors(newErrors)
    return Object.keys(newErrors).length === 0
  }

  const saveCurrentGoal = () => {
    if (!validate()) return false

    const cost = parseFloat(formData.estimated_cost)
    const savings = parseFloat(formData.current_savings) || 0

    const updatedGoal: SelectedGoal = {
      goal_category: currentGoal.goal_category,
      goal_name: currentGoal.goal_name,
      estimated_cost: cost,
      target_date: formData.has_target_date ? formData.target_date : null,
      current_savings: savings,
      importance: formData.importance,
      notes: formData.notes || null,
    }

    onUpdateGoal(currentGoalIndex, updatedGoal)
    return true
  }

  const handleNext = () => {
    if (saveCurrentGoal()) {
      if (currentGoalIndex < selectedGoals.length - 1) {
        onNextGoal()
      } else {
        onNext()
      }
    }
  }

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-bold text-white mb-2">Goal Details</h2>
        <p className="text-sm text-gray-400">
          {currentGoal.goal_name} ({currentGoalIndex + 1} of {selectedGoals.length})
        </p>
        <p className="text-sm text-gray-400 mt-1">
          Set targets and priorities for your goal.
        </p>
      </div>

      <div className="space-y-4 max-h-[60vh] overflow-y-auto pr-2">
        {/* Estimated Cost */}
        <div>
          <label className="block text-sm font-medium text-white mb-2">
            Estimated Cost (₹) *
          </label>
          <input
            type="number"
            min="0"
            step="1000"
            value={formData.estimated_cost}
            onChange={(e) => setFormData({ ...formData, estimated_cost: e.target.value })}
            className={`w-full ${glassFilter} px-4 py-3 rounded-lg text-white`}
            placeholder="Enter target amount"
          />
          {errors.estimated_cost && (
            <p className="text-red-400 text-xs mt-1">{errors.estimated_cost}</p>
          )}
        </div>

        {/* Target Date */}
        <div className={`${glassFilter} p-4 rounded-lg space-y-3`}>
          <label className="flex items-center gap-2">
            <input
              type="checkbox"
              checked={formData.has_target_date}
              onChange={(e) => {
                setFormData({
                  ...formData,
                  has_target_date: e.target.checked,
                  target_date: e.target.checked ? formData.target_date || defaultTargetDate() : '',
                })
              }}
              className="w-4 h-4 rounded"
            />
            <span className="text-sm text-white">Set Target Date</span>
          </label>
          {formData.has_target_date && (
            <input
              type="date"
              value={formData.target_date}
              onChange={(e) => setFormData({ ...formData, target_date: e.target.value })}
              min={new Date().toISOString().split('T')[0]}
              className={`w-full ${glassFilter} px-4 py-2 rounded-lg text-white`}
            />
          )}
        </div>

        {/* Current Savings */}
        <div>
          <label className="block text-sm font-medium text-white mb-2">
            Current Savings (₹)
          </label>
          <input
            type="number"
            min="0"
            step="1000"
            value={formData.current_savings}
            onChange={(e) => setFormData({ ...formData, current_savings: e.target.value })}
            className={`w-full ${glassFilter} px-4 py-3 rounded-lg text-white`}
            placeholder="Enter current savings"
          />
        </div>

        {/* Importance */}
        <div className={`${glassFilter} p-4 rounded-lg space-y-3`}>
          <div className="flex items-center justify-between">
            <label className="text-sm font-medium text-gray-300">Importance</label>
            <span className="text-lg font-bold text-[#D4AF37]">{formData.importance}</span>
          </div>
          <input
            type="range"
            min="1"
            max="5"
            step="1"
            value={formData.importance}
            onChange={(e) => setFormData({ ...formData, importance: parseInt(e.target.value) })}
            className="w-full"
          />
          <div className="flex items-center justify-between text-xs text-gray-400">
            <span>Low</span>
            <span>High</span>
          </div>
        </div>

        {/* Notes */}
        <div>
          <label className="block text-sm font-medium text-white mb-2">
            Notes (Optional)
          </label>
          <textarea
            value={formData.notes}
            onChange={(e) => setFormData({ ...formData, notes: e.target.value })}
            rows={3}
            className={`w-full ${glassFilter} px-4 py-3 rounded-lg text-white resize-none`}
            placeholder="Add any notes about this goal"
          />
        </div>
      </div>

      {/* Navigation Buttons */}
      <div className="flex gap-3 pt-4 border-t border-white/10">
        {currentGoalIndex > 0 ? (
          <button
            onClick={() => {
              saveCurrentGoal()
              onPreviousGoal()
            }}
            className="flex-1 px-4 py-3 rounded-lg bg-white/5 border border-white/10 hover:bg-white/10 transition-colors text-white"
          >
            Previous
          </button>
        ) : (
          <button
            onClick={onBack}
            className="flex-1 px-4 py-3 rounded-lg bg-white/5 border border-white/10 hover:bg-white/10 transition-colors text-white"
          >
            Back
          </button>
        )}
        <button
          onClick={handleNext}
          className="flex-1 px-4 py-3 rounded-lg bg-[#D4AF37] text-black font-medium hover:bg-[#D4AF37]/90 transition-colors"
        >
          {currentGoalIndex < selectedGoals.length - 1 ? 'Next Goal' : 'Review'}
        </button>
      </div>
    </div>
  )
}
