'use client'

import { useEffect, useState } from 'react'
import { env } from '../env'
import type { Session } from '@supabase/supabase-js'

type Props = {
  session: Session
}

type SessionState =
  | { status: 'idle' }
  | { status: 'loading' }
  | { status: 'success'; payload: { user_id: string; email?: string | null } }
  | { status: 'error'; message: string }

export function SessionStatus({ session }: Props) {
  const [state, setState] = useState<SessionState>({ status: 'idle' })

  useEffect(() => {
    const controller = new AbortController()

    const fetchSession = async () => {
      setState({ status: 'loading' })
      try {
        const response = await fetch(`${env.apiBaseUrl}/auth/session`, {
          method: 'GET',
          headers: {
            Authorization: `Bearer ${session.access_token}`,
          },
          signal: controller.signal,
        })

        if (!response.ok) {
          throw new Error('Backend rejected Supabase token')
        }

        const payload = (await response.json()) as { user_id: string; email?: string | null }
        setState({ status: 'success', payload })
      } catch (error) {
        setState({
          status: 'error',
          message: error instanceof Error ? error.message : 'Unknown error',
        })
      }
    }

    void fetchSession()

    return () => {
      controller.abort()
    }
  }, [session])

  if (state.status === 'loading' || state.status === 'idle') {
    return <p className="status-loading">Validating session with backend…</p>
  }

  if (state.status === 'error') {
    return <p className="error-message">{state.message}</p>
  }

  return (
    <div className="glass-card floating-card session-card">
      <p>
        <strong>Backend verification complete</strong>
      </p>
      <p>
        Session linked to <span style={{ color: 'var(--color-gold)' }}>{state.payload.user_id}</span>
      </p>
      {state.payload.email ? <small>{state.payload.email}</small> : null}
    </div>
  )
}

