import { useState } from 'react'

type LifeContext = {
  age_band: string
  dependents_spouse: boolean
  dependents_children_count: number
  dependents_parents_care: boolean
  housing: string
  employment: string
  income_regularity: string
  region_code: string
  emergency_opt_out: boolean
}

type SelectedGoal = {
  goal_category: string
  goal_name: string
  estimated_cost: number
  target_date: string | null
  current_savings: number
  importance: number
  notes: string | null
}

type Props = {
  lifeContext: LifeContext | null
  selectedGoals: SelectedGoal[]
  onSubmit: () => void
  onBack: () => void
  submitting: boolean
}

export function ReviewStep({ lifeContext, selectedGoals, onSubmit, onBack, submitting }: Props) {
  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('en-IN', {
      style: 'currency',
      currency: 'INR',
      maximumFractionDigits: 0,
    }).format(amount)
  }

  const formatDate = (dateStr: string | null) => {
    if (!dateStr) return 'Not set'
    return new Date(dateStr).toLocaleDateString('en-IN', {
      year: 'numeric',
      month: 'long',
      day: 'numeric',
    })
  }

  const getProgress = (goal: SelectedGoal) => {
    if (goal.estimated_cost === 0) return 0
    return Math.min((goal.current_savings / goal.estimated_cost) * 100, 100)
  }

  return (
    <div className="review-step">
      <h2>Review Your Goals</h2>
      <p className="text-muted">Please review your information before submitting.</p>

      {lifeContext && (
        <div className="review-section glass-card">
          <h3>Life Context</h3>
          <div className="review-grid">
            <div>
              <span className="review-label">Age Range:</span>
              <span>{lifeContext.age_band}</span>
            </div>
            <div>
              <span className="review-label">Housing:</span>
              <span>{lifeContext.housing.replace('_', ' ')}</span>
            </div>
            <div>
              <span className="review-label">Employment:</span>
              <span>{lifeContext.employment.replace('_', ' ')}</span>
            </div>
            <div>
              <span className="review-label">Income Stability:</span>
              <span>{lifeContext.income_regularity.replace('_', ' ')}</span>
            </div>
            <div>
              <span className="review-label">Region:</span>
              <span>{lifeContext.region_code}</span>
            </div>
          </div>
        </div>
      )}

      <div className="review-section glass-card">
        <h3>Selected Goals ({selectedGoals.length})</h3>
        <div className="goals-review-list">
          {selectedGoals.map((goal, index) => (
            <div key={index} className="goal-review-item glass-card">
              <div className="goal-review-header">
                <h4>{goal.goal_name}</h4>
                <span className="goal-review-category">{goal.goal_category}</span>
              </div>
              <div className="goal-review-details">
                <div className="goal-review-row">
                  <span>Target Amount:</span>
                  <strong>{formatCurrency(goal.estimated_cost)}</strong>
                </div>
                <div className="goal-review-row">
                  <span>Current Savings:</span>
                  <strong>{formatCurrency(goal.current_savings)}</strong>
                </div>
                <div className="goal-review-row">
                  <span>Remaining:</span>
                  <strong>{formatCurrency(goal.estimated_cost - goal.current_savings)}</strong>
                </div>
                <div className="goal-review-row">
                  <span>Target Date:</span>
                  <strong>{formatDate(goal.target_date)}</strong>
                </div>
                <div className="goal-review-row">
                  <span>Importance:</span>
                  <strong>{goal.importance}/5</strong>
                </div>
                <div className="goal-review-progress">
                  <div className="progress-bar">
                    <div
                      className="progress-fill"
                      style={{ width: `${getProgress(goal)}%` }}
                    />
                  </div>
                  <span className="progress-text">{getProgress(goal).toFixed(1)}%</span>
                </div>
                {goal.notes && (
                  <div className="goal-review-notes">
                    <span className="review-label">Notes:</span>
                    <p>{goal.notes}</p>
                  </div>
                )}
              </div>
            </div>
          ))}
        </div>
      </div>

      <div className="form-actions">
        <button type="button" className="ghost-button" onClick={onBack} disabled={submitting}>
          Back
        </button>
        <button
          type="button"
          className="primary-button"
          onClick={onSubmit}
          disabled={submitting}
        >
          {submitting ? 'Submitting...' : 'Submit Goals'}
        </button>
      </div>
    </div>
  )
}

