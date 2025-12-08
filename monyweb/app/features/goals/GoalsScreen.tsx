'use client'

import { useState, useEffect } from 'react'
import type { Session } from '@supabase/supabase-js'
import { env } from '../../env'
import { GoalsStepper } from './GoalsStepper'
import './GoalsScreen.css'

type Props = {
  session: Session
}

export function GoalsScreen({ session }: Props) {
  return (
    <section className="goals-screen">
      <header className="glass-card goals-screen__hero">
        <div>
          <p className="eyebrow">Goals</p>
          <h1>Set Your Financial Goals</h1>
          <p className="text-muted">
            Tell us about yourself and your financial aspirations. We'll help you prioritize and track your progress.
          </p>
        </div>
      </header>

      <GoalsStepper session={session} />
    </section>
  )
}

