import { useState } from 'react'
import './App.css'
import { LoginForm } from './auth/components/LoginForm'
import { useAuth } from './auth/hooks/useAuth'
import monytixLogoSvg from './assets/monytix-logo.svg'
import monytixLogoPng from './assets/monytix-logo.png'
import { MolyConsole } from './features/molyconsole/MolyConsole'
import { SpendSenseScreen } from './features/spendsense/SpendSenseScreen'
import { SettingsScreen } from './features/settings/SettingsScreen'
import { GoalsScreen } from './features/goals/GoalsScreen'
import { GoalCompassScreen } from './features/goalcompass/GoalCompassScreen'
import { BudgetPilotScreen } from './features/budgetpilot/BudgetPilotScreen'
import { MoneyMomentsScreen } from './features/moneymoments/MoneyMomentsScreen'
import { ToastProvider } from './components/Toast'
import { Compass, Wallet, Target, Settings, Menu, X, Plane, MessageSquare } from 'lucide-react'

function App() {
  return (
    <ToastProvider>
      <AppContent />
    </ToastProvider>
  )
}

function AppContent() {
  const { user, session, loading, signIn, signUp, signInWithGoogle, signOut } = useAuth()
  const [activeView, setActiveView] = useState<'console' | 'spendsense' | 'goals' | 'goalcompass' | 'budgetpilot' | 'moneymoments' | 'settings'>('console')
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
            {navOpen ? <X size={20} /> : <Menu size={20} />}
          </button>
      <div className="top-bar__content">
      <div>
            <p className="eyebrow">Monytix</p>
            <h2 className="top-bar__title">
              {activeView === 'console' ? 'MolyConsole' : activeView === 'spendsense' ? 'SpendSense' : activeView === 'goals' ? 'Goals' : activeView === 'goalcompass' ? 'GoalCompass' : activeView === 'budgetpilot' ? 'BudgetPilot' : activeView === 'moneymoments' ? 'MoneyMoments' : 'Settings'}
            </h2>
            </div>
            <nav className="top-bar__menu">
              <button
                className={`top-menu-link ${activeView === 'console' ? 'top-menu-link--active' : ''}`}
                onClick={() => setActiveView('console')}
                aria-label="Console"
              >
                <Compass size={16} />
                <span>Console</span>
              </button>
              <button
                className={`top-menu-link ${activeView === 'spendsense' ? 'top-menu-link--active' : ''}`}
                onClick={() => setActiveView('spendsense')}
                aria-label="SpendSense"
              >
                <Wallet size={16} />
                <span>SpendSense</span>
              </button>
              <button
                className={`top-menu-link ${activeView === 'goals' ? 'top-menu-link--active' : ''}`}
                onClick={() => setActiveView('goals')}
                aria-label="Goals"
              >
                <Target size={16} />
                <span>Goals</span>
              </button>
              <button
                className={`top-menu-link ${activeView === 'goalcompass' ? 'top-menu-link--active' : ''}`}
                onClick={() => setActiveView('goalcompass')}
                aria-label="GoalCompass"
              >
                <Compass size={16} />
                <span>GoalCompass</span>
              </button>
              <button
                className={`top-menu-link ${activeView === 'budgetpilot' ? 'top-menu-link--active' : ''}`}
                onClick={() => setActiveView('budgetpilot')}
                aria-label="BudgetPilot"
              >
                <Plane size={16} />
                <span>BudgetPilot</span>
              </button>
              <button
                className={`top-menu-link ${activeView === 'moneymoments' ? 'top-menu-link--active' : ''}`}
                onClick={() => setActiveView('moneymoments')}
                aria-label="MoneyMoments"
              >
                <MessageSquare size={16} />
                <span>MoneyMoments</span>
              </button>
              <button
                className={`top-menu-link ${activeView === 'settings' ? 'top-menu-link--active' : ''}`}
                onClick={() => setActiveView('settings')}
                aria-label="Settings"
              >
                <Settings size={16} />
                <span>Settings</span>
              </button>
            </nav>
      </div>
          <button className="ghost-button" onClick={() => void signOut()}>
            Sign out
          </button>
        </header>
        <main className="console-shell">
          {activeView === 'console' ? (
            <MolyConsole user={user} session={session} onSignOut={() => void signOut()} />
          ) : activeView === 'spendsense' ? (
            <SpendSenseScreen session={session} />
          ) : activeView === 'goals' ? (
            <GoalsScreen session={session} />
          ) : activeView === 'goalcompass' ? (
            <GoalCompassScreen session={session} />
          ) : activeView === 'budgetpilot' ? (
            <BudgetPilotScreen session={session} />
          ) : activeView === 'moneymoments' ? (
            <MoneyMomentsScreen session={session} />
          ) : (
            <SettingsScreen session={session} />
          )}
        </main>
        <div className={`nav-overlay ${navOpen ? 'nav-overlay--open' : ''}`}>
          <nav className="nav-drawer glass-card">
            <div className="nav-drawer__header">
              <p className="eyebrow">Navigate</p>
              <button
                className="nav-drawer__close"
                onClick={() => setNavOpen(false)}
                aria-label="Close navigation"
              >
                <X size={20} />
              </button>
            </div>
            <ul>
              <li>
                <button
                  className={activeView === 'console' ? 'nav-link nav-link--active' : 'nav-link'}
                  onClick={() => {
                    setActiveView('console')
                    setNavOpen(false)
                  }}
                >
                  <Compass size={18} />
                  <span>MolyConsole</span>
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
                  <Wallet size={18} />
                  <span>SpendSense</span>
                </button>
              </li>
              <li>
                <button
                  className={activeView === 'goals' ? 'nav-link nav-link--active' : 'nav-link'}
                  onClick={() => {
                    setActiveView('goals')
                    setNavOpen(false)
                  }}
                >
                  <Target size={18} />
                  <span>Goals</span>
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
                  <Compass size={18} />
                  <span>GoalCompass</span>
                </button>
              </li>
              <li>
                <button
                  className={activeView === 'budgetpilot' ? 'nav-link nav-link--active' : 'nav-link'}
                  onClick={() => {
                    setActiveView('budgetpilot')
                    setNavOpen(false)
                  }}
                >
                  <Plane size={18} />
                  <span>BudgetPilot</span>
                </button>
              </li>
              <li>
                <button
                  className={activeView === 'moneymoments' ? 'nav-link nav-link--active' : 'nav-link'}
                  onClick={() => {
                    setActiveView('moneymoments')
                    setNavOpen(false)
                  }}
                >
                  <MessageSquare size={18} />
                  <span>MoneyMoments</span>
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
                  <Settings size={18} />
                  <span>Settings</span>
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
          <picture>
            <source srcSet={monytixLogoSvg} type="image/svg+xml" />
            <img src={monytixLogoPng} alt="Monytix logo" className="brand-logo" />
          </picture>
          <p className="brand-tagline">AI fintech intelligence for high-trust teams</p>
        </div>
        <LoginForm onSubmit={handleSignIn} onRegister={handleRegister} onGoogle={handleGoogle} />
      </section>
    </main>
  )
}

export default App
