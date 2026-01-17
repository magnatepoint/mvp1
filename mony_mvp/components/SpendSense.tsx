'use client'

import { useState } from 'react'
import type { Session } from '@supabase/supabase-js'
import CategoriesTab from './spendsense/CategoriesTab'
import TransactionsTab from './spendsense/TransactionsTab'
import InsightsTab from './spendsense/InsightsTab'
import SpendSenseWelcomeBanner from './spendsense/SpendSenseWelcomeBanner'

export type SpendSenseTab = 'categories' | 'transactions' | 'insights'

interface SpendSenseProps {
  session: Session
  onBack?: () => void
}

export default function SpendSense({ session }: SpendSenseProps) {
  const [selectedTab, setSelectedTab] = useState<SpendSenseTab>('categories')

  const tabs: { id: SpendSenseTab; label: string }[] = [
    { id: 'categories', label: 'Categories' },
    { id: 'transactions', label: 'Transactions' },
    { id: 'insights', label: 'Insights' },
  ]

  const userEmail = session.user.email || 'User'

  return (
    <div className="min-h-screen bg-white dark:bg-black text-foreground">
      {/* Header */}
      <div className="sticky top-0 z-10 bg-white/95 dark:bg-black/95 backdrop-blur-sm border-b border-gray-200 dark:border-gray-800">
        <div className="flex items-center justify-between px-4 py-4">
          <h1 className="text-xl font-bold">SpendSense</h1>
        </div>

        {/* Custom Tab Bar */}
        <div className="border-t border-gray-200 dark:border-gray-800">
          <div className="flex">
            {tabs.map((tab) => (
              <button
                key={tab.id}
                onClick={() => setSelectedTab(tab.id)}
                className={`flex-1 px-4 py-3 font-medium transition-all relative ${
                  selectedTab === tab.id
                    ? 'text-foreground border-b-2 border-foreground'
                    : 'text-gray-500 dark:text-gray-400 hover:text-foreground'
                }`}
              >
                {tab.label}
              </button>
            ))}
          </div>
        </div>
      </div>

      {/* Welcome Banner */}
      <SpendSenseWelcomeBanner username={userEmail} />

      {/* Tab Content */}
      <div className="p-4">
        {selectedTab === 'categories' && <CategoriesTab session={session} />}
        {selectedTab === 'transactions' && <TransactionsTab session={session} />}
        {selectedTab === 'insights' && <InsightsTab session={session} />}
      </div>
    </div>
  )
}
