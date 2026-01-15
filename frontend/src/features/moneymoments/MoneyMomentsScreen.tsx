import React, { useCallback, useEffect, useState } from 'react'
import type { Session } from '@supabase/supabase-js'
import { fetchMoneyMoments, computeMoneyMoments, fetchNudges, evaluateNudges, processNudges, computeSignal } from '../../api/moneymoments'
import type { MoneyMoment, Nudge } from '../../types/moneymoments'
import { SkeletonLoader } from '../../components/SkeletonLoader'
import { useToast } from '../../components/Toast'
import { TrendingUp, AlertCircle, Info, Sparkles } from 'lucide-react'
import './MoneyMomentsScreen.css'

type Props = {
  session: Session
}

export const MoneyMomentsScreen: React.FC<Props> = ({ session }) => {
  const { showToast } = useToast()
  const [moments, setMoments] = useState<MoneyMoment[]>([])
  const [nudges, setNudges] = useState<Nudge[]>([])
  const [loading, setLoading] = useState(true)
  const [computing, setComputing] = useState(false)
  const [processingNudges, setProcessingNudges] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const loadData = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const [momentsRes, nudgesRes] = await Promise.all([
        fetchMoneyMoments(session),
        fetchNudges(session),
      ])
      setMoments(momentsRes.moments)
      setNudges(nudgesRes.nudges)
    } catch (err) {
      console.error('Error loading money moments:', err)
      setError(err instanceof Error ? err.message : 'Failed to load money moments')
      showToast('Failed to load money moments', 'error')
    } finally {
      setLoading(false)
    }
  }, [session, showToast])

  useEffect(() => {
    void loadData()
  }, [loadData])

  const handleCompute = async () => {
    setComputing(true)
    try {
      const result = await computeMoneyMoments(session)
      setMoments(result.moments)
      showToast(`Computed ${result.count} money moments!`, 'success')
      void loadData() // Reload to get updated data
    } catch (err) {
      console.error('Error computing moments:', err)
      showToast(err instanceof Error ? err.message : 'Failed to compute moments', 'error')
    } finally {
      setComputing(false)
    }
  }

  const handleProcessNudges = async () => {
    setProcessingNudges(true)
    try {
      // First compute signal if needed
      try {
        await computeSignal(session)
      } catch (err) {
        console.warn('Signal computation failed (may not be critical):', err)
        // Continue even if signal computation fails
      }

      // Then evaluate rules
      const evalResult = await evaluateNudges(session)
      showToast(`Evaluated ${evalResult.count} nudge candidates`, 'success')

      // Then process and deliver
      const processResult = await processNudges(session, 10)
      showToast(`Processed and delivered ${processResult.count} nudges!`, 'success')

      // Reload nudges
      void loadData()
    } catch (err) {
      console.error('Error processing nudges:', err)
      const errorMessage = err instanceof Error
        ? (err as any).isNetworkError
          ? err.message
          : err.message
        : 'Failed to process nudges'
      showToast(errorMessage, 'error')
    } finally {
      setProcessingNudges(false)
    }
  }

  const getIcon = (habitId: string) => {
    if (habitId.includes('burn_rate') || habitId.includes('spend_to_income')) {
      return <TrendingUp size={20} className="moment-icon" />
    }
    if (habitId.includes('micro') || habitId.includes('cash')) {
      return <Info size={20} className="moment-icon" />
    }
    return <AlertCircle size={20} className="moment-icon" />
  }

  const getConfidenceColor = (confidence: number) => {
    if (confidence >= 0.7) return 'high'
    if (confidence >= 0.5) return 'medium'
    return 'low'
  }

  if (loading) {
    return (
      <section className="moneymoments-screen">
        <h1>MoneyMoments</h1>
        <SkeletonLoader height={200} width="100%" />
      </section>
    )
  }

  if (error) {
    return (
      <section className="moneymoments-screen">
        <h1>MoneyMoments</h1>
        <div className="error-message">{error}</div>
      </section>
    )
  }

  return (
    <section className="moneymoments-screen">
      <div className="moneymoments-header">
        <h1>MoneyMoments</h1>
        <p className="moneymoments-subtitle">
          Discover your spending patterns and behavioral insights
        </p>
        <div className="action-buttons">
          <button
            className="compute-button"
            onClick={() => void handleCompute()}
            disabled={computing}
          >
            {computing ? 'Computing...' : 'Compute Moments'}
          </button>
          <button
            className="compute-button secondary"
            onClick={() => void handleProcessNudges()}
            disabled={processingNudges}
          >
            {processingNudges ? 'Processing...' : 'Evaluate & Deliver Nudges'}
          </button>
        </div>
      </div>

      {moments.length > 0 ? (
        <div className="moments-section">
          <h2>Your Behavioral Insights</h2>
          <div className="moments-grid">
            {moments.map((moment) => (
              <div key={moment.habit_id} className="moment-card">
                <div className="moment-header">
                  {getIcon(moment.habit_id)}
                  <div className="moment-title-section">
                    <h3>{moment.label}</h3>
                    <span className={`confidence-badge confidence-${getConfidenceColor(moment.confidence)}`}>
                      {Math.round(moment.confidence * 100)}% confidence
                    </span>
                  </div>
                </div>
                <p className="moment-insight">{moment.insight_text}</p>
                <div className="moment-meta">
                  <span className="moment-value">
                    {moment.habit_id.includes('ratio') || moment.habit_id.includes('share')
                      ? `${(moment.value * 100).toFixed(1)}%`
                      : moment.habit_id.includes('count')
                        ? `${moment.value.toFixed(0)}`
                        : `₹${moment.value.toLocaleString('en-IN')}`}
                  </span>
                  <span className="moment-habit-id">{moment.habit_id.replace(/_/g, ' ')}</span>
                </div>
              </div>
            ))}
          </div>
        </div>
      ) : (
        <div className="no-moments">
          <p>No moments computed yet. Click "Compute Moments" to analyze your spending patterns.</p>
        </div>
      )}

      <div className="nudges-section">
        <h2>Recent Nudges</h2>
        {nudges.length > 0 ? (
          <div className="nudges-list">
            {nudges.map((nudge) => (
              <div key={nudge.delivery_id} className="nudge-card">
                <div className="nudge-header">
                  <Sparkles size={16} className="nudge-icon" />
                  <span className="nudge-rule">{nudge.rule_name}</span>
                  <span className="nudge-time">
                    {new Date(nudge.sent_at).toLocaleDateString('en-IN')}
                  </span>
                </div>
                <h3 className="nudge-title">{nudge.title || nudge.title_template || 'Nudge'}</h3>
                <p className="nudge-body">{nudge.body || nudge.body_template || ''}</p>
                {nudge.cta_text && (
                  <button className="nudge-cta">{nudge.cta_text}</button>
                )}
              </div>
            ))}
          </div>
        ) : (
          <div className="no-nudges">
            <p>No nudges delivered yet. Click "Evaluate & Deliver Nudges" to generate personalized nudges based on your spending patterns.</p>
          </div>
        )}
      </div>
    </section>
  )
}

