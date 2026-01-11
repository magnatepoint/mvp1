import { useState, useEffect } from 'react'
import type { GoalDetailRequest, GoalCatalogItem } from '../../../types/goals'

type Props = {
  goal: GoalDetailRequest
  catalogItem: GoalCatalogItem | undefined
  currentIndex: number
  totalGoals: number
  onSubmit: (goal: GoalDetailRequest) => void
  onBack: () => void
}

export function GoalDetailStep({
  goal,
  catalogItem,
  currentIndex,
  totalGoals,
  onSubmit,
  onBack,
}: Props) {
  const [formData, setFormData] = useState<GoalDetailRequest>(goal)
  const [errors, setErrors] = useState<Record<string, string>>({})

  useEffect(() => {
    setFormData(goal)
  }, [goal])

  const validate = (): boolean => {
    const newErrors: Record<string, string> = {}

    if (!formData.estimated_cost || formData.estimated_cost <= 0) {
      newErrors.estimated_cost = 'Estimated cost must be greater than 0'
    }
    if (!formData.importance || formData.importance < 1 || formData.importance > 5) {
      newErrors.importance = 'Importance must be between 1 and 5'
    }

    setErrors(newErrors)
    return Object.keys(newErrors).length === 0
  }

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    if (validate()) {
      onSubmit(formData)
    }
  }

  const getDefaultTargetDate = (): string => {
    if (formData.target_date) return formData.target_date

    const today = new Date()
    if (catalogItem?.default_horizon === 'short_term') {
      today.setFullYear(today.getFullYear() + 1)
    } else if (catalogItem?.default_horizon === 'medium_term') {
      today.setFullYear(today.getFullYear() + 3)
    } else if (catalogItem?.default_horizon === 'long_term') {
      today.setFullYear(today.getFullYear() + 7)
    } else {
      today.setFullYear(today.getFullYear() + 3)
    }
    return today.toISOString().split('T')[0]
  }

  return (
    <form onSubmit={handleSubmit} className="goal-detail-form">
      <div className="goal-detail-header">
        <h2>
          {goal.goal_name} ({currentIndex + 1} of {totalGoals})
        </h2>
        <p className="text-muted">{goal.goal_category}</p>
      </div>

      <div className="form-group">
        <label htmlFor="estimated_cost">
          Estimated Cost (₹) *
          {catalogItem?.suggested_min_amount_formula && (
            <span className="text-muted"> - {catalogItem.suggested_min_amount_formula}</span>
          )}
        </label>
        <input
          id="estimated_cost"
          type="number"
          min="0"
          step="1000"
          className="input-field"
          value={formData.estimated_cost || ''}
          onChange={(e) =>
            setFormData({ ...formData, estimated_cost: parseFloat(e.target.value) || 0 })
          }
          required
        />
        {errors.estimated_cost && <div className="error-message">{errors.estimated_cost}</div>}
      </div>

      <div className="form-group">
        <label htmlFor="target_date">Target Date</label>
        <input
          id="target_date"
          type="date"
          className="input-field"
          value={formData.target_date || getDefaultTargetDate()}
          onChange={(e) => setFormData({ ...formData, target_date: e.target.value || null })}
          min={new Date().toISOString().split('T')[0]}
        />
        <small className="text-muted">
          Leave empty to use default based on goal horizon
        </small>
      </div>

      <div className="form-group">
        <label htmlFor="current_savings">Current Savings (₹)</label>
        <input
          id="current_savings"
          type="number"
          min="0"
          step="1000"
          className="input-field"
          value={formData.current_savings || ''}
          onChange={(e) =>
            setFormData({ ...formData, current_savings: parseFloat(e.target.value) || 0 })
          }
        />
      </div>

      <div className="form-group">
        <label htmlFor="importance">
          Importance (1-5) * - {formData.importance || 3}
        </label>
        <input
          id="importance"
          type="range"
          min="1"
          max="5"
          className="input-range"
          value={formData.importance || 3}
          onChange={(e) =>
            setFormData({ ...formData, importance: parseInt(e.target.value) })
          }
        />
        <div className="importance-labels">
          <span>Low</span>
          <span>High</span>
        </div>
        {errors.importance && <div className="error-message">{errors.importance}</div>}
      </div>

      <div className="form-group">
        <label htmlFor="notes">Notes (Optional)</label>
        <textarea
          id="notes"
          className="input-field"
          rows={3}
          value={formData.notes || ''}
          onChange={(e) => setFormData({ ...formData, notes: e.target.value || null })}
          placeholder="Add any additional notes about this goal..."
        />
      </div>

      <div className="form-group">
        <label className="checkbox-label">
          <input
            type="checkbox"
            checked={formData.is_must_have}
            onChange={(e) => setFormData({ ...formData, is_must_have: e.target.checked })}
          />
          <span>This is a must-have goal (non-negotiable)</span>
        </label>
      </div>

      <div className="form-group">
        <label htmlFor="timeline_flexibility">Timeline Flexibility</label>
        <select
          id="timeline_flexibility"
          className="input-field"
          value={formData.timeline_flexibility ?? 'somewhat_flexible'}
          onChange={(e) =>
            setFormData({
              ...formData,
              timeline_flexibility: e.target.value as GoalDetailRequest['timeline_flexibility'],
            })
          }
        >
          <option value="rigid">Rigid (must meet deadline)</option>
          <option value="somewhat_flexible">Somewhat Flexible</option>
          <option value="flexible">Flexible (can adjust timeline)</option>
        </select>
      </div>

      <div className="form-group">
        <label htmlFor="risk_profile_for_goal">Risk Profile for This Goal</label>
        <select
          id="risk_profile_for_goal"
          className="input-field"
          value={formData.risk_profile_for_goal ?? ''}
          onChange={(e) =>
            setFormData({
              ...formData,
              risk_profile_for_goal: e.target.value
                ? (e.target.value as GoalDetailRequest['risk_profile_for_goal'])
                : null,
            })
          }
        >
          <option value="">Use overall profile</option>
          <option value="conservative">Conservative</option>
          <option value="balanced">Balanced</option>
          <option value="aggressive">Aggressive</option>
        </select>
      </div>

      <div className="form-actions">
        <button type="button" className="ghost-button" onClick={onBack}>
          {currentIndex > 0 ? 'Previous' : 'Back'}
        </button>
        <button type="submit" className="primary-button">
          {currentIndex < totalGoals - 1 ? 'Next Goal' : 'Review'}
        </button>
      </div>
    </form>
  )
}

