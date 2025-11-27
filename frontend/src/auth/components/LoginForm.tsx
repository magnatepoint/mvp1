import type { FormEvent } from 'react'
import { useState } from 'react'

type Props = {
  onSubmit: (email: string, password: string) => Promise<unknown>
  onRegister: (email: string, password: string) => Promise<unknown>
  onGoogle: () => Promise<unknown>
}

type Mode = 'sign-in' | 'register'

export function LoginForm({ onSubmit, onRegister, onGoogle }: Props) {
  const [mode, setMode] = useState<Mode>('sign-in')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [confirmPassword, setConfirmPassword] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [isSubmitting, setIsSubmitting] = useState(false)

  const handleSubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault()
    setError(null)
    setIsSubmitting(true)
    try {
      if (mode === 'register') {
        if (password !== confirmPassword) {
          throw new Error('Passwords do not match')
        }
        await onRegister(email, password)
      } else {
        await onSubmit(email, password)
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Something went wrong')
    } finally {
      setIsSubmitting(false)
    }
  }

  const handleGoogle = async () => {
    setError(null)
    try {
      await onGoogle()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Something went wrong')
    }
  }

  return (
    <form className="glass-card floating-card auth-form" onSubmit={handleSubmit}>
      <div className="auth-tabs">
        <button
          type="button"
          className={`auth-tab ${mode === 'sign-in' ? 'active' : ''}`}
          onClick={() => setMode('sign-in')}
        >
          Sign in
        </button>
        <button
          type="button"
          className={`auth-tab ${mode === 'register' ? 'active' : ''}`}
          onClick={() => setMode('register')}
        >
          Register
        </button>
      </div>

      <div>
        <p className="eyebrow">{mode === 'sign-in' ? 'Access' : 'Create account'}</p>
        <h1>{mode === 'sign-in' ? 'Sign in' : 'Register'}</h1>
        <p className="subtitle text-muted">
          {mode === 'sign-in'
            ? 'Secure entry into your AI fintech console'
            : 'Launch your AI fintech cockpit in under a minute'}
        </p>
      </div>

      <div className="field-group">
        <span className="field-label">Email</span>
        <div className="input-wrapper">
          <span className="input-icon">@</span>
          <input
            className="input-field"
            type="email"
            value={email}
            onChange={(event) => setEmail(event.target.value)}
            placeholder="you@example.com"
            required
          />
        </div>
      </div>

      <div className="field-group">
        <span className="field-label">Password</span>
        <div className="input-wrapper">
          <span className="input-icon">••</span>
          <input
            className="input-field"
            type="password"
            value={password}
            onChange={(event) => setPassword(event.target.value)}
            placeholder="••••••••"
            required
          />
        </div>
      </div>

      {mode === 'register' ? (
        <div className="field-group">
          <span className="field-label">Confirm password</span>
          <div className="input-wrapper">
            <span className="input-icon">✓</span>
            <input
              className="input-field"
              type="password"
              value={confirmPassword}
              onChange={(event) => setConfirmPassword(event.target.value)}
              placeholder="Re-enter password"
              required
            />
          </div>
        </div>
      ) : null}

      <button className="primary-button" type="submit" disabled={isSubmitting}>
        {isSubmitting
          ? mode === 'sign-in'
            ? 'Signing in…'
            : 'Creating account…'
          : mode === 'sign-in'
            ? 'Continue'
            : 'Register'}
      </button>

      <button type="button" className="google-button" onClick={() => void handleGoogle()}>
        <span className="google-icon">G</span>
        <span>Sign in with Google</span>
      </button>

      {error ? <p className="error-message">{error}</p> : null}
    </form>
  )
}

