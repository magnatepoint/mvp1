import { useState, useEffect } from 'react'
import type { Session } from '@supabase/supabase-js'
import { Sparkles, TrendingUp, Target, X } from 'lucide-react'
import {
  fetchGoalSuggestions,
  updateGoalSuggestionStatus,
} from '../../api/goals'
import type { GoalSuggestion } from '../../types/goals'
import { SkeletonLoader } from '../SkeletonLoader'
import { useToast } from '../Toast'
import './GoalSuggestionsList.css'

type Props = {
  session: Session
}

export function GoalSuggestionsList({ session }: Props) {
  const { showToast } = useToast()
  const [suggestions, setSuggestions] = useState<GoalSuggestion[]>([])
  const [loading, setLoading] = useState(true)
  const [updating, setUpdating] = useState<string | null>(null)

  const loadSuggestions = async () => {
    setLoading(true)
    try {
      const data = await fetchGoalSuggestions(session)
      setSuggestions(data)
    } catch (err) {
      console.error('Error fetching suggestions:', err)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    void loadSuggestions()
  }, [session])

  const handleStatusChange = async (id: string, status: 'accepted' | 'dismissed') => {
    setUpdating(id)
    try {
      await updateGoalSuggestionStatus(session, id, status)
      showToast(
        status === 'accepted' ? 'Suggestion accepted' : 'Suggestion dismissed',
        'success'
      )
      await loadSuggestions()
    } catch (err) {
      showToast(
        err instanceof Error ? err.message : 'Failed to update suggestion',
        'error'
      )
    } finally {
      setUpdating(null)
    }
  }

  const getSuggestionIcon = (type: string) => {
    switch (type) {
      case 'INCREASE_CONTRIBUTION':
        return <TrendingUp size={16} />
      case 'ALLOCATE_SURPLUS':
        return <Sparkles size={16} />
      case 'CUT_EXPENSE':
        return <Target size={16} />
      default:
        return <Sparkles size={16} />
    }
  }

  if (loading) {
    return (
      <div className="goal-suggestions-list">
        <SkeletonLoader height={120} width="100%" style={{ marginBottom: '0.75rem' }} />
        <SkeletonLoader height={120} width="100%" />
      </div>
    )
  }

  if (suggestions.length === 0) {
    return (
      <div className="goal-suggestions-list goal-suggestions-list--empty">
        <Sparkles size={24} className="text-gray-400" />
        <p className="text-sm text-gray-500">No suggestions right now.</p>
      </div>
    )
  }

  return (
    <div className="goal-suggestions-list">
      {suggestions.map((suggestion) => (
        <div key={suggestion.id} className="goal-suggestion">
          <div className="goal-suggestion__header">
            <div className="goal-suggestion__icon">
              {getSuggestionIcon(suggestion.suggestion_type)}
            </div>
            <div className="goal-suggestion__title-section">
              <h3 className="goal-suggestion__title">{suggestion.title}</h3>
              <p className="goal-suggestion__meta">
                {suggestion.suggestion_type.replace(/_/g, ' ')} ·{' '}
                {new Date(suggestion.created_at).toLocaleDateString('en-IN', {
                  month: 'short',
                  day: 'numeric',
                })}
              </p>
            </div>
          </div>

          <p className="goal-suggestion__description">{suggestion.description}</p>

          {suggestion.action_payload?.suggested_extra_per_month && (
            <div className="goal-suggestion__payload">
              <span className="goal-suggestion__payload-label">Suggested extra per month:</span>
              <span className="goal-suggestion__payload-value">
                ₹{Number(suggestion.action_payload.suggested_extra_per_month).toLocaleString('en-IN')}
              </span>
            </div>
          )}

          <div className="goal-suggestion__actions">
            <button
              className="goal-suggestion__button goal-suggestion__button--accept"
              onClick={() => handleStatusChange(suggestion.id, 'accepted')}
              disabled={updating === suggestion.id}
            >
              Accept
            </button>
            <button
              className="goal-suggestion__button goal-suggestion__button--dismiss"
              onClick={() => handleStatusChange(suggestion.id, 'dismissed')}
              disabled={updating === suggestion.id}
            >
              <X size={14} />
              Dismiss
            </button>
          </div>
        </div>
      ))}
    </div>
  )
}

