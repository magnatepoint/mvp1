import { useState } from 'react'
import type { Session } from '@supabase/supabase-js'
import { SpendSensePanel } from './SpendSensePanel'
import { env } from '../../env'
import './SpendSensePanel.css'

type Props = {
  session: Session
}

export function SpendSenseScreen({ session }: Props) {
  const [triggering, setTriggering] = useState(false)
  const [jobMessage, setJobMessage] = useState<string | null>(null)

  const handleTrigger = async () => {
    setTriggering(true)
    setJobMessage(null)
    try {
      const response = await fetch(`${env.apiBaseUrl}/spendsense/re-enrich`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${session.access_token}`,
        },
      })
      if (!response.ok) {
        const body = await response.json().catch(() => ({}))
        throw new Error(body.detail ?? 'Failed to trigger normalization')
      }
      const data = (await response.json().catch(() => ({}))) as { enriched_count?: number }
      const count = data?.enriched_count ?? 0
      setJobMessage(count ? `Re-enriched ${count} transactions` : 'Normalization job triggered')
    } catch (error) {
      setJobMessage(error instanceof Error ? error.message : 'Unexpected error')
    } finally {
      setTriggering(false)
    }
  }

  return (
    <section className="spendsense-screen">
      <header className="glass-card spendsense-screen__hero">
        <div>
          <p className="eyebrow">SpendSense</p>
          <h1>Transaction engine cockpit</h1>
          <p className="text-muted">
            Monitor ingestion pipelines, run manual uploads, and inspect enrichment accuracy.
          </p>
        </div>
        <div className="spendsense__heroActions">
          <button className="primary-button" onClick={handleTrigger} disabled={triggering}>
            {triggering ? 'Running…' : 'Trigger normalization job'}
          </button>
          {jobMessage && (
            <p className="spendsense__heroHint" aria-live="polite">
              {jobMessage}
            </p>
          )}
        </div>
      </header>

      <SpendSensePanel session={session} />
    </section>
  )
}

