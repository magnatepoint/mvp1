'use client'

import { useState, useEffect } from 'react'
import type { Session } from '@supabase/supabase-js'
import { fetchCategories, fetchSubcategories } from '@/lib/api/spendsense'
import type { Category, Subcategory } from '@/types/spendsense'
import { glassFilter, glassCardPrimary } from '@/lib/theme/glass'

interface Filters {
  category_code: string | null
  subcategory_code: string | null
  channel: string | null
  direction: 'debit' | 'credit' | null
  start_date: string | null
  end_date: string | null
}

interface TransactionFiltersProps {
  session: Session
  filters: Filters
  onFiltersChange: (filters: Filters) => void
}

export default function TransactionFilters({
  session,
  filters,
  onFiltersChange,
}: TransactionFiltersProps) {
  const [categories, setCategories] = useState<Category[]>([])
  const [subcategories, setSubcategories] = useState<Subcategory[]>([])
  const [showCategoryModal, setShowCategoryModal] = useState(false)
  const [showSubcategoryModal, setShowSubcategoryModal] = useState(false)
  const [showChannelModal, setShowChannelModal] = useState(false)
  const [showDirectionModal, setShowDirectionModal] = useState(false)
  const [showDateModal, setShowDateModal] = useState(false)

  useEffect(() => {
    loadCategories()
  }, [])

  useEffect(() => {
    if (filters.category_code) {
      loadSubcategories(filters.category_code)
    } else {
      setSubcategories([])
      if (filters.subcategory_code) {
        onFiltersChange({ ...filters, subcategory_code: null })
      }
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [filters.category_code])

  const loadCategories = async () => {
    try {
      const cats = await fetchCategories(session)
      setCategories(cats)
    } catch (err) {
      console.error('Failed to load categories:', err)
    }
  }

  const loadSubcategories = async (categoryCode: string) => {
    try {
      const subs = await fetchSubcategories(session, categoryCode)
      setSubcategories(subs)
    } catch (err) {
      console.error('Failed to load subcategories:', err)
    }
  }

  const updateFilter = (key: keyof Filters, value: any) => {
    onFiltersChange({ ...filters, [key]: value })
  }

  const clearFilter = (key: keyof Filters) => {
    if (key === 'category_code') {
      onFiltersChange({
        ...filters,
        category_code: null,
        subcategory_code: null,
      })
    } else {
      onFiltersChange({ ...filters, [key]: null })
    }
  }

  const clearAllFilters = () => {
    onFiltersChange({
      category_code: null,
      subcategory_code: null,
      channel: null,
      direction: null,
      start_date: null,
      end_date: null,
    })
  }

  const hasActiveFilters =
    filters.category_code ||
    filters.subcategory_code ||
    filters.channel ||
    filters.direction ||
    filters.start_date ||
    filters.end_date

  const selectedCategory = categories.find((c) => c.category_code === filters.category_code)
  const selectedSubcategory = subcategories.find((s) => s.subcategory_code === filters.subcategory_code)

  const getDateRangeLabel = () => {
    if (!filters.start_date && !filters.end_date) return 'Date'
    if (filters.start_date && filters.end_date) {
      const start = new Date(filters.start_date)
      const end = new Date(filters.end_date)
      const today = new Date()
      today.setHours(0, 0, 0, 0)
      const startDate = new Date(start)
      startDate.setHours(0, 0, 0, 0)
      const endDate = new Date(end)
      endDate.setHours(0, 0, 0, 0)

      // Check if it's "Today"
      if (startDate.getTime() === today.getTime() && endDate.getTime() === today.getTime()) {
        return 'Today'
      }

      // Check if it's "This Month"
      const firstDayOfMonth = new Date(today.getFullYear(), today.getMonth(), 1)
      if (startDate.getTime() === firstDayOfMonth.getTime() && endDate.getTime() === today.getTime()) {
        return 'This Month'
      }

      // Check if it's "Last Month"
      const firstDayLastMonth = new Date(today.getFullYear(), today.getMonth() - 1, 1)
      const lastDayLastMonth = new Date(today.getFullYear(), today.getMonth(), 0)
      if (
        startDate.getTime() === firstDayLastMonth.getTime() &&
        endDate.getTime() === lastDayLastMonth.getTime()
      ) {
        return 'Last Month'
      }

      // Custom range
      return `${start.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })} - ${end.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })}`
    }
    return 'Date'
  }

  const channels = ['Cash', 'UPI', 'NEFT', 'IMPS', 'Card', 'ATM', 'ACH', 'NACH', 'Other']

  return (
    <>
      {/* Filter Chips - Horizontal Scroll */}
      <div className="overflow-x-auto scrollbar-hide -mx-4 px-4">
        <div className="flex items-center gap-2 min-w-max pb-2">
          {/* Category Filter */}
          <FilterChip
            label={selectedCategory ? selectedCategory.category_name : 'Category'}
            isActive={!!filters.category_code}
            onClick={() => setShowCategoryModal(true)}
            onClear={() => clearFilter('category_code')}
          />

          {/* Subcategory Filter (only show if category selected) */}
          {filters.category_code && (
            <FilterChip
              label={selectedSubcategory ? selectedSubcategory.subcategory_name : 'Subcategory'}
              isActive={!!filters.subcategory_code}
              onClick={() => setShowSubcategoryModal(true)}
              onClear={() => clearFilter('subcategory_code')}
            />
          )}

          {/* Channel Filter */}
          <FilterChip
            label={filters.channel ? filters.channel.toUpperCase() : 'Channel'}
            isActive={!!filters.channel}
            onClick={() => setShowChannelModal(true)}
            onClear={() => clearFilter('channel')}
          />

          {/* Direction Filter */}
          <FilterChip
            label={
              filters.direction === 'debit'
                ? 'Debit'
                : filters.direction === 'credit'
                  ? 'Credit'
                  : 'Direction'
            }
            isActive={!!filters.direction}
            onClick={() => setShowDirectionModal(true)}
            onClear={() => clearFilter('direction')}
          />

          {/* Date Range Filter */}
          <FilterChip
            label={getDateRangeLabel()}
            isActive={!!(filters.start_date || filters.end_date)}
            onClick={() => setShowDateModal(true)}
            onClear={() => {
              updateFilter('start_date', null)
              updateFilter('end_date', null)
            }}
          />

          {/* Clear All Button */}
          {hasActiveFilters && (
            <button
              onClick={clearAllFilters}
              className="flex-shrink-0 px-3 py-2 rounded-lg bg-white/5 border border-white/10 hover:bg-white/10 transition-colors text-sm font-medium text-gray-400 hover:text-white"
            >
              Clear All
            </button>
          )}
        </div>
      </div>

      {/* Category Modal */}
      {showCategoryModal && (
        <FilterModal
          title="Select Category"
          onClose={() => setShowCategoryModal(false)}
          onSelect={(value) => {
            updateFilter('category_code', value)
            setShowCategoryModal(false)
          }}
          selectedValue={filters.category_code}
        >
          <div className="space-y-2 max-h-96 overflow-y-auto">
            <button
              onClick={() => {
                updateFilter('category_code', null)
                setShowCategoryModal(false)
              }}
              className={`w-full text-left px-4 py-3 rounded-lg transition-colors ${
                !filters.category_code
                  ? 'bg-[#D4AF37]/20 border border-[#D4AF37]/30'
                  : 'bg-white/5 border border-white/10 hover:bg-white/10'
              }`}
            >
              All Categories
            </button>
            {categories.map((cat) => (
              <button
                key={cat.category_code}
                onClick={() => {
                  updateFilter('category_code', cat.category_code)
                  setShowCategoryModal(false)
                }}
                className={`w-full text-left px-4 py-3 rounded-lg transition-colors ${
                  filters.category_code === cat.category_code
                    ? 'bg-[#D4AF37]/20 border border-[#D4AF37]/30'
                    : 'bg-white/5 border border-white/10 hover:bg-white/10'
                }`}
              >
                {cat.category_name}
              </button>
            ))}
          </div>
        </FilterModal>
      )}

      {/* Subcategory Modal */}
      {showSubcategoryModal && filters.category_code && (
        <FilterModal
          title="Select Subcategory"
          onClose={() => setShowSubcategoryModal(false)}
          onSelect={(value) => {
            updateFilter('subcategory_code', value)
            setShowSubcategoryModal(false)
          }}
          selectedValue={filters.subcategory_code}
        >
          <div className="space-y-2 max-h-96 overflow-y-auto">
            <button
              onClick={() => {
                updateFilter('subcategory_code', null)
                setShowSubcategoryModal(false)
              }}
              className={`w-full text-left px-4 py-3 rounded-lg transition-colors ${
                !filters.subcategory_code
                  ? 'bg-[#D4AF37]/20 border border-[#D4AF37]/30'
                  : 'bg-white/5 border border-white/10 hover:bg-white/10'
              }`}
            >
              All Subcategories
            </button>
            {subcategories.map((sub) => (
              <button
                key={sub.subcategory_code}
                onClick={() => {
                  updateFilter('subcategory_code', sub.subcategory_code)
                  setShowSubcategoryModal(false)
                }}
                className={`w-full text-left px-4 py-3 rounded-lg transition-colors ${
                  filters.subcategory_code === sub.subcategory_code
                    ? 'bg-[#D4AF37]/20 border border-[#D4AF37]/30'
                    : 'bg-white/5 border border-white/10 hover:bg-white/10'
                }`}
              >
                {sub.subcategory_name}
              </button>
            ))}
          </div>
        </FilterModal>
      )}

      {/* Channel Modal */}
      {showChannelModal && (
        <FilterModal
          title="Select Channel"
          onClose={() => setShowChannelModal(false)}
          onSelect={(value) => {
            updateFilter('channel', value)
            setShowChannelModal(false)
          }}
          selectedValue={filters.channel}
        >
          <div className="space-y-2 max-h-96 overflow-y-auto">
            <button
              onClick={() => {
                updateFilter('channel', null)
                setShowChannelModal(false)
              }}
              className={`w-full text-left px-4 py-3 rounded-lg transition-colors ${
                !filters.channel
                  ? 'bg-[#D4AF37]/20 border border-[#D4AF37]/30'
                  : 'bg-white/5 border border-white/10 hover:bg-white/10'
              }`}
            >
              All Channels
            </button>
            {channels.map((channel) => (
              <button
                key={channel}
                onClick={() => {
                  updateFilter('channel', channel.toLowerCase())
                  setShowChannelModal(false)
                }}
                className={`w-full text-left px-4 py-3 rounded-lg transition-colors ${
                  filters.channel === channel.toLowerCase()
                    ? 'bg-[#D4AF37]/20 border border-[#D4AF37]/30'
                    : 'bg-white/5 border border-white/10 hover:bg-white/10'
                }`}
              >
                {channel}
              </button>
            ))}
          </div>
        </FilterModal>
      )}

      {/* Direction Modal */}
      {showDirectionModal && (
        <FilterModal
          title="Select Direction"
          onClose={() => setShowDirectionModal(false)}
          onSelect={(value) => {
            updateFilter('direction', value as 'debit' | 'credit' | null)
            setShowDirectionModal(false)
          }}
          selectedValue={filters.direction || ''}
        >
          <div className="space-y-2">
            <button
              onClick={() => {
                updateFilter('direction', null)
                setShowDirectionModal(false)
              }}
              className={`w-full text-left px-4 py-3 rounded-lg transition-colors ${
                !filters.direction
                  ? 'bg-[#D4AF37]/20 border border-[#D4AF37]/30'
                  : 'bg-white/5 border border-white/10 hover:bg-white/10'
              }`}
            >
              All
            </button>
            <button
              onClick={() => {
                updateFilter('direction', 'debit')
                setShowDirectionModal(false)
              }}
              className={`w-full text-left px-4 py-3 rounded-lg transition-colors ${
                filters.direction === 'debit'
                  ? 'bg-[#D4AF37]/20 border border-[#D4AF37]/30'
                  : 'bg-white/5 border border-white/10 hover:bg-white/10'
              }`}
            >
              Debit (Expenses)
            </button>
            <button
              onClick={() => {
                updateFilter('direction', 'credit')
                setShowDirectionModal(false)
              }}
              className={`w-full text-left px-4 py-3 rounded-lg transition-colors ${
                filters.direction === 'credit'
                  ? 'bg-[#D4AF37]/20 border border-[#D4AF37]/30'
                  : 'bg-white/5 border border-white/10 hover:bg-white/10'
              }`}
            >
              Credit (Income)
            </button>
          </div>
        </FilterModal>
      )}

      {/* Date Range Modal */}
      {showDateModal && (
        <DateRangeModal
          filters={filters}
          onClose={() => setShowDateModal(false)}
          onApply={(startDate, endDate) => {
            updateFilter('start_date', startDate)
            updateFilter('end_date', endDate)
            setShowDateModal(false)
          }}
        />
      )}
    </>
  )
}

function FilterChip({
  label,
  isActive,
  onClick,
  onClear,
}: {
  label: string
  isActive: boolean
  onClick: () => void
  onClear: () => void
}) {
  return (
    <button
      onClick={onClick}
      className={`flex-shrink-0 flex items-center gap-2 px-4 py-2 rounded-lg font-medium transition-colors ${
        isActive
          ? 'bg-[#D4AF37]/20 border border-[#D4AF37]/30 text-[#D4AF37]'
          : 'bg-white/5 border border-white/10 text-gray-400 hover:text-white hover:bg-white/10'
      }`}
    >
      <span>{label}</span>
      {isActive && (
        <span
          onClick={(e) => {
            e.stopPropagation()
            onClear()
          }}
          className="ml-1 hover:bg-white/10 rounded-full p-0.5 cursor-pointer"
          role="button"
          tabIndex={0}
          onKeyDown={(e) => {
            if (e.key === 'Enter' || e.key === ' ') {
              e.preventDefault()
              e.stopPropagation()
              onClear()
            }
          }}
          aria-label="Clear filter"
        >
          <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
          </svg>
        </span>
      )}
    </button>
  )
}

function FilterModal({
  title,
  children,
  onClose,
  onSelect,
  selectedValue,
}: {
  title: string
  children: React.ReactNode
  onClose: () => void
  onSelect: (value: string | null) => void
  selectedValue: string | null
}) {
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm">
      <div className={`relative ${glassCardPrimary} p-6 max-w-sm w-full mx-4 max-h-[80vh] overflow-y-auto`}>
        <button
          onClick={onClose}
          className="absolute top-4 right-4 p-2 rounded-lg hover:bg-white/10 transition-colors"
        >
          <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
        <h3 className="text-xl font-bold mb-4">{title}</h3>
        {children}
      </div>
    </div>
  )
}

function DateRangeModal({
  filters,
  onClose,
  onApply,
}: {
  filters: Filters
  onClose: () => void
  onApply: (startDate: string | null, endDate: string | null) => void
}) {
  const [customStartDate, setCustomStartDate] = useState(filters.start_date || '')
  const [customEndDate, setCustomEndDate] = useState(filters.end_date || '')
  const [showCustom, setShowCustom] = useState(false)

  const today = new Date()
  today.setHours(0, 0, 0, 0)

  const getDateString = (date: Date) => {
    return date.toISOString().split('T')[0]
  }

  const setQuickRange = (type: string) => {
    let startDate: Date | null = null
    let endDate: Date | null = null

    switch (type) {
      case 'today':
        startDate = new Date(today)
        endDate = new Date(today)
        break
      case 'thisWeek':
        const dayOfWeek = today.getDay()
        startDate = new Date(today)
        startDate.setDate(today.getDate() - dayOfWeek)
        endDate = new Date(today)
        break
      case 'thisMonth':
        startDate = new Date(today.getFullYear(), today.getMonth(), 1)
        endDate = new Date(today)
        break
      case 'lastMonth':
        startDate = new Date(today.getFullYear(), today.getMonth() - 1, 1)
        endDate = new Date(today.getFullYear(), today.getMonth(), 0)
        break
      case 'allTime':
        startDate = null
        endDate = null
        break
    }

    if (type === 'custom') {
      setShowCustom(true)
      return
    }

    onApply(startDate ? getDateString(startDate) : null, endDate ? getDateString(endDate) : null)
    onClose()
  }

  const handleCustomApply = () => {
    onApply(customStartDate || null, customEndDate || null)
    onClose()
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm">
      <div className={`relative ${glassCardPrimary} p-6 max-w-sm w-full mx-4 max-h-[80vh] overflow-y-auto`}>
        <button
          onClick={onClose}
          className="absolute top-4 right-4 p-2 rounded-lg hover:bg-white/10 transition-colors"
        >
          <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
        <h3 className="text-xl font-bold mb-4">Select Date Range</h3>

        {!showCustom ? (
          <div className="space-y-2">
            <button
              onClick={() => setQuickRange('today')}
              className="w-full text-left px-4 py-3 rounded-lg bg-white/5 border border-white/10 hover:bg-white/10 transition-colors"
            >
              Today
            </button>
            <button
              onClick={() => setQuickRange('thisWeek')}
              className="w-full text-left px-4 py-3 rounded-lg bg-white/5 border border-white/10 hover:bg-white/10 transition-colors"
            >
              This Week
            </button>
            <button
              onClick={() => setQuickRange('thisMonth')}
              className="w-full text-left px-4 py-3 rounded-lg bg-white/5 border border-white/10 hover:bg-white/10 transition-colors"
            >
              This Month
            </button>
            <button
              onClick={() => setQuickRange('lastMonth')}
              className="w-full text-left px-4 py-3 rounded-lg bg-white/5 border border-white/10 hover:bg-white/10 transition-colors"
            >
              Last Month
            </button>
            <button
              onClick={() => setQuickRange('allTime')}
              className="w-full text-left px-4 py-3 rounded-lg bg-white/5 border border-white/10 hover:bg-white/10 transition-colors"
            >
              All Time
            </button>
            <button
              onClick={() => setQuickRange('custom')}
              className="w-full text-left px-4 py-3 rounded-lg bg-white/5 border border-white/10 hover:bg-white/10 transition-colors"
            >
              Custom Range
            </button>
          </div>
        ) : (
          <div className="space-y-4">
            <div>
              <label className="block text-sm font-medium mb-2">Start Date</label>
              <input
                type="date"
                value={customStartDate}
                onChange={(e) => setCustomStartDate(e.target.value)}
                max={getDateString(today)}
                className={`w-full ${glassFilter} px-4 py-3 rounded-lg text-foreground`}
              />
            </div>
            <div>
              <label className="block text-sm font-medium mb-2">End Date</label>
              <input
                type="date"
                value={customEndDate}
                onChange={(e) => setCustomEndDate(e.target.value)}
                max={getDateString(today)}
                min={customStartDate || undefined}
                className={`w-full ${glassFilter} px-4 py-3 rounded-lg text-foreground`}
              />
            </div>
            <div className="flex gap-3">
              <button
                onClick={() => setShowCustom(false)}
                className="flex-1 px-4 py-3 rounded-lg bg-white/5 border border-white/10 hover:bg-white/10 transition-colors"
              >
                Back
              </button>
              <button
                onClick={handleCustomApply}
                className="flex-1 px-4 py-3 rounded-lg bg-[#D4AF37] text-black font-medium hover:bg-[#D4AF37]/90 transition-colors"
              >
                Apply
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  )
}
