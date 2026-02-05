'use client'

import { useEffect, useState } from 'react'
import type { Session } from '@supabase/supabase-js'
import { fetchKPIs, fetchInsights, fetchGoals, transformGoals, generateAIInsights } from '@/lib/api/console'
import { fetchTransactions } from '@/lib/api/spendsense'
import type { AIInsight } from '@/types/console'

interface AIInsightTabProps {
  session: Session
}

export default function AIInsightTab({ session }: AIInsightTabProps) {
  const [insights, setInsights] = useState<AIInsight[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const loadInsights = async () => {
    setLoading(true)
    setError(null)
    try {
      const now = new Date()
      const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1)
      const endOfMonth = new Date(now.getFullYear(), now.getMonth() + 1, 0)
      const startDate = startOfMonth.toISOString().slice(0, 10)
      const endDate = endOfMonth.toISOString().slice(0, 10)

      const [transactionsResponse, kpis, insightsData, goalsData] = await Promise.all([
        fetchTransactions(session, { limit: 1 }),
        fetchKPIs(session),
        fetchInsights(session, startDate, endDate),
        fetchGoals(session),
      ])
      const hasTransactions = transactionsResponse.total > 0
      if (!hasTransactions || !kpis.month) {
        setInsights([])
        setLoading(false)
        return
      }
      const goals = transformGoals(goalsData)
      const aiInsights = generateAIInsights(kpis, insightsData, goals)
      setInsights(aiInsights)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load AI insights')
      console.error('Error loading AI insights:', err)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    loadInsights()
  }, [session])

  const getInsightIcon = (type: string) => {
    const icons: Record<string, string> = {
      spending_alert: '⚠️',
      goal_progress: '✅',
      investment_recommendation: '📊',
      budget_tip: '💡',
      savings_opportunity: '💰',
    }
    return icons[type] || '✨'
  }

  const getInsightColor = (type: string) => {
    const colors: Record<string, string> = {
      spending_alert: 'text-yellow-400',
      goal_progress: 'text-green-400',
      investment_recommendation: 'text-purple-400',
      budget_tip: 'text-blue-400',
      savings_opportunity: 'text-green-400',
    }
    return colors[type] || 'text-gray-400'
  }

  const getPriorityBadge = (priority: string) => {
    const badges: Record<string, { label: string; color: string }> = {
      high: { label: 'High', color: 'bg-red-500/20 text-red-400' },
      medium: { label: 'Medium', color: 'bg-yellow-500/20 text-yellow-400' },
      low: { label: 'Low', color: 'bg-blue-500/20 text-blue-400' },
    }
    return badges[priority] || badges.low
  }

  if (loading && insights.length === 0 && !error) {
    return (
      <div className="max-w-7xl mx-auto space-y-4">
        <h2 className="text-xl font-bold text-white mb-4">AI Insights</h2>
        <div className="space-y-4">
          {[1, 2, 3].map((i) => (
            <div key={i} className="rounded-xl bg-white/5 border border-white/10 p-4 animate-pulse">
              <div className="flex items-center gap-2 mb-2">
                <div className="h-5 w-5 bg-white/10 rounded" />
                <div className="h-4 bg-white/10 rounded w-1/4" />
              </div>
              <div className="h-3 bg-white/10 rounded w-full" />
              <div className="h-3 bg-white/10 rounded w-3/4 mt-2" />
            </div>
          ))}
        </div>
      </div>
    )
  }

  if (error) {
    return (
      <div className="flex flex-col items-center justify-center py-20 gap-4">
        <div className="text-red-400 text-center">
          <p className="text-lg font-bold mb-2">Unable to Load AI Insights</p>
          <p className="text-sm">{error}</p>
        </div>
        <button
          onClick={loadInsights}
          className="px-6 py-2 bg-[#D4AF37] text-black rounded-lg font-medium hover:bg-[#D4AF37]/90 transition-colors"
        >
          Retry
        </button>
      </div>
    )
  }

  if (insights.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center py-20 gap-4">
        <span className="text-5xl">✨</span>
        <p className="text-lg font-semibold text-white">No AI Insights</p>
        <p className="text-sm text-gray-400">Insights will appear as you use the app</p>
      </div>
    )
  }

  return (
    <div className="max-w-7xl mx-auto space-y-4">
      <h2 className="text-xl font-bold text-white mb-4">AI Insights</h2>
      {insights.map((insight) => (
        <div
          key={insight.id}
          className="bg-white/5 backdrop-blur-sm rounded-2xl p-6 border border-white/10"
        >
          <div className="flex items-start gap-4">
            <div className={`text-3xl ${getInsightColor(insight.type)}`}>
              {getInsightIcon(insight.type)}
            </div>
            <div className="flex-1">
              <div className="flex items-center gap-3 mb-2">
                <h3 className="text-lg font-bold text-white">{insight.title}</h3>
                <span
                  className={`px-2 py-1 rounded-full text-xs font-medium ${getPriorityBadge(insight.priority).color}`}
                >
                  {getPriorityBadge(insight.priority).label}
                </span>
              </div>
              <p className="text-gray-300 leading-relaxed">{insight.message}</p>
              {insight.category && (
                <p className="text-sm text-gray-500 mt-2">Category: {insight.category}</p>
              )}
            </div>
          </div>
        </div>
      ))}
    </div>
  )
}
