import { useState, useEffect } from 'react'
import type { Session } from '@supabase/supabase-js'
import { LifeContextStep } from './steps/LifeContextStep'
import { GoalSelectionStep } from './steps/GoalSelectionStep'
import { GoalDetailStep } from './steps/GoalDetailStep'
import { ReviewStep } from './steps/ReviewStep'
import { CheckCircle2 } from 'lucide-react'
import { useToast } from '../../components/Toast'
import { SkeletonLoader } from '../../components/SkeletonLoader'
import {
  fetchGoalCatalog,
  fetchRecommendedGoals,
  fetchLifeContext,
  submitGoals,
} from '../../api/goals'
import type {
  LifeContextRequest,
  GoalCatalogItem,
  GoalDetailRequest,
} from '../../types/goals'
import './GoalsStepper.css'

type Props = {
  session: Session
}

const STEPS = [
  { id: 1, title: 'Life Context', description: 'Tell us about yourself' },
  { id: 2, title: 'Select Goals', description: 'Choose your financial goals' },
  { id: 3, title: 'Goal Details', description: 'Set targets and priorities' },
  { id: 4, title: 'Review', description: 'Review and submit' },
]

export function GoalsStepper({ session }: Props) {
  const { showToast } = useToast()
  const [currentStep, setCurrentStep] = useState(1)
  const [lifeContext, setLifeContext] = useState<LifeContextRequest | null>(null)
  const [goalCatalog, setGoalCatalog] = useState<GoalCatalogItem[]>([])
  const [recommendedGoals, setRecommendedGoals] = useState<GoalCatalogItem[]>([])
  const [selectedGoals, setSelectedGoals] = useState<GoalDetailRequest[]>([])
  const [currentGoalIndex, setCurrentGoalIndex] = useState(0)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [submitting, setSubmitting] = useState(false)
  const [submitted, setSubmitted] = useState(false)

  // Load existing life context and goal catalog
  useEffect(() => {
    const loadData = async () => {
      setLoading(true)
      setError(null)
      try {
        // Load goal catalog
        const catalog = await fetchGoalCatalog(session)
        setGoalCatalog(catalog)

        // Load existing life context
        const context = await fetchLifeContext(session)
        if (context) {
          setLifeContext(context)
        }

        // Load recommended goals
        try {
          const recommended = await fetchRecommendedGoals(session)
          setRecommendedGoals(recommended)
        } catch (err) {
          // Recommended goals endpoint might not be available, ignore
          console.warn('Failed to load recommended goals:', err)
        }
      } catch (err) {
        setError(err instanceof Error ? err.message : 'Failed to load data')
      } finally {
        setLoading(false)
      }
    }

    void loadData()
  }, [session])

  const handleLifeContextSubmit = (context: LifeContextRequest) => {
    setLifeContext(context)
    setCurrentStep(2)
  }

  const handleGoalSelection = (goals: GoalCatalogItem[]) => {
    // Initialize selected goals with default values
    const initialized: GoalDetailRequest[] = goals.map((goal) => ({
      goal_category: goal.goal_category,
      goal_name: goal.goal_name,
      estimated_cost: 0,
      target_date: null,
      current_savings: 0,
      importance: 3,
      notes: null,
      is_must_have: goal.is_mandatory_flag,
      timeline_flexibility: 'somewhat_flexible',
    }))
    setSelectedGoals(initialized)
    setCurrentGoalIndex(0)
    setCurrentStep(3)
  }

  const handleGoalDetailSubmit = (goalDetail: GoalDetailRequest) => {
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
    if (!lifeContext) {
      setError('Life context is required')
      return
    }

    setSubmitting(true)
    setError(null)

    try {
      await submitGoals(session, {
          context: lifeContext,
          selected_goals: selectedGoals,
      })

      // Success - show toast and success state
      showToast('Goals submitted successfully! 🎉', 'success', 5000)
      setSubmitted(true)
      // Reset form after showing success
      setTimeout(() => {
        setCurrentStep(1)
        setSelectedGoals([])
        setCurrentGoalIndex(0)
        setLifeContext(null)
        setSubmitted(false)
      }, 3000)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to submit goals')
    } finally {
      setSubmitting(false)
    }
  }

  if (loading) {
    return (
      <div className="glass-card goals-stepper">
        <div style={{ padding: '2rem' }}>
          <SkeletonLoader height={24} width="60%" style={{ marginBottom: '1rem' }} />
          <SkeletonLoader height={200} width="100%" />
        </div>
      </div>
    )
  }

  return (
    <div className="goals-stepper-container">
      {/* Enhanced Stepper Header */}
      <div className="glass-card goals-stepper-header">
        <div className="stepper-progress-bar">
          <div
            className="stepper-progress-fill"
            style={{ width: `${((currentStep - 1) / (STEPS.length - 1)) * 100}%` }}
          />
        </div>
        <div className="stepper-steps">
          {STEPS.map((step, index) => {
            const isCompleted = currentStep > step.id
            const isCurrent = currentStep === step.id
            const isUpcoming = currentStep < step.id
            
            return (
              <div
                key={step.id}
                className={`stepper-step ${isCompleted ? 'stepper-step--completed' : ''} ${
                  isCurrent ? 'stepper-step--current' : ''
                } ${isUpcoming ? 'stepper-step--upcoming' : ''}`}
              >
                <div className="stepper-step__connector">
                  {index > 0 && <div className={`stepper-connector-line ${isCompleted ? 'stepper-connector-line--active' : ''}`} />}
                </div>
                <div className={`stepper-step__number ${isCompleted ? 'stepper-step__number--completed' : ''} ${isCurrent ? 'stepper-step__number--current' : ''}`}>
                  {isCompleted ? <CheckCircle2 size={20} /> : step.id}
                </div>
                <div className="stepper-step__content">
                  <div className="stepper-step__title">{step.title}</div>
                  <div className="stepper-step__description">{step.description}</div>
                </div>
              </div>
            )
          })}
        </div>
      </div>

      {/* Step Content */}
      <div className="glass-card goals-stepper-content">
        {error && <div className="error-message">{error}</div>}

        {submitted && (
          <div className="goals-success-state">
            <CheckCircle2 size={64} className="goals-success-icon" />
            <h2>Goals Created Successfully! 🎉</h2>
            <p className="text-muted">
              Your financial goals have been set up. You can now track your progress in GoalCompass.
            </p>
            <button
              className="primary-button"
              onClick={() => {
                setSubmitted(false)
                setCurrentStep(1)
              }}
            >
              Create More Goals
            </button>
          </div>
        )}

        {!submitted && currentStep === 1 && (
          <LifeContextStep
            initialData={lifeContext}
            onSubmit={handleLifeContextSubmit}
            onSkip={() => setCurrentStep(2)}
          />
        )}

        {!submitted && currentStep === 2 && (
          <GoalSelectionStep
            catalog={goalCatalog}
            recommended={recommendedGoals}
            onSelect={handleGoalSelection}
            onBack={handleBack}
          />
        )}

        {!submitted && currentStep === 3 && selectedGoals.length > 0 && (
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

        {!submitted && currentStep === 4 && (
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

