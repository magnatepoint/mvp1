'use client'

import { useState, useEffect, useMemo } from 'react'
import type { Session } from '@supabase/supabase-js'
import { fetchMoneyMoments, fetchNudges } from '@/lib/api/moneymoments'
import type { MoneyMoment, Nudge, ProgressMetrics } from '@/types/moneymoments'
import MoneyMomentsWelcomeBanner from './MoneyMomentsWelcomeBanner'
import NudgesTab from './tabs/NudgesTab'
import HabitsTab from './tabs/HabitsTab'
import AIInsightsTab from './tabs/AIInsightsTab'

type MoneyMomentsTab = 'nudges' | 'habits' | 'aiInsights'

interface MoneyMomentsProps {
  session: Session
  onBack?: () => void
}

export default function MoneyMoments({ session }: MoneyMomentsProps) {
  const [selectedTab, setSelectedTab] = useState<MoneyMomentsTab>('nudges')
  const [moments, setMoments] = useState<MoneyMoment[]>([])
  const [nudges, setNudges] = useState<Nudge[]>([])
  const [isMomentsLoading, setIsMomentsLoading] = useState(true)
  const [isNudgesLoading, setIsNudgesLoading] = useState(true)
  const [momentsError, setMomentsError] = useState<string | null>(null)
  const [nudgesError, setNudgesError] = useState<string | null>(null)

  const loadData = async () => {
    setIsMomentsLoading(true)
    setIsNudgesLoading(true)
    setMomentsError(null)
    setNudgesError(null)

    try {
      const [momentsData, nudgesData] = await Promise.all([
        fetchMoneyMoments(session).catch((err) => {
          setMomentsError(err instanceof Error ? err.message : 'Failed to load moments')
          return []
        }),
        fetchNudges(session).catch((err) => {
          setNudgesError(err instanceof Error ? err.message : 'Failed to load nudges')
          return []
        }),
      ])

      setMoments(momentsData)
      setNudges(nudgesData)
    } catch (err) {
      console.error('Error loading money moments data:', err)
    } finally {
      setIsMomentsLoading(false)
      setIsNudgesLoading(false)
    }
  }

  useEffect(() => {
    loadData()
  }, [session])

  // Compute progress metrics from moments and nudges
  const progressMetrics = useMemo<ProgressMetrics>(() => {
    // Streak: Calculate based on consecutive months with moments
    let streak = 0
    if (moments.length > 0) {
      const months = [...new Set(moments.map((m) => m.month))].sort().reverse()
      const now = new Date()
      const currentMonth = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`
      
      if (months.includes(currentMonth)) {
        streak = 1
        for (let i = 1; i < months.length; i++) {
          const prevMonth = months[i - 1]
          const currMonth = months[i]
          // Check if months are consecutive
          const prevDate = new Date(prevMonth + '-01')
          const currDate = new Date(currMonth + '-01')
          const monthDiff = (prevDate.getFullYear() - currDate.getFullYear()) * 12 + 
                           (prevDate.getMonth() - currDate.getMonth())
          if (monthDiff === 1) {
            streak++
          } else {
            break
          }
        }
      }
    }

    // Nudges count
    const nudgesCount = nudges.length

    // Habits count (unique habit_ids)
    const habitsCount = new Set(moments.map((m) => m.habit_id)).size

    // Saved amount: Estimate from moments (can be improved with actual savings data)
    const savedAmount = moments
      .filter((m) => m.habit_id.includes('savings') || m.habit_id.includes('assets'))
      .reduce((sum, m) => sum + (m.value > 0 ? m.value : 0), 0)

    return {
      streak,
      nudgesCount,
      habitsCount,
      savedAmount,
    }
  }, [moments, nudges])

  const tabs: { id: MoneyMomentsTab; label: string; icon: string }[] = [
    { id: 'nudges', label: 'Nudges', icon: '🔔' },
    { id: 'habits', label: 'Habits', icon: '🔄' },
    { id: 'aiInsights', label: 'AI Insights', icon: '💡' },
  ]

  const userEmail = session.user.email || null

  return (
    <div className="min-h-screen bg-[#2E2E2E] text-white">
      {/* Welcome Banner */}
      <MoneyMomentsWelcomeBanner username={userEmail} />

      {/* Header */}
      <div className="px-4 pt-4 pb-2">
        <div className="flex items-start justify-between gap-4">
          <div className="flex-1">
            <h1 className="text-3xl font-bold text-white mb-2">MoneyMoments</h1>
            <p className="text-base text-gray-400">
              Behavioral insights and personalized nudges for smarter financial habits
            </p>
          </div>

          {/* Refresh Button */}
          <button
            onClick={loadData}
            disabled={isMomentsLoading || isNudgesLoading}
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

      {/* Custom Tab Bar */}
      <div className="sticky top-0 z-10 bg-[#2E2E2E]/95 backdrop-blur-sm border-b border-white/10">
        <div className="overflow-x-auto scrollbar-hide">
          <div className="flex gap-2 px-4 py-3">
            {tabs.map((tab) => (
              <button
                key={tab.id}
                onClick={() => setSelectedTab(tab.id)}
                className={`flex flex-col items-center gap-2 px-4 py-2 rounded-lg font-medium transition-all whitespace-nowrap relative ${
                  selectedTab === tab.id
                    ? 'text-[#D4AF37]'
                    : 'text-gray-400 hover:text-white hover:bg-white/5'
                }`}
              >
                <div className="flex items-center gap-2">
                  <span>{tab.icon}</span>
                  <span className="font-semibold">{tab.label}</span>
                </div>
                {selectedTab === tab.id && (
                  <div className="absolute bottom-0 left-1/2 transform -translate-x-1/2 w-12 h-0.5 bg-[#D4AF37] rounded-full" />
                )}
              </button>
            ))}
          </div>
        </div>
      </div>

      {/* Tab Content */}
      <div className="mt-4">
        {selectedTab === 'nudges' && (
          <NudgesTab
            session={session}
            nudges={nudges}
            moments={moments}
            progressMetrics={progressMetrics}
            isLoading={isNudgesLoading}
            error={nudgesError}
            onRetry={loadData}
            onNudgesUpdated={loadData}
          />
        )}
        {selectedTab === 'habits' && (
          <HabitsTab
            session={session}
            moments={moments}
            isLoading={isMomentsLoading}
            error={momentsError}
            onRetry={loadData}
            onMomentsUpdated={loadData}
          />
        )}
        {selectedTab === 'aiInsights' && (
          <AIInsightsTab
            moments={moments}
            nudges={nudges}
            isLoading={isMomentsLoading || isNudgesLoading}
          />
        )}
      </div>
    </div>
  )
}
