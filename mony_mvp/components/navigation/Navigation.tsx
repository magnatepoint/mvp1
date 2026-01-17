'use client'

import { useMediaQuery } from '@/hooks/useMediaQuery'
import type { Screen } from '@/app/page'
import type { Session } from '@supabase/supabase-js'
import BottomNavBar from './BottomNavBar'
import SidebarNav from './SidebarNav'

interface NavigationProps {
  currentScreen: Screen
  session: Session
  onNavigate: (screen: Screen) => void
  onSignOut: () => void
}

export default function Navigation({
  currentScreen,
  session,
  onNavigate,
  onSignOut,
}: NavigationProps) {
  const isDesktop = useMediaQuery(768)

  if (isDesktop) {
    return (
      <SidebarNav
        currentScreen={currentScreen}
        session={session}
        onNavigate={onNavigate}
        onSignOut={onSignOut}
      />
    )
  }

  return <BottomNavBar currentScreen={currentScreen} onNavigate={onNavigate} />
}
