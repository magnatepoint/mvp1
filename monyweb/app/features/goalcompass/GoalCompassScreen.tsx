'use client'

import { useState, useEffect } from 'react'
import type { Session } from '@supabase/supabase-js'
import { env } from '../../env'
import { GoalsStepper } from '../goals/GoalsStepper'
import './GoalCompassScreen.css'

type Props = {
  session: Session
}

type GoalProgress = {
  goal_id: string
  goal_name: string
  progress_pct: number
  current_savings_close: number
  remaining_amount: number
  projected_completion_date: string | null
  milestones: number[]
}

export function GoalCompassScreen({ session }: Props) {
  const [goals, setGoals] = useState<GoalProgress[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [showQuestionnaire, setShowQuestionnaire] = useState(false)
  const [hasGoals, setHasGoals] = useState(false)

  // Check if user has goals on mount
  useEffect(() => {
    const checkUserGoals = async () => {
      setLoading(true)
      setError(null)
      try {
        // Check if user has goals
        const goalsRes = await fetch(`${env.apiBaseUrl}/v1/goals`, {
          headers: {
            Authorization: `Bearer ${session.access_token}`,
          },
        }).catch(() => null) // Silently catch network errors

        if (goalsRes && goalsRes.ok) {
          const userGoals = await goalsRes.json()
          if (userGoals && userGoals.length > 0) {
            setHasGoals(true)
            // Load progress
            await loadProgress()
          } else {
            // No goals - show questionnaire
            setHasGoals(false)
            setShowQuestionnaire(true)
          }
        } else {
          // Any error (404, 500, network, etc.) - show questionnaire as fallback
          // This is the expected behavior for new users or when backend has issues
          setHasGoals(false)
          setShowQuestionnaire(true)
        }
      } catch (err) {
        // On any error, show questionnaire as fallback (expected for new users)
        setHasGoals(false)
        setShowQuestionnaire(true)
      } finally {
        setLoading(false)
      }
    }

    void checkUserGoals()
  }, [session])

  const loadProgress = async () => {
    try {
      const response = await fetch(`${env.apiBaseUrl}/v1/goals/progress`, {
        headers: {
          Authorization: `Bearer ${session.access_token}`,
        },
      })

      if (!response.ok) {
        if (response.status === 404) {
          setGoals([])
          return
        }
        throw new Error('Failed to load goal progress')
      }

      const data = await response.json()
      setGoals(data.goals || [])
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load progress')
      setGoals([])
    }
  }

  const handleGoalsSubmitted = async () => {
    // After goals are submitted, reload progress
    setShowQuestionnaire(false)
    setHasGoals(true)
    await loadProgress()
  }

  const handleAddNewGoal = () => {
    setShowQuestionnaire(true)
  }

  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('en-IN', {
      style: 'currency',
      currency: 'INR',
      maximumFractionDigits: 0,
    }).format(amount)
  }

  const formatDate = (dateStr: string | null) => {
    if (!dateStr) return 'Calculating...'
    return new Date(dateStr).toLocaleDateString('en-IN', {
      year: 'numeric',
      month: 'long',
      day: 'numeric',
    })
  }

  if (loading) {
    return (
      <section className="goalcompass-screen">
        <header className="glass-card goalcompass-screen__hero">
          <div>
            <p className="eyebrow">GoalCompass</p>
            <h1>Goal Progress Tracking</h1>
            <p className="text-muted">Track your financial goals and milestones.</p>
          </div>
        </header>
        <div className="glass-card">
          <p className="status-loading">Loading...</p>
        </div>
      </section>
    )
  }

  // Show questionnaire if no goals or user clicked "Add New Goal"
  if (showQuestionnaire) {
    return (
      <section className="goalcompass-screen">
        <header className="glass-card goalcompass-screen__hero">
          <div>
            <p className="eyebrow">GoalCompass</p>
            <h1>Set Your Financial Goals</h1>
            <p className="text-muted">
              {hasGoals
                ? 'Add new goals to track your financial progress.'
                : "Tell us about yourself and your financial aspirations. We'll help you prioritize and track your progress."}
            </p>
            {hasGoals && (
              <button
                type="button"
                className="ghost-button"
                onClick={() => setShowQuestionnaire(false)}
                style={{ marginTop: '1rem' }}
              >
                ← Back to Progress
              </button>
            )}
          </div>
        </header>
        <GoalsStepper session={session} onComplete={handleGoalsSubmitted} />
      </section>
    )
  }

  // Show progress view
  return (
    <section className="goalcompass-screen">
      <header className="glass-card goalcompass-screen__hero">
        <div>
          <p className="eyebrow">GoalCompass</p>
          <h1>Goal Progress Tracking</h1>
          <p className="text-muted">
            Monitor your financial goals, track milestones, and see projected completion dates.
          </p>
          <button
            type="button"
            className="primary-button"
            onClick={handleAddNewGoal}
            style={{ marginTop: '1rem' }}
          >
            + Add New Goal
          </button>
        </div>
      </header>

      {error && (
        <div className="glass-card error-banner">
          <p className="error-message">{error}</p>
          <p className="text-muted">
            The GoalCompass tracking engine is being set up. Progress tracking will be available soon.
          </p>
        </div>
      )}

      {!error && goals.length === 0 && (
        <div className="glass-card empty-state">
          <h2>No Goals Yet</h2>
          <p className="text-muted">
            Set up your financial goals first to start tracking progress.
          </p>
          <button
            type="button"
            className="primary-button"
            onClick={handleAddNewGoal}
            style={{ marginTop: '1rem' }}
          >
            Set Up Goals
          </button>
        </div>
      )}

      {!error && goals.length > 0 && (
        <div className="goals-progress-grid">
          {goals.map((goal) => (
            <div key={goal.goal_id} className="glass-card goal-progress-card">
              <div className="goal-progress-header">
                <h3>{goal.goal_name}</h3>
                <div className="progress-percentage">{goal.progress_pct.toFixed(1)}%</div>
              </div>

              <div className="progress-bar-large">
                <div
                  className="progress-fill-large"
                  style={{ width: `${Math.min(goal.progress_pct, 100)}%` }}
                />
              </div>

              <div className="goal-progress-details">
                <div className="progress-row">
                  <span className="progress-label">Current Savings:</span>
                  <strong>{formatCurrency(goal.current_savings_close)}</strong>
                </div>
                <div className="progress-row">
                  <span className="progress-label">Remaining:</span>
                  <strong>{formatCurrency(goal.remaining_amount)}</strong>
                </div>
                <div className="progress-row">
                  <span className="progress-label">Projected Completion:</span>
                  <strong>{formatDate(goal.projected_completion_date)}</strong>
                </div>
              </div>

              {goal.milestones && goal.milestones.length > 0 && (
                <div className="milestones-section">
                  <p className="milestones-label">Milestones Achieved:</p>
                  <div className="milestones-badges">
                    {goal.milestones.map((milestone) => (
                      <span key={milestone} className="milestone-badge">
                        {milestone}%
                      </span>
                    ))}
                  </div>
                </div>
              )}
            </div>
          ))}
        </div>
      )}
    </section>
  )
}
