'use client'

import { useEffect, useState } from 'react'
import type { Session } from '@supabase/supabase-js'
import { fetchInsights } from '@/lib/api/spendsense'
import type { InsightsResponse } from '@/types/console'
import DateRangeSelector, { type DateRange } from './components/DateRangeSelector'
import KeyMetricsCards from './components/KeyMetricsCards'
import UncategorizedAlert from './components/UncategorizedAlert'
import OverviewTab from './tabs/OverviewTab'
import TrendsTab from './tabs/TrendsTab'
import PatternsTab from './tabs/PatternsTab'
import FixUncategorizedTab from './tabs/FixUncategorizedTab'
import { ChartSkeleton, MetricCardSkeleton } from './components/LoadingSkeleton'

interface InsightsTabProps {
  session: Session
}

type TabType = 'overview' | 'trends' | 'patterns' | 'fix'

export default function InsightsTab({ session }: InsightsTabProps) {
  const [insights, setInsights] = useState<InsightsResponse | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [activeTab, setActiveTab] = useState<TabType>('overview')
  const [dateRange, setDateRange] = useState<DateRange>(() => {
    const today = new Date()
    const thirtyDaysAgo = new Date(today)
    thirtyDaysAgo.setDate(today.getDate() - 30)
    return {
      startDate: thirtyDaysAgo.toISOString().split('T')[0],
      endDate: today.toISOString().split('T')[0],
      preset: '30d',
    }
  })

  const loadInsights = async () => {
    setLoading(true)
    setError(null)
    try {
      const data = await fetchInsights(session, dateRange.startDate || undefined, dateRange.endDate || undefined)
      setInsights(data)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load insights')
      console.error('Error loading insights:', err)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    loadInsights()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [session, dateRange.startDate, dateRange.endDate])

  const handleCategoryClick = (categoryCode: string) => {
    // Navigate to transactions tab with category filter
    // This would require parent component coordination
    console.log('Category clicked:', categoryCode)
  }

  if (loading) {
    return (
      <div className="max-w-7xl mx-auto space-y-6">
        <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
          <div>
            <div className="h-8 w-48 bg-white/10 rounded mb-2 animate-pulse" />
            <div className="h-4 w-64 bg-white/10 rounded animate-pulse" />
          </div>
        </div>
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
          {[1, 2, 3, 4].map((i) => (
            <MetricCardSkeleton key={i} />
          ))}
        </div>
        <ChartSkeleton />
      </div>
    )
  }

  if (error) {
    return (
      <div className="flex flex-col items-center justify-center py-20 gap-4">
        <div className="text-red-500 text-center">
          <p className="text-lg font-bold mb-2">Unable to Load Insights</p>
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

  if (!insights) {
    return (
      <div className="flex flex-col items-center justify-center py-20 gap-4">
        <span className="text-5xl">💡</span>
        <p className="text-lg font-semibold">No insights available</p>
        <p className="text-sm text-gray-500 dark:text-gray-400">Upload more transactions to see insights</p>
      </div>
    )
  }

  // Calculate uncategorized metrics
  const uncategorized = insights.category_breakdown?.find((cat) => cat.category_code === 'uncategorized')
  const uncategorizedAmount = uncategorized?.amount || 0
  const uncategorizedPercentage = uncategorized?.percentage || 0
  const uncategorizedCount = uncategorized?.transaction_count || 0

  const tabs: { id: TabType; label: string; badge?: number }[] = [
    { id: 'overview', label: 'Overview' },
    { id: 'trends', label: 'Trends' },
    { id: 'patterns', label: 'Patterns' },
    {
      id: 'fix',
      label: 'Fix Uncategorized',
      badge: uncategorizedCount > 0 ? uncategorizedCount : undefined,
    },
  ]

  return (
    <div className="max-w-7xl mx-auto space-y-6">
      {/* Header with Date Range */}
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        <div>
          <h2 className="text-2xl font-bold">Spending Insights</h2>
          <p className="text-sm text-gray-400 mt-1">Analyze your spending patterns and trends</p>
        </div>
        <DateRangeSelector value={dateRange} onChange={setDateRange} />
      </div>

      {/* Key Metrics Cards */}
      <KeyMetricsCards insights={insights} />

      {/* Uncategorized Alert */}
      {uncategorizedPercentage > 10 && (
        <UncategorizedAlert
          amount={uncategorizedAmount}
          percentage={uncategorizedPercentage}
          transactionCount={uncategorizedCount}
          onFixClick={() => setActiveTab('fix')}
        />
      )}

      {/* Tab Navigation */}
      <div className="flex gap-2 border-b border-white/10">
        {tabs.map((tab) => (
          <button
            key={tab.id}
            onClick={() => setActiveTab(tab.id)}
            className={`px-6 py-3 font-medium transition-colors relative ${
              activeTab === tab.id
                ? 'text-[#D4AF37] border-b-2 border-[#D4AF37]'
                : 'text-gray-400 hover:text-white'
            }`}
          >
            {tab.label}
            {tab.badge && (
              <span className="ml-2 px-2 py-0.5 bg-orange-500 text-white text-xs rounded-full">
                {tab.badge}
              </span>
            )}
          </button>
        ))}
      </div>

      {/* Tab Content */}
      <div className="mt-6">
        {activeTab === 'overview' && (
          <OverviewTab
            insights={insights}
            onCategoryClick={handleCategoryClick}
            onFixUncategorized={() => setActiveTab('fix')}
          />
        )}
        {activeTab === 'trends' && <TrendsTab insights={insights} />}
        {activeTab === 'patterns' && <PatternsTab insights={insights} />}
        {activeTab === 'fix' && (
          <FixUncategorizedTab
            session={session}
            uncategorizedCount={uncategorizedCount}
            uncategorizedAmount={uncategorizedAmount}
            uncategorizedPercentage={uncategorizedPercentage}
          />
        )}
      </div>
    </div>
  )
}
