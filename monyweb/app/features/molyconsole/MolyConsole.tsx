'use client'

import { useState, useEffect, useCallback, useMemo } from 'react'
import type { Session, User } from '@supabase/supabase-js'
import { SessionStatus } from '../../components/SessionStatus'
import { useToast, ToastContainer } from '../../components/Toast'
import { CommandPalette, type Command } from '../../components/CommandPalette'
import { useKeyboardShortcuts } from '../../hooks/useKeyboardShortcuts'
import { useWebSocket } from '../../hooks/useWebSocket'
import { Sparkline } from '../../components/SimpleChart'
import { ThemeSwitcher } from '../../components/ThemeSwitcher'
import { env } from '../../env'
import './MolyConsole.css'

type MolyConsoleProps = {
  user: User
  session: Session
  onSignOut: () => void
}

type KPIData = {
  label: string
  value: string
  change: string
  trend: 'up' | 'down' | 'flat'
  icon?: string
}

const DEFAULT_KPI_DATA: KPIData[] = [
  {
    label: 'Cash Runway',
    value: '14.2 mo',
    change: '+1.1 mo WoW',
    trend: 'up',
    icon: '⏱️',
  },
  {
    label: 'Net Revenue (MTD)',
    value: '₹18.7M',
    change: '+12.4%',
    trend: 'up',
    icon: '💰',
  },
  {
    label: 'SpendSense Accuracy',
    value: '97.3%',
    change: '+0.6%',
    trend: 'flat',
    icon: '🎯',
  },
  {
    label: 'Goal Funding Rate',
    value: '82%',
    change: '-3%',
    trend: 'down',
    icon: '📊',
  },
]

type QuickLink = {
  title: string
  description: string
  action: string
  color: 'teal' | 'gold' | 'violet' | 'copper'
  icon: string
  onClick?: () => void
}

const QUICK_LINKS: QuickLink[] = [
  {
    title: 'SpendSense',
    description: 'Realtime transaction intelligence + nudges',
    action: 'Open spend panel',
    color: 'teal',
    icon: '📈',
  },
  {
    title: 'GoalCompass',
    description: 'Prioritise high intent goals & forecast completion',
    action: 'Review goal matrix',
    color: 'gold',
    icon: '🧭',
  },
  {
    title: 'BudgetPilot',
    description: 'Adaptive budget splits across the 50/30/20 mix',
    action: 'Tune allocations',
    color: 'violet',
    icon: '✈️',
  },
  {
    title: 'MoneyMoments',
    description: 'Personalised nudges queued for delivery',
    action: 'Preview narratives',
    color: 'copper',
    icon: '💬',
  },
]

type ActivityItem = {
  time: string
  title: string
  meta: string
  icon?: string
  type?: 'success' | 'info' | 'warning'
}

const DEFAULT_ACTIVITY: ActivityItem[] = [
  {
    time: '07:42',
    title: 'Nudge sent · Swiggy spike',
    meta: 'MoneyMoments · User 5419',
    icon: '📤',
    type: 'success',
  },
  {
    time: '09:10',
    title: 'SpendSense ingest completed',
    meta: 'Gmail parser · 4.3k events',
    icon: '✅',
    type: 'success',
  },
  {
    time: '10:02',
    title: 'GoalCompass priority reshuffle',
    meta: 'Top 3 goals recalculated',
    icon: '🔄',
    type: 'info',
  },
]

