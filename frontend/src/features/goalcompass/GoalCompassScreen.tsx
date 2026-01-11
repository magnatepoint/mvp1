import { useState, useEffect } from 'react'
import type { Session } from '@supabase/supabase-js'
import { Target, TrendingUp, Calendar, Edit2, Trash2, CheckCircle2, Sparkles } from 'lucide-react'
import { ResponsiveContainer, PieChart, Pie, Cell, LineChart, Line, XAxis, YAxis, Tooltip } from 'recharts'
import { SkeletonLoader } from '../../components/SkeletonLoader'
import { GoalDetailModal } from '../../components/GoalDetailModal'
import { fetchGoalsProgress, fetchGoals } from '../../api/goals'
import type { GoalProgressItem, GoalResponse } from '../../types/goals'
import './GoalCompassScreen.css'

type Props = {
  session: Session
}

export function GoalCompassScreen({ session }: Props) {
  const [goals, setGoals] = useState<GoalProgressItem[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [selectedGoal, setSelectedGoal] = useState<GoalProgressItem | null>(null)
  const [isModalOpen, setIsModalOpen] = useState(false)
  const [goalDetails, setGoalDetails] = useState<{ estimated_cost?: number; target_date?: string | null } | null>(null)

  useEffect(() => {
    const fetchProgress = async () => {
      setLoading(true)
      setError(null)
      try {
        const data = await fetchGoalsProgress(session)
        console.log('Goals progress data received:', data)
        setGoals(data.goals || [])
      } catch (err) {
        console.error('Error fetching goals progress:', err)
        let errorMessage = 'Failed to load progress'
        
        if (err instanceof Error) {
          errorMessage = err.message
        } else if (typeof err === 'string') {
          errorMessage = err
        } else if (err && typeof err === 'object') {
          // Handle error objects
          const errObj = err as any
          if (errObj.message) {
            errorMessage = String(errObj.message)
          } else if (errObj.detail) {
            errorMessage = String(errObj.detail)
          } else {
            errorMessage = 'An unexpected error occurred'
          }
        }
        
        setError(errorMessage)
        setGoals([])
      } finally {
        setLoading(false)
      }
    }

    void fetchProgress()
  }, [session])

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
        <div className="goalcompass-loading">
          <SkeletonLoader height={300} width="100%" style={{ marginBottom: '1.5rem' }} />
          <div className="goals-progress-grid">
            {Array.from({ length: 3 }).map((_, i) => (
              <SkeletonLoader key={i} height={250} width="100%" />
            ))}
          </div>
        </div>
      </section>
    )
  }

  return (
    <section className="goalcompass-screen">
      <header className="glass-card goalcompass-screen__hero">
        <div>
          <p className="eyebrow">GoalCompass</p>
          <h1>Goal Progress Tracking</h1>
          <p className="text-muted">
            Monitor your financial goals, track milestones, and see projected completion dates.
          </p>
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
        <div className="glass-card goalcompass-empty-state">
          <div className="goalcompass-empty-state__icon">
            <Target size={64} />
          </div>
          <h2>No Goals Yet</h2>
          <p className="text-muted" style={{ marginBottom: '2rem', maxWidth: '500px', margin: '0 auto 2rem' }}>
            Set up your financial goals first to start tracking progress. We'll help you visualize your journey and celebrate milestones along the way.
          </p>
          <button
            className="primary-button"
            onClick={() => {
              // Navigate to Goals screen - this would need to be handled by parent
              window.location.hash = '#goals'
            }}
          >
            Create Your First Goal
          </button>
        </div>
      )}

      {!error && goals.length > 0 && (
        <>
          {/* SVG Gradient Definition */}
          <svg width="0" height="0" style={{ position: 'absolute' }}>
            <defs>
              <linearGradient id="goalProgressGradient" x1="0%" y1="0%" x2="100%" y2="100%">
                <stop offset="0%" stopColor="var(--color-gold)" />
                <stop offset="100%" stopColor="var(--color-teal)" />
              </linearGradient>
            </defs>
          </svg>

          {/* Overview Summary */}
          <div className="goalcompass-overview">
            <div className="goalcompass-overview-card">
              <Target size={24} />
              <div>
                <div className="goalcompass-overview-label">Active Goals</div>
                <div className="goalcompass-overview-value">{goals.length}</div>
              </div>
            </div>
            <div className="goalcompass-overview-card">
              <TrendingUp size={24} />
              <div>
                <div className="goalcompass-overview-label">Total Progress</div>
                <div className="goalcompass-overview-value">
                  {goals.length > 0
                    ? (goals.reduce((sum, g) => sum + g.progress_pct, 0) / goals.length).toFixed(1)
                    : 0}%
                </div>
              </div>
            </div>
            <div className="goalcompass-overview-card">
              <Calendar size={24} />
              <div>
                <div className="goalcompass-overview-label">Avg. Completion</div>
                <div className="goalcompass-overview-value">
                  {goals.filter((g) => g.projected_completion_date).length > 0
                    ? formatDate(
                        goals
                          .filter((g) => g.projected_completion_date)
                          .sort(
                            (a, b) =>
                              new Date(a.projected_completion_date!).getTime() -
                              new Date(b.projected_completion_date!).getTime()
                          )[0]?.projected_completion_date || null
                      )
                    : '—'}
                </div>
              </div>
            </div>
          </div>

          {/* Goals Grid */}
          <div className="goals-progress-grid">
            {goals.map((goal) => {
              const progress = Math.min(goal.progress_pct, 100)
              const isCompleted = progress >= 100
              const circumference = 2 * Math.PI * 45
              const offset = circumference - (progress / 100) * circumference

              return (
                <div
                  key={goal.goal_id}
                  className={`glass-card goal-progress-card ${isCompleted ? 'goal-progress-card--completed' : ''} goal-progress-card--clickable`}
                  onClick={async () => {
                    setSelectedGoal(goal)
                    setIsModalOpen(true)
                    
                    // Fetch full goal details if available
                    try {
                      const allGoals = await fetchGoals(session)
                      const fullGoal = allGoals.find((g: GoalResponse) => g.goal_id === goal.goal_id)
                        if (fullGoal) {
                          setGoalDetails({
                            estimated_cost: fullGoal.estimated_cost,
                            target_date: fullGoal.target_date,
                          })
                      }
                    } catch (err) {
                      // Silently fail - we'll use calculated values
                      console.error('Failed to fetch goal details:', err)
                    }
                  }}
                  role="button"
                  tabIndex={0}
                  onKeyDown={(e) => {
                    if (e.key === 'Enter' || e.key === ' ') {
                      setSelectedGoal(goal)
                      setIsModalOpen(true)
                    }
                  }}
                >
                  <div className="goal-progress-header">
                    <div className="goal-progress-title-section">
                      <Target size={20} className="goal-progress-icon" />
                      <h3>{goal.goal_name}</h3>
                    </div>
                    <div className="goal-progress-actions">
                      <button className="goal-action-button" aria-label="Edit goal">
                        <Edit2 size={16} />
                      </button>
                      <button className="goal-action-button goal-action-button--danger" aria-label="Delete goal">
                        <Trash2 size={16} />
                      </button>
                    </div>
                  </div>

                  {/* Circular Progress */}
                  <div className="goal-progress-circular">
                    <svg className="goal-progress-circle" viewBox="0 0 100 100">
                      <circle
                        className="goal-progress-circle-bg"
                        cx="50"
                        cy="50"
                        r="45"
                        fill="none"
                        strokeWidth="8"
                      />
                      <circle
                        className="goal-progress-circle-fill"
                        cx="50"
                        cy="50"
                        r="45"
                        fill="none"
                        strokeWidth="8"
                        strokeDasharray={circumference}
                        strokeDashoffset={offset}
                        transform="rotate(-90 50 50)"
                      />
                      {isCompleted && (
                        <circle
                          className="goal-progress-circle-complete"
                          cx="50"
                          cy="50"
                          r="45"
                          fill="none"
                          strokeWidth="8"
                          strokeDasharray={circumference}
                          strokeDashoffset={0}
                          transform="rotate(-90 50 50)"
                        />
                      )}
                    </svg>
                    <div className="goal-progress-circular-content">
                      <div className="progress-percentage-large">{progress.toFixed(1)}%</div>
                      {isCompleted && (
                        <div className="goal-completed-badge">
                          <CheckCircle2 size={16} />
                          <span>Completed!</span>
                        </div>
                      )}
                    </div>
                  </div>

                  {/* Progress Bar (Alternative view) */}
                  <div className="progress-bar-large">
                    <div
                      className="progress-fill-large"
                      style={{ width: `${progress}%` }}
                    />
                  </div>

                  <div className="goal-progress-details">
                    <div className="progress-row">
                      <span className="progress-label">
                        <TrendingUp size={14} />
                        Current Savings
                      </span>
                      <strong className="progress-value--positive">
                        {formatCurrency(goal.current_savings_close)}
                      </strong>
                    </div>
                    <div className="progress-row">
                      <span className="progress-label">Remaining</span>
                      <strong className="progress-value">
                        {formatCurrency(goal.remaining_amount)}
                      </strong>
                    </div>
                    <div className="progress-row">
                      <span className="progress-label">
                        <Calendar size={14} />
                        Projected Completion
                      </span>
                      <strong className="progress-value">
                        {formatDate(goal.projected_completion_date)}
                      </strong>
                    </div>
                  </div>

                  {goal.milestones && goal.milestones.length > 0 && (
                    <div className="milestones-section">
                      <p className="milestones-label">
                        <Sparkles size={14} />
                        Milestones Achieved
                      </p>
                      <div className="milestones-badges">
                        {goal.milestones.map((milestone) => (
                          <span key={milestone} className="milestone-badge milestone-badge--achieved">
                            {milestone}%
                          </span>
                        ))}
                        {[25, 50, 75, 100]
                          .filter((m) => !goal.milestones.includes(m))
                          .map((milestone) => (
                            <span key={milestone} className="milestone-badge milestone-badge--pending">
                              {milestone}%
                            </span>
                          ))}
                      </div>
                    </div>
                  )}
                </div>
              )
            })}
          </div>
        </>
      )}

      {/* Goal Detail Modal */}
      <GoalDetailModal
        goal={selectedGoal ? {
          goal_id: selectedGoal.goal_id,
          goal_name: selectedGoal.goal_name,
          progress_pct: selectedGoal.progress_pct,
          current_savings_close: selectedGoal.current_savings_close,
          remaining_amount: selectedGoal.remaining_amount,
          projected_completion_date: selectedGoal.projected_completion_date,
          milestones: selectedGoal.milestones,
          estimated_cost: goalDetails?.estimated_cost,
          target_date: goalDetails?.target_date || null,
        } : null}
        isOpen={isModalOpen}
        onClose={() => {
          setIsModalOpen(false)
          setSelectedGoal(null)
          setGoalDetails(null)
        }}
        loading={false}
      />
    </section>
  )
}

