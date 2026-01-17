'use client'

import { useEffect, useState } from 'react'
import type { Nudge } from '@/types/moneymoments'
import { glassCardPrimary } from '@/lib/theme/glass'
import { logNudgeInteraction } from '@/lib/api/moneymoments'
import type { Session } from '@supabase/supabase-js'

interface NudgeCardProps {
  nudge: Nudge
  session: Session
  onInteraction?: () => void
}

export default function NudgeCard({ nudge, session, onInteraction }: NudgeCardProps) {
  const [hasTrackedView, setHasTrackedView] = useState(false)

  useEffect(() => {
    // Track view when card appears
    if (!hasTrackedView) {
      setHasTrackedView(true)
      logNudgeInteraction(session, nudge.delivery_id, 'view').catch((err) => {
        console.error('Error logging nudge view:', err)
      })
    }
  }, [hasTrackedView, nudge.delivery_id, session])

  const handleCTAClick = async () => {
    try {
      await logNudgeInteraction(session, nudge.delivery_id, 'click')
      onInteraction?.()
    } catch (err) {
      console.error('Error logging nudge click:', err)
    }
  }

  const formatDate = (dateString: string) => {
    try {
      const date = new Date(dateString)
      return date.toLocaleDateString('en-IN', {
        year: 'numeric',
        month: 'short',
        day: 'numeric',
      })
    } catch {
      return dateString
    }
  }

  const title = nudge.title || nudge.title_template || 'Nudge'
  const body = nudge.body || nudge.body_template || ''

  return (
    <div className={`${glassCardPrimary} p-5 space-y-4`}>
      {/* Header */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <span className="text-[#D4AF37] text-lg">✨</span>
          <span className="text-xs font-semibold text-gray-400 uppercase">
            {nudge.rule_name}
          </span>
        </div>
        <span className="text-xs text-gray-500">{formatDate(nudge.sent_at)}</span>
      </div>

      {/* Title */}
      <h3 className="text-lg font-bold text-white">{title}</h3>

      {/* Body */}
      {body && (
        <p className="text-sm text-gray-300 line-clamp-4 leading-relaxed">{body}</p>
      )}

      {/* CTA Button */}
      {nudge.cta_text && (
        <button
          onClick={handleCTAClick}
          className="w-full py-3 rounded-xl font-semibold bg-[#D4AF37] text-black hover:bg-[#D4AF37]/90 transition-colors"
        >
          {nudge.cta_text}
        </button>
      )}
    </div>
  )
}
