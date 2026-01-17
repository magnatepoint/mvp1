'use client'

import type { MoneyMoment, Nudge, AIInsight } from '@/types/moneymoments'
import AIInsightCard from '../components/AIInsightCard'
import { useMemo } from 'react'

interface AIInsightsTabProps {
  moments: MoneyMoment[]
  nudges: Nudge[]
  isLoading: boolean
}

export default function AIInsightsTab({ moments, nudges, isLoading }: AIInsightsTabProps) {
  // Transform moments and nudges into AI insights (mock data for now)
  const insights = useMemo<AIInsight[]>(() => {
    const result: AIInsight[] = []

    // Generate insights from moments
    if (moments.length > 0) {
      const highConfidenceMoments = moments.filter((m) => m.confidence >= 0.7)
      if (highConfidenceMoments.length > 0) {
        result.push({
          id: 'insight-1',
          type: 'progress',
          message: `Great progress! You have ${highConfidenceMoments.length} well-established spending patterns.`,
          timestamp: new Date(),
          icon: '🏆',
        })
      }

      const recentMoment = moments[0]
      if (recentMoment) {
        result.push({
          id: 'insight-2',
          type: 'suggestion',
          message: `Based on your ${recentMoment.label.toLowerCase()}, consider reviewing your ${recentMoment.habit_id.replace(/_/g, ' ')}.`,
          timestamp: new Date(Date.now() - 3600000), // 1 hour ago
          icon: '💡',
        })
      }
    }

    // Generate insights from nudges
    if (nudges.length > 0) {
      result.push({
        id: 'insight-3',
        type: 'milestone',
        message: `You've received ${nudges.length} personalized recommendations. Keep up the great work!`,
        timestamp: new Date(Date.now() - 7200000), // 2 hours ago
        icon: '🎯',
      })
    }

    // If no insights, add a default one
    if (result.length === 0) {
      result.push({
        id: 'insight-default',
        type: 'suggestion',
        message: 'AI insights will appear here based on your spending patterns and habits.',
        timestamp: new Date(),
        icon: '✨',
      })
    }

    // Sort by timestamp (newest first)
    return result.sort((a, b) => b.timestamp.getTime() - a.timestamp.getTime())
  }, [moments, nudges])

  if (isLoading) {
    return (
      <div className="flex items-center justify-center py-20">
        <div className="animate-spin rounded-full h-12 w-12 border-t-2 border-b-2 border-[#D4AF37]"></div>
      </div>
    )
  }

  if (insights.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center py-20 gap-4 px-4">
        <span className="text-5xl">💡</span>
        <p className="text-lg font-semibold text-white">No Insights Yet</p>
        <p className="text-sm text-gray-400 text-center px-8">
          AI insights will appear here based on your spending patterns and habits.
        </p>
      </div>
    )
  }

  return (
    <div className="space-y-6 pb-6">
      <div className="space-y-4 px-4">
        <h2 className="text-xl font-bold text-white">Recent Insights</h2>
        <div className="space-y-4">
          {insights.map((insight) => (
            <AIInsightCard key={insight.id} insight={insight} />
          ))}
        </div>
      </div>
    </div>
  )
}
