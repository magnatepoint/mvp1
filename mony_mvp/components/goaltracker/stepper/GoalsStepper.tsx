'use client'

import { useState, useEffect } from 'react'
import type { Session } from '@supabase/supabase-js'
import { fetchGoalCatalog, fetchLifeContext, fetchRecommendedGoals } from '@/lib/api/goals'
import type { GoalCatalogItem, LifeContextRequest, SelectedGoal } from '@/types/goals'
import LifeContextStep from './LifeContextStep'
import GoalSelectionStep from './GoalSelectionStep'
import GoalDetailStep from './GoalDetailStep'
import ReviewStep from './ReviewStep'
import { glassCardPrimary } from '@/lib/theme/glass'

interface GoalsStepperProps {
  session: Session
  isOpen: boolean
  onClose: () => void
  onComplete: () => void
}

export default function GoalsStepper({ session, isOpen, onClose, onComplete }: GoalsStepperProps) {
  const [currentStep, setCurrentStep] = useState(1)
  const [catalog, setCatalog] = useState<GoalCatalogItem[]>([])
  const [recommendedGoals, setRecommendedGoals] = useState<GoalCatalogItem[]>([])
  const [lifeContext, setLifeContext] = useState<LifeContextRequest | null>(null)
  const [selectedGoals, setSelectedGoals] = useState<SelectedGoal[]>([])
  const [currentGoalIndex, setCurrentGoalIndex] = useState(0)
  const [loading, setLoading] = useState(false)

  useEffect(() => {
    if (isOpen) {
      loadInitialData()
    } else {
      // Reset state when modal closes
      setCurrentStep(1)
      setSelectedGoals([])
      setCurrentGoalIndex(0)
      setLifeContext(null)
    }
  }, [isOpen])

  const loadInitialData = async () => {
    setLoading(true)
    try {
      const [catalogData, contextData] = await Promise.all([
        fetchGoalCatalog(session),
        fetchLifeContext(session),
      ])
      setCatalog(catalogData)
      if (contextData) {
        setLifeContext(contextData)
        // Load recommended goals if context exists
        const recommended = await fetchRecommendedGoals(session)
        setRecommendedGoals(recommended)
      }
    } catch (err) {
      console.error('Error loading initial data:', err)
    } finally {
      setLoading(false)
    }
  }

  const nextStep = () => {
    if (currentStep < 4) {
      setCurrentStep(currentStep + 1)
    }
  }

  const previousStep = () => {
    if (currentStep > 1) {
      setCurrentStep(currentStep - 1)
    }
  }

  const addSelectedGoal = (goal: GoalCatalogItem) => {
    const selectedGoal: SelectedGoal = {
      goal_category: goal.goal_category,
      goal_name: goal.goal_name,
      estimated_cost: 0,
      target_date: null,
      current_savings: 0,
      importance: 3,
      notes: null,
    }
    setSelectedGoals([...selectedGoals, selectedGoal])
  }

  const removeSelectedGoal = (index: number) => {
    setSelectedGoals(selectedGoals.filter((_, i) => i !== index))
    if (currentGoalIndex >= selectedGoals.length - 1) {
      setCurrentGoalIndex(Math.max(0, selectedGoals.length - 2))
    }
  }

  const updateSelectedGoal = (index: number, goal: SelectedGoal) => {
    const updated = [...selectedGoals]
    updated[index] = goal
    setSelectedGoals(updated)
  }

  const nextGoal = () => {
    if (currentGoalIndex < selectedGoals.length - 1) {
      setCurrentGoalIndex(currentGoalIndex + 1)
    }
  }

  const previousGoal = () => {
    if (currentGoalIndex > 0) {
      setCurrentGoalIndex(currentGoalIndex - 1)
    }
  }

  if (!isOpen) return null

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm">
      <div className={`relative ${glassCardPrimary} p-6 max-w-2xl w-full mx-4 max-h-[90vh] overflow-y-auto`}>
        {/* Close Button */}
        <button
          onClick={onClose}
          disabled={loading}
          className="absolute top-4 right-4 p-2 rounded-lg hover:bg-white/10 transition-colors disabled:opacity-50"
        >
          <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>

        {/* Step Indicator */}
        <div className="flex items-center gap-2 mb-6">
          {[1, 2, 3, 4].map((step) => (
            <div key={step} className="flex items-center gap-2 flex-1">
              <div
                className={`w-3 h-3 rounded-full transition-colors ${
                  step <= currentStep ? 'bg-[#D4AF37]' : 'bg-gray-500/30'
                }`}
              />
              {step < 4 && (
                <div
                  className={`h-0.5 flex-1 transition-colors ${
                    step < currentStep ? 'bg-[#D4AF37]' : 'bg-gray-500/30'
                  }`}
                />
              )}
            </div>
          ))}
        </div>

        {/* Step Content */}
        {loading && currentStep === 1 ? (
          <div className="flex items-center justify-center py-20">
            <div className="animate-spin rounded-full h-12 w-12 border-t-2 border-b-2 border-[#D4AF37]"></div>
          </div>
        ) : (
          <>
            {currentStep === 1 && (
              <LifeContextStep
                session={session}
                initialContext={lifeContext}
                onNext={(context) => {
                  setLifeContext(context)
                  nextStep()
                }}
                onClose={onClose}
              />
            )}
            {currentStep === 2 && (
              <GoalSelectionStep
                catalog={catalog}
                recommendedGoals={recommendedGoals}
                selectedGoals={selectedGoals}
                onAddGoal={addSelectedGoal}
                onRemoveGoal={removeSelectedGoal}
                onNext={nextStep}
                onBack={previousStep}
              />
            )}
            {currentStep === 3 && (
              <GoalDetailStep
                catalog={catalog}
                selectedGoals={selectedGoals}
                currentGoalIndex={currentGoalIndex}
                onUpdateGoal={updateSelectedGoal}
                onNextGoal={nextGoal}
                onPreviousGoal={previousGoal}
                onNext={nextStep}
                onBack={previousStep}
              />
            )}
            {currentStep === 4 && (
              <ReviewStep
                session={session}
                lifeContext={lifeContext!}
                selectedGoals={selectedGoals}
                onBack={previousStep}
                onComplete={onComplete}
                onClose={onClose}
              />
            )}
          </>
        )}
      </div>
    </div>
  )
}
