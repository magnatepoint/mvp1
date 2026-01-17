'use client'

import { useState, useEffect } from 'react'
import type { Session } from '@supabase/supabase-js'
import {
  fetchBudgetRecommendations,
  fetchCommittedBudget,
  commitBudget,
  fetchBudgetVariance,
} from '@/lib/api/budget'
import type { BudgetRecommendation, CommittedBudget, BudgetCommitRequest, BudgetVariance } from '@/types/budget'
import { glassCardPrimary } from '@/lib/theme/glass'
import BudgetPilotWelcomeBanner from './BudgetPilotWelcomeBanner'
import EnhancedCommittedBudgetCard from './components/EnhancedCommittedBudgetCard'
import EnhancedBudgetRecommendationCard from './components/EnhancedBudgetRecommendationCard'
import BudgetInfoCard from './components/BudgetInfoCard'
import BudgetComparisonModal from './components/BudgetComparisonModal'

interface BudgetPilotProps {
  session: Session
  onBack?: () => void
}

export default function BudgetPilot({ session }: BudgetPilotProps) {
  const [recommendations, setRecommendations] = useState<BudgetRecommendation[]>([])
  const [committedBudget, setCommittedBudget] = useState<CommittedBudget | null>(null)
  const [variance, setVariance] = useState<BudgetVariance | null>(null)
  const [isRecommendationsLoading, setIsRecommendationsLoading] = useState(true)
  const [isCommittedLoading, setIsCommittedLoading] = useState(true)
  const [isVarianceLoading, setIsVarianceLoading] = useState(true)
  const [recommendationsError, setRecommendationsError] = useState<string | null>(null)
  const [committedError, setCommittedError] = useState<string | null>(null)
  const [isCommitting, setIsCommitting] = useState(false)
  const [committingPlanCode, setCommittingPlanCode] = useState<string | null>(null)
  const [selectedMonth, setSelectedMonth] = useState<string | null>(null)
  const [comparingRecommendation, setComparingRecommendation] = useState<BudgetRecommendation | null>(null)

  const loadData = async () => {
    // Load all data in parallel
    setIsRecommendationsLoading(true)
    setIsCommittedLoading(true)
    setIsVarianceLoading(true)
    setRecommendationsError(null)
    setCommittedError(null)

    try {
      const [recommendationsData, committedData, varianceData] = await Promise.all([
        fetchBudgetRecommendations(session, selectedMonth || undefined).catch((err) => {
          setRecommendationsError(err instanceof Error ? err.message : 'Failed to load recommendations')
          return []
        }),
        fetchCommittedBudget(session, selectedMonth || undefined).catch((err) => {
          setCommittedError(err instanceof Error ? err.message : 'Failed to load committed budget')
          return null
        }),
        fetchBudgetVariance(session, selectedMonth || undefined).catch((err) => {
          console.error('Failed to load budget variance:', err)
          return null
        }),
      ])

      setRecommendations(recommendationsData)
      setCommittedBudget(committedData)
      setVariance(varianceData)
    } catch (err) {
      console.error('Error loading budget data:', err)
    } finally {
      setIsRecommendationsLoading(false)
      setIsCommittedLoading(false)
      setIsVarianceLoading(false)
    }
  }

  useEffect(() => {
    loadData()
  }, [session])

  const handleCommit = async (planCode: string) => {
    setIsCommitting(true)
    setCommittingPlanCode(planCode)
    try {
      const request: BudgetCommitRequest = {
        plan_code: planCode,
      }
      const committed = await commitBudget(session, request)
      setCommittedBudget(committed)
      // Reload recommendations to update UI
      await loadData()
    } catch (err) {
      console.error('Error committing budget:', err)
      alert(err instanceof Error ? err.message : 'Failed to commit budget')
    } finally {
      setIsCommitting(false)
      setCommittingPlanCode(null)
    }
  }

  const userEmail = session.user.email || null

  return (
    <div className="min-h-screen bg-[#2E2E2E] text-white">
      {/* Welcome Banner */}
      <BudgetPilotWelcomeBanner username={userEmail} />

      {/* Header */}
      <div className="px-4 pt-4 pb-2">
        <div className="flex items-start justify-between gap-4">
          <div className="flex-1">
            <h1 className="text-3xl font-bold text-white mb-2">BudgetPilot</h1>
            <p className="text-base text-gray-400">
              Smart budget recommendations tailored to your spending patterns and goals
            </p>
          </div>

          <div className="flex items-center gap-2">
            {/* Month Selector */}
            <input
              type="month"
              value={selectedMonth || new Date().toISOString().slice(0, 7)}
              onChange={(e) => {
                setSelectedMonth(e.target.value)
                // Reload data when month changes
                setTimeout(() => loadData(), 100)
              }}
              className="px-3 py-2 bg-white/5 border border-white/10 rounded-lg text-white text-sm"
            />

            {/* Refresh Button */}
            <button
              onClick={loadData}
              disabled={isRecommendationsLoading || isCommittedLoading}
              className="p-2 rounded-lg hover:bg-white/10 transition-colors disabled:opacity-50"
              title="Refresh"
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
                  d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"
                />
              </svg>
            </button>
          </div>
        </div>
      </div>

      {/* Content */}
      <div className="space-y-6 pb-6">
        {/* Quick Stats */}
        {committedBudget && variance && (
          <div className="px-4 grid grid-cols-1 sm:grid-cols-3 gap-4">
            <BudgetInfoCard
              title="Monthly Income"
              value={new Intl.NumberFormat('en-IN', {
                style: 'currency',
                currency: 'INR',
                maximumFractionDigits: 0,
              }).format(variance.income_amt)}
              icon="💰"
              color="green"
            />
            <BudgetInfoCard
              title="Total Spending"
              value={new Intl.NumberFormat('en-IN', {
                style: 'currency',
                currency: 'INR',
                maximumFractionDigits: 0,
              }).format(variance.needs_amt + variance.wants_amt)}
              icon="📊"
              color="orange"
            />
            <BudgetInfoCard
              title="Savings Rate"
              value={`${variance.income_amt > 0 ? ((variance.assets_amt / variance.income_amt) * 100).toFixed(1) : 0}%`}
              subtitle={new Intl.NumberFormat('en-IN', {
                style: 'currency',
                currency: 'INR',
                maximumFractionDigits: 0,
              }).format(variance.assets_amt)}
              icon="🎯"
              color="purple"
            />
          </div>
        )}

        {/* Committed Budget Section */}
        {isCommittedLoading ? (
          <div className="flex items-center justify-center py-10 px-4">
            <div className="animate-spin rounded-full h-8 w-8 border-t-2 border-b-2 border-[#D4AF37]"></div>
          </div>
        ) : committedBudget ? (
          <div className="space-y-4 px-4">
            <div className="flex items-center justify-between">
              <h2 className="text-xl font-bold text-white">Your Committed Budget</h2>
              {!isVarianceLoading && variance && (
                <span className="text-xs text-gray-400">
                  {new Date(variance.month).toLocaleDateString('en-IN', { month: 'long', year: 'numeric' })}
                </span>
              )}
            </div>
            <EnhancedCommittedBudgetCard
              session={session}
              committedBudget={committedBudget}
              variance={variance}
            />
          </div>
        ) : (
          <div className="px-4">
            <div className={`${glassCardPrimary} p-8 text-center`}>
              <span className="text-5xl mb-4 block">📊</span>
              <h3 className="text-lg font-semibold text-white mb-2">No Budget Committed</h3>
              <p className="text-sm text-gray-400">
                Commit to a budget plan below to start tracking your spending against your goals.
              </p>
            </div>
          </div>
        )}

        {/* Recommendations Section */}
        <div className="space-y-4 px-4">
          <h2 className="text-xl font-bold text-white">
            {committedBudget ? 'Other Recommendations' : 'Recommended Budget Plans'}
          </h2>

          {isRecommendationsLoading ? (
            <div className="flex items-center justify-center py-20">
              <div className="animate-spin rounded-full h-12 w-12 border-t-2 border-b-2 border-[#D4AF37]"></div>
            </div>
          ) : recommendationsError ? (
            <div className="flex flex-col items-center justify-center py-20 gap-4">
              <div className="text-red-400 text-center">
                <p className="text-lg font-bold mb-2">Unable to Load Recommendations</p>
                <p className="text-sm">{recommendationsError}</p>
              </div>
              <button
                onClick={loadData}
                className="px-6 py-2 bg-[#D4AF37] text-black rounded-lg font-medium hover:bg-[#D4AF37]/90 transition-colors"
              >
                Retry
              </button>
            </div>
          ) : recommendations.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-20 gap-4">
              <span className="text-5xl">📊</span>
              <p className="text-lg font-semibold text-white">No Recommendations Available</p>
              <p className="text-sm text-gray-400 text-center px-8">
                Budget recommendations will appear here once you have spending data and goals set up.
              </p>
            </div>
          ) : (
            <div className="space-y-4">
              {recommendations.map((recommendation) => (
                <EnhancedBudgetRecommendationCard
                  key={recommendation.plan_code}
                  recommendation={recommendation}
                  isCommitted={
                    committedBudget?.plan_code === recommendation.plan_code
                  }
                  isCommitting={
                    isCommitting && committingPlanCode === recommendation.plan_code
                  }
                  onCommit={() => handleCommit(recommendation.plan_code)}
                  onCompare={() => setComparingRecommendation(recommendation)}
                />
              ))}
            </div>
          )}
        </div>
      </div>

      {/* Comparison Modal */}
      {comparingRecommendation && (
        <BudgetComparisonModal
          committedBudget={committedBudget}
          recommendation={comparingRecommendation}
          isOpen={!!comparingRecommendation}
          onClose={() => setComparingRecommendation(null)}
        />
      )}
    </div>
  )
}
