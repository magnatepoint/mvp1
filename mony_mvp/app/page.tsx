'use client'

import { useEffect, useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import SplashScreen from '@/components/SplashScreen'
import AuthScreen from '@/components/AuthScreen'
import MolyConsole from '@/components/MolyConsole'
import SpendSense from '@/components/SpendSense'
import type { Session } from '@supabase/supabase-js'

type Screen = 'molyconsole' | 'spendsense'

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
      const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || 'https://api.monytix.ai'
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
        await supabase.auth.signOut()
        setSession(null)
      }
    } catch (error) {
      console.error('Failed to validate session:', error)
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

  // User is authenticated - show current screen
  if (currentScreen === 'spendsense') {
    return <SpendSense session={session} onBack={() => setCurrentScreen('molyconsole')} />
  }

  return (
    <MolyConsole
      session={session}
      onSignOut={handleSignOut}
      onNavigateToSpendSense={() => setCurrentScreen('spendsense')}
    />
  )
}
