import { useState, useEffect } from 'react'
import type { Session } from '@supabase/supabase-js'
import { Target, Edit2, Trash2, TrendingUp, Calendar } from 'lucide-react'
import { fetchGoals, deleteGoal } from '../../api/goals'
import type { GoalResponse } from '../../types/goals'
import { SkeletonLoader } from '../../components/SkeletonLoader'
import { useToast } from '../../components/Toast'
import './GoalsList.css'

type Props = {
  session: Session
  onEdit?: (goal: GoalResponse) => void
}

export function GoalsList({ session, onEdit }: Props) {
  const { showToast } = useToast()
  const [goals, setGoals] = useState<GoalResponse[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [deletingId, setDeletingId] = useState<string | null>(null)

  useEffect(() => {
    const loadGoals = async () => {
      setLoading(true)
      setError(null)
      try {
        const data = await fetchGoals(session)
        console.log('Goals data received:', data)
        setGoals(data)
      } catch (err) {
        console.error('Error fetching goals:', err)
        let errorMessage = 'Failed to load goals'
        
        if (err instanceof Error) {
          errorMessage = err.message
        } else if (typeof err === 'string') {
          errorMessage = err
        } else if (err && typeof err === 'object') {
          const errObj = err as any
          if (errObj.message) {
            errorMessage = String(errObj.message)
          } else if (errObj.detail) {
            errorMessage = String(errObj.detail)
          }
        }
        
        setError(errorMessage)
      } finally {
        setLoading(false)
      }
    }

    void loadGoals()
  }, [session])

  const handleDelete = async (goalId: string) => {
    if (!confirm('Are you sure you want to delete this goal?')) return

    setDeletingId(goalId)
    try {
      await deleteGoal(session, goalId)
      setGoals(goals.filter((g) => g.goal_id !== goalId))
      showToast('Goal deleted successfully', 'success')
    } catch (err) {
      showToast(err instanceof Error ? err.message : 'Failed to delete goal', 'error')
    } finally {
      setDeletingId(null)
    }
  }

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
      month: 'short',
      day: 'numeric',
    })
  }

  const getProgress = (goal: GoalResponse) => {
    if (goal.estimated_cost === 0) return 0
    return Math.min((goal.current_savings / goal.estimated_cost) * 100, 100)
  }

  if (loading) {
    return (
      <div className="goals-list-loading">
        {Array.from({ length: 3 }).map((_, i) => (
          <SkeletonLoader key={i} height={120} width="100%" style={{ marginBottom: '1rem' }} />
        ))}
      </div>
    )
  }

  if (error) {
    return (
      <div className="glass-card error-banner">
        <p className="error-message">{error}</p>
      </div>
    )
  }

  if (goals.length === 0) {
    return (
      <div className="glass-card goals-empty-state">
        <Target size={64} />
        <h2>No Goals Yet</h2>
        <p className="text-muted">
          Create your first financial goal to get started with Goal Compass.
        </p>
      </div>
    )
  }

  return (
    <div className="goals-list">
      <div className="goals-list-header">
        <h2>Your Goals ({goals.length})</h2>
      </div>
      <div className="goals-list-grid">
        {goals.map((goal) => {
          const progress = getProgress(goal)
          const isCompleted = progress >= 100

          return (
            <div
              key={goal.goal_id}
              className={`glass-card goal-card ${isCompleted ? 'goal-card--completed' : ''}`}
            >
              <div className="goal-card__header">
                <div className="goal-card__title-section">
                  <Target size={20} className="goal-card__icon" />
                  <div>
                    <h3>{goal.goal_name}</h3>
                    <p className="goal-card__category">{goal.goal_category}</p>
                  </div>
                </div>
                <div className="goal-card__actions">
                  {onEdit && (
                    <button
                      className="goal-action-button"
                      onClick={() => onEdit(goal)}
                      aria-label="Edit goal"
                    >
                      <Edit2 size={16} />
                    </button>
                  )}
                  <button
                    className="goal-action-button goal-action-button--danger"
                    onClick={() => handleDelete(goal.goal_id)}
                    disabled={deletingId === goal.goal_id}
                    aria-label="Delete goal"
                  >
                    <Trash2 size={16} />
                  </button>
                </div>
              </div>

              <div className="goal-card__progress">
                <div className="progress-bar">
                  <div className="progress-fill" style={{ width: `${progress}%` }} />
                </div>
                <span className="progress-text">{progress.toFixed(1)}%</span>
              </div>

              <div className="goal-card__details">
                <div className="goal-detail-row">
                  <span className="goal-detail-label">
                    <TrendingUp size={14} />
                    Current Savings
                  </span>
                  <strong>{formatCurrency(goal.current_savings)}</strong>
                </div>
                <div className="goal-detail-row">
                  <span className="goal-detail-label">Target Amount</span>
                  <strong>{formatCurrency(goal.estimated_cost)}</strong>
                </div>
                <div className="goal-detail-row">
                  <span className="goal-detail-label">
                    <Calendar size={14} />
                    Target Date
                  </span>
                  <strong>{formatDate(goal.target_date)}</strong>
                </div>
                {goal.priority_rank && (
                  <div className="goal-detail-row">
                    <span className="goal-detail-label">Priority</span>
                    <strong>#{goal.priority_rank}</strong>
                  </div>
                )}
                {goal.importance && (
                  <div className="goal-detail-row">
                    <span className="goal-detail-label">Importance</span>
                    <strong>{goal.importance}/5</strong>
                  </div>
                )}
              </div>

              {goal.notes && (
                <div className="goal-card__notes">
                  <p className="text-muted">{goal.notes}</p>
                </div>
              )}
            </div>
          )
        })}
      </div>
    </div>
  )
}

