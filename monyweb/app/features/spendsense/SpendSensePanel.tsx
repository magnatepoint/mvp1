'use client'

import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import type { Session } from '@supabase/supabase-js'
import './SpendSensePanel.css'
import { env } from '../../env'
import { usePullToRefresh } from '../../hooks/usePullToRefresh'

type Category = {
  code: string
  name: string
}

type Subcategory = {
  code: string
  name: string
}

type Transaction = {
  txn_id: string
  txn_date: string
  merchant: string | null
  category: string | null
  subcategory: string | null
  bank_code: string | null
  channel: string | null
  amount: number
  direction: string
}

type Props = {
  session: Session
}

const PAGE_SIZE = 25

const BANK_META: Record<
  string,
  {
    name: string
    logo?: string
  }
> = {
  federal_bank: { name: 'Federal Bank', logo: '🏦' },
  hdfc_bank: { name: 'HDFC Bank', logo: '🏛️' },
  icici_bank: { name: 'ICICI Bank', logo: '🏢' },
  axis_bank: { name: 'Axis Bank', logo: '🏬' },
  sbi_bank: { name: 'State Bank of India', logo: '🏦' },
  kotak_bank: { name: 'Kotak Bank', logo: '🏦' },
}

const CHANNEL_META: Record<
  string,
  {
    label: string
  }
> = {
  upi: { label: 'UPI' },
  bank_transfer: { label: 'Bank transfer' },
  credit_card: { label: 'Credit card' },
  loan: { label: 'Loan / EMI' },
  investment: { label: 'Investment' },
  insurance: { label: 'Insurance' },
}

const CHANNEL_OPTIONS = Object.entries(CHANNEL_META).map(([value, meta]) => ({
  value,
  label: meta.label,
}))

const formatLabel = (value?: string | null) => {
  if (!value) return '—'
  if (value.trim().includes(' ')) return value
  const pretty = value
    .toLowerCase()
    .split(/[_\s]+/)
    .filter(Boolean)
    .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
    .join(' ')
  return pretty || value
}

const formatPercent = (value?: number | null) => {
  if (value === null || value === undefined || Number.isNaN(value)) return '—'
  const rounded = value.toFixed(1)
  return `${value > 0 ? '+' : ''}${rounded}%`
}

const formatMonthLabel = (value?: string | null) => {
  if (!value) return '—'
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return value
  return date.toLocaleDateString('en-IN', {
    month: 'short',
    year: 'numeric',
  })
}

const rarityLabel: Record<string, string> = {
  legendary: 'Legendary haul',
  epic: 'Epic drop',
  rare: 'Rare find',
  common: 'Fresh batch',
}

const tierLabel: Record<string, string> = {
  gold: 'Gold badge',
  silver: 'Silver badge',
  bronze: 'Bronze badge',
  ember: 'Rising ember',
}

const categoryTooltip = (cat: CategoryBadge) => {
  if (cat.change_pct === null || Number.isNaN(cat.change_pct)) {
    return 'No previous month data yet'
  }
  const direction = cat.change_pct >= 0 ? 'Up' : 'Down'
  return `${direction} ${Math.abs(cat.change_pct).toFixed(1)}% vs last month`
}

type TransactionResponse = {
  transactions: Transaction[]
  total: number
  limit: number
  offset: number
}

type CategoryBadge = {
  category_code: string
  category_name: string | null
  txn_count: number
  spend_amount: number
  income_amount: number
  share: number
  tier: string
  change_pct: number | null
}

type WantsGauge = {
  ratio: number
  label: string
  threshold_crossed: boolean
}

type BestMonthSnapshot = {
  month: string
  income_amount: number
  needs_amount: number
  wants_amount: number
  delta_pct: number | null
  is_current_best: boolean
}

type LootDropSummary = {
  batch_id: string
  file_name: string | null
  transactions_ingested: number
  status: string
  occurred_at: string | null
  rarity: string
}

type DashboardKPI = {
  month: string | null
  income_amount: number
  needs_amount: number
  wants_amount: number
  assets_amount: number
  top_categories: CategoryBadge[]
  wants_gauge: WantsGauge | null
  best_month: BestMonthSnapshot | null
  recent_loot_drop: LootDropSummary | null
}

type TransactionRowProps = {
  transaction: Transaction
  session: Session
  onUpdate: () => void
  onDelete: () => void
}