export function MolyConsole({ user, session, onSignOut }: MolyConsoleProps) {
  const [kpiData, setKpiData] = useState<KPIData[]>(DEFAULT_KPI_DATA)
  const [activity, setActivity] = useState<ActivityItem[]>(DEFAULT_ACTIVITY)
  const [loading, setLoading] = useState(false)
  const [refreshing, setRefreshing] = useState(false)
  const [isMobile, setIsMobile] = useState(false)
  const [commandPaletteOpen, setCommandPaletteOpen] = useState(false)
  const [widgetsVisible, setWidgetsVisible] = useState({
    kpis: true,
    quickLinks: true,
    activity: true,
    session: true,
  })
  const [isEditingLayout, setIsEditingLayout] = useState(false)
  const [systemHealth, setSystemHealth] = useState<{
    api: 'healthy' | 'degraded' | 'down'
    database: 'healthy' | 'degraded' | 'down'
    websocket: 'connected' | 'disconnected'
  }>({
    api: 'healthy',
    database: 'healthy',
    websocket: 'disconnected',
  })
  const [notifications, setNotifications] = useState<Array<{
    id: string
    title: string
    message: string
    type: 'info' | 'warning' | 'error' | 'success'
    timestamp: Date
    read: boolean
  }>>([])
  const [notificationCenterOpen, setNotificationCenterOpen] = useState(false)
  const toast = useToast()

  // WebSocket for real-time updates
  const wsUrl = useMemo(() => {
    const baseUrl = env.apiBaseUrl.replace(/^http/, 'ws')
    const token = session?.access_token
    if (!token) {
      console.debug('WebSocket: No token available, skipping connection')
      return null
    }
    // Check if token is expired (basic check - JWT exp claim)
    try {
      const payload = JSON.parse(atob(token.split('.')[1]))
      const exp = payload.exp * 1000 // Convert to milliseconds
      if (Date.now() >= exp) {
        console.warn('WebSocket: Token expired, skipping connection')
        return null
      }
    } catch (e) {
      // If we can't parse the token, still try to connect (might be a different format)
      console.debug('WebSocket: Could not parse token expiration, attempting connection anyway')
    }
    return `${baseUrl}/ws?token=${encodeURIComponent(token)}`
  }, [session?.access_token])
  const { isConnected, lastMessage } = useWebSocket({
    url: wsUrl || undefined,
    enabled: !!wsUrl && !!session?.access_token,
    onMessage: (message) => {
      if (message.type === 'activity') {
        setActivity(prev => [message.data, ...prev].slice(0, 10))
        toast.info(message.data.title || 'New activity')
        // Add notification
        setNotifications(prev => [{
          id: Math.random().toString(36),
          title: 'New Activity',
          message: message.data.title || 'Activity update',
          type: 'info',
          timestamp: new Date(),
          read: false,
        }, ...prev].slice(0, 20))
      } else if (message.type === 'kpi_update') {
        setKpiData(message.data || DEFAULT_KPI_DATA)
        toast.success('KPIs updated')
      } else if (message.type === 'notification') {
        setNotifications(prev => [{
          id: Math.random().toString(36),
          title: message.data.title || 'Notification',
          message: message.data.message || '',
          type: message.data.type || 'info',
          timestamp: new Date(),
          read: false,
        }, ...prev].slice(0, 20))
      }
    },
    onError: () => {
      setSystemHealth(prev => ({ ...prev, websocket: 'disconnected' }))
    },
    onOpen: () => {
      setSystemHealth(prev => ({ ...prev, websocket: 'connected' }))
    },
  })

  // Update system health when WebSocket connection changes
  useEffect(() => {
    setSystemHealth(prev => ({
      ...prev,
      websocket: isConnected ? 'connected' : 'disconnected',
    }))
  }, [isConnected])

  // Check system health
  useEffect(() => {
    const checkHealth = async () => {
      try {
        const response = await fetch(`${env.apiBaseUrl}/health`, {
          method: 'GET',
          headers: { Authorization: `Bearer ${session.access_token}` },
        })
        setSystemHealth(prev => ({
          ...prev,
          api: response.ok ? 'healthy' : 'degraded',
        }))
      } catch {
        setSystemHealth(prev => ({ ...prev, api: 'down' }))
      }
    }
    
    checkHealth()
    const interval = setInterval(checkHealth, 30000) // Check every 30s
    return () => clearInterval(interval)
  }, [session.access_token])

  const displayName = user.user_metadata?.full_name ?? user.email ?? 'Operator'
  const greeting = useMemo(() => {
    const hour = new Date().getHours()
    if (hour < 12) return 'Morning'
    if (hour < 17) return 'Afternoon'
    return 'Evening'
  }, [])

  // Detect mobile viewport
  useEffect(() => {
    const checkMobile = () => setIsMobile(window.innerWidth < 768)
    checkMobile()
    window.addEventListener('resize', checkMobile)
    return () => window.removeEventListener('resize', checkMobile)
  }, [])

  const handleRefresh = useCallback(async () => {
    setRefreshing(true)
    // Simulate API call - replace with actual API call
    await new Promise((resolve) => setTimeout(resolve, 1000))
    setRefreshing(false)
    toast.success('Dashboard refreshed')
  }, [toast])

  const handleQuickLinkClick = useCallback((link: QuickLink) => {
    toast.info(`Opening ${link.title}...`)
    // Add navigation logic here
  }, [toast])

  // Command palette commands
  const commands: Command[] = useMemo(() => [
    {
      id: 'refresh',
      title: 'Refresh Dashboard',
      description: 'Reload all data',
      icon: '🔄',
      category: 'Actions',
      action: handleRefresh,
      keywords: ['reload', 'update'],
    },
    {
      id: 'spendsense',
      title: 'Open SpendSense',
      description: 'Navigate to transaction panel',
      icon: '📈',
      category: 'Navigation',
      action: () => {
        toast.info('Opening SpendSense...')
        // Add navigation logic
      },
      keywords: ['transactions', 'spending'],
    },
    {
      id: 'signout',
      title: 'Sign Out',
      description: 'Log out of your account',
      icon: '🚪',
      category: 'Account',
      action: onSignOut,
      keywords: ['logout', 'exit'],
    },
    {
      id: 'command-palette',
      title: 'Command Palette',
      description: 'Open command palette',
      icon: '⌘',
      category: 'System',
      action: () => setCommandPaletteOpen(true),
      keywords: ['cmd', 'k', 'palette'],
    },
  ], [handleRefresh, onSignOut, toast])

  // Keyboard shortcuts
  useKeyboardShortcuts([
    {
      key: 'k',
      meta: true,
      action: () => setCommandPaletteOpen(true),
      description: 'Open command palette',
    },
    {
      key: 'r',
      meta: true,
      action: handleRefresh,
      description: 'Refresh dashboard',
    },
  ])

  // Skeleton loaders
  const SkeletonKPICard = () => (
    <article className="console__kpiCard console__skeleton">
      <div className="console__skeleton-line" style={{ width: '60%', marginBottom: '0.5rem' }} />
      <div className="console__skeleton-line" style={{ width: '80%', marginBottom: '0.5rem', height: '2rem' }} />
      <div className="console__skeleton-line" style={{ width: '40%' }} />
    </article>
  )

  const SkeletonActivityItem = () => (
    <li className="console__activityItem console__skeleton">
      <div className="console__skeleton-line" style={{ width: '60px' }} />
      <div>
        <div className="console__skeleton-line" style={{ width: '70%', marginBottom: '0.5rem' }} />
        <div className="console__skeleton-line" style={{ width: '50%' }} />
      </div>
    </li>
  )

  return (
    <>
      <ToastContainer toasts={toast.toasts} onRemove={toast.removeToast} />
      <CommandPalette
        commands={commands}
        isOpen={commandPaletteOpen}
        onClose={() => setCommandPaletteOpen(false)}
      />
    <section className="console">
      <header className="console__hero glass-card">
        <div>
          <p className="eyebrow">MolyConsole</p>
          <h1>{greeting}, {displayName.split(' ')[0]}</h1>
          <p className="text-muted">
            Here&apos;s what your AI fintech stack has orchestrated in the last few hours.
          </p>
        </div>
        <div className="console__heroActions">
          <div className="console__statusIndicator">
            <ThemeSwitcher />
            {isConnected && (
              <span className="console__wsStatus" title="Real-time updates connected">
                🟢 Live
              </span>
            )}
            <button
              className="ghost-button"
              onClick={() => setNotificationCenterOpen(true)}
              style={{ position: 'relative' }}
              aria-label="Notifications"
            >
              🔔
              {notifications.filter(n => !n.read).length > 0 && (
                <span className="console__notificationBadge">
                  {notifications.filter(n => !n.read).length}
                </span>
              )}
            </button>
          </div>
          <button 
            className="ghost-button" 
            onClick={handleRefresh}
            disabled={refreshing}
            aria-label="Refresh dashboard"
          >
            {refreshing ? 'Refreshing...' : '🔄 Refresh'}
          </button>
          <button 
            className="ghost-button" 
            onClick={() => onSignOut()}
            aria-label="Sign out"
          >
            Sign out
          </button>
          <button 
            className="primary-button"
            aria-label="Launch command palette"
            onClick={() => setCommandPaletteOpen(true)}
          >
            Launch command palette
          </button>
        </div>
      </header>

      <section className="console__grid">
        {widgetsVisible.kpis && (
        <div className="console__kpis glass-card">
          <header className="console__sectionHeader">
            <div>
              <p className="eyebrow">Key metrics</p>
              <h3>Performance at a glance</h3>
            </div>
            {isEditingLayout && (
              <button
                className="ghost-button"
                onClick={() => setWidgetsVisible(prev => ({ ...prev, kpis: false }))}
                style={{ fontSize: '0.75rem', padding: '0.25rem 0.5rem' }}
                aria-label="Hide KPIs widget"
              >
                ✕
              </button>
            )}
          </header>
          <div className="console__kpisGrid">
            {loading ? (
              <>
                <SkeletonKPICard />
                <SkeletonKPICard />
                <SkeletonKPICard />
                <SkeletonKPICard />
              </>
            ) : kpiData.length === 0 ? (
              <div className="console__emptyState">
                <div className="console__emptyStateIcon">📊</div>
                <p>No KPI data available</p>
              </div>
            ) : (
              kpiData.map((item) => {
                // Generate mock sparkline data
                const sparklineData = Array.from({ length: 7 }, (_, i) => {
                  const base = parseFloat(item.value.replace(/[^\d.]/g, '')) || 0
                  const variation = item.trend === 'up' ? 1.1 : item.trend === 'down' ? 0.9 : 1
                  return base * (0.8 + Math.random() * 0.4) * Math.pow(variation, i - 3)
                })
                
                return (
                  <article 
                    key={item.label} 
                    className="console__kpiCard" 
                    tabIndex={0}
                    onClick={() => toast.info(`Viewing details for ${item.label}`)}
                    style={{ cursor: 'pointer' }}
                  >
                    {item.icon && <div className="console__kpiIcon">{item.icon}</div>}
                <p className="text-muted">{item.label}</p>
                <h2>{item.value}</h2>
                    <div className="console__kpiTrendRow">
                <span className={`console__trend console__trend--${item.trend}`}>
                        {item.trend === 'up' && '↗ '}
                        {item.trend === 'down' && '↘ '}
                        {item.trend === 'flat' && '→ '}
                  {item.change}
                </span>
                      <Sparkline data={sparklineData} width={60} height={20} />
                    </div>
              </article>
                )
              })
            )}
          </div>
        </div>
        )}

        <div className="console__rightColumn">
          {widgetsVisible.quickLinks && (
          <section className="glass-card console__links">
            <header className="console__sectionHeader">
              <div>
              <p className="eyebrow">Quick links</p>
              <h3>Navigate the stack</h3>
              </div>
              {isEditingLayout && (
                <button
                  className="ghost-button"
                  onClick={() => setWidgetsVisible(prev => ({ ...prev, quickLinks: false }))}
                  style={{ fontSize: '0.75rem', padding: '0.25rem 0.5rem' }}
                  aria-label="Hide Quick Links widget"
                >
                  ✕
                </button>
              )}
            </header>
            <div className="console__linksGrid">
              {QUICK_LINKS.map((link) => (
                <button 
                  key={link.title} 
                  className={`console__link console__link--${link.color}`}
                  onClick={() => handleQuickLinkClick(link)}
                  aria-label={`Open ${link.title}`}
                >
                  <div className="console__linkHeader">
                    {link.icon && <span className="console__linkIcon">{link.icon}</span>}
                  <div>
                    <p className="console__linkTitle">{link.title}</p>
                    <p className="text-muted">{link.description}</p>
                    </div>
                  </div>
                  <span className="console__linkAction">{link.action} →</span>
                </button>
              ))}
            </div>
          </section>
          )}

          {widgetsVisible.session && (
          <section className="glass-card console__session">
            <div className="console__sectionHeader">
            <p className="eyebrow">Auth heartbeat</p>
              {isEditingLayout && (
                <button
                  className="ghost-button"
                  onClick={() => setWidgetsVisible(prev => ({ ...prev, session: false }))}
                  style={{ fontSize: '0.75rem', padding: '0.25rem 0.5rem' }}
                  aria-label="Hide Session widget"
                >
                  ✕
                </button>
              )}
            </div>
            <SessionStatus session={session} />
          </section>
          )}
        </div>
      </section>

      {widgetsVisible.activity && (
      <section className="console__activity glass-card">
        <header className="console__sectionHeader">
          <div>
          <p className="eyebrow">Realtime activity</p>
          <h3>Latest AI interventions</h3>
          </div>
          <div style={{ display: 'flex', gap: '0.5rem', alignItems: 'center' }}>
            {isEditingLayout && (
              <button
                className="ghost-button"
                onClick={() => setWidgetsVisible(prev => ({ ...prev, activity: false }))}
                style={{ fontSize: '0.75rem', padding: '0.25rem 0.5rem' }}
                aria-label="Hide Activity widget"
              >
                ✕
              </button>
            )}
            <button 
              className="ghost-button console__refreshButton"
              onClick={handleRefresh}
              disabled={refreshing}
              aria-label="Refresh activity"
              title="Refresh activity feed"
            >
              {refreshing ? '⟳' : '↻'}
            </button>
          </div>
        </header>
        {loading ? (
        <ul>
            {Array.from({ length: 3 }).map((_, i) => (
              <SkeletonActivityItem key={i} />
            ))}
          </ul>
        ) : activity.length === 0 ? (
          <div className="console__emptyState">
            <div className="console__emptyStateIcon">📋</div>
            <p>No recent activity</p>
            <small className="text-muted">Activity will appear here as events occur</small>
          </div>
        ) : (
          <ul>
            {activity.map((item, index) => (
              <li key={`${item.title}-${index}`} className={`console__activityItem ${item.type ? `console__activityItem--${item.type}` : ''}`}>
                <div className="console__activityTimeWrapper">
                  {item.icon && <span className="console__activityIcon">{item.icon}</span>}
              <span className="console__activityTime">{item.time}</span>
                </div>
              <div>
                  <p className="console__activityTitle">{item.title}</p>
                <small className="text-muted">{item.meta}</small>
              </div>
            </li>
          ))}
        </ul>
        )}
      </section>
      )}
      
      {isEditingLayout && (
        <div className="console__layoutEditor">
          <p className="eyebrow">Layout Editor</p>
          <div className="console__widgetToggle">
            {Object.entries(widgetsVisible).map(([key, visible]) => (
              <label key={key} className="console__widgetToggleItem">
                <input
                  type="checkbox"
                  checked={visible}
                  onChange={(e) => setWidgetsVisible(prev => ({ ...prev, [key]: e.target.checked }))}
                />
                <span>{key.charAt(0).toUpperCase() + key.slice(1).replace(/([A-Z])/g, ' $1')}</span>
              </label>
            ))}
          </div>
          <button className="ghost-button" onClick={() => setIsEditingLayout(false)}>
            Done Editing
          </button>
        </div>
      )}
      
      {!isEditingLayout && (
        <button 
          className="ghost-button console__editLayoutButton"
          onClick={() => setIsEditingLayout(true)}
          aria-label="Edit dashboard layout"
        >
          ⚙️ Customize Layout
        </button>
      )}

      {/* System Health Dashboard */}
      <section className="console__health glass-card">
        <header className="console__sectionHeader">
          <div>
            <p className="eyebrow">System Health</p>
            <h3>Service Status</h3>
          </div>
        </header>
        <div className="console__healthGrid">
          <div className={`console__healthItem console__healthItem--${systemHealth.api}`}>
            <div className="console__healthIcon">
              {systemHealth.api === 'healthy' ? '✅' : systemHealth.api === 'degraded' ? '⚠️' : '❌'}
            </div>
            <div>
              <p className="console__healthLabel">API</p>
              <p className="console__healthStatus">{systemHealth.api}</p>
            </div>
          </div>
          <div className={`console__healthItem console__healthItem--${systemHealth.database}`}>
            <div className="console__healthIcon">
              {systemHealth.database === 'healthy' ? '✅' : systemHealth.database === 'degraded' ? '⚠️' : '❌'}
            </div>
            <div>
              <p className="console__healthLabel">Database</p>
              <p className="console__healthStatus">{systemHealth.database}</p>
            </div>
          </div>
          <div className={`console__healthItem console__healthItem--${systemHealth.websocket === 'connected' ? 'healthy' : 'degraded'}`}>
            <div className="console__healthIcon">
              {systemHealth.websocket === 'connected' ? '✅' : '⚠️'}
            </div>
            <div>
              <p className="console__healthLabel">WebSocket</p>
              <p className="console__healthStatus">{systemHealth.websocket}</p>
            </div>
          </div>
        </div>
      </section>

      {/* Notification Center */}
      {notificationCenterOpen && (
        <div className="console__notificationOverlay" onClick={() => setNotificationCenterOpen(false)}>
          <div className="console__notificationCenter" onClick={(e) => e.stopPropagation()}>
            <header className="console__notificationHeader">
              <h3>Notifications</h3>
              <button
                className="ghost-button"
                onClick={() => {
                  setNotifications(prev => prev.map(n => ({ ...n, read: true })))
                }}
                style={{ fontSize: '0.875rem' }}
              >
                Mark all read
              </button>
              <button
                className="ghost-button"
                onClick={() => setNotificationCenterOpen(false)}
                aria-label="Close notifications"
              >
                ✕
              </button>
            </header>
            <div className="console__notificationList">
              {notifications.length === 0 ? (
                <div className="console__emptyState">
                  <div className="console__emptyStateIcon">🔔</div>
                  <p>No notifications</p>
                </div>
              ) : (
                notifications.map(notif => (
                  <div
                    key={notif.id}
                    className={`console__notificationItem console__notificationItem--${notif.type} ${notif.read ? 'is-read' : ''}`}
                    onClick={() => {
                      setNotifications(prev => prev.map(n => 
                        n.id === notif.id ? { ...n, read: true } : n
                      ))
                    }}
                  >
                    <div className="console__notificationContent">
                      <p className="console__notificationTitle">{notif.title}</p>
                      <p className="console__notificationMessage">{notif.message}</p>
                      <small className="console__notificationTime">
                        {notif.timestamp.toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit' })}
                      </small>
                    </div>
                    {!notif.read && <div className="console__notificationDot" />}
                  </div>
                ))
              )}
            </div>
          </div>
        </div>
      )}
    </section>
    </>
  )
}

