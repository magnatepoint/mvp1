'use client'

import React, { useEffect, useState } from 'react'
import type { Session } from '@supabase/supabase-js'
import { fetchBudgetRecommendations, commitBudget, fetchCommittedBudget } from '../../api/budget'
import type { BudgetRecommendation, CommittedBudget } from '../../types/budget'
import './BudgetPilotScreen.css'

type Props = {
  session: Session
}

export const BudgetPilotScreen: React.FC<Props> = ({ session }) => {
  const [recommendations, setRecommendations] = useState<BudgetRecommendation[]>([])
  const [committed, setCommitted] = useState<CommittedBudget | null>(null)
  const [loading, setLoading] = useState(true)
  const [committing, setCommitting] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    void loadData()
  }, [session])

  const loadData = async () => {
    setLoading(true)
    setError(null)
    try {
      const [recsRes, commitRes] = await Promise.all([
        fetchBudgetRecommendations(session),
        fetchCommittedBudget(session),
      ])
      setRecommendations(recsRes.recommendations)
      setCommitted(commitRes.budget)
    } catch (err) {
      console.error('Error loading budget data:', err)
      setError(err instanceof Error ? err.message : 'Failed to load budget recommendations')
    } finally {
      setLoading(false)
    }
  }

  const handleCommit = async (planCode: string) => {
    setCommitting(true)
    try {
      const result = await commitBudget(session, { plan_code: planCode })
      setCommitted(result.budget)
      alert('Budget committed successfully!')
    } catch (err) {
      console.error('Error committing budget:', err)
      alert(err instanceof Error ? err.message : 'Failed to commit budget')
    } finally {
      setCommitting(false)
    }
  }

  if (loading) {
    return (
      <section className="budgetpilot-screen">
        <h1>BudgetPilot</h1>
        <div>Loading...</div>
      </section>
    )
  }

  if (error) {
    return (
      <section className="budgetpilot-screen">
        <h1>BudgetPilot</h1>
        <div className="error-message">{error}</div>
      </section>
    )
  }

  return (
    <section className="budgetpilot-screen">
      <div className="budgetpilot-header">
        <h1>BudgetPilot</h1>
        <p className="budgetpilot-subtitle">
          Smart budget recommendations tailored to your spending patterns and goals
        </p>
      </div>

      {committed ? (
        <div className="committed-budget-section">
          <h2>Your Committed Budget</h2>
          <div className="committed-budget-card">
            <div className="budget-summary">
              <div className="budget-item">
                <span className="budget-label">Needs</span>
                <span className="budget-value">{(committed.alloc_needs_pct * 100).toFixed(0)}%</span>
              </div>
              <div className="budget-item">
                <span className="budget-label">Wants</span>
                <span className="budget-value">{(committed.alloc_wants_pct * 100).toFixed(0)}%</span>
              </div>
              <div className="budget-item">
                <span className="budget-label">Savings</span>
                <span className="budget-value">{(committed.alloc_assets_pct * 100).toFixed(0)}%</span>
              </div>
            </div>
            {committed.goal_allocations && committed.goal_allocations.length > 0 && (
              <div className="goal-allocations">
                <h3>Goal Allocations</h3>
                <ul>
                  {committed.goal_allocations.map((alloc) => (
                    <li key={alloc.goal_id}>
                      <span>{alloc.goal_name || alloc.goal_id.slice(0, 8) + '...'}</span>
                      <span>₹{alloc.planned_amount.toLocaleString('en-IN')}</span>
                    </li>
                  ))}
                </ul>
              </div>
            )}
          </div>
        </div>
      ) : null}

      <div className="recommendations-section">
        <h2>{committed ? 'Other Recommendations' : 'Recommended Budget Plans'}</h2>
        <div className="recommendations-grid">
          {recommendations.map((rec) => (
            <div key={rec.plan_code} className="recommendation-card">
              <div className="recommendation-header">
                <h3>{rec.name}</h3>
                <span className="recommendation-score">Score: {rec.score.toFixed(2)}</span>
              </div>
              <p className="recommendation-description">{rec.description}</p>
              <div className="recommendation-allocation">
                <div className="allocation-bar">
                  <div
                    className="allocation-segment needs"
                    style={{ width: `${rec.needs_budget_pct * 100}%` }}
                  />
                  <div
                    className="allocation-segment wants"
                    style={{ width: `${rec.wants_budget_pct * 100}%` }}
                  />
                  <div
                    className="allocation-segment savings"
                    style={{ width: `${rec.savings_budget_pct * 100}%` }}
                  />
                </div>
                <div className="allocation-labels">
                  <span>Needs {(rec.needs_budget_pct * 100).toFixed(0)}%</span>
                  <span>Wants {(rec.wants_budget_pct * 100).toFixed(0)}%</span>
                  <span>Savings {(rec.savings_budget_pct * 100).toFixed(0)}%</span>
                </div>
              </div>
              <p className="recommendation-reason">{rec.recommendation_reason}</p>
              {rec.goal_preview && rec.goal_preview.length > 0 && (
                <div className="goal-preview">
                  <h4>Goal Allocation Preview</h4>
                  <ul>
                    {rec.goal_preview.slice(0, 3).map((goal) => (
                      <li key={goal.goal_id}>
                        <span>{goal.goal_name}</span>
                        <span>₹{goal.allocation_amount.toLocaleString('en-IN')}</span>
                      </li>
                    ))}
                  </ul>
                </div>
              )}
              {(!committed || committed.plan_code !== rec.plan_code) && (
                <button
                  className="commit-button"
                  onClick={() => void handleCommit(rec.plan_code)}
                  disabled={committing}
                >
                  {committing ? 'Committing...' : 'Commit to This Plan'}
                </button>
              )}
              {committed && committed.plan_code === rec.plan_code && (
                <div className="committed-badge">✓ Committed</div>
              )}
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}

