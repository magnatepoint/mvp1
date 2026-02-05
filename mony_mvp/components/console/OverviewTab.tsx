'use client'

import { useEffect, useState } from 'react'
import type { Session } from '@supabase/supabase-js'
import {
  fetchKPIs,
  fetchGoals,
  fetchInsights,
  transformToOverviewSummary,
  transformGoals,
  generateAIInsights,
  hasNoTransactionData,
} from '@/lib/api/console'
import type { OverviewSummary } from '@/types/console'
import { glassCardPrimary } from '@/lib/theme/glass'

interface OverviewTabProps {
  session: Session
}

export default function OverviewTab({ session }: OverviewTabProps) {
  const [summary, setSummary] = useState<OverviewSummary | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const loadData = async () => {
    setLoading(true)
    setError(null)
    try {
      // Phase 1: Load only KPIs + goals so we can paint the 4 cards quickly
      const [kpis, goals] = await Promise.all([
        fetchKPIs(session),
        fetchGoals(session),
      ])

      if (hasNoTransactionData(kpis)) {
        setSummary(null)
        setLoading(false)
        return
      }

      const transformedGoals = transformGoals(goals)
      const overview = transformToOverviewSummary(kpis, transformedGoals, undefined)
      setSummary(overview)
      setLoading(false)
      // Page paints here with the 4 cards; AI insight loads below

      // Phase 2: Load insights in background and add AI insight when ready (no block on paint)
      const now = new Date()
      const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1)
      const endOfMonth = new Date(now.getFullYear(), now.getMonth() + 1, 0)
      const insightsStart = startOfMonth.toISOString().slice(0, 10)
      const insightsEnd = endOfMonth.toISOString().slice(0, 10)

      fetchInsights(session, insightsStart, insightsEnd)
        .then((insights) => {
          const aiInsights = generateAIInsights(kpis, insights, transformedGoals)
          const insight = aiInsights[0]
          if (insight) {
            setSummary((prev) => (prev ? { ...prev, latest_insight: insight } : null))
          }
        })
        .catch((err) => console.error('Insights load failed (overview already shown):', err))
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load overview')
      console.error('Error loading overview:', err)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    loadData()
  }, [session])

  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('en-IN', {
      style: 'currency',
      currency: 'INR',
      maximumFractionDigits: 0,
    }).format(amount)
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center py-20">
        <div className="animate-spin rounded-full h-12 w-12 border-t-2 border-b-2 border-[#D4AF37]"></div>
      </div>
    )
  }

  if (error) {
    return (
      <div className="flex flex-col items-center justify-center py-20 gap-4">
        <div className="text-red-400 text-center">
          <p className="text-lg font-bold mb-2">Unable to Load Overview</p>
          <p className="text-sm">{error}</p>
        </div>
        <button
          onClick={loadData}
          className="px-6 py-2 bg-[#D4AF37] text-black rounded-lg font-medium hover:bg-[#D4AF37]/90 transition-colors"
        >
          Retry
        </button>
      </div>
    )
  }

  if (!summary) {
    return (
      <div className="flex flex-col items-center justify-center py-20 gap-4">
        <p className="text-gray-400">No overview data available</p>
        <p className="text-sm text-gray-500">Upload statements to see your financial overview</p>
      </div>
    )
  }

  const monthName = new Date().toLocaleString('en-IN', { month: 'long' })

  return (
    <div className="max-w-7xl mx-auto space-y-6">
      <h2 className="text-xl font-bold text-white mb-4">Quick Overview</h2>

      {/* Summary Cards Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <SummaryCard
          title={`Net (${monthName})`}
          value={formatCurrency(summary.total_balance)}
          color="green"
          icon="💰"
        />
        <SummaryCard
          title={`${monthName} Spending`}
          value={formatCurrency(summary.this_month_spending)}
          color="red"
          icon="📅"
        />
        <SummaryCard
          title="Savings Rate"
          value={`${summary.savings_rate.toFixed(1)}%`}
          color="green"
          icon="📈"
        />
        <SummaryCard
          title="Active Goals"
          value={summary.active_goals_count.toString()}
          color="gold"
          icon="🎯"
        />
      </div>

      {/* AI Insight Card */}
      {summary.latest_insight && (
        <div className="mt-6">
          <AIInsightCard insight={summary.latest_insight} />
        </div>
      )}
    </div>
  )
}

function SummaryCard({
  title,
  value,
  color,
  icon,
}: {
  title: string
  value: string
  color: string
  icon: string
}) {
  const colorClasses = {
    green: 'text-green-400',
    red: 'text-red-400',
    gold: 'text-[#D4AF37]',
  }

  return (
    <div className={`${glassCardPrimary} p-6`}>
      <div className="flex items-start justify-between mb-4">
        <span className="text-2xl">{icon}</span>
      </div>
      <p className="text-sm text-gray-400 mb-2">{title}</p>
      <p className={`text-2xl font-bold ${colorClasses[color as keyof typeof colorClasses]}`}>
        {value}
      </p>
    </div>
  )
}

function AIInsightCard({ insight }: { insight: any }) {
  const iconMap: Record<string, string> = {
    spending_alert: '⚠️',
    goal_progress: '✅',
    investment_recommendation: '📊',
    budget_tip: '💡',
    savings_opportunity: '💰',
  }

  return (
    <div className={`${glassCardPrimary} p-6`}>
      <div className="flex items-start gap-4">
        <span className="text-2xl">{iconMap[insight.type] || '✨'}</span>
        <div className="flex-1">
          <div className="flex items-center gap-2 mb-2">
            <span className="text-sm font-semibold text-gray-400">AI Insight</span>
          </div>
          <p className="text-white text-base leading-relaxed">{insight.message}</p>
        </div>
      </div>
    </div>
  )
}
