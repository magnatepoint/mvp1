'use client'

import { useState, useEffect } from 'react'
import type { Session } from '@supabase/supabase-js'
import { env } from '../../env'
import { LifeContextStep } from './steps/LifeContextStep'
import { GoalSelectionStep } from './steps/GoalSelectionStep'
import { GoalDetailStep } from './steps/GoalDetailStep'
import { ReviewStep } from './steps/ReviewStep'
import './GoalsStepper.css'

type Props = {
  session: Session
  onComplete?: () => void
}

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

type GoalCatalogItem = {
  goal_category: string
  goal_name: string
  default_horizon: string
  policy_linked_txn_type: string
  is_mandatory_flag: boolean
  suggested_min_amount_formula: string | null
  display_order: number
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

const STEPS = [
  { id: 1, title: 'Life Context', description: 'Tell us about yourself' },
  { id: 2, title: 'Select Goals', description: 'Choose your financial goals' },
  { id: 3, title: 'Goal Details', description: 'Set targets and priorities' },
  { id: 4, title: 'Review', description: 'Review and submit' },
]

export function GoalsStepper({ session, onComplete }: Props) {
  const [currentStep, setCurrentStep] = useState(1)
  const [lifeContext, setLifeContext] = useState<LifeContext | null>(null)
  const [goalCatalog, setGoalCatalog] = useState<GoalCatalogItem[]>([])
  const [recommendedGoals, setRecommendedGoals] = useState<GoalCatalogItem[]>([])
  const [selectedGoals, setSelectedGoals] = useState<SelectedGoal[]>([])
  const [currentGoalIndex, setCurrentGoalIndex] = useState(0)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [submitting, setSubmitting] = useState(false)

  // Load existing life context and goal catalog
  useEffect(() => {
    const loadData = async () => {
      setLoading(true)
      setError(null)
      try {
        // Load goal catalog
        const catalogRes = await fetch(`${env.apiBaseUrl}/v1/goals/catalog`, {
          headers: {
            Authorization: `Bearer ${session.access_token}`,
          },
        })
        if (!catalogRes.ok) throw new Error('Failed to load goal catalog')
        const catalog = await catalogRes.json()
        setGoalCatalog(catalog)

        // Load existing life context (404 is expected if no context exists)
        try {
          const contextRes = await fetch(`${env.apiBaseUrl}/v1/goals/context`, {
            headers: {
              Authorization: `Bearer ${session.access_token}`,
            },
          }).catch(() => null) // Silently catch network errors
          
          if (contextRes && contextRes.ok) {
            const context = await contextRes.json()
            setLifeContext(context)
            // If context exists and we're adding new goals, start at goal selection
            try {
              const goalsRes = await fetch(`${env.apiBaseUrl}/v1/goals`, {
                headers: {
                  Authorization: `Bearer ${session.access_token}`,
                },
              }).catch(() => null) // Silently catch network errors
              
              if (goalsRes && goalsRes.ok) {
                const existingGoals = await goalsRes.json()
                if (existingGoals && existingGoals.length > 0) {
                  // User has existing goals, skip to goal selection
                  setCurrentStep(2)
                }
              }
            } catch (goalsErr) {
              // Silently ignore errors when checking for existing goals
            }
          }
          // 404 is expected if no context exists, so we don't need to handle it
        } catch (contextErr) {
          // Silently ignore errors when loading context - it's optional
        }

        // Load recommended goals
        const recommendedRes = await fetch(`${env.apiBaseUrl}/v1/goals/recommended`, {
          headers: {
            Authorization: `Bearer ${session.access_token}`,
          },
        })
        if (recommendedRes.ok) {
          const recommended = await recommendedRes.json()
          setRecommendedGoals(recommended)
        }
      } catch (err) {
        setError(err instanceof Error ? err.message : 'Failed to load data')
      } finally {
        setLoading(false)
      }
    }

    void loadData()
  }, [session])

  const handleLifeContextSubmit = (context: LifeContext) => {
    setLifeContext(context)
    setCurrentStep(2)
  }

  const handleGoalSelection = (goals: GoalCatalogItem[]) => {
    // Initialize selected goals with default values
    const initialized: SelectedGoal[] = goals.map((goal) => ({
      goal_category: goal.goal_category,
      goal_name: goal.goal_name,
      estimated_cost: 0,
      target_date: null,
      current_savings: 0,
      importance: 3,
      notes: null,
    }))
    setSelectedGoals(initialized)
    setCurrentGoalIndex(0)
    setCurrentStep(3)
  }

  const handleGoalDetailSubmit = (goalDetail: SelectedGoal) => {
    const updated = [...selectedGoals]
    updated[currentGoalIndex] = goalDetail

    if (currentGoalIndex < selectedGoals.length - 1) {
      setSelectedGoals(updated)
      setCurrentGoalIndex(currentGoalIndex + 1)
    } else {
      setSelectedGoals(updated)
      setCurrentStep(4)
    }
  }

  const handleBack = () => {
    if (currentStep === 3 && currentGoalIndex > 0) {
      setCurrentGoalIndex(currentGoalIndex - 1)
    } else if (currentStep > 1) {
      setCurrentStep(currentStep - 1)
    }
  }

  const handleSubmit = async () => {
    // If no life context and we're on step 1, require it
    if (!lifeContext && currentStep === 1) {
      setError('Life context is required')
      return
    }

    // If no goals selected, require at least one
    if (selectedGoals.length === 0) {
      setError('Please select at least one goal')
      return
    }

    setSubmitting(true)
    setError(null)

    try {
      // Use submit endpoint which handles both life context and goals
      // If life context exists, it will be updated; if not, it will be created
      const response = await fetch(`${env.apiBaseUrl}/v1/goals/submit`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${session.access_token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          context: lifeContext || {},
          selected_goals: selectedGoals,
        }),
      })

      if (!response.ok) {
        const body = await response.json().catch(() => ({}))
        throw new Error(body.detail ?? 'Failed to submit goals')
      }

      // Success - notify parent and reset form
      if (onComplete) {
        onComplete()
      } else {
        alert('Goals submitted successfully!')
      }
      // Reset form
      setCurrentStep(1)
      setSelectedGoals([])
      setCurrentGoalIndex(0)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to submit goals')
    } finally {
      setSubmitting(false)
    }
  }

  if (loading) {
    return (
      <div className="glass-card goals-stepper">
        <p className="status-loading">Loading...</p>
      </div>
    )
  }

  return (
    <div className="goals-stepper-container">
      {/* Stepper Header */}
      <div className="glass-card goals-stepper-header">
        <div className="stepper-steps">
          {STEPS.map((step) => (
            <div
              key={step.id}
              className={`stepper-step ${currentStep >= step.id ? 'stepper-step--active' : ''} ${
                currentStep === step.id ? 'stepper-step--current' : ''
              }`}
            >
              <div className="stepper-step__number">{step.id}</div>
              <div className="stepper-step__content">
                <div className="stepper-step__title">{step.title}</div>
                <div className="stepper-step__description">{step.description}</div>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Step Content */}
      <div className="glass-card goals-stepper-content">
        {error && <div className="error-message">{error}</div>}

        {currentStep === 1 && (
          <LifeContextStep
            initialData={lifeContext}
            onSubmit={handleLifeContextSubmit}
            onSkip={() => setCurrentStep(2)}
          />
        )}

        {currentStep === 2 && (
          <GoalSelectionStep
            catalog={goalCatalog}
            recommended={recommendedGoals}
            onSelect={handleGoalSelection}
            onBack={handleBack}
          />
        )}

        {currentStep === 3 && selectedGoals.length > 0 && (
          <GoalDetailStep
            goal={selectedGoals[currentGoalIndex]}
            catalogItem={goalCatalog.find(
              (g) =>
                g.goal_category === selectedGoals[currentGoalIndex].goal_category &&
                g.goal_name === selectedGoals[currentGoalIndex].goal_name
            )}
            currentIndex={currentGoalIndex}
            totalGoals={selectedGoals.length}
            onSubmit={handleGoalDetailSubmit}
            onBack={handleBack}
          />
        )}

        {currentStep === 4 && (
          <ReviewStep
            lifeContext={lifeContext}
            selectedGoals={selectedGoals}
            onSubmit={handleSubmit}
            onBack={handleBack}
            submitting={submitting}
          />
        )}
      </div>
    </div>
  )
}

