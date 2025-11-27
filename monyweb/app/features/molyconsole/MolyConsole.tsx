'use client'

import type { Session, User } from '@supabase/supabase-js'
import { SessionStatus } from '../../components/SessionStatus'
import './MolyConsole.css'

type MolyConsoleProps = {
  user: User
  session: Session
  onSignOut: () => void
}

const KPI_DATA = [
  {
    label: 'Cash Runway',
    value: '14.2 mo',
    change: '+1.1 mo WoW',
    trend: 'up',
  },
  {
    label: 'Net Revenue (MTD)',
    value: '₹18.7M',
    change: '+12.4%',
    trend: 'up',
  },
  {
    label: 'SpendSense Accuracy',
    value: '97.3%',
    change: '+0.6%',
    trend: 'flat',
  },
  {
    label: 'Goal Funding Rate',
    value: '82%',
    change: '-3%',
    trend: 'down',
  },
]

const QUICK_LINKS = [
  {
    title: 'SpendSense',
    description: 'Realtime transaction intelligence + nudges',
    action: 'Open spend panel',
    color: 'teal',
  },
  {
    title: 'GoalCompass',
    description: 'Prioritise high intent goals & forecast completion',
    action: 'Review goal matrix',
    color: 'gold',
  },
  {
    title: 'BudgetPilot',
    description: 'Adaptive budget splits across the 50/30/20 mix',
    action: 'Tune allocations',
    color: 'violet',
  },
  {
    title: 'MoneyMoments',
    description: 'Personalised nudges queued for delivery',
    action: 'Preview narratives',
    color: 'copper',
  },
]

const ACTIVITY = [
  {
    time: '07:42',
    title: 'Nudge sent · Swiggy spike',
    meta: 'MoneyMoments · User 5419',
  },
  {
    time: '09:10',
    title: 'SpendSense ingest completed',
    meta: 'Gmail parser · 4.3k events',
  },
  {
    time: '10:02',
    title: 'GoalCompass priority reshuffle',
    meta: 'Top 3 goals recalculated',
  },
]

export function MolyConsole({ user, session, onSignOut }: MolyConsoleProps) {
  const displayName = user.user_metadata?.full_name ?? user.email ?? 'Operator'

  return (
    <section className="console">
      <header className="console__hero glass-card">
        <div>
          <p className="eyebrow">MolyConsole</p>
          <h1>Morning, {displayName.split(' ')[0]}</h1>
          <p className="text-muted">
            Here&apos;s what your AI fintech stack has orchestrated in the last few hours.
          </p>
        </div>
        <div className="console__heroActions">
          <button className="ghost-button" onClick={() => onSignOut()}>
            Sign out
          </button>
          <button className="primary-button">Launch command palette</button>
        </div>
      </header>

      <section className="console__grid">
        <div className="console__kpis glass-card">
          <div className="console__kpisGrid">
            {KPI_DATA.map((item) => (
              <article key={item.label} className="console__kpiCard">
                <p className="text-muted">{item.label}</p>
                <h2>{item.value}</h2>
                <span className={`console__trend console__trend--${item.trend}`}>
                  {item.change}
                </span>
              </article>
            ))}
          </div>
        </div>

        <div className="console__rightColumn">
          <section className="glass-card console__links">
            <header>
              <p className="eyebrow">Quick links</p>
              <h3>Navigate the stack</h3>
            </header>
            <div className="console__linksGrid">
              {QUICK_LINKS.map((link) => (
                <button key={link.title} className={`console__link console__link--${link.color}`}>
                  <div>
                    <p className="console__linkTitle">{link.title}</p>
                    <p className="text-muted">{link.description}</p>
                  </div>
                  <span>{link.action}</span>
                </button>
              ))}
            </div>
          </section>

          <section className="glass-card console__session">
            <p className="eyebrow">Auth heartbeat</p>
            <SessionStatus session={session} />
          </section>
        </div>
      </section>

      <section className="console__activity glass-card">
        <header>
          <p className="eyebrow">Realtime activity</p>
          <h3>Latest AI interventions</h3>
        </header>
        <ul>
          {ACTIVITY.map((item) => (
            <li key={item.title}>
              <span className="console__activityTime">{item.time}</span>
              <div>
                <p>{item.title}</p>
                <small className="text-muted">{item.meta}</small>
              </div>
            </li>
          ))}
        </ul>
      </section>
    </section>
  )
}

