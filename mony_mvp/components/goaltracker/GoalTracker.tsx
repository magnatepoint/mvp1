'use client'

import { useState, useEffect } from 'react'
import type { Session } from '@supabase/supabase-js'
import { fetchUserGoals } from '@/lib/api/goals'
import GoalTrackerWelcomeBanner from './GoalTrackerWelcomeBanner'
import OverviewTab from './tabs/OverviewTab'
import GoalsListTab from './tabs/GoalsListTab'
import AIInsightsTab from './tabs/AIInsightsTab'
import GoalsStepper from './stepper/GoalsStepper'

type GoalTrackerTab = 'overview' | 'goals' | 'aiInsights'

interface GoalTrackerProps {
  session: Session
  onBack?: () => void
}

export default function GoalTracker({ session }: GoalTrackerProps) {
  const [selectedTab, setSelectedTab] = useState<GoalTrackerTab>('overview')
  const [showStepper, setShowStepper] = useState(false)
  const [hasGoals, setHasGoals] = useState(false)
  const [isLoading, setIsLoading] = useState(true)

  const checkUserGoals = async () => {
    setIsLoading(true)
    try {
      const goals = await fetchUserGoals(session)
      setHasGoals(goals.length > 0)
    } catch (err) {
      console.error('Error checking goals:', err)
      setHasGoals(false)
    } finally {
      setIsLoading(false)
    }
  }

  useEffect(() => {
    checkUserGoals()
  }, [session])

  const handleStepperComplete = () => {
    setShowStepper(false)
    checkUserGoals()
  }

  const tabs: { id: GoalTrackerTab; label: string; icon: string }[] = [
    { id: 'overview', label: 'Overview', icon: '📊' },
    { id: 'goals', label: 'Goals', icon: '🎯' },
    { id: 'aiInsights', label: 'AI Insights', icon: '✨' },
  ]

  const userEmail = session.user.email || null

  return (
    <div className="min-h-screen bg-[#2E2E2E] text-white">
      {/* Welcome Banner */}
      <GoalTrackerWelcomeBanner username={userEmail} />

      {/* Custom Tab Bar */}
      <div className="sticky top-0 z-10 bg-[#2E2E2E]/95 backdrop-blur-sm border-b border-white/10">
        <div className="flex items-center justify-between px-4 py-3">
          <div className="flex gap-2 overflow-x-auto scrollbar-hide flex-1">
            {tabs.map((tab) => (
              <button
                key={tab.id}
                onClick={() => setSelectedTab(tab.id)}
                className={`flex items-center gap-2 px-4 py-2 rounded-lg font-medium transition-all whitespace-nowrap ${
                  selectedTab === tab.id
                    ? 'bg-white text-black'
                    : 'text-gray-400 hover:text-white hover:bg-white/5'
                }`}
              >
                <span>{tab.icon}</span>
                <span>{tab.label}</span>
              </button>
            ))}
          </div>

          {/* Add Goal Button */}
          <button
            onClick={() => setShowStepper(true)}
            className="ml-2 p-2 rounded-lg hover:bg-white/10 transition-colors"
            title="Add Goal"
          >
            <svg
              className="w-6 h-6 text-[#D4AF37]"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2}
                d="M12 4v16m8-8H4"
              />
            </svg>
          </button>

        </div>
      </div>

      {/* Tab Content */}
      {isLoading ? (
        <div className="flex items-center justify-center py-20">
          <div className="animate-spin rounded-full h-12 w-12 border-t-2 border-b-2 border-[#D4AF37]"></div>
        </div>
      ) : !hasGoals && selectedTab === 'overview' ? (
        // Show stepper prompt if no goals
        <div className="flex flex-col items-center justify-center py-20 gap-6 px-4">
          <span className="text-6xl">🎯</span>
          <div className="text-center space-y-2">
            <h2 className="text-2xl font-bold text-white">No Goals Yet</h2>
            <p className="text-gray-400 max-w-md">
              Set up your financial goals first to start tracking progress.
            </p>
          </div>
          <button
            onClick={() => setShowStepper(true)}
            className="flex items-center gap-2 px-6 py-3 rounded-lg bg-[#D4AF37] text-black font-semibold hover:bg-[#D4AF37]/90 transition-colors"
          >
            <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2}
                d="M12 4v16m8-8H4"
              />
            </svg>
            Set Up Goals
          </button>
        </div>
      ) : (
        <div className="p-4">
          {selectedTab === 'overview' && <OverviewTab session={session} />}
          {selectedTab === 'goals' && <GoalsListTab session={session} />}
          {selectedTab === 'aiInsights' && <AIInsightsTab session={session} />}
        </div>
      )}

      {/* Goals Stepper Modal */}
      <GoalsStepper
        session={session}
        isOpen={showStepper}
        onClose={() => setShowStepper(false)}
        onComplete={handleStepperComplete}
      />
    </div>
  )
}
