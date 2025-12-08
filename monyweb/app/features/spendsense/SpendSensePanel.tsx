'use client'

import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import type { Session } from '@supabase/supabase-js'
import './SpendSensePanel.css'
import { env } from '../../env'
import { usePullToRefresh } from '../../hooks/usePullToRefresh'
import { useToast, ToastContainer } from '../../components/Toast'
import { useKeyboardShortcuts } from '../../hooks/useKeyboardShortcuts'
import { SimpleLineChart } from '../../components/SimpleChart'

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
  selected?: boolean
  onSelect?: (selected: boolean) => void
  isRecurring?: boolean
}

function TransactionRow({ transaction, session, onUpdate, onDelete, selected, onSelect, isRecurring }: TransactionRowProps) {
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
  const toast = useToast()

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
        .then((data: any[]) => {
          // Map backend response to frontend format
          const mapped = data.map((item: any) => ({
            code: item.category_code || item.code,
            name: item.category_name || item.name,
          }))
          setCategories(mapped)
          // Find current category code
          const currentCat = mapped.find((c) => c.name === transaction.category)
          if (currentCat) {
            setSelectedCategory(currentCat.code)
            // Fetch subcategories for this category
            fetch(`${env.apiBaseUrl}/spendsense/subcategories?category_code=${currentCat.code}`, {
              headers: { Authorization: `Bearer ${session.access_token}` },
            })
              .then((res) => res.json())
              .then((subs: any[]) => {
                // Map backend response to frontend format
                const mappedSubs = subs.map((item: any) => ({
                  code: item.subcategory_code || item.code,
                  name: item.subcategory_name || item.name,
                }))
                setSubcategories(mappedSubs)
                const currentSub = mappedSubs.find((s) => s.name === transaction.subcategory)
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
      toast.success('Transaction updated successfully')
      onUpdate()
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Unknown error'
      setError(message)
      toast.error(message)
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
      toast.success('Transaction deleted successfully')
      onDelete()
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Unknown error'
      setError(message)
      toast.error(message)
      setDeleting(false)
    }
  }

  if (editing) {
    return (
      <tr className="spendsense__editRow">
        {onSelect && (
          <td>
            <input
              type="checkbox"
              checked={selected || false}
              onChange={(e) => onSelect(e.target.checked)}
              aria-label={`Select transaction ${transaction.txn_id}`}
            />
          </td>
        )}
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
              <option key="auto-channel" value="">Auto (based on detection)</option>
              {CHANNEL_OPTIONS.map((channelOption, index) => (
                <option key={`channel-${channelOption.value || index}-${index}`} value={channelOption.value}>
                  {channelOption.label}
                </option>
              ))}
              {selectedChannel &&
                !CHANNEL_META[selectedChannel] && (
                  <option key={`custom-${selectedChannel}`} value={selectedChannel}>{selectedChannel}</option>
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
                  .then((subs: any[]) => {
                    // Map backend response to frontend format
                    const mapped = subs.map((item: any) => ({
                      code: item.subcategory_code || item.code,
                      name: item.subcategory_name || item.name,
                    }))
                    setSubcategories(mapped)
                  })
              } else {
                setSubcategories([])
              }
            }}
          >
            <option key="no-category" value="">—</option>
            {categories.map((cat, index) => (
              <option key={`cat-${cat.code || index}-${index}`} value={cat.code}>
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
            <option key="no-subcategory" value="">—</option>
            {subcategories.map((sub, index) => (
              <option key={`sub-${sub.code || index}-${index}`} value={sub.code}>
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
      <tr className={isRecurring ? 'spendsense__recurringTransaction' : ''}>
        {onSelect && (
          <td>
            <input
              type="checkbox"
              checked={selected || false}
              onChange={(e) => onSelect(e.target.checked)}
              aria-label={`Select transaction ${transaction.txn_id}`}
            />
          </td>
        )}
        <td>
          {new Date(transaction.txn_date).toLocaleDateString('en-IN', { day: '2-digit', month: 'short' })}
          {isRecurring && (
            <span className="spendsense__recurringBadge" title="Recurring transaction">🔄</span>
          )}
        </td>
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
          <td colSpan={onSelect ? 7 : 6} className="spendsense__deleteConfirm">
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
  const [uploadProgress, setUploadProgress] = useState(0)
  const [pdfPassword, setPdfPassword] = useState('')
  const [isDragOver, setIsDragOver] = useState(false)
  const fileInputRef = useRef<HTMLInputElement | null>(null)
  const passwordInputRef = useRef<HTMLInputElement | null>(null)
  const uploadAreaRef = useRef<HTMLDivElement | null>(null)
  const [filters, setFilters] = useState({
    search: '',
    category: '',
    subcategory: '',
    channel: '',
    dateFrom: '',
    dateTo: '',
    amountMin: '',
    amountMax: '',
  })
  const [searchDebounce, setSearchDebounce] = useState('')
  const [searchSuggestions, setSearchSuggestions] = useState<string[]>([])
  const [showSuggestions, setShowSuggestions] = useState(false)
  const [searchHistory, setSearchHistory] = useState<string[]>([])
  const [filterPanelOpen, setFilterPanelOpen] = useState(false)
  const [filterCategories, setFilterCategories] = useState<Category[]>([])
  const [filterSubcategories, setFilterSubcategories] = useState<Subcategory[]>([])
  const [kpis, setKpis] = useState<DashboardKPI | null>(null)
  const [kpiLoading, setKpiLoading] = useState(true)
  const [kpiError, setKpiError] = useState<string | null>(null)
  const [kpiMonth, setKpiMonth] = useState<string | null>(null) // YYYY-MM format
  const [availableMonths, setAvailableMonths] = useState<string[]>([])
  const [lootFlip, setLootFlip] = useState(false)
  const [activeTab, setActiveTab] = useState<'kpis' | 'insights' | 'transactions'>('kpis')
  const [insights, setInsights] = useState<any>(null)
  const [insightsLoading, setInsightsLoading] = useState(false)
  const [insightsError, setInsightsError] = useState<string | null>(null)
  const [spendingTrends, setSpendingTrends] = useState<Array<{ date: string; value: number; label: string }>>([])
  const [trendsLoading, setTrendsLoading] = useState(false)
  const [insightMessages, setInsightMessages] = useState<Array<{ type: string; message: string; severity: 'info' | 'warning' | 'success' }>>([])
  const [recurringTransactions, setRecurringTransactions] = useState<Set<string>>(new Set())

  const currencyFormatter = useMemo(
    () =>
      new Intl.NumberFormat('en-IN', {
        style: 'currency',
        currency: 'INR',
        maximumFractionDigits: 0,
      }),
    [],
  )
  const [isMobile, setIsMobile] = useState(false)
  const [selectedTransactions, setSelectedTransactions] = useState<Set<string>>(new Set())
  const toast = useToast()

  const totalPages = Math.ceil(totalCount / PAGE_SIZE)

  // Detect mobile viewport
  useEffect(() => {
    const checkMobile = () => {
      setIsMobile(window.innerWidth < 768)
    }
    checkMobile()
    window.addEventListener('resize', checkMobile)
    return () => window.removeEventListener('resize', checkMobile)
  }, [])

  // Load search history from localStorage
  useEffect(() => {
    const saved = localStorage.getItem('spendsense_search_history')
    if (saved) {
      try {
        setSearchHistory(JSON.parse(saved))
      } catch {
        // Ignore parse errors
      }
    }
  }, [])

  // Generate search suggestions
  useEffect(() => {
    if (!searchDebounce.trim()) {
      setSearchSuggestions(searchHistory.slice(0, 5))
      return
    }

    const query = searchDebounce.toLowerCase()
    const suggestions: string[] = []
    
    // Add matching merchants from current transactions
    const merchantMatches = Array.from(
      new Set(
        transactions
          .map(t => t.merchant)
          .filter(m => m && m.toLowerCase().includes(query))
          .slice(0, 5)
      )
    )
    suggestions.push(...merchantMatches)

    // Add matching history items
    const historyMatches = searchHistory.filter(h => 
      h.toLowerCase().includes(query) && !suggestions.includes(h)
    ).slice(0, 3)
    suggestions.push(...historyMatches)

    setSearchSuggestions(suggestions.slice(0, 8))
  }, [searchDebounce, transactions, searchHistory])

  // Debounce search
  useEffect(() => {
    const timer = setTimeout(() => {
      setFilters((prev) => ({ ...prev, search: searchDebounce }))
      setCurrentPage(1)
      
      // Save to history
      if (searchDebounce.trim() && !searchHistory.includes(searchDebounce.trim())) {
        const updated = [searchDebounce.trim(), ...searchHistory].slice(0, 10)
        setSearchHistory(updated)
        localStorage.setItem('spendsense_search_history', JSON.stringify(updated))
      }
    }, 300)
    return () => clearTimeout(timer)
  }, [searchDebounce, searchHistory])

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
      if (appliedFilters.dateFrom) params.append('date_from', appliedFilters.dateFrom)
      if (appliedFilters.dateTo) params.append('date_to', appliedFilters.dateTo)
      if (appliedFilters.amountMin) params.append('amount_min', appliedFilters.amountMin)
      if (appliedFilters.amountMax) params.append('amount_max', appliedFilters.amountMax)

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
      .then((data: any[]) => {
        // Map backend response (category_code, category_name) to frontend format (code, name)
        const mapped = data.map((item: any) => ({
          code: item.category_code || item.code,
          name: item.category_name || item.name,
        }))
        setFilterCategories(mapped)
      })
      .catch((err) => {
        console.error('Failed to fetch categories:', err)
        setFilterCategories([])
      })
  }, [session.access_token])

  useEffect(() => {
    if (filters.category) {
      fetch(`${env.apiBaseUrl}/spendsense/subcategories?category_code=${filters.category}`, {
        headers: { Authorization: `Bearer ${session.access_token}` },
      })
        .then((res) => res.json())
        .then((data: any[]) => {
          // Map backend response (subcategory_code, subcategory_name) to frontend format (code, name)
          const mapped = data.map((item: any) => ({
            code: item.subcategory_code || item.code,
            name: item.subcategory_name || item.name,
          }))
          setFilterSubcategories(mapped)
        })
        .catch((err) => {
          console.error('Failed to fetch subcategories:', err)
          setFilterSubcategories([])
        })
    } else {
      setFilterSubcategories([])
    }
  }, [filters.category, session.access_token])

  const fetchInsights = useCallback(() => {
    if (!session?.access_token) return
    setInsightsLoading(true)
    setInsightsError(null)
    
    fetch(`${env.apiBaseUrl}/spendsense/insights`, {
      headers: {
        Authorization: `Bearer ${session.access_token}`,
      },
    })
      .then((response) => {
        if (!response.ok) throw new Error('Unable to load insights')
        return response.json()
      })
      .then((data) => {
        setInsights(data)
      })
      .catch((err) => {
        setInsightsError(err instanceof Error ? err.message : 'Unknown error')
      })
      .finally(() => setInsightsLoading(false))
  }, [session?.access_token])

  useEffect(() => {
    if (activeTab === 'insights' && !insights && !insightsLoading) {
      fetchInsights()
    }
  }, [activeTab, insights, insightsLoading, fetchInsights])

  const fetchKpis = useCallback(() => {
    setKpiLoading(true)
    setKpiError(null)
    const url = new URL(`${env.apiBaseUrl}/spendsense/kpis`)
    if (kpiMonth) {
      url.searchParams.append('month', kpiMonth)
    }
    return fetch(url.toString(), {
      headers: { Authorization: `Bearer ${session.access_token}` },
    })
      .then((res) => {
        if (!res.ok) throw new Error('Unable to load KPIs')
        return res.json() as Promise<DashboardKPI>
      })
      .then((data) => {
        setKpis(data)
      })
      .catch((err) => setKpiError(err instanceof Error ? err.message : 'Unknown error'))
      .finally(() => setKpiLoading(false))
  }, [session.access_token, kpiMonth])

  // Fetch available months for filter
  useEffect(() => {
    if (activeTab === 'kpis' && session?.access_token) {
      fetch(`${env.apiBaseUrl}/spendsense/kpis/available-months`, {
        headers: { Authorization: `Bearer ${session.access_token}` },
      })
        .then((res) => res.json())
        .then((months: string[]) => setAvailableMonths(months))
        .catch(() => {
          // Fallback: extract months from transactions
          if (transactions.length > 0) {
            const months = new Set<string>()
            transactions.forEach(t => {
              const date = new Date(t.txn_date)
              const monthStr = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}`
              months.add(monthStr)
            })
            setAvailableMonths(Array.from(months).sort().reverse())
          }
        })
    }
  }, [activeTab, session?.access_token, transactions])

  useEffect(() => {
    fetchKpis()
  }, [fetchKpis])

  // Fetch spending trends (mock data for now - replace with actual API call)
  useEffect(() => {
    if (activeTab === 'kpis' && !trendsLoading) {
      setTrendsLoading(true)
      // Generate mock trend data from transactions
      const now = new Date()
      const months: Array<{ date: string; value: number; label: string }> = []
      for (let i = 5; i >= 0; i--) {
        const date = new Date(now.getFullYear(), now.getMonth() - i, 1)
        const monthTransactions = transactions.filter(t => {
          const txnDate = new Date(t.txn_date)
          return txnDate.getMonth() === date.getMonth() && txnDate.getFullYear() === date.getFullYear()
        })
        const total = monthTransactions
          .filter(t => t.direction === 'debit')
          .reduce((sum, t) => sum + Math.abs(t.amount), 0)
        months.push({
          date: date.toISOString(),
          value: total,
          label: date.toLocaleDateString('en-IN', { month: 'short', year: '2-digit' }),
        })
      }
      setSpendingTrends(months)
      setTrendsLoading(false)
    }
  }, [activeTab, transactions, trendsLoading])

  // Generate AI insights and detect recurring transactions
  useEffect(() => {
    if (transactions.length === 0) {
      setInsightMessages([])
      setRecurringTransactions(new Set())
      return
    }

    const newInsights: Array<{ type: string; message: string; severity: 'info' | 'warning' | 'success' }> = []
    const recurring = new Set<string>()

    // Detect recurring transactions (same merchant, similar amount, monthly pattern)
    const merchantGroups = new Map<string, Array<{ txn: Transaction; date: Date }>>()
    transactions.forEach(txn => {
      if (!txn.merchant) return
      const key = txn.merchant.toLowerCase()
      if (!merchantGroups.has(key)) {
        merchantGroups.set(key, [])
      }
      merchantGroups.get(key)!.push({ txn, date: new Date(txn.txn_date) })
    })

    merchantGroups.forEach((group, merchant) => {
      if (group.length >= 3) {
        // Check if amounts are similar (within 10%)
        const amounts = group.map(g => Math.abs(g.txn.amount))
        const avgAmount = amounts.reduce((a, b) => a + b, 0) / amounts.length
        const isSimilar = amounts.every(amt => Math.abs(amt - avgAmount) / avgAmount < 0.1)
        
        if (isSimilar) {
          group.forEach(g => recurring.add(g.txn.txn_id))
          newInsights.push({
            type: 'recurring',
            message: `Recurring payment detected: ${group[0].txn.merchant} (~${currencyFormatter.format(avgAmount)}/month)`,
            severity: 'info',
          })
        }
      }
    })

    // Spending pattern insights
    const monthlySpending = transactions
      .filter(t => t.direction === 'debit')
      .reduce((sum, t) => sum + Math.abs(t.amount), 0)
    
    const avgTransaction = monthlySpending / transactions.filter(t => t.direction === 'debit').length || 0
    
    if (avgTransaction > 10000) {
      newInsights.push({
        type: 'spending',
        message: `High average transaction size: ${currencyFormatter.format(avgTransaction)}`,
        severity: 'warning',
      })
    }

    // Category concentration
    const categorySpend = new Map<string, number>()
    transactions.filter(t => t.direction === 'debit').forEach(t => {
      const cat = t.category || 'Uncategorized'
      categorySpend.set(cat, (categorySpend.get(cat) || 0) + Math.abs(t.amount))
    })
    
    const topCategory = Array.from(categorySpend.entries())
      .sort((a, b) => b[1] - a[1])[0]
    
    if (topCategory && topCategory[1] / monthlySpending > 0.4) {
      newInsights.push({
        type: 'category',
        message: `${topCategory[0]} accounts for ${((topCategory[1] / monthlySpending) * 100).toFixed(0)}% of spending`,
        severity: 'info',
      })
    }

    setInsightMessages(newInsights.slice(0, 5))
    setRecurringTransactions(recurring)
  }, [transactions, currencyFormatter])

  // Pull-to-refresh handler
  const handleRefresh = useCallback(async () => {
    await Promise.all([
      fetchTransactions(currentPage, filters),
      fetchKpis(),
    ])
  }, [fetchTransactions, fetchKpis, currentPage, filters])

  // Export CSV handler
  const handleExportCSV = useCallback(async () => {
    try {
      const params = new URLSearchParams()
      if (filters.search.trim()) params.append('search', filters.search.trim())
      if (filters.category) params.append('category_code', filters.category)
      if (filters.subcategory) params.append('subcategory_code', filters.subcategory)
      if (filters.channel) params.append('channel', filters.channel)
      if (filters.dateFrom) params.append('date_from', filters.dateFrom)
      if (filters.dateTo) params.append('date_to', filters.dateTo)
      if (filters.amountMin) params.append('amount_min', filters.amountMin)
      if (filters.amountMax) params.append('amount_max', filters.amountMax)
      
      // Fetch all transactions (no pagination for export)
      params.append('limit', '10000')
      params.append('offset', '0')

      const response = await fetch(`${env.apiBaseUrl}/spendsense/transactions?${params.toString()}`, {
        headers: { Authorization: `Bearer ${session.access_token}` },
      })
      
      if (!response.ok) throw new Error('Failed to fetch transactions')
      
      const data = await response.json() as TransactionResponse
      const transactions = data.transactions || []
      
      // Convert to CSV
      const headers = ['Date', 'Merchant', 'Category', 'Subcategory', 'Channel', 'Amount', 'Direction']
      const rows = transactions.map(t => [
        t.txn_date,
        t.merchant || '',
        t.category || '',
        t.subcategory || '',
        t.channel || '',
        Math.abs(t.amount).toString(),
        t.direction,
      ])
      
      const csvContent = [
        headers.join(','),
        ...rows.map(row => row.map(cell => `"${cell}"`).join(','))
      ].join('\n')
      
      // Download
      const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' })
      const link = document.createElement('a')
      const url = URL.createObjectURL(blob)
      link.setAttribute('href', url)
      link.setAttribute('download', `transactions_${new Date().toISOString().split('T')[0]}.csv`)
      link.style.visibility = 'hidden'
      document.body.appendChild(link)
      link.click()
      document.body.removeChild(link)
      
      toast.success(`Exported ${transactions.length} transactions to CSV`)
    } catch (err) {
      toast.error(err instanceof Error ? err.message : 'Export failed')
    }
  }, [filters, session.access_token, toast])

  // Keyboard shortcuts
  useKeyboardShortcuts([
    {
      key: 'r',
      meta: true,
      action: handleRefresh,
      description: 'Refresh data',
    },
    {
      key: 'f',
      meta: true,
      action: () => setFilterPanelOpen(prev => !prev),
      description: 'Toggle filters',
    },
    {
      key: 'e',
      meta: true,
      action: handleExportCSV,
      description: 'Export to CSV',
    },
    {
      key: '1',
      meta: true,
      action: () => setActiveTab('kpis'),
      description: 'Switch to KPIs tab',
    },
    {
      key: '2',
      meta: true,
      action: () => setActiveTab('transactions'),
      description: 'Switch to Transactions tab',
    },
  ], true)

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

  const handleFileUpload = async (file: File) => {
    if (!file) return
    setUploadError(null)
    setUploading(true)
    setUploadProgress(0)
    try {
      const formData = new FormData()
      formData.append('file', file)
      if (pdfPassword.trim()) {
        formData.append('password', pdfPassword.trim())
      }
      
      const xhr = new XMLHttpRequest()
      xhr.upload.addEventListener('progress', (e) => {
        if (e.lengthComputable) {
          setUploadProgress((e.loaded / e.total) * 100)
        }
      })

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
      
      setUploadProgress(100)
      toast.success('File uploaded successfully')
      // Reset to first page and refresh after upload
      setCurrentPage(1)
      fetchTransactions(1)
      fetchKpis()
      setPdfPassword('')
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Unknown error'
      setUploadError(message)
      toast.error(message)
      if (message.toLowerCase().includes('password')) {
        passwordInputRef.current?.focus()
      }
    } finally {
      setUploading(false)
      setUploadProgress(0)
      setIsDragOver(false)
    }
  }

  const handleFileChange = async (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0]
    if (file) {
      await handleFileUpload(file)
      event.target.value = ''
    }
  }

  const handleDragOver = (e: React.DragEvent) => {
    e.preventDefault()
    e.stopPropagation()
    setIsDragOver(true)
  }

  const handleDragLeave = (e: React.DragEvent) => {
    e.preventDefault()
    e.stopPropagation()
    setIsDragOver(false)
  }

  const handleDrop = async (e: React.DragEvent) => {
    e.preventDefault()
    e.stopPropagation()
    setIsDragOver(false)
    
    const file = e.dataTransfer.files?.[0]
    if (file && (file.type === 'application/pdf' || file.name.match(/\.(csv|xls|xlsx)$/i))) {
      await handleFileUpload(file)
    } else {
      toast.error('Please upload a PDF, CSV, or Excel file')
    }
  }

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
      dateFrom: '',
      dateTo: '',
      amountMin: '',
      amountMax: '',
    })
    setSearchDebounce('')
    setCurrentPage(1)
  }

  // Bulk operations
  const handleSelectTransaction = (txnId: string, selected: boolean) => {
    setSelectedTransactions(prev => {
      const next = new Set(prev)
      if (selected) {
        next.add(txnId)
      } else {
        next.delete(txnId)
      }
      return next
    })
  }

  const handleSelectAll = () => {
    if (selectedTransactions.size === transactions.length) {
      setSelectedTransactions(new Set())
    } else {
      setSelectedTransactions(new Set(transactions.map(t => t.txn_id)))
    }
  }

  const handleBulkDelete = async () => {
    if (selectedTransactions.size === 0) return
    
    if (!confirm(`Delete ${selectedTransactions.size} transaction(s)? This cannot be undone.`)) {
      return
    }

    try {
      const deletePromises = Array.from(selectedTransactions).map(txnId =>
        fetch(`${env.apiBaseUrl}/spendsense/transactions/${txnId}`, {
          method: 'DELETE',
          headers: { Authorization: `Bearer ${session.access_token}` },
        })
      )
      
      await Promise.all(deletePromises)
      toast.success(`Deleted ${selectedTransactions.size} transaction(s)`)
      setSelectedTransactions(new Set())
      fetchTransactions(currentPage, filters)
      setTotalCount(prev => Math.max(0, prev - selectedTransactions.size))
    } catch (err) {
      toast.error(err instanceof Error ? err.message : 'Bulk delete failed')
    }
  }

  const handleBulkCategorize = async (categoryCode: string, subcategoryCode: string) => {
    if (selectedTransactions.size === 0) return

    try {
      const updatePromises = Array.from(selectedTransactions).map(txnId =>
        fetch(`${env.apiBaseUrl}/spendsense/transactions/${txnId}`, {
          method: 'PUT',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${session.access_token}`,
          },
          body: JSON.stringify({
            category_code: categoryCode || null,
            subcategory_code: subcategoryCode || null,
          }),
        })
      )
      
      await Promise.all(updatePromises)
      toast.success(`Updated ${selectedTransactions.size} transaction(s)`)
      setSelectedTransactions(new Set())
      fetchTransactions(currentPage, filters)
    } catch (err) {
      toast.error(err instanceof Error ? err.message : 'Bulk update failed')
    }
  }

  const activeFilterCount = Object.entries(filters).filter(([k, v]) => {
    if (k === 'search') return v.trim() !== ''
    return v !== ''
  }).length
  const hasActiveFilters = activeFilterCount > 0

  const getFilterLabel = (key: string, value: string) => {
    if (key === 'category') {
      const cat = filterCategories.find((c) => c.code === value)
      return cat?.name ?? value
    }
    if (key === 'subcategory') {
      const sub = filterSubcategories.find((s) => s.code === value)
      return sub?.name ?? value
    }
    if (key === 'channel') {
      return CHANNEL_META[value]?.label ?? value
    }
    return value
  }

  // Skeleton loaders
  const SkeletonCard = () => (
    <article className="spendsense__step spendsense__skeleton">
      <div className="spendsense__stepIcon spendsense__skeleton-shimmer" />
      <div style={{ flex: 1 }}>
        <div className="spendsense__skeleton-line" style={{ width: '60%', marginBottom: '0.5rem' }} />
        <div className="spendsense__skeleton-line" style={{ width: '80%', marginBottom: '0.25rem' }} />
        <div className="spendsense__skeleton-line" style={{ width: '40%' }} />
      </div>
    </article>
  )

  const SkeletonTableRow = () => (
    <tr className="spendsense__skeleton-row">
      <td><div className="spendsense__skeleton-line" style={{ width: '60px' }} /></td>
      <td><div className="spendsense__skeleton-line" style={{ width: '120px' }} /></td>
      <td><div className="spendsense__skeleton-line" style={{ width: '100px' }} /></td>
      <td><div className="spendsense__skeleton-line" style={{ width: '80px' }} /></td>
      <td><div className="spendsense__skeleton-line" style={{ width: '70px', marginLeft: 'auto' }} /></td>
      <td><div className="spendsense__skeleton-line" style={{ width: '80px', margin: '0 auto' }} /></td>
    </tr>
  )

  const TransactionCard = ({ transaction }: { transaction: Transaction }) => {
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
    const bankInfo = transaction.bank_code ? BANK_META[transaction.bank_code] : undefined
    const channelInfo = transaction.channel ? CHANNEL_META[transaction.channel] : undefined
    
    useEffect(() => {
      if (editing) {
        setMerchantName(transaction.merchant ?? '')
        setSelectedChannel(transaction.channel ?? '')
        fetch(`${env.apiBaseUrl}/spendsense/categories`, {
          headers: { Authorization: `Bearer ${session.access_token}` },
        })
          .then((res) => res.json())
          .then((data: any[]) => {
            // Map backend response to frontend format
            const mapped = data.map((item: any) => ({
              code: item.category_code || item.code,
              name: item.category_name || item.name,
            }))
            setCategories(mapped)
            const currentCat = mapped.find((c) => c.name === transaction.category)
            if (currentCat) {
              setSelectedCategory(currentCat.code)
              fetch(`${env.apiBaseUrl}/spendsense/subcategories?category_code=${currentCat.code}`, {
                headers: { Authorization: `Bearer ${session.access_token}` },
              })
                .then((res) => res.json())
                .then((subs: any[]) => {
                  // Map backend response to frontend format
                  const mappedSubs = subs.map((item: any) => ({
                    code: item.subcategory_code || item.code,
                    name: item.subcategory_name || item.name,
                  }))
                  setSubcategories(mappedSubs)
                  const currentSub = mappedSubs.find((s) => s.name === transaction.subcategory)
                  if (currentSub) setSelectedSubcategory(currentSub.code)
                })
            }
          })
      }
    }, [editing, session.access_token, transaction.category, transaction.subcategory, transaction.merchant, transaction.channel])

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
        toast.success('Transaction updated successfully')
        fetchTransactions(currentPage)
      } catch (err) {
        const message = err instanceof Error ? err.message : 'Unknown error'
        setError(message)
        toast.error(message)
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
          headers: { Authorization: `Bearer ${session.access_token}` },
        })
        if (!response.ok) {
          const body = await response.json().catch(() => ({}))
          throw new Error(body.detail ?? 'Failed to delete transaction')
        }
        setShowDeleteConfirm(false)
        toast.success('Transaction deleted successfully')
        setTransactions((prev) => prev.filter((t) => t.txn_id !== transaction.txn_id))
        setTotalCount((prev) => Math.max(0, prev - 1))
      } catch (err) {
        const message = err instanceof Error ? err.message : 'Unknown error'
        setError(message)
        toast.error(message)
        setDeleting(false)
      }
    }
    
    if (editing) {
  return (
        <div className="spendsense__transactionCard spendsense__transactionCard--editing">
          <div className="spendsense__transactionCardDate">
            {new Date(transaction.txn_date).toLocaleDateString('en-IN', { day: '2-digit', month: 'short' })}
          </div>
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
              <option key="auto-channel" value="">Auto (based on detection)</option>
              {CHANNEL_OPTIONS.map((channelOption, index) => (
                <option key={`channel-${channelOption.value || index}-${index}`} value={channelOption.value}>
                  {channelOption.label}
                </option>
              ))}
            </select>
          </div>
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
                  .then((subs: any[]) => {
                    // Map backend response to frontend format
                    const mapped = subs.map((item: any) => ({
                      code: item.subcategory_code || item.code,
                      name: item.subcategory_name || item.name,
                    }))
                    setSubcategories(mapped)
                  })
              } else {
                setSubcategories([])
              }
            }}
          >
            <option key="no-category" value="">—</option>
            {categories.map((cat, index) => (
              <option key={`cat-${cat.code || index}-${index}`} value={cat.code}>
                {cat.name}
              </option>
            ))}
          </select>
          <select
            className="input-field"
            value={selectedSubcategory}
            onChange={(e) => setSelectedSubcategory(e.target.value)}
            disabled={!selectedCategory}
          >
            <option key="no-subcategory" value="">—</option>
            {subcategories.map((sub, index) => (
              <option key={`sub-${sub.code || index}-${index}`} value={sub.code}>
                {sub.name}
              </option>
            ))}
          </select>
          <div className="spendsense__transactionCardAmount">
            {currencyFormatter.format(Math.abs(transaction.amount))}
          </div>
          {error && <span className="error-message" style={{ fontSize: '0.75rem' }}>{error}</span>}
          <div className="spendsense__transactionCardActions">
            <button className="ghost-button" onClick={handleSave} disabled={saving}>
              {saving ? 'Saving…' : 'Save'}
            </button>
            <button className="ghost-button" onClick={() => setEditing(false)} disabled={saving}>
              Cancel
            </button>
          </div>
        </div>
      )
    }
    
    return (
      <div className="spendsense__transactionCard">
        <div className="spendsense__transactionCardHeader">
          <div>
            <div className="spendsense__transactionCardDate">
              {new Date(transaction.txn_date).toLocaleDateString('en-IN', { day: '2-digit', month: 'short' })}
            </div>
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
          <div className={`spendsense__transactionCardAmount ${transaction.direction === 'debit' ? 'amount-debit' : 'amount-credit'}`}>
            {currencyFormatter.format(Math.abs(transaction.amount))}
          </div>
        </div>
        <div className="spendsense__transactionCardMeta">
          <div>
            <span className="spendsense__transactionCardLabel">Category:</span>
            <span>{formatLabel(transaction.category)}</span>
          </div>
          <div>
            <span className="spendsense__transactionCardLabel">Subcategory:</span>
            <span>{formatLabel(transaction.subcategory)}</span>
          </div>
        </div>
        {showDeleteConfirm ? (
          <div className="spendsense__deleteConfirm">
            <p>Are you sure you want to delete this transaction?</p>
            <div className="spendsense__rowActions">
              <button 
                className="ghost-button" 
                onClick={handleDelete}
                disabled={deleting}
              >
                {deleting ? 'Deleting…' : 'Yes, Delete'}
              </button>
              <button className="ghost-button" onClick={() => setShowDeleteConfirm(false)} disabled={deleting}>
                Cancel
              </button>
            </div>
          </div>
        ) : (
          <div className="spendsense__transactionCardActions">
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
        )}
      </div>
    )
  }

  const EmptyState = ({ type }: { type: 'transactions' | 'kpis' }) => (
    <div className="spendsense__emptyState">
      <div className="spendsense__emptyStateIcon">
        {type === 'transactions' ? '📊' : '💡'}
      </div>
      <h3 className="spendsense__emptyStateTitle">
        {type === 'transactions' ? 'No transactions found' : 'No data available'}
      </h3>
      <p className="spendsense__emptyStateMessage">
        {type === 'transactions' 
          ? hasActiveFilters
            ? 'Try adjusting your filters to see more results'
            : 'Upload a statement or enable Gmail integration to get started'
          : 'Upload transaction data to see your financial insights'}
      </p>
      {type === 'transactions' && !hasActiveFilters && (
        <button className="ghost-button" onClick={handleUploadClick} style={{ marginTop: '1rem' }}>
          Upload statement
        </button>
      )}
    </div>
  )

  return (
    <>
      <ToastContainer toasts={toast.toasts} onRemove={toast.removeToast} />
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
            aria-label="Refresh data"
          >
            {isRefreshing ? 'Refreshing...' : '🔄'}
          </button>
          <div 
            ref={uploadAreaRef}
            className={`spendsense__uploadArea ${isDragOver ? 'is-drag-over' : ''} ${uploading ? 'is-uploading' : ''}`}
            onDragOver={handleDragOver}
            onDragLeave={handleDragLeave}
            onDrop={handleDrop}
          >
          <input
            ref={fileInputRef}
            type="file"
            accept=".csv,.xls,.xlsx,.pdf"
            hidden
            onChange={handleFileChange}
              aria-label="Upload file"
          />
          <input
            type="password"
            ref={passwordInputRef}
            className="input-field spendsense__pdfInput"
            placeholder="PDF password (optional)"
            value={pdfPassword}
            onChange={(event) => setPdfPassword(event.target.value)}
              aria-label="PDF password"
          />
            <button 
              className="ghost-button" 
              onClick={handleUploadClick} 
              disabled={uploading}
              aria-label="Upload statement"
            >
              {uploading ? `Uploading… ${Math.round(uploadProgress)}%` : 'Upload statement'}
          </button>
            {uploading && (
              <div className="spendsense__uploadProgress">
                <div 
                  className="spendsense__uploadProgressBar" 
                  style={{ width: `${uploadProgress}%` }}
                />
              </div>
            )}
            {isDragOver && (
              <div className="spendsense__dragOverlay">
                <div className="spendsense__dragOverlayIcon">📁</div>
                <div className="spendsense__dragOverlayText">Drop file here</div>
              </div>
            )}
          </div>
        </div>
      </header>

      <div className="spendsense__tabs">
        <button
          className={`spendsense__tab ${activeTab === 'kpis' ? 'is-active' : ''}`}
          onClick={() => setActiveTab('kpis')}
          type="button"
        >
          KPIs
        </button>
        <button
          className={`spendsense__tab ${activeTab === 'insights' ? 'is-active' : ''}`}
          onClick={() => setActiveTab('insights')}
          type="button"
        >
          Insights
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
          {/* Month Filter for KPIs */}
          <div style={{ marginBottom: '1.5rem', display: 'flex', alignItems: 'center', gap: '1rem', flexWrap: 'wrap' }}>
            <label htmlFor="kpi-month-filter" style={{ fontSize: '0.875rem', color: 'var(--text-secondary)', fontWeight: 500 }}>
              Filter by Month:
            </label>
            <select
              id="kpi-month-filter"
              value={kpiMonth || ''}
              onChange={(e) => {
                setKpiMonth(e.target.value || null)
              }}
              style={{
                padding: '0.5rem 1rem',
                borderRadius: '0.5rem',
                border: '1px solid var(--border-color)',
                backgroundColor: 'var(--bg-secondary)',
                color: 'var(--text-primary)',
                fontSize: '0.875rem',
                cursor: 'pointer',
                minWidth: '150px',
              }}
            >
              <option key="latest-available" value="">Latest Available</option>
              {availableMonths.map((month, index) => {
                const [year, monthNum] = month.split('-')
                const date = new Date(parseInt(year), parseInt(monthNum) - 1, 1)
                const label = date.toLocaleDateString('en-IN', { month: 'long', year: 'numeric' })
                return (
                  <option key={`month-${month || index}-${index}`} value={month}>
                    {label}
                  </option>
                )
              })}
            </select>
            {kpiMonth && (
              <button
                onClick={() => setKpiMonth(null)}
                style={{
                  padding: '0.5rem 1rem',
                  borderRadius: '0.5rem',
                  border: '1px solid var(--border-color)',
                  backgroundColor: 'transparent',
                  color: 'var(--text-primary)',
                  fontSize: '0.875rem',
                  cursor: 'pointer',
                }}
              >
                Clear Filter
              </button>
            )}
          </div>
          <div className="spendsense__pipeline">
            {kpiLoading ? (
              <>
                <SkeletonCard />
                <SkeletonCard />
                <SkeletonCard />
              </>
            ) : kpiError ? (
              <div className="spendsense__errorState">
              <p className="error-message">{kpiError}</p>
                <button className="ghost-button" onClick={fetchKpis} style={{ marginTop: '0.5rem' }}>
                  Retry
                </button>
              </div>
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
          {spendingTrends.length > 0 && (
            <div className="spendsense__trendsChart">
              <p className="eyebrow">Spending Trends</p>
              <div className="spendsense__chartContainer">
                <SimpleLineChart
                  data={spendingTrends}
                  width={600}
                  height={200}
                  color="var(--color-gold)"
                  showGrid={true}
                  showPoints={true}
                />
              </div>
            </div>
          )}
          {insightMessages.length > 0 && (
            <div className="spendsense__insights">
              <p className="eyebrow">AI Insights</p>
              <ul className="spendsense__insightsList">
                {insightMessages.map((insight, idx) => (
                  <li key={`insight-${insight.type}-${insight.severity}-${idx}`} className={`spendsense__insightItem spendsense__insightItem--${insight.severity}`}>
                    <span className="spendsense__insightIcon">
                      {insight.severity === 'warning' ? '⚠️' : insight.severity === 'success' ? '✅' : '💡'}
                    </span>
                    <span>{insight.message}</span>
                  </li>
                ))}
              </ul>
            </div>
          )}
        </>
      )}

      {activeTab === 'insights' && (
        <div className="spendsense__insights">
          <header className="spendsense__insightsHeader">
            <div>
              <p className="eyebrow">Analytics & Insights</p>
              <h3>Spending patterns and trends</h3>
            </div>
            <button 
              className="ghost-button" 
              onClick={fetchInsights}
              disabled={insightsLoading}
              title="Refresh insights"
            >
              {insightsLoading ? 'Loading...' : '🔄 Refresh'}
            </button>
          </header>

          {insightsLoading && !insights && (
            <div className="spendsense__loading">
              <div className="spendsense__skeleton" style={{ height: '400px', marginBottom: '2rem' }} />
              <div className="spendsense__skeleton" style={{ height: '300px', marginBottom: '2rem' }} />
              <div className="spendsense__skeleton" style={{ height: '200px' }} />
            </div>
          )}

          {insightsError && (
            <div className="spendsense__error">
              <p>⚠️ {insightsError}</p>
              <button className="ghost-button" onClick={fetchInsights}>Try again</button>
            </div>
          )}

          {insights && !insightsLoading && (
            <div className="spendsense__insightsContent">
              {/* Time Series Chart */}
              {insights.time_series && insights.time_series.length > 0 && (
                <section className="spendsense__insightSection">
                  <h4>Monthly Spending Trend</h4>
                  <div className="spendsense__chartContainer">
                    <SimpleLineChart
                      data={insights.time_series.map((point: any) => ({
                        date: point.date,
                        value: point.value || 0,
                        label: point.label || point.date,
                      }))}
                      width={800}
                      height={300}
                      color="#FF6B6B"
                    />
                  </div>
                </section>
              )}

              {/* Category Breakdown */}
              {insights.category_breakdown && insights.category_breakdown.length > 0 && (
                <section className="spendsense__insightSection">
                  <h4>Category Breakdown</h4>
                  <div className="spendsense__categoryBreakdown">
                    {insights.category_breakdown.slice(0, 10).map((cat: any) => (
                      <div key={cat.category_code} className="spendsense__categoryItem">
                        <div className="spendsense__categoryHeader">
                          <span className="spendsense__categoryName">{cat.category_name}</span>
                          <span className="spendsense__categoryAmount">
                            {currencyFormatter.format(cat.amount)}
                          </span>
                        </div>
                        <div className="spendsense__categoryBar">
                          <div 
                            className="spendsense__categoryBarFill"
                            style={{ width: `${cat.percentage}%` }}
                          />
                        </div>
                        <div className="spendsense__categoryMeta">
                          <span>{cat.percentage.toFixed(1)}%</span>
                          <span>{cat.transaction_count} transactions</span>
                          <span>Avg: {currencyFormatter.format(cat.avg_transaction)}</span>
                        </div>
                      </div>
                    ))}
                  </div>
                </section>
              )}

              {/* Spending Trends */}
              {insights.spending_trends && insights.spending_trends.length > 0 && (
                <section className="spendsense__insightSection">
                  <h4>Income vs Expenses</h4>
                  <div className="spendsense__trendsGrid">
                    {insights.spending_trends.slice(-6).map((trend: any) => (
                      <div key={trend.period} className="spendsense__trendCard">
                        <h5>{trend.period}</h5>
                        <div className="spendsense__trendMetrics">
                          <div>
                            <span className="spendsense__trendLabel">Income</span>
                            <span className="spendsense__trendValue positive">
                              {currencyFormatter.format(trend.income)}
                            </span>
                          </div>
                          <div>
                            <span className="spendsense__trendLabel">Expenses</span>
                            <span className="spendsense__trendValue negative">
                              {currencyFormatter.format(trend.expenses)}
                            </span>
                          </div>
                          <div>
                            <span className="spendsense__trendLabel">Net</span>
                            <span className={`spendsense__trendValue ${trend.net >= 0 ? 'positive' : 'negative'}`}>
                              {currencyFormatter.format(trend.net)}
                            </span>
                          </div>
                        </div>
                        <div className="spendsense__trendBreakdown">
                          <span>Needs: {currencyFormatter.format(trend.needs)}</span>
                          <span>Wants: {currencyFormatter.format(trend.wants)}</span>
                          <span>Assets: {currencyFormatter.format(trend.assets)}</span>
                        </div>
                      </div>
                    ))}
                  </div>
                </section>
              )}

              {/* Recurring Transactions */}
              {insights.recurring_transactions && insights.recurring_transactions.length > 0 && (
                <section className="spendsense__insightSection">
                  <h4>Recurring Transactions</h4>
                  <div className="spendsense__recurringList">
                    {insights.recurring_transactions.map((recurring: any, idx: number) => (
                      <div key={`recurring-${recurring.merchant_name}-${recurring.category_name}-${idx}`} className="spendsense__recurringItem">
                        <div className="spendsense__recurringHeader">
                          <div>
                            <h5>{recurring.merchant_name}</h5>
                            <span className="spendsense__recurringCategory">
                              {recurring.category_name}
                              {recurring.subcategory_name && ` • ${recurring.subcategory_name}`}
                            </span>
                          </div>
                          <span className={`spendsense__recurringBadge frequency-${recurring.frequency}`}>
                            {recurring.frequency}
                          </span>
                        </div>
                        <div className="spendsense__recurringMetrics">
                          <div>
                            <span className="spendsense__recurringLabel">Avg Amount</span>
                            <span className="spendsense__recurringValue">
                              {currencyFormatter.format(recurring.avg_amount)}
                            </span>
                          </div>
                          <div>
                            <span className="spendsense__recurringLabel">Total</span>
                            <span className="spendsense__recurringValue">
                              {currencyFormatter.format(recurring.total_amount)}
                            </span>
                          </div>
                          <div>
                            <span className="spendsense__recurringLabel">Occurrences</span>
                            <span className="spendsense__recurringValue">{recurring.transaction_count}</span>
                          </div>
                          <div>
                            <span className="spendsense__recurringLabel">Last</span>
                            <span className="spendsense__recurringValue">
                              {new Date(recurring.last_occurrence).toLocaleDateString()}
                            </span>
                          </div>
                          {recurring.next_expected && (
                            <div>
                              <span className="spendsense__recurringLabel">Next Expected</span>
                              <span className="spendsense__recurringValue">
                                {new Date(recurring.next_expected).toLocaleDateString()}
                              </span>
                            </div>
                          )}
                        </div>
                      </div>
                    ))}
                  </div>
                </section>
              )}

              {/* Spending Patterns */}
              {insights.spending_patterns && insights.spending_patterns.length > 0 && (
                <section className="spendsense__insightSection">
                  <h4>Spending by Day of Week</h4>
                  <div className="spendsense__patternsGrid">
                    {insights.spending_patterns.map((pattern: any) => (
                      <div key={pattern.day_of_week} className="spendsense__patternCard">
                        <h5>{pattern.day_of_week}</h5>
                        <div className="spendsense__patternAmount">
                          {currencyFormatter.format(pattern.amount)}
                        </div>
                        <div className="spendsense__patternCount">
                          {pattern.transaction_count} transactions
                        </div>
                      </div>
                    ))}
                  </div>
                </section>
              )}

              {/* Top Merchants */}
              {insights.top_merchants && insights.top_merchants.length > 0 && (
                <section className="spendsense__insightSection">
                  <h4>Top Merchants</h4>
                  <div className="spendsense__merchantsList">
                    {insights.top_merchants.map((merchant: any, idx: number) => (
                      <div key={`merchant-${merchant.merchant_name || 'unknown'}-${idx}`} className="spendsense__merchantItem">
                        <div className="spendsense__merchantRank">#{idx + 1}</div>
                        <div className="spendsense__merchantInfo">
                          <h5>{merchant.merchant_name}</h5>
                          <div className="spendsense__merchantMeta">
                            <span>{merchant.transaction_count} transactions</span>
                            {merchant.last_transaction && (
                              <span>Last: {new Date(merchant.last_transaction).toLocaleDateString()}</span>
                            )}
                          </div>
                        </div>
                        <div className="spendsense__merchantAmount">
                          <div className="spendsense__merchantTotal">
                            {currencyFormatter.format(merchant.total_spend)}
                          </div>
                          <div className="spendsense__merchantAvg">
                            Avg: {currencyFormatter.format(merchant.avg_spend)}
                          </div>
                        </div>
                      </div>
                    ))}
                  </div>
                </section>
              )}

              {(!insights.time_series || insights.time_series.length === 0) &&
               (!insights.category_breakdown || insights.category_breakdown.length === 0) && (
                <div className="spendsense__emptyState">
                  <p>📊 No insights available yet</p>
                  <p>Upload more transactions to see spending patterns and trends.</p>
                </div>
              )}
            </div>
          )}
        </div>
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
          <div style={{ display: 'flex', gap: '0.5rem', alignItems: 'center', flexWrap: 'wrap' }}>
            <button 
              className="ghost-button" 
              onClick={handleRefresh}
              disabled={isRefreshing || loading}
              title="Refresh transactions"
              aria-label="Refresh transactions"
            >
              {isRefreshing ? 'Refreshing...' : '🔄 Refresh'}
            </button>
            <button 
              className="ghost-button" 
              onClick={() => setFilterPanelOpen((prev) => !prev)}
              aria-label="Toggle filters"
            >
              {filterPanelOpen ? 'Hide Filters' : `Filter${hasActiveFilters ? ` (${activeFilterCount})` : ''}`}
            </button>
          </div>
        </header>
        {filterPanelOpen && (
          <div className="spendsense__filters">
            {hasActiveFilters && (
              <div className="spendsense__activeFilters">
                {Object.entries(filters).map(([key, value]) => {
                  if (!value || (key === 'search' && !value.trim())) return null
                  const displayKey = key === 'dateFrom' ? 'From' : key === 'dateTo' ? 'To' : key === 'amountMin' ? 'Min Amount' : key === 'amountMax' ? 'Max Amount' : key
                  return (
                    <span key={key} className="spendsense__filterBadge">
                      {displayKey}: {key.startsWith('date') || key.startsWith('amount') ? value : getFilterLabel(key, value)}
                      <button
                        className="spendsense__filterBadgeRemove"
                        onClick={() => {
                          if (key === 'subcategory') {
                            handleFilterChange({ [key]: '', category: filters.category })
                          } else {
                            handleFilterChange({ [key]: '' })
                          }
                        }}
                        aria-label={`Remove ${key} filter`}
                      >
                        ×
                      </button>
                    </span>
                  )
                })}
                <button className="ghost-button" onClick={handleClearFilters} style={{ fontSize: '0.875rem' }}>
                  Clear all
                </button>
              </div>
            )}
            <div className="spendsense__filterGroup" style={{ position: 'relative' }}>
              <label>Search</label>
              <div style={{ position: 'relative' }}>
              <input
                type="text"
                className="input-field"
                placeholder="Merchant or description"
                  value={searchDebounce}
                  onChange={(event) => {
                    setSearchDebounce(event.target.value)
                    setShowSuggestions(true)
                  }}
                  onFocus={() => setShowSuggestions(true)}
                  onBlur={() => setTimeout(() => setShowSuggestions(false), 200)}
                  aria-label="Search transactions"
                  aria-autocomplete="list"
                  aria-expanded={showSuggestions && searchSuggestions.length > 0}
                />
                {showSuggestions && searchSuggestions.length > 0 && (
                  <div className="spendsense__searchSuggestions">
                    {searchSuggestions.map((suggestion, idx) => (
                      <button
                        key={`suggestion-${suggestion}-${idx}`}
                        className="spendsense__suggestionItem"
                        onClick={() => {
                          setSearchDebounce(suggestion)
                          setShowSuggestions(false)
                        }}
                        type="button"
                      >
                        <span className="spendsense__suggestionIcon">🔍</span>
                        <span>{suggestion}</span>
                        {searchHistory.includes(suggestion) && (
                          <span className="spendsense__suggestionBadge">History</span>
                        )}
                      </button>
                    ))}
                  </div>
                )}
              </div>
            </div>
            <div className="spendsense__filterGroup">
              <label>Date From</label>
              <input
                type="date"
                className="input-field"
                value={filters.dateFrom}
                onChange={(event) => handleFilterChange({ dateFrom: event.target.value })}
                aria-label="Filter from date"
              />
            </div>
            <div className="spendsense__filterGroup">
              <label>Date To</label>
              <input
                type="date"
                className="input-field"
                value={filters.dateTo}
                onChange={(event) => handleFilterChange({ dateTo: event.target.value })}
                aria-label="Filter to date"
              />
            </div>
            <div className="spendsense__filterGroup">
              <label>Min Amount (₹)</label>
              <input
                type="number"
                className="input-field"
                placeholder="0"
                value={filters.amountMin}
                onChange={(event) => handleFilterChange({ amountMin: event.target.value })}
                aria-label="Minimum amount filter"
                min="0"
                step="0.01"
              />
            </div>
            <div className="spendsense__filterGroup">
              <label>Max Amount (₹)</label>
              <input
                type="number"
                className="input-field"
                placeholder="No limit"
                value={filters.amountMax}
                onChange={(event) => handleFilterChange({ amountMax: event.target.value })}
                aria-label="Maximum amount filter"
                min="0"
                step="0.01"
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
                <option key="all-categories" value="">All categories</option>
                {filterCategories.map((cat, index) => (
                  <option key={`category-${cat.code || index}-${index}`} value={cat.code}>
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
                <option key="all-subcategories" value="">All subcategories</option>
                {filterSubcategories.map((sub, index) => (
                  <option key={`subcategory-${sub.code || index}-${index}`} value={sub.code}>
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
                <option key="all-channels" value="">All channels</option>
                {CHANNEL_OPTIONS.map((option, index) => (
                  <option key={`channel-${option.value || index}-${index}`} value={option.value}>
                    {option.label}
                  </option>
                ))}
              </select>
            </div>
            <div className="spendsense__filterActions">
              <button className="ghost-button" onClick={handleClearFilters}>
                Clear filters
              </button>
              <button 
                className="ghost-button" 
                onClick={handleExportCSV}
                style={{ borderColor: 'var(--color-gold)', color: 'var(--color-gold)' }}
                title="Export filtered transactions to CSV"
              >
                📥 Export CSV
              </button>
            </div>
          </div>
        )}
        {uploadError ? <p className="error-message">{uploadError}</p> : null}
        {selectedTransactions.size > 0 && (
          <div className="spendsense__bulkActions">
            <div className="spendsense__bulkActionsInfo">
              <strong>{selectedTransactions.size}</strong> transaction{selectedTransactions.size > 1 ? 's' : ''} selected
            </div>
            <div className="spendsense__bulkActionsButtons">
              <select
                className="input-field"
                onChange={(e) => {
                  const [cat, sub] = e.target.value.split('|')
                  if (cat || sub) {
                    handleBulkCategorize(cat || '', sub || '')
                    e.target.value = ''
                  }
                }}
                defaultValue=""
                style={{ fontSize: '0.875rem', padding: '0.5rem' }}
              >
                <option key="bulk-categorize-placeholder" value="">Bulk categorize...</option>
                {filterCategories.map((cat, catIndex) => (
                  <optgroup key={`optgroup-${cat.code || catIndex}-${catIndex}`} label={cat.name}>
                    <option key={`${cat.code || catIndex}|none`} value={`${cat.code}|`}>{cat.name} (no subcategory)</option>
                    {filterSubcategories
                      .filter(sub => sub.code.startsWith(cat.code))
                      .map((sub, subIndex) => (
                        <option key={`${cat.code || catIndex}|${sub.code || subIndex}-${subIndex}`} value={`${cat.code}|${sub.code}`}>
                          {cat.name} → {sub.name}
                        </option>
                      ))}
                  </optgroup>
                ))}
              </select>
              <button
                className="ghost-button"
                onClick={handleBulkDelete}
                style={{ color: '#f87171' }}
              >
                Delete Selected
              </button>
              <button
                className="ghost-button"
                onClick={() => setSelectedTransactions(new Set())}
              >
                Clear Selection
              </button>
            </div>
          </div>
        )}
        {loading ? (
          <div className="spendsense__tableContainer">
            {isMobile ? (
              <div className="spendsense__transactionCards">
                {Array.from({ length: 5 }).map((_, i) => (
                  <div key={i} className="spendsense__transactionCard spendsense__skeleton">
                    <div className="spendsense__skeleton-line" style={{ width: '60%', marginBottom: '0.5rem' }} />
                    <div className="spendsense__skeleton-line" style={{ width: '40%' }} />
                  </div>
                ))}
              </div>
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
                  {Array.from({ length: 5 }).map((_, i) => (
                    <SkeletonTableRow key={i} />
                  ))}
                </tbody>
              </table>
            )}
          </div>
        ) : error ? (
          <div className="spendsense__errorState">
          <p className="error-message">{error}</p>
            <button className="ghost-button" onClick={() => fetchTransactions(currentPage)} style={{ marginTop: '0.5rem' }}>
              Retry
            </button>
          </div>
        ) : transactions.length === 0 ? (
          <EmptyState type="transactions" />
        ) : (
          <div className="spendsense__tableContainer">
            {isMobile ? (
              <div className="spendsense__transactionCards">
                {transactions.map((txn) => (
                  <TransactionCard key={txn.txn_id} transaction={txn} />
                ))}
              </div>
        ) : (
          <table className="spendsense__table">
            <thead>
              <tr>
                <th>
                  <input
                    type="checkbox"
                    checked={selectedTransactions.size === transactions.length && transactions.length > 0}
                    onChange={handleSelectAll}
                    aria-label="Select all transactions"
                  />
                </th>
                <th>Date</th>
                <th>Merchant</th>
                <th>Category</th>
                <th>Subcategory</th>
                <th className="spendsense__amountCol">Amount</th>
                <th className="spendsense__actionsCol">Actions</th>
              </tr>
            </thead>
            <tbody>
                  {transactions.map((txn) => (
                <TransactionRow
                  key={txn.txn_id}
                  transaction={txn}
                  session={session}
                      selected={selectedTransactions.has(txn.txn_id)}
                      onSelect={(selected) => handleSelectTransaction(txn.txn_id, selected)}
                      isRecurring={recurringTransactions.has(txn.txn_id)}
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
          </div>
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
    </>
  )
}

