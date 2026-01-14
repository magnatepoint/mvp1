import { X, Calendar, TrendingUp, Target, CheckCircle2, Clock } from 'lucide-react'
import { ResponsiveContainer, LineChart, Line, XAxis, YAxis, Tooltip, ReferenceLine } from 'recharts'
import { SkeletonLoader } from './SkeletonLoader'
import './GoalDetailModal.css'

type GoalDetail = {
  goal_id: string
  goal_name: string
  progress_pct: number
  current_savings_close: number
  remaining_amount: number
  projected_completion_date: string | null
  milestones: number[]
  estimated_cost?: number
  target_date?: string | null
}

type GoalDetailModalProps = {
  goal: GoalDetail | null
  isOpen: boolean
  onClose: () => void
  loading?: boolean
}

export function GoalDetailModal({ goal, isOpen, onClose, loading = false }: GoalDetailModalProps) {
  if (!isOpen) return null

  const currencyFormatter = new Intl.NumberFormat('en-IN', {
    style: 'currency',
    currency: 'INR',
    maximumFractionDigits: 0,
  })

  const formatDate = (dateStr: string | null) => {
    if (!dateStr) return 'Calculating...'
    return new Date(dateStr).toLocaleDateString('en-IN', {
      year: 'numeric',
      month: 'long',
      day: 'numeric',
    })
  }

  // Calculate monthly contribution needed
  const calculateMonthlyContribution = () => {
    if (!goal || !goal.projected_completion_date || goal.remaining_amount <= 0) return null

    const today = new Date()
    const completionDate = new Date(goal.projected_completion_date)
    const monthsRemaining = Math.max(
      1,
      Math.ceil(
        (completionDate.getTime() - today.getTime()) / (1000 * 60 * 60 * 24 * 30)
      )
    )

    return goal.remaining_amount / monthsRemaining
  }

  const monthlyContribution = calculateMonthlyContribution()

  // Generate timeline data for visualization
  const generateTimelineData = () => {
    if (!goal || !goal.projected_completion_date) return []

    const today = new Date()
    const completionDate = new Date(goal.projected_completion_date)
    const monthsRemaining = Math.max(
      1,
      Math.ceil(
        (completionDate.getTime() - today.getTime()) / (1000 * 60 * 60 * 24 * 30)
      )
    )

    const totalGoalAmount = goal.estimated_cost || goal.current_savings_close + goal.remaining_amount
    const data: { month: string; cumulative: number; target: number; milestone?: any }[] = []
    let cumulative = goal.current_savings_close
    const monthlyAmount = monthlyContribution || goal.remaining_amount / monthsRemaining

    for (let i = 0; i <= Math.min(monthsRemaining, 12); i++) {
      const date = new Date(today)
      date.setMonth(date.getMonth() + i)

      if (i > 0) {
        cumulative = Math.min(cumulative + monthlyAmount, totalGoalAmount)
      }

      data.push({
        month: date.toLocaleDateString('en-IN', { month: 'short', year: '2-digit' }),
        cumulative: Math.min(cumulative, totalGoalAmount),
        target: totalGoalAmount,
        milestone: [25, 50, 75, 100].find((m) => {
          const milestoneAmount = (totalGoalAmount * m) / 100
          return cumulative >= milestoneAmount && (i === 0 || (data[i - 1]?.cumulative || 0) < milestoneAmount)
        }),
      })
    }

    return data
  }

  const timelineData = generateTimelineData()

  // Calculate milestone dates
  const calculateMilestoneDates = () => {
    if (!goal || !monthlyContribution || !goal.projected_completion_date) return []

    const target = goal.estimated_cost || goal.current_savings_close + goal.remaining_amount
    const milestones = [25, 50, 75, 100]
    const today = new Date()

    return milestones.map((milestone) => {
      const milestoneAmount = (target * milestone) / 100
      const remainingToMilestone = Math.max(0, milestoneAmount - goal.current_savings_close)
      const monthsToMilestone = Math.ceil(remainingToMilestone / monthlyContribution)
      const milestoneDate = new Date(today)
      milestoneDate.setMonth(milestoneDate.getMonth() + monthsToMilestone)

      return {
        percentage: milestone,
        date: milestoneDate,
        amount: milestoneAmount,
        achieved: goal.milestones.includes(milestone),
      }
    })
  }

  const milestoneDates = calculateMilestoneDates()

  return (
    <div className="goal-detail-modal-overlay" onClick={onClose}>
      <div className="goal-detail-modal" onClick={(e) => e.stopPropagation()}>
        <div className="goal-detail-modal__header">
          <div>
            <h2>{goal?.goal_name || 'Goal Details'}</h2>
            <p className="goal-detail-modal__subtitle">Completion Plan & Timeline</p>
          </div>
          <button className="goal-detail-modal__close" onClick={onClose} aria-label="Close">
            <X size={24} />
          </button>
        </div>

        {loading ? (
          <div className="goal-detail-modal__content">
            <SkeletonLoader height={200} width="100%" style={{ marginBottom: '1.5rem' }} />
            <SkeletonLoader height={300} width="100%" />
          </div>
        ) : goal ? (
          <div className="goal-detail-modal__content">
            {/* Progress Overview */}
            <div className="goal-detail-overview">
              <div className="goal-detail-overview-card">
                <div className="goal-detail-overview-icon">
                  <TrendingUp size={20} />
                </div>
                <div>
                  <div className="goal-detail-overview-label">Current Progress</div>
                  <div className="goal-detail-overview-value">{goal.progress_pct.toFixed(1)}%</div>
                </div>
              </div>
              <div className="goal-detail-overview-card">
                <div className="goal-detail-overview-icon">
                  <Target size={20} />
                </div>
                <div>
                  <div className="goal-detail-overview-label">Remaining</div>
                  <div className="goal-detail-overview-value">{currencyFormatter.format(goal.remaining_amount)}</div>
                </div>
              </div>
              {monthlyContribution && (
                <div className="goal-detail-overview-card">
                  <div className="goal-detail-overview-icon">
                    <Calendar size={20} />
                  </div>
                  <div>
                    <div className="goal-detail-overview-label">Monthly Needed</div>
                    <div className="goal-detail-overview-value">{currencyFormatter.format(monthlyContribution)}</div>
                  </div>
                </div>
              )}
              <div className="goal-detail-overview-card">
                <div className="goal-detail-overview-icon">
                  <Clock size={20} />
                </div>
                <div>
                  <div className="goal-detail-overview-label">Completion Date</div>
                  <div className="goal-detail-overview-value-small">
                    {formatDate(goal.projected_completion_date)}
                  </div>
                </div>
              </div>
            </div>

            {/* Timeline Chart */}
            {timelineData.length > 0 && (
              <div className="goal-detail-section">
                <h3 className="goal-detail-section-title">Progress Timeline</h3>
                <div className="goal-detail-chart">
                  <ResponsiveContainer width="100%" height={250}>
                    <LineChart data={timelineData} margin={{ top: 10, right: 30, left: 20, bottom: 10 }}>
                      <XAxis
                        dataKey="month"
                        tick={{ fill: '#93a4c2', fontSize: 12 }}
                      />
                      <YAxis
                        tick={{ fill: '#93a4c2', fontSize: 12 }}
                        tickFormatter={(value) => `₹${(value / 1000).toFixed(0)}K`}
                      />
                      <Tooltip
                        formatter={(value: number) => currencyFormatter.format(value)}
                        contentStyle={{
                          backgroundColor: 'rgba(8, 12, 20, 0.95)',
                          border: '1px solid rgba(255, 255, 255, 0.1)',
                          borderRadius: '8px',
                          color: '#f9fbff',
                        }}
                      />
                      <ReferenceLine
                        y={goal.estimated_cost || goal.current_savings_close + goal.remaining_amount}
                        stroke="rgba(255, 255, 255, 0.3)"
                        strokeDasharray="3 3"
                        label={{ value: 'Target', position: 'right', fill: '#93a4c2' }}
                      />
                      <Line
                        type="monotone"
                        dataKey="cumulative"
                        stroke="#34f5c5"
                        strokeWidth={3}
                        dot={{ fill: '#34f5c5', r: 4 }}
                        name="Savings"
                      />
                      <Line
                        type="monotone"
                        dataKey="target"
                        stroke="rgba(255, 255, 255, 0.2)"
                        strokeWidth={2}
                        strokeDasharray="5 5"
                        dot={false}
                        name="Target"
                      />
                    </LineChart>
                  </ResponsiveContainer>
                </div>
              </div>
            )}

            {/* Milestone Plan */}
            <div className="goal-detail-section">
              <h3 className="goal-detail-section-title">Milestone Roadmap</h3>
              <div className="goal-detail-milestones">
                {milestoneDates.map((milestone, index) => (
                  <div
                    key={milestone.percentage}
                    className={`goal-detail-milestone ${milestone.achieved ? 'goal-detail-milestone--achieved' : ''}`}
                  >
                    <div className="goal-detail-milestone-indicator">
                      {milestone.achieved ? (
                        <CheckCircle2 size={24} className="goal-detail-milestone-icon--achieved" />
                      ) : (
                        <div className="goal-detail-milestone-circle">
                          {milestone.percentage}%
                        </div>
                      )}
                      {index < milestoneDates.length - 1 && (
                        <div
                          className={`goal-detail-milestone-connector ${milestone.achieved ? 'goal-detail-milestone-connector--active' : ''
                            }`}
                        />
                      )}
                    </div>
                    <div className="goal-detail-milestone-content">
                      <div className="goal-detail-milestone-header">
                        <span className="goal-detail-milestone-percentage">{milestone.percentage}% Milestone</span>
                        {milestone.achieved && (
                          <span className="goal-detail-milestone-badge">Achieved</span>
                        )}
                      </div>
                      <div className="goal-detail-milestone-amount">
                        {currencyFormatter.format(milestone.amount)}
                      </div>
                      <div className="goal-detail-milestone-date">
                        {milestone.achieved
                          ? 'Already achieved! 🎉'
                          : `Target: ${formatDate(milestone.date.toISOString())}`}
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </div>

            {/* Monthly Contribution Plan */}
            {monthlyContribution && (
              <div className="goal-detail-section">
                <h3 className="goal-detail-section-title">Monthly Contribution Plan</h3>
                <div className="goal-detail-contribution-plan">
                  <div className="goal-detail-contribution-card">
                    <div className="goal-detail-contribution-amount">
                      {currencyFormatter.format(monthlyContribution)}
                    </div>
                    <div className="goal-detail-contribution-label">per month</div>
                    <div className="goal-detail-contribution-note">
                      Save this amount monthly to reach your goal on time
                    </div>
                  </div>
                  <div className="goal-detail-contribution-breakdown">
                    <div className="goal-detail-contribution-item">
                      <span>Total Goal Amount</span>
                      <strong>{currencyFormatter.format(goal.estimated_cost || goal.current_savings_close + goal.remaining_amount)}</strong>
                    </div>
                    <div className="goal-detail-contribution-item">
                      <span>Already Saved</span>
                      <strong className="goal-detail-contribution-positive">
                        {currencyFormatter.format(goal.current_savings_close)}
                      </strong>
                    </div>
                    <div className="goal-detail-contribution-item">
                      <span>Remaining</span>
                      <strong>{currencyFormatter.format(goal.remaining_amount)}</strong>
                    </div>
                    <div className="goal-detail-contribution-item goal-detail-contribution-item--highlight">
                      <span>Monthly Contribution</span>
                      <strong className="goal-detail-contribution-highlight">
                        {currencyFormatter.format(monthlyContribution)}
                      </strong>
                    </div>
                  </div>
                </div>
              </div>
            )}
          </div>
        ) : (
          <div className="goal-detail-modal__content">
            <p className="text-muted">No goal data available</p>
          </div>
        )}
      </div>
    </div>
  )
}

