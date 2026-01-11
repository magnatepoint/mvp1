import { useState } from 'react'
import type { Session } from '@supabase/supabase-js'
import { GoalsStepper } from './GoalsStepper'
import { GoalsList } from './GoalsList'
import { GoalInsightsPanel } from '../../components/goals/GoalInsightsPanel'
import { GoalSuggestionsList } from '../../components/goals/GoalSuggestionsList'
import type { GoalResponse } from '../../types/goals'
import './GoalsScreen.css'

type Props = {
  session: Session
}

export function GoalsScreen({ session }: Props) {
  const [showStepper, setShowStepper] = useState(false)
  const [editingGoal, setEditingGoal] = useState<GoalResponse | null>(null)

  const handleEdit = (goal: GoalResponse) => {
    setEditingGoal(goal)
    setShowStepper(true)
  }

  if (showStepper) {
    return (
      <section className="goals-screen">
        <header className="glass-card goals-screen__hero">
          <div>
            <p className="eyebrow">Goals</p>
            <h1>{editingGoal ? 'Edit Goal' : 'Set Your Financial Goals'}</h1>
            <p className="text-muted">
              Tell us about yourself and your financial aspirations. We'll help you prioritize and track your progress.
            </p>
          </div>
        </header>
        <GoalsStepper session={session} />
        <div style={{ marginTop: '1.5rem' }}>
          <button className="ghost-button" onClick={() => {
            setShowStepper(false)
            setEditingGoal(null)
          }}>
            Back to Goals List
          </button>
        </div>
      </section>
    )
  }

  return (
    <section className="goals-screen">
      <header className="glass-card goals-screen__hero">
        <div>
          <p className="eyebrow">Goals</p>
          <h1>Your Financial Goals</h1>
          <p className="text-muted">
            View and manage your financial goals. Track progress and adjust targets as needed.
          </p>
        </div>
        <button className="primary-button" onClick={() => setShowStepper(true)}>
          Create New Goal
        </button>
      </header>

      <GoalsList session={session} onEdit={handleEdit} />

      {/* Insights and Suggestions Section */}
      <div className="goals-screen__insights-section">
        <div className="goals-screen__insights-column">
          <h2 className="goals-screen__insights-title">Goal Insights</h2>
          <GoalInsightsPanel session={session} />
        </div>
        <div className="goals-screen__insights-column">
          <h2 className="goals-screen__insights-title">Suggested Actions</h2>
          <GoalSuggestionsList session={session} />
        </div>
      </div>
    </section>
  )
}

