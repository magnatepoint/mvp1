'use client'

import { useEffect, useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import SplashScreen from '@/components/SplashScreen'
import AuthScreen from '@/components/AuthScreen'
import MolyConsole from '@/components/MolyConsole'
import SpendSense from '@/components/SpendSense'
import GoalTracker from '@/components/goaltracker/GoalTracker'
import BudgetPilot from '@/components/budgetpilot/BudgetPilot'
import MoneyMoments from '@/components/moneymoments/MoneyMoments'
import Settings from '@/components/settings/Settings'
import Navigation from '@/components/navigation/Navigation'
import type { Session } from '@supabase/supabase-js'

export type Screen = 'molyconsole' | 'spendsense' | 'goaltracker' | 'budgetpilot' | 'moneymoments' | 'settings'

export default function Home() {
  const [showSplash, setShowSplash] = useState(true)
  const [session, setSession] = useState<Session | null>(null)
  const [loading, setLoading] = useState(true)
  const [currentScreen, setCurrentScreen] = useState<Screen>('molyconsole')
  const supabase = createClient()

  useEffect(() => {
    // Check for existing session
    supabase.auth.getSession().then(({ data: { session } }) => {
      setSession(session)
      setLoading(false)
    })

    // Listen for auth changes
    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((_event, session) => {
      setSession(session)
      if (session) {
        // Validate session with backend
        validateSessionWithBackend(session)
      }
    })

    return () => subscription.unsubscribe()
  }, [])

  const validateSessionWithBackend = async (session: Session) => {
    try {
      // Validate API URL - should not contain paths and should point to API domain
      const rawApiUrl = process.env.NEXT_PUBLIC_API_URL || 'https://api.monytix.ai'
      let API_BASE_URL = rawApiUrl.split('/').slice(0, 3).join('/') // Remove any paths
      
      // Check if hostname is wrong (points to frontend instead of API)
      const urlObj = new URL(API_BASE_URL)
      const isWrongHostname = urlObj.hostname === 'mvp.monytix.ai' || urlObj.hostname.includes('mvp.monytix.ai')
      
      // If hostname is wrong, use the correct default API URL
      if (isWrongHostname) {
        console.error('[Debug] ⚠️ CRITICAL: NEXT_PUBLIC_API_URL points to frontend domain!')
        console.error('[Debug] Current value:', rawApiUrl)
        console.error('[Debug] Using fallback: https://api.monytix.ai')
        console.error('[Debug] Fix in Cloudflare Pages → Settings → Environment Variables')
        API_BASE_URL = 'https://api.monytix.ai'
      }
      
      console.log('[Debug] API URL:', API_BASE_URL)
      
      const response = await fetch(`${API_BASE_URL}/auth/session`, {
        method: 'GET',
        headers: {
          Authorization: `Bearer ${session.access_token}`,
        },
      })

      if (response.ok) {
        // Session is valid, user can access the app
        console.log('Session validated with backend')
      } else {
        // Session invalid, sign out
        console.warn('Session validation failed:', response.status, response.statusText)
        await supabase.auth.signOut()
        setSession(null)
      }
    } catch (error) {
      console.error('Failed to validate session:', error)
      // Don't sign out on network errors - might be temporary connectivity issue
      if (error instanceof TypeError && error.message === 'Failed to fetch') {
        console.error('Network error - check if NEXT_PUBLIC_API_URL is set correctly in Cloudflare Pages environment variables')
        console.error('Current API URL:', process.env.NEXT_PUBLIC_API_URL || 'https://api.monytix.ai (default)')
      }
    }
  }

  const handleSplashComplete = () => {
    setShowSplash(false)
  }

  const handleSignOut = async () => {
    await supabase.auth.signOut()
    setSession(null)
  }

  if (showSplash) {
    return <SplashScreen onComplete={handleSplashComplete} />
  }

  if (loading) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-black">
        <div className="text-white">Loading...</div>
      </div>
    )
  }

  if (!session) {
    return <AuthScreen />
  }

  // User is authenticated - show current screen with navigation
  return (
    <div className="relative min-h-screen">
      {/* Navigation Component */}
      <Navigation
        currentScreen={currentScreen}
        session={session}
        onNavigate={(screen) => setCurrentScreen(screen)}
        onSignOut={handleSignOut}
      />

      {/* Main Content Area */}
      <div className="min-h-screen bg-[#2E2E2E]">
        {/* Desktop: Add left margin for sidebar */}
        <div className="md:ml-64">
          {/* Mobile: Add bottom padding for bottom nav */}
          <div className="pb-16 md:pb-0">
            {currentScreen === 'molyconsole' && (
              <MolyConsole session={session} onSignOut={handleSignOut} />
            )}
            {currentScreen === 'spendsense' && <SpendSense session={session} />}
            {currentScreen === 'goaltracker' && <GoalTracker session={session} />}
            {currentScreen === 'budgetpilot' && <BudgetPilot session={session} />}
            {currentScreen === 'moneymoments' && <MoneyMoments session={session} />}
            {currentScreen === 'settings' && (
              <Settings session={session} onSignOut={handleSignOut} />
            )}
          </div>
        </div>
      </div>
    </div>
  )
}