function TransactionRow({ transaction, session, onUpdate, onDelete }: TransactionRowProps) {
  const [editing, setEditing] = useState(false)
  const [deleting, setDeleting] = useState(false)
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false)
  const [categories, setCategories] = useState<Category[]>([])
  const [subcategories, setSubcategories] = useState<Subcategory[]>([])
  const [selectedCategory, setSelectedCategory] = useState<string>('')
  const [selectedSubcategory, setSelectedSubcategory] = useState<string>('')
  const [merchantName, setMerchantName] = useState(transaction.merchant ?? '')
  const [selectedChannel, setSelectedChannel] = useState(transaction.channel ?? '')
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const currencyFormatter = useMemo(
    () =>
      new Intl.NumberFormat('en-IN', {
        style: 'currency',
        currency: 'INR',
        maximumFractionDigits: 0,
      }),
    [],
  )
  useEffect(() => {
    if (editing) {
      setMerchantName(transaction.merchant ?? '')
      setSelectedChannel(transaction.channel ?? '')
      // Fetch categories
      fetch(`${env.apiBaseUrl}/spendsense/categories`, {
        headers: { Authorization: `Bearer ${session.access_token}` },
      })
        .then((res) => res.json())
        .then((data: Category[]) => {
          setCategories(data)
          // Find current category code
          const currentCat = data.find((c) => c.name === transaction.category)
          if (currentCat) {
            setSelectedCategory(currentCat.code)
            // Fetch subcategories for this category
            fetch(`${env.apiBaseUrl}/spendsense/subcategories?category_code=${currentCat.code}`, {
              headers: { Authorization: `Bearer ${session.access_token}` },
            })
              .then((res) => res.json())
              .then((subs: Subcategory[]) => {
                setSubcategories(subs)
                const currentSub = subs.find((s) => s.name === transaction.subcategory)
                if (currentSub) setSelectedSubcategory(currentSub.code)
              })
          } else {
            setSelectedCategory('')
            setSubcategories([])
            setSelectedSubcategory('')
          }
        })
    }
  }, [
    editing,
    session.access_token,
    transaction.category,
    transaction.subcategory,
    transaction.merchant,
    transaction.channel,
  ])

  const handleSave = async () => {
    setSaving(true)
    setError(null)
    try {
      const response = await fetch(`${env.apiBaseUrl}/spendsense/transactions/${transaction.txn_id}`, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${session.access_token}`,
        },
        body: JSON.stringify({
          category_code: selectedCategory || null,
          subcategory_code: selectedSubcategory || null,
          merchant_name: merchantName.trim() ? merchantName.trim() : null,
          channel: selectedChannel || null,
        }),
      })
      if (!response.ok) {
        const body = await response.json().catch(() => ({}))
        throw new Error(body.detail ?? 'Failed to update transaction')
      }
      setEditing(false)
      onUpdate()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Unknown error')
    } finally {
      setSaving(false)
    }
  }

  const handleDelete = async () => {
    setDeleting(true)
    setError(null)
    try {
      const response = await fetch(`${env.apiBaseUrl}/spendsense/transactions/${transaction.txn_id}`, {
        method: 'DELETE',
        headers: {
          Authorization: `Bearer ${session.access_token}`,
        },
      })
      if (!response.ok) {
        const body = await response.json().catch(() => ({}))
        throw new Error(body.detail ?? 'Failed to delete transaction')
      }
      setShowDeleteConfirm(false)
      onDelete()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Unknown error')
      setDeleting(false)
    }
  }

  if (editing) {
    return (
      <tr className="spendsense__editRow">
        <td>{new Date(transaction.txn_date).toLocaleDateString('en-IN', { day: '2-digit', month: 'short' })}</td>
        <td>
          <div className="spendsense__merchantEdit">
            <input
              className="input-field"
              type="text"
              value={merchantName}
              onChange={(e) => setMerchantName(e.target.value)}
              placeholder="Merchant name"
            />
            <select
              className="input-field"
              value={selectedChannel}
              onChange={(e) => setSelectedChannel(e.target.value)}
            >
              <option value="">Auto (based on detection)</option>
              {CHANNEL_OPTIONS.map((channelOption) => (
                <option key={channelOption.value} value={channelOption.value}>
                  {channelOption.label}
                </option>
              ))}
              {selectedChannel &&
                !CHANNEL_META[selectedChannel] && (
                  <option value={selectedChannel}>{selectedChannel}</option>
                )}
            </select>
          </div>
        </td>
        <td>
          <select
            className="input-field"
            value={selectedCategory}
            onChange={(e) => {
              setSelectedCategory(e.target.value)
              setSelectedSubcategory('')
              if (e.target.value) {
                fetch(`${env.apiBaseUrl}/spendsense/subcategories?category_code=${e.target.value}`, {
                  headers: { Authorization: `Bearer ${session.access_token}` },
                })
                  .then((res) => res.json())
                  .then((subs: Subcategory[]) => setSubcategories(subs))
              } else {
                setSubcategories([])
              }
            }}
          >
            <option value="">—</option>
            {categories.map((cat) => (
              <option key={cat.code} value={cat.code}>
                {cat.name}
              </option>
            ))}
          </select>
        </td>
        <td>
          <select
            className="input-field"
            value={selectedSubcategory}
            onChange={(e) => setSelectedSubcategory(e.target.value)}
            disabled={!selectedCategory}
          >
            <option value="">—</option>
            {subcategories.map((sub) => (
              <option key={sub.code} value={sub.code}>
                {sub.name}
              </option>
            ))}
          </select>
        </td>
        <td className={transaction.direction === 'debit' ? 'amount-debit' : 'amount-credit'}>
          {currencyFormatter.format(Math.abs(transaction.amount))}
        </td>
        <td>
          <div className="spendsense__rowActions">
            {error && <span className="error-message" style={{ fontSize: '0.75rem' }}>{error}</span>}
            <button className="ghost-button" onClick={handleSave} disabled={saving}>
              {saving ? 'Saving…' : 'Save'}
            </button>
            <button className="ghost-button" onClick={() => setEditing(false)} disabled={saving}>
              Cancel
            </button>
          </div>
        </td>
      </tr>
    )
  }

    const bankInfo = transaction.bank_code ? BANK_META[transaction.bank_code] : undefined
    const channelInfo = transaction.channel ? CHANNEL_META[transaction.channel] : undefined

    return (
    <>
      <tr>
        <td>{new Date(transaction.txn_date).toLocaleDateString('en-IN', { day: '2-digit', month: 'short' })}</td>
          <td>
            <div className="spendsense__merchant">
              <div className="spendsense__merchantName">{transaction.merchant ?? '—'}</div>
              {(bankInfo || channelInfo) && (
                <div className="spendsense__merchantMeta">
                  {bankInfo && (
                    <span className="spendsense__badge">
                      {bankInfo.logo && <span className="spendsense__badgeIcon">{bankInfo.logo}</span>}
                      {bankInfo.name}
                    </span>
                  )}
                  {channelInfo && (
                    <span className={`spendsense__chip spendsense__chip--${transaction.channel}`}>
                      {channelInfo.label ?? transaction.channel}
                    </span>
                  )}
                </div>
              )}
            </div>
          </td>
        <td>{formatLabel(transaction.category)}</td>
        <td>{formatLabel(transaction.subcategory)}</td>
        <td className={transaction.direction === 'debit' ? 'amount-debit' : 'amount-credit'}>
          {currencyFormatter.format(Math.abs(transaction.amount))}
        </td>
        <td>
          <div className="spendsense__rowActions">
            <button className="ghost-button" onClick={() => setEditing(true)} style={{ fontSize: '0.875rem' }}>
              Edit
            </button>
            <button
              className="ghost-button"
              onClick={() => setShowDeleteConfirm(true)}
              style={{ fontSize: '0.875rem', color: '#f87171' }}
            >
              Delete
            </button>
          </div>
        </td>
      </tr>
      {showDeleteConfirm && (
        <tr>
          <td colSpan={6} className="spendsense__deleteConfirm">
            <div>
              <p>Are you sure you want to delete this transaction? This action cannot be undone.</p>
              <div className="spendsense__rowActions">
                <button className="ghost-button" onClick={handleDelete} disabled={deleting}>
                  {deleting ? 'Deleting…' : 'Yes, Delete'}
                </button>
                <button className="ghost-button" onClick={() => setShowDeleteConfirm(false)} disabled={deleting}>
                  Cancel
                </button>
              </div>
              {error && <p className="error-message" style={{ fontSize: '0.75rem', marginTop: '0.5rem' }}>{error}</p>}
            </div>
          </td>
        </tr>
      )}
    </>
  )
}

export function SpendSensePanel({ session }: Props) {
  const [transactions, setTransactions] = useState<Transaction[]>([])
  const [totalCount, setTotalCount] = useState(0)
  const [currentPage, setCurrentPage] = useState(1)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [uploadError, setUploadError] = useState<string | null>(null)
  const [uploading, setUploading] = useState(false)
  const [pdfPassword, setPdfPassword] = useState('')
  const fileInputRef = useRef<HTMLInputElement | null>(null)
  const passwordInputRef = useRef<HTMLInputElement | null>(null)
  const [filters, setFilters] = useState({
    search: '',
    category: '',
    subcategory: '',
    channel: '',
  })
  const [filterPanelOpen, setFilterPanelOpen] = useState(false)
  const [filterCategories, setFilterCategories] = useState<Category[]>([])
  const [filterSubcategories, setFilterSubcategories] = useState<Subcategory[]>([])
  const [kpis, setKpis] = useState<DashboardKPI | null>(null)
  const [kpiLoading, setKpiLoading] = useState(true)
  const [kpiError, setKpiError] = useState<string | null>(null)
  const [lootFlip, setLootFlip] = useState(false)
  const [activeTab, setActiveTab] = useState<'kpis' | 'transactions'>('kpis')

  const totalPages = Math.ceil(totalCount / PAGE_SIZE)

  const fetchTransactions = useCallback(
    (page: number = 1, appliedFilters = filters) => {
      const controller = new AbortController()
      setLoading(true)
      setError(null)
      const offset = (page - 1) * PAGE_SIZE
      const params = new URLSearchParams({
        limit: PAGE_SIZE.toString(),
        offset: offset.toString(),
      })
      if (appliedFilters.search.trim()) params.append('search', appliedFilters.search.trim())
      if (appliedFilters.category) params.append('category_code', appliedFilters.category)
      if (appliedFilters.subcategory) params.append('subcategory_code', appliedFilters.subcategory)
      if (appliedFilters.channel) params.append('channel', appliedFilters.channel)

      fetch(`${env.apiBaseUrl}/spendsense/transactions?${params.toString()}`, {
        headers: {
          Authorization: `Bearer ${session.access_token}`,
        },
        signal: controller.signal,
      })
        .then((response) => {
          if (!response.ok) throw new Error('Unable to load transactions')
          return response.json() as Promise<TransactionResponse>
        })
        .then((data) => {
          if (Array.isArray(data)) {
            setTransactions(data)
            setTotalCount(data.length)
          } else {
            setTransactions(data.transactions || [])
            setTotalCount(data.total || 0)
          }
        })
        .catch((err) => {
          if (!(err instanceof DOMException && err.name === 'AbortError')) {
            setError(err instanceof Error ? err.message : 'Unknown error')
            setTransactions([])
            setTotalCount(0)
          }
        })
        .finally(() => setLoading(false))
      return () => controller.abort()
    },
    [filters, session.access_token],
  )

  useEffect(() => {
    const cancel = fetchTransactions(currentPage, filters)
    return () => cancel()
  }, [currentPage, filters, fetchTransactions])

  useEffect(() => {
    fetch(`${env.apiBaseUrl}/spendsense/categories`, {
      headers: { Authorization: `Bearer ${session.access_token}` },
    })
      .then((res) => res.json())
      .then((data: Category[]) => setFilterCategories(data))
      .catch(() => undefined)
  }, [session.access_token])

  useEffect(() => {
    if (filters.category) {
      fetch(`${env.apiBaseUrl}/spendsense/subcategories?category_code=${filters.category}`, {
        headers: { Authorization: `Bearer ${session.access_token}` },
      })
        .then((res) => res.json())
        .then((data: Subcategory[]) => setFilterSubcategories(data))
        .catch(() => undefined)
    } else {
      setFilterSubcategories([])
    }
  }, [filters.category, session.access_token])

  const fetchKpis = useCallback(() => {
    setKpiLoading(true)
    setKpiError(null)
    return fetch(`${env.apiBaseUrl}/spendsense/kpis`, {
      headers: { Authorization: `Bearer ${session.access_token}` },
    })
      .then((res) => {
        if (!res.ok) throw new Error('Unable to load KPIs')
        return res.json() as Promise<DashboardKPI>
      })
      .then((data) => setKpis(data))
      .catch((err) => setKpiError(err instanceof Error ? err.message : 'Unknown error'))
      .finally(() => setKpiLoading(false))
  }, [session.access_token])

  useEffect(() => {
    fetchKpis()
  }, [fetchKpis])

  // Pull-to-refresh handler
  const handleRefresh = useCallback(async () => {
    await Promise.all([
      fetchTransactions(currentPage, filters),
      fetchKpis(),
    ])
  }, [fetchTransactions, fetchKpis, currentPage, filters])

  const { elementRef, isPulling, isRefreshing, progress } = usePullToRefresh({
    onRefresh: handleRefresh,
    threshold: 80,
  })

  useEffect(() => {
    if (!kpis?.recent_loot_drop?.batch_id) return
    setLootFlip(true)
    const timeout = window.setTimeout(() => setLootFlip(false), 1600)
    return () => window.clearTimeout(timeout)
  }, [kpis?.recent_loot_drop?.batch_id])

  const handleUploadClick = () => {
    fileInputRef.current?.click()
  }

  const handleFileChange = async (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0]
    if (!file) return
    setUploadError(null)
    setUploading(true)
    try {
      const formData = new FormData()
      formData.append('file', file)
      if (pdfPassword.trim()) {
        formData.append('password', pdfPassword.trim())
      }
      const response = await fetch(`${env.apiBaseUrl}/spendsense/uploads/file`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${session.access_token}`,
        },
        body: formData,
      })
      if (!response.ok) {
        const body = await response.json().catch(() => ({}))
        throw new Error(body.detail ?? 'Upload failed')
      }
      // Reset to first page and refresh after upload
      setCurrentPage(1)
      fetchTransactions(1)
      fetchKpis()
      setPdfPassword('')
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Unknown error'
      setUploadError(message)
      if (message.toLowerCase().includes('password')) {
        passwordInputRef.current?.focus()
      }
    } finally {
      setUploading(false)
      event.target.value = ''
    }
  }

  const currencyFormatter = useMemo(
    () =>
      new Intl.NumberFormat('en-IN', {
        style: 'currency',
        currency: 'INR',
        maximumFractionDigits: 0,
      }),
    [],
  )
  const wantsRatio = Math.min(1, Math.max(0, kpis?.wants_gauge?.ratio ?? 0))
  const gaugeDegrees = wantsRatio * 360
  const wantsPercent = Number.isNaN(wantsRatio) ? 0 : Math.round(wantsRatio * 100)
  const gaugeClass = kpis?.wants_gauge?.threshold_crossed ? 'is-alert' : ''
  const lootDrop = kpis?.recent_loot_drop
  const lootRarity = lootDrop?.rarity ?? 'common'
  const lootTimestamp = lootDrop?.occurred_at
    ? new Date(lootDrop.occurred_at).toLocaleString('en-IN', {
        month: 'short',
        day: '2-digit',
        hour: '2-digit',
        minute: '2-digit',
      })
    : null
  const bestMonth = kpis?.best_month
  const bestMonthDeltaLabel = bestMonth
    ? bestMonth.is_current_best
      ? bestMonth.delta_pct === null
        ? 'First record unlocked'
        : `${formatPercent(bestMonth.delta_pct)} vs previous best`
      : `${formatPercent(bestMonth.delta_pct)} vs this month`
    : null
  const kpiCards = [
    {
      key: 'income',
      label: 'Income',
      value: kpis?.income_amount ?? 0,
      subtitle: `Month ${kpis?.month ?? '—'}`,
      accent: 'spendsense__step--healthy',
      icon: '💰',
    },
    {
      key: 'needs',
      label: 'Needs',
      value: kpis?.needs_amount ?? 0,
      subtitle: 'Essentials this month',
      accent: 'spendsense__step--warning',
      icon: '🛡️',
    },
    {
      key: 'wants',
      label: 'Wants',
      value: kpis?.wants_amount ?? 0,
      subtitle: 'Lifestyle spending',
      accent: 'spendsense__step--neutral',
      icon: '🎯',
    },
  ]

  const handleFilterChange = (updates: Partial<typeof filters>) => {
    setFilters((prev) => ({ ...prev, ...updates }))
    setCurrentPage(1)
  }

  const handleClearFilters = () => {
    setFilters({
      search: '',
      category: '',
      subcategory: '',
      channel: '',
    })
    setCurrentPage(1)
  }

  return (
    <section 
      ref={elementRef}
      className="spendsense glass-card"
      style={{ 
        position: 'relative',
        overflowY: 'auto',
        maxHeight: '100vh',
        touchAction: 'pan-y',
      }}
    >
      {/* Pull-to-refresh indicator */}
      {(isPulling || isRefreshing) && (
        <div 
          className="pull-to-refresh-indicator"
          style={{
            position: 'absolute',
            top: 0,
            left: 0,
            right: 0,
            height: `${Math.min(80, progress * 80)}px`,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            background: 'var(--background)',
            zIndex: 1000,
            transition: isRefreshing ? 'height 0.3s ease' : 'none',
          }}
        >
          {isRefreshing ? (
            <span style={{ color: 'var(--primary)', fontSize: '14px' }}>Refreshing...</span>
          ) : (
            <span style={{ 
              color: 'var(--primary)', 
              fontSize: '14px',
              opacity: progress,
            }}>
              {progress >= 1 ? 'Release to refresh' : 'Pull to refresh'}
            </span>
          )}
        </div>
      )}
      <header className="spendsense__header">
        <div>
          <p className="eyebrow">SpendSense pipeline</p>
          <h3>Incoming transaction batches</h3>
        </div>
        <div className="spendsense__actions">
          <button 
            className="ghost-button" 
            onClick={handleRefresh}
            disabled={isRefreshing || loading || kpiLoading}
            title="Refresh data"
            style={{ marginRight: '0.5rem' }}
          >
            {isRefreshing ? 'Refreshing...' : '🔄'}
          </button>
          <input
            ref={fileInputRef}
            type="file"
            accept=".csv,.xls,.xlsx,.pdf"
            hidden
            onChange={handleFileChange}
          />
          <input
            type="password"
            ref={passwordInputRef}
            className="input-field spendsense__pdfInput"
            placeholder="PDF password (optional)"
            value={pdfPassword}
            onChange={(event) => setPdfPassword(event.target.value)}
          />
          <button className="ghost-button" onClick={handleUploadClick} disabled={uploading}>
            {uploading ? 'Uploading…' : 'Upload statement'}
          </button>
        </div>
      </header>

      <div className="spendsense__tabs">
        <button
          className={`spendsense__tab ${activeTab === 'kpis' ? 'is-active' : ''}`}
          onClick={() => setActiveTab('kpis')}
          type="button"
        >
          KPIs & Insights
        </button>
        <button
          className={`spendsense__tab ${activeTab === 'transactions' ? 'is-active' : ''}`}
          onClick={() => setActiveTab('transactions')}
          type="button"
        >
          Transactions
        </button>
      </div>

      {activeTab === 'kpis' && (
        <>
          <div className="spendsense__pipeline">
            {kpiLoading ? (
              <p className="status-loading">Loading KPI…</p>
            ) : kpiError ? (
              <p className="error-message">{kpiError}</p>
            ) : (
              kpiCards.map((card) => (
                <article key={card.key} className={`spendsense__step ${card.accent}`}>
                  <div className="spendsense__stepIcon" aria-hidden="true">
                    {card.icon}
                  </div>
                  <div>
                    <p className="spendsense__stepTitle">{card.label}</p>
                    <p className="spendsense__kpiValue">{currencyFormatter.format(card.value)}</p>
                    <p className="spendsense__kpiChange">{card.subtitle}</p>
                  </div>
                </article>
              ))
            )}
          </div>
          {!kpiLoading && !kpiError && (
            <div className="spendsense__gamifiedRow">
              <article className={`spendsense__gaugeCard ${gaugeClass}`}>
                <svg className="spendsense__gaugeChart" viewBox="0 0 120 120">
                  <circle className="gauge-bg" cx="60" cy="60" r="48" />
                  <circle
                    className="gauge-fill"
                    cx="60"
                    cy="60"
                    r="48"
                    strokeDasharray={`${Math.max(0, Math.min(100, wantsRatio * 100)) * 3.02} 999`}
                    strokeDashoffset="0"
                  />
                  <text x="60" y="54" textAnchor="middle" className="gauge-label">
                    Wants
                  </text>
                  <text x="60" y="78" textAnchor="middle" className="gauge-value">
                    {wantsPercent}%
                  </text>
                </svg>
                <div className="spendsense__gaugeMeta">
                  <p className="spendsense__stepTitle">Wants vs Needs</p>
                  <p className="spendsense__gaugeLabel">{kpis?.wants_gauge?.label ?? 'Chill Mode'}</p>
                  <small>
                    Needs share: {Number.isFinite(100 - wantsPercent) ? `${100 - wantsPercent}%` : '—'}
                  </small>
                </div>
              </article>
              <article className={`spendsense__bestMonthCard ${bestMonth?.is_current_best ? 'is-current' : ''}`}>
                <div className="spendsense__bestBadge">
                  <p className="eyebrow">Leaderboard</p>
                  {bestMonth?.is_current_best && <span className="spendsense__confetti">🎉</span>}
                </div>
                <h4>{formatMonthLabel(bestMonth?.month)}</h4>
                <p className="spendsense__bestMetric">
                  {currencyFormatter.format(
                    bestMonth ? bestMonth.income_amount - bestMonth.wants_amount : 0,
                  )}
                </p>
                <p className="spendsense__bestDelta">{bestMonthDeltaLabel ?? 'Upload data to unlock stats'}</p>
              </article>
              <article
                className={`spendsense__lootCard rarity-${lootRarity} ${lootFlip ? 'is-flipped' : ''}`}
                aria-live="polite"
              >
                <div className="spendsense__lootFace spendsense__lootFace--front">
                  {lootDrop ? (
                    <>
                      <p className="eyebrow">Latest loot</p>
                      <h4>{rarityLabel[lootRarity] ?? 'Fresh batch'}</h4>
                      <p className="spendsense__lootCount">
                        You unlocked <strong>{lootDrop.transactions_ingested}</strong> txns
                      </p>
                      <span className="spendsense__chip spendsense__chip--rarity">
                        {lootDrop.file_name ?? lootDrop.status}
                      </span>
                    </>
                  ) : (
                    <>
                      <p className="eyebrow">No drops yet</p>
                      <p>Upload a statement or enable Gmail to reveal a loot drop.</p>
                    </>
                  )}
                </div>
                <div className="spendsense__lootFace spendsense__lootFace--back">
                  {lootDrop ? (
                    <>
                      <p>Status: {formatLabel(lootDrop.status)}</p>
                      {lootTimestamp && <small>{lootTimestamp}</small>}
                    </>
                  ) : (
                    <p>Complete an ingest to flip this card.</p>
                  )}
                </div>
              </article>
            </div>
          )}
          {kpis?.top_categories?.length ? (
            <div className="spendsense__topCategories">
              <p className="eyebrow">Top categories</p>
              <ul>
                {kpis.top_categories.map((cat) => (
                  <li
                    key={`${cat.category_code}-${cat.txn_count}`}
                    className={`tier-${cat.tier}`}
                    title={categoryTooltip(cat)}
                  >
                    <div>
                      <span className={`spendsense__tierBadge tier-${cat.tier}`}>
                        {tierLabel[cat.tier] ?? cat.tier}
                      </span>
                      <div className="spendsense__categoryName">
                        {cat.category_name ?? formatLabel(cat.category_code)}
                      </div>
                      <small>
                        {(cat.share * 100).toFixed(1)}% share · {cat.txn_count} txns
                      </small>
                    </div>
                    <div className="spendsense__categoryMeta">
                      <strong>{currencyFormatter.format(cat.spend_amount ?? 0)}</strong>
                      <span
                        className={`spendsense__trend ${
                          cat.change_pct === null ? '' : cat.change_pct >= 0 ? 'is-up' : 'is-down'
                        }`}
                      >
                        {cat.change_pct === null ? '—' : formatPercent(cat.change_pct)}
                      </span>
                    </div>
                  </li>
                ))}
              </ul>
            </div>
          ) : null}
        </>
      )}

      {activeTab === 'transactions' && (
      <div 
        className="spendsense__transactions"
        style={{ 
          marginTop: isPulling || isRefreshing ? `${Math.min(80, progress * 80)}px` : '0',
          transition: isRefreshing ? 'margin-top 0.3s ease' : 'none',
        }}
      >
        <header className="spendsense__transactionsHeader">
          <div>
            <p className="eyebrow">Transactions</p>
            <h3>Latest categorized activity</h3>
          </div>
          <div style={{ display: 'flex', gap: '0.5rem', alignItems: 'center' }}>
            <button 
              className="ghost-button" 
              onClick={handleRefresh}
              disabled={isRefreshing || loading}
              title="Refresh transactions"
            >
              {isRefreshing ? 'Refreshing...' : '🔄 Refresh'}
            </button>
            <button className="ghost-button" onClick={() => setFilterPanelOpen((prev) => !prev)}>
              {filterPanelOpen ? 'Hide Filters' : 'Filter'}
            </button>
          </div>
        </header>
        {filterPanelOpen && (
          <div className="spendsense__filters">
            <div className="spendsense__filterGroup">
              <label>Search</label>
              <input
                type="text"
                className="input-field"
                placeholder="Merchant or description"
                value={filters.search}
                onChange={(event) => handleFilterChange({ search: event.target.value })}
              />
            </div>
            <div className="spendsense__filterGroup">
              <label>Category</label>
              <select
                className="input-field"
                value={filters.category}
                onChange={(event) =>
                  handleFilterChange({ category: event.target.value, subcategory: '' })
                }
              >
                <option value="">All categories</option>
                {filterCategories.map((cat) => (
                  <option key={cat.code} value={cat.code}>
                    {cat.name}
                  </option>
                ))}
              </select>
            </div>
            <div className="spendsense__filterGroup">
              <label>Subcategory</label>
              <select
                className="input-field"
                value={filters.subcategory}
                onChange={(event) => handleFilterChange({ subcategory: event.target.value })}
                disabled={!filters.category}
              >
                <option value="">All subcategories</option>
                {filterSubcategories.map((sub) => (
                  <option key={sub.code} value={sub.code}>
                    {sub.name}
                  </option>
                ))}
              </select>
            </div>
            <div className="spendsense__filterGroup">
              <label>Channel</label>
              <select
                className="input-field"
                value={filters.channel}
                onChange={(event) => handleFilterChange({ channel: event.target.value })}
              >
                <option value="">All channels</option>
                {CHANNEL_OPTIONS.map((option) => (
                  <option key={option.value} value={option.value}>
                    {option.label}
                  </option>
                ))}
              </select>
            </div>
            <div className="spendsense__filterActions">
              <button className="ghost-button" onClick={handleClearFilters}>
                Clear filters
              </button>
            </div>
          </div>
        )}
        {uploadError ? <p className="error-message">{uploadError}</p> : null}
        {loading ? (
          <p className="status-loading">Loading transactions…</p>
        ) : error ? (
          <p className="error-message">{error}</p>
        ) : (
          <table className="spendsense__table">
            <thead>
              <tr>
                <th>Date</th>
                <th>Merchant</th>
                <th>Category</th>
                <th>Subcategory</th>
                <th className="spendsense__amountCol">Amount</th>
                <th className="spendsense__actionsCol">Actions</th>
              </tr>
            </thead>
            <tbody>
              {(transactions || []).map((txn) => (
                <TransactionRow
                  key={txn.txn_id}
                  transaction={txn}
                  session={session}
                  onUpdate={() => fetchTransactions(currentPage)}
                  onDelete={() => {
                    setTransactions((prev) => prev.filter((t) => t.txn_id !== txn.txn_id))
                    setTotalCount((prev) => Math.max(0, prev - 1))
                  }}
                />
              ))}
            </tbody>
          </table>
        )}
        {!loading && !error && totalCount > 0 && (
          <div className="spendsense__pagination">
            <div className="spendsense__paginationInfo">
              Showing {((currentPage - 1) * PAGE_SIZE) + 1} - {Math.min(currentPage * PAGE_SIZE, totalCount)} of {totalCount}
            </div>
            <div className="spendsense__paginationControls">
              <button
                className="ghost-button"
                onClick={() => setCurrentPage((p) => Math.max(1, p - 1))}
                disabled={currentPage === 1}
              >
                Previous
              </button>
              <div className="spendsense__pageNumbers">
                {Array.from({ length: Math.min(5, totalPages) }, (_, i) => {
                  let pageNum: number
                  if (totalPages <= 5) {
                    pageNum = i + 1
                  } else if (currentPage <= 3) {
                    pageNum = i + 1
                  } else if (currentPage >= totalPages - 2) {
                    pageNum = totalPages - 4 + i
                  } else {
                    pageNum = currentPage - 2 + i
                  }
                  return (
                    <button
                      key={pageNum}
                      className={`ghost-button ${currentPage === pageNum ? 'active' : ''}`}
                      onClick={() => setCurrentPage(pageNum)}
                    >
                      {pageNum}
                    </button>
                  )
                })}
              </div>
              <button
                className="ghost-button"
                onClick={() => setCurrentPage((p) => Math.min(totalPages, p + 1))}
                disabled={currentPage === totalPages}
              >
                Next
              </button>
            </div>
          </div>
        )}
      </div>
      )}
    </section>
  )
}

