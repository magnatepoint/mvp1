'use client'

import { useState } from 'react'
import { LoginForm } from './auth/components/LoginForm'
import { useAuth } from './auth/hooks/useAuth'
import { MolyConsole } from './features/molyconsole/MolyConsole'
import { SpendSenseScreen } from './features/spendsense/SpendSenseScreen'
import { SettingsScreen } from './features/settings/SettingsScreen'
import { GoalCompassScreen } from './features/goalcompass/GoalCompassScreen'
import { ThemeSwitcher } from './components/ThemeSwitcher'

export default function Home() {
  const { user, session, loading, signIn, signUp, signInWithGoogle, signOut } = useAuth()
  const [activeView, setActiveView] = useState<'console' | 'spendsense' | 'goalcompass' | 'settings'>('console')
  const [navOpen, setNavOpen] = useState(false)

  const handleSignIn = async (email: string, password: string) => {
    const error = await signIn(email, password)
    if (error) {
      throw new Error(error.message)
    }
  }

  if (loading) {
    return (
      <main className="app-shell">
        <p className="status-loading">Checking session…</p>
      </main>
    )
  }

  const handleRegister = async (email: string, password: string) => {
    const error = await signUp(email, password)
    if (error) {
      throw new Error(error.message)
    }
  }

  const handleGoogle = async () => {
    const error = await signInWithGoogle()
    if (error) {
      throw new Error(error.message)
    }
  }

  if (user && session) {
    return (
      <div className="authenticated-shell">
        <header className="top-bar glass-card">
          <button
            className={`hamburger ${navOpen ? 'hamburger--open' : ''}`}
            onClick={() => setNavOpen((prev) => !prev)}
            aria-label="Toggle navigation"
          >
            <span />
            <span />
            <span />
          </button>
          <div>
            <p className="eyebrow">Monytix</p>
            <h2 className="top-bar__title">
              {activeView === 'console' ? 'MolyConsole' : activeView === 'spendsense' ? 'SpendSense' : activeView === 'goalcompass' ? 'GoalCompass' : 'Settings'}
            </h2>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
            <ThemeSwitcher />
          <button className="ghost-button" onClick={() => void signOut()}>
            Sign out
          </button>
          </div>
        </header>
        <main className="console-shell">
          {activeView === 'console' ? (
            <MolyConsole user={user} session={session} onSignOut={() => void signOut()} />
          ) : activeView === 'spendsense' ? (
            <SpendSenseScreen session={session} />
          ) : activeView === 'goalcompass' ? (
            <GoalCompassScreen session={session} />
          ) : (
            <SettingsScreen session={session} />
          )}
        </main>
        <div 
          className={`nav-overlay ${navOpen ? 'nav-overlay--open' : ''}`}
          onClick={() => setNavOpen(false)}
        >
          <nav className="nav-drawer glass-card" onClick={(e) => e.stopPropagation()}>
            <p className="eyebrow">Navigate</p>
            <ul>
              <li>
                <button
                  className={activeView === 'console' ? 'nav-link nav-link--active' : 'nav-link'}
                  onClick={() => {
                    setActiveView('console')
                    setNavOpen(false)
                  }}
                >
                  🧭 MolyConsole
                </button>
              </li>
              <li>
                <button
                  className={activeView === 'spendsense' ? 'nav-link nav-link--active' : 'nav-link'}
                  onClick={() => {
                    setActiveView('spendsense')
                    setNavOpen(false)
                  }}
                >
                  💸 SpendSense
                </button>
              </li>
              <li>
                <button
                  className={activeView === 'goalcompass' ? 'nav-link nav-link--active' : 'nav-link'}
                  onClick={() => {
                    setActiveView('goalcompass')
                    setNavOpen(false)
                  }}
                >
                  🧭 GoalCompass
                </button>
              </li>
              <li>
                <button
                  className={activeView === 'settings' ? 'nav-link nav-link--active' : 'nav-link'}
                  onClick={() => {
                    setActiveView('settings')
                    setNavOpen(false)
                  }}
                >
                  ⚙️ Settings
                </button>
              </li>
            </ul>
          </nav>
        </div>
      </div>
    )
  }

  return (
    <main className="app-shell">
      <section className="auth-layout">
        <div className="brand-lockup glass-card">
          <h1 style={{ fontSize: '2rem', fontWeight: 700, margin: 0, background: 'var(--gold-gradient)', WebkitBackgroundClip: 'text', WebkitTextFillColor: 'transparent' }}>
            Monytix
          </h1>
          <p className="brand-tagline">AI fintech intelligence for high-trust teams</p>
        </div>
        <LoginForm onSubmit={handleSignIn} onRegister={handleRegister} onGoogle={handleGoogle} />
      </section>
      </main>
  )
}
