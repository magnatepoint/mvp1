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
import { fetchTransactions } from '@/lib/api/spendsense'
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
      // First check if there are any transactions at all
      const transactionsResponse = await fetchTransactions(session, { limit: 1 })
      const hasTransactions = transactionsResponse.total > 0

      if (!hasTransactions) {
        // No transactions - show empty state
        setSummary(null)
        setLoading(false)
        return
      }

      const [kpis, goals, insights] = await Promise.all([
        fetchKPIs(session),
        fetchGoals(session),
        fetchInsights(session),
      ])

      const transformedGoals = transformGoals(goals)
      
      // Only generate insights if there's actual transaction data
      const hasData = !hasNoTransactionData(kpis)
      const aiInsights = hasData ? generateAIInsights(kpis, insights, transformedGoals) : []
      const overview = transformToOverviewSummary(kpis, transformedGoals, aiInsights[0] || undefined)

      setSummary(overview)
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

  return (
    <div className="max-w-7xl mx-auto space-y-6">
      <h2 className="text-xl font-bold text-white mb-4">Quick Overview</h2>

      {/* Summary Cards Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <SummaryCard
          title="Total Balance"
          value={formatCurrency(summary.total_balance)}
          color="green"
          icon="💰"
        />
        <SummaryCard
          title="This Month"
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
