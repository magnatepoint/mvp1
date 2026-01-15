'use client'

import { useState } from 'react'
import type { Session } from '@supabase/supabase-js'
import OverviewTab from './console/OverviewTab'
import AccountsTab from './console/AccountsTab'
import SpendingTab from './console/SpendingTab'
import GoalsTab from './console/GoalsTab'
import AIInsightTab from './console/AIInsightTab'
import WelcomeBanner from './console/WelcomeBanner'
import FileUploadModal from './FileUploadModal'

export type ConsoleTab = 'overview' | 'accounts' | 'spending' | 'goals' | 'aiInsight'

interface MolyConsoleProps {
  session: Session
  onSignOut: () => void
  onNavigateToSpendSense?: () => void
}

export default function MolyConsole({
  session,
  onSignOut,
  onNavigateToSpendSense,
}: MolyConsoleProps) {
  const [selectedTab, setSelectedTab] = useState<ConsoleTab>('overview')
  const [isUploadModalOpen, setIsUploadModalOpen] = useState(false)

  const tabs: { id: ConsoleTab; label: string; icon: string }[] = [
    { id: 'overview', label: 'Overview', icon: '📊' },
    { id: 'accounts', label: 'Accounts', icon: '💳' },
    { id: 'spending', label: 'Spending', icon: '💰' },
    { id: 'goals', label: 'Goals', icon: '🎯' },
    { id: 'aiInsight', label: 'AI Insight', icon: '✨' },
  ]

  const userEmail = session.user.email || 'User'

  return (
    <div className="min-h-screen bg-[#2E2E2E] text-white">
      {/* Welcome Banner */}
      <WelcomeBanner username={userEmail} />

      {/* Custom Tab Bar */}
      <div className="sticky top-0 z-10 bg-[#2E2E2E]/95 backdrop-blur-sm border-b border-white/10">
        <div className="overflow-x-auto scrollbar-hide">
          <div className="flex gap-2 px-4 py-3">
            {tabs.map((tab) => (
              <button
                key={tab.id}
                onClick={() => setSelectedTab(tab.id)}
                className={`flex items-center gap-2 px-4 py-2 rounded-lg font-medium transition-all whitespace-nowrap ${
                  selectedTab === tab.id
                    ? 'bg-[#D4AF37]/20 text-[#D4AF37] border border-[#D4AF37]/30'
                    : 'text-gray-400 hover:text-white hover:bg-white/5'
                }`}
              >
                <span>{tab.icon}</span>
                <span>{tab.label}</span>
              </button>
            ))}
          </div>
        </div>
      </div>

      {/* Tab Content */}
      <div className="p-4">
        {selectedTab === 'overview' && <OverviewTab session={session} />}
        {selectedTab === 'accounts' && <AccountsTab session={session} />}
        {selectedTab === 'spending' && <SpendingTab session={session} />}
        {selectedTab === 'goals' && <GoalsTab session={session} />}
        {selectedTab === 'aiInsight' && <AIInsightTab session={session} />}
      </div>

      {/* Header Actions */}
      <div className="fixed top-4 right-4 z-20 flex gap-2">
        {onNavigateToSpendSense && (
          <button
            onClick={onNavigateToSpendSense}
            className="p-2 rounded-lg bg-white/10 hover:bg-white/20 transition-colors"
            title="SpendSense"
          >
            <svg
              className="w-5 h-5 text-[#D4AF37]"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2}
                d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"
              />
            </svg>
          </button>
        )}
        <button
          onClick={onSignOut}
          className="p-2 rounded-lg bg-white/10 hover:bg-white/20 transition-colors"
          title="Sign Out"
        >
          <svg
            className="w-5 h-5 text-[#D4AF37]"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1"
            />
          </svg>
        </button>
      </div>

      {/* Floating Upload Button */}
      <button
        onClick={() => setIsUploadModalOpen(true)}
        className="fixed bottom-6 right-6 z-20 w-14 h-14 rounded-full bg-[#D4AF37] text-black shadow-lg hover:bg-[#D4AF37]/90 transition-all hover:scale-110 flex items-center justify-center"
        title="Upload Statement"
      >
        <svg
          className="w-6 h-6"
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
        >
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={2}
            d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"
          />
        </svg>
      </button>

      {/* File Upload Modal */}
      <FileUploadModal
        session={session}
        isOpen={isUploadModalOpen}
        onClose={() => setIsUploadModalOpen(false)}
        onUploadComplete={() => {
          // Refresh current tab data
          window.location.reload() // Simple refresh - can be optimized later
        }}
      />
    </div>
  )
}
