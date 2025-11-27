import { useState } from 'react'
import './App.css'
import { LoginForm } from './auth/components/LoginForm'
import { useAuth } from './auth/hooks/useAuth'
import monytixLogoSvg from './assets/monytix-logo.svg'
import monytixLogoPng from './assets/monytix-logo.png'
import { MolyConsole } from './features/molyconsole/MolyConsole'
import { SpendSenseScreen } from './features/spendsense/SpendSenseScreen'
import { SettingsScreen } from './features/settings/SettingsScreen'

function App() {
  const { user, session, loading, signIn, signUp, signInWithGoogle, signOut } = useAuth()
  const [activeView, setActiveView] = useState<'console' | 'spendsense' | 'settings'>('console')
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
              {activeView === 'console' ? 'MolyConsole' : activeView === 'spendsense' ? 'SpendSense' : 'Settings'}
            </h2>
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
          ) : (
            <SettingsScreen session={session} />
          )}
        </main>
        <div className={`nav-overlay ${navOpen ? 'nav-overlay--open' : ''}`}>
          <nav className="nav-drawer glass-card">
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
