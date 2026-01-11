import { useState, useEffect } from 'react'
import type { Session } from '@supabase/supabase-js'
import { AlertCircle, Info, AlertTriangle, CheckCircle2 } from 'lucide-react'
import { fetchGoalSignals } from '../../api/goals'
import type { GoalSignal } from '../../types/goals'
import { SkeletonLoader } from '../SkeletonLoader'
import './GoalInsightsPanel.css'

type Props = {
  session: Session
}

export function GoalInsightsPanel({ session }: Props) {
  const [signals, setSignals] = useState<GoalSignal[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    const loadSignals = async () => {
      setLoading(true)
      setError(null)
      try {
        const data = await fetchGoalSignals(session)
        setSignals(data)
      } catch (err) {
        console.error('Error fetching signals:', err)
        setError(err instanceof Error ? err.message : 'Failed to load insights')
      } finally {
        setLoading(false)
      }
    }

    void loadSignals()
  }, [session])

  const getSeverityIcon = (severity: string) => {
    switch (severity) {
      case 'critical':
        return <AlertCircle size={16} className="text-red-500" />
      case 'warning':
        return <AlertTriangle size={16} className="text-amber-500" />
      case 'info':
        return <Info size={16} className="text-blue-500" />
      default:
        return <Info size={16} className="text-gray-500" />
    }
  }

  const getSeverityStyles = (severity: string) => {
    switch (severity) {
      case 'critical':
        return 'goal-signal--critical'
      case 'warning':
        return 'goal-signal--warning'
      case 'info':
        return 'goal-signal--info'
      default:
        return ''
    }
  }

  if (loading) {
    return (
      <div className="goal-insights-panel">
        <SkeletonLoader height={60} width="100%" style={{ marginBottom: '0.5rem' }} />
        <SkeletonLoader height={60} width="100%" />
      </div>
    )
  }

  if (error) {
    return (
      <div className="goal-insights-panel">
        <p className="text-sm text-gray-500">Failed to load insights: {error}</p>
      </div>
    )
  }

  if (signals.length === 0) {
    return (
      <div className="goal-insights-panel goal-insights-panel--empty">
        <CheckCircle2 size={24} className="text-green-500" />
        <p className="text-sm text-gray-500">No alerts right now 🎉</p>
      </div>
    )
  }

  return (
    <div className="goal-insights-panel">
      {signals.map((signal) => (
        <div
          key={signal.id}
          className={`goal-signal ${getSeverityStyles(signal.severity)}`}
        >
          <div className="goal-signal__header">
            <div className="goal-signal__icon">{getSeverityIcon(signal.severity)}</div>
            <span className="goal-signal__type">{signal.signal_type}</span>
            <span className="goal-signal__time">
              {new Date(signal.created_at).toLocaleDateString('en-IN', {
                month: 'short',
                day: 'numeric',
              })}
            </span>
          </div>
          <p className="goal-signal__message">{signal.message}</p>
        </div>
      ))}
    </div>
  )
}

