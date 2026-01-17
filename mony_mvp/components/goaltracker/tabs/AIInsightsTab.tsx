'use client'

import { useState, useEffect } from 'react'
import type { Session } from '@supabase/supabase-js'
import { fetchUserGoals, fetchGoalProgress } from '@/lib/api/goals'
import type { GoalResponse, GoalProgressItem, AIInsight } from '@/types/goals'
import GoalAIInsightCard from '../components/GoalAIInsightCard'

interface AIInsightsTabProps {
  session: Session
}

export default function AIInsightsTab({ session }: AIInsightsTabProps) {
  const [goals, setGoals] = useState<GoalResponse[]>([])
  const [progress, setProgress] = useState<GoalProgressItem[]>([])
  const [insights, setInsights] = useState<AIInsight[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const loadData = async () => {
      try {
        const [goalsData, progressData] = await Promise.all([
          fetchUserGoals(session),
          fetchGoalProgress(session),
        ])
        setGoals(goalsData)
        setProgress(progressData)
        generateMockInsights(goalsData, progressData)
      } catch (err) {
        console.error('Error loading data for insights:', err)
      } finally {
        setLoading(false)
      }
    }
    loadData()
  }, [session])

  const generateMockInsights = (
    goalsData: GoalResponse[],
    progressData: GoalProgressItem[]
  ) => {
    const mockInsights: AIInsight[] = []

    const completedGoals = goalsData.filter((g) => g.status.toLowerCase() === 'completed')
    const activeGoals = goalsData.filter((g) => g.status.toLowerCase() === 'active')

    // Achievement insight
    if (completedGoals.length > 0 && goalsData.length > 0) {
      const completionRate = (completedGoals.length / goalsData.length) * 100
      mockInsights.push({
        id: '1',
        title: 'Goal Achievement Rate',
        message: `You're on track to complete ${Math.round(completionRate)}% of your goals this year!`,
        type: 'goalProgress',
        priority: 'high',
        createdAt: new Date(Date.now() - 2 * 60 * 60 * 1000).toISOString(), // 2 hours ago
        category: null,
      })
    }

    // Optimization insight
    if (activeGoals.length > 0 && progressData.length > 0) {
      const activeGoal = activeGoals[0]
      const goalProgress = progressData.find((p) => p.goal_id === activeGoal.goal_id)
      if (goalProgress && goalProgress.remaining_amount > 50000) {
        mockInsights.push({
          id: '2',
          title: 'Savings Optimization',
          message: `Consider increasing your ${activeGoal.goal_name.toLowerCase()} contribution by ₹5,000/month to reach your goal faster.`,
          type: 'savingsOpportunity',
          priority: 'medium',
          createdAt: new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString(), // 1 day ago
          category: activeGoal.goal_name,
        })
      }
    }

    // Milestone insight
    const milestoneGoal = progressData.find((p) => p.progress_pct >= 70 && p.progress_pct < 100)
    if (milestoneGoal) {
      mockInsights.push({
        id: '3',
        title: 'Goal Milestone',
        message: `Congratulations! You've reached ${Math.round(milestoneGoal.progress_pct)}% of your ${milestoneGoal.goal_name.toLowerCase()} goal.`,
        type: 'goalProgress',
        priority: 'low',
        createdAt: new Date(Date.now() - 3 * 24 * 60 * 60 * 1000).toISOString(), // 3 days ago
        category: milestoneGoal.goal_name,
      })
    }

    // Default tip if no insights
    if (mockInsights.length === 0) {
      mockInsights.push({
        id: '4',
        title: 'Getting Started',
        message: 'Set up your first goal to start tracking your financial progress!',
        type: 'budgetTip',
        priority: 'low',
        createdAt: new Date().toISOString(),
        category: null,
      })
    }

    // Sort by creation date (newest first)
    setInsights(
      mockInsights.sort((a, b) => {
        const dateA = a.createdAt ? new Date(a.createdAt).getTime() : 0
        const dateB = b.createdAt ? new Date(b.createdAt).getTime() : 0
        return dateB - dateA
      })
    )
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center py-20">
        <div className="animate-spin rounded-full h-12 w-12 border-t-2 border-b-2 border-[#D4AF37]"></div>
      </div>
    )
  }

  return (
    <div className="space-y-5 pb-6">
      {/* Header */}
      <div className="px-4 pt-4 space-y-2">
        <h2 className="text-xl font-bold text-white">AI Insights</h2>
        <p className="text-sm text-gray-400">
          Personalized recommendations and insights based on your goals
        </p>
      </div>

      {/* Insights List */}
      {insights.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-20 gap-4">
          <span className="text-5xl">🧠</span>
          <p className="text-lg font-semibold text-white">No Insights Yet</p>
          <p className="text-sm text-gray-400 text-center px-8">
            AI insights will appear here as you progress with your goals.
          </p>
        </div>
      ) : (
        <div className="space-y-3 px-4">
          {insights.map((insight) => (
            <GoalAIInsightCard key={insight.id} insight={insight} />
          ))}
        </div>
      )}
    </div>
  )
}
