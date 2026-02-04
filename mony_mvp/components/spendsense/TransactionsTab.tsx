'use client'

import { useEffect, useState } from 'react'
import type { Session } from '@supabase/supabase-js'
import { fetchTransactions, deleteTransaction } from '@/lib/api/spendsense'
import type { Transaction, TransactionListResponse } from '@/types/spendsense'
import { glassCardSecondary, glassCardPrimary, glassFilter } from '@/lib/theme/glass'
import FileUploadModal from '../FileUploadModal'
import TransactionDetailModal from './TransactionDetailModal'
import ManualTransactionModal from './ManualTransactionModal'
import TransactionEditModal from './TransactionEditModal'
import TransactionFilters from './TransactionFilters'

interface TransactionsTabProps {
  session: Session
}

export default function TransactionsTab({ session }: TransactionsTabProps) {
  const [transactions, setTransactions] = useState<Transaction[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [page, setPage] = useState(1)
  const [total, setTotal] = useState(0)
  const [searchText, setSearchText] = useState('')
  const [filters, setFilters] = useState({
    category_code: null as string | null,
    subcategory_code: null as string | null,
    channel: null as string | null,
    direction: null as 'debit' | 'credit' | null,
    start_date: null as string | null,
    end_date: null as string | null,
  })
  const [isUploadModalOpen, setIsUploadModalOpen] = useState(false)
  const [isManualTransactionModalOpen, setIsManualTransactionModalOpen] = useState(false)
  const [selectedTransaction, setSelectedTransaction] = useState<Transaction | null>(null)
  const [isTransactionDetailModalOpen, setIsTransactionDetailModalOpen] = useState(false)
  const [isTransactionEditModalOpen, setIsTransactionEditModalOpen] = useState(false)
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false)
  const PAGE_SIZE = 25

  const loadTransactions = async (append = false) => {
    setLoading(true)
    setError(null)
    try {
      const offset = (page - 1) * PAGE_SIZE
      const response = await fetchTransactions(session, {
        limit: PAGE_SIZE,
        offset,
        search: searchText || undefined,
        category_code: filters.category_code || undefined,
        subcategory_code: filters.subcategory_code || undefined,
        channel: filters.channel || undefined,
        direction: filters.direction || undefined,
        start_date: filters.start_date || undefined,
        end_date: filters.end_date || undefined,
      })
      // Append new transactions if loading more, otherwise replace
      if (append && page > 1) {
        setTransactions((prev) => [...prev, ...response.transactions])
      } else {
        setTransactions(response.transactions)
      }
      setTotal(response.total)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load transactions')
      console.error('Error loading transactions:', err)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    setPage(1)
    setTransactions([]) // Clear transactions when filters change
  }, [filters.category_code, filters.subcategory_code, filters.channel, filters.direction, filters.start_date, filters.end_date, searchText])

  useEffect(() => {
    // If page is 1, replace transactions. If page > 1, append (load more)
    const append = page > 1
    loadTransactions(append)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [session.access_token, page, searchText, filters.category_code, filters.subcategory_code, filters.channel, filters.direction, filters.start_date, filters.end_date])

  const handleTransactionClick = (transaction: Transaction) => {
    setSelectedTransaction(transaction)
    setIsTransactionDetailModalOpen(true)
  }

  const handleEdit = () => {
    setIsTransactionDetailModalOpen(false)
    setIsTransactionEditModalOpen(true)
  }

  const handleDelete = async () => {
    if (!selectedTransaction) return
    try {
      await deleteTransaction(session, selectedTransaction.txn_id)
      setShowDeleteConfirm(false)
      setIsTransactionDetailModalOpen(false)
      setSelectedTransaction(null)
      loadTransactions()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to delete transaction')
    }
  }

  const handleDeleteClick = () => {
    setShowDeleteConfirm(true)
  }

  const handleUpdateSuccess = () => {
    setIsTransactionEditModalOpen(false)
    setSelectedTransaction(null)
    loadTransactions()
  }

  const handleCreateSuccess = () => {
    setIsManualTransactionModalOpen(false)
    loadTransactions()
  }

  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('en-IN', {
      style: 'currency',
      currency: 'INR',
      maximumFractionDigits: 0,
    }).format(Math.abs(amount))
  }

  const formatDate = (dateString: string) => {
    const date = new Date(dateString)
    return date.toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric',
      year: 'numeric',
    })
  }

  const groupedTransactions = transactions.reduce((acc, txn) => {
    const date = formatDate(txn.txn_date)
    if (!acc[date]) acc[date] = []
    acc[date].push(txn)
    return acc
  }, {} as Record<string, Transaction[]>)

  if (loading && transactions.length === 0) {
    return (
      <div className="flex items-center justify-center py-20">
        <div className="animate-spin rounded-full h-12 w-12 border-t-2 border-b-2 border-foreground"></div>
      </div>
    )
  }

  if (error && transactions.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center py-20 gap-4">
        <div className="text-red-500 text-center">
          <p className="text-lg font-bold mb-2">Unable to Load Transactions</p>
          <p className="text-sm">{error}</p>
        </div>
        <button
          onClick={() => loadTransactions(false)}
          className="px-6 py-2 bg-foreground text-background rounded-lg font-medium hover:opacity-90 transition-opacity"
        >
          Retry
        </button>
      </div>
    )
  }

  return (
    <div className="max-w-7xl mx-auto space-y-4">
      {/* Search Bar */}
      <div className="relative">
        <input
          type="text"
          placeholder="Search transactions..."
          value={searchText}
          onChange={(e) => {
            setSearchText(e.target.value)
            setPage(1)
          }}
          className={`w-full px-4 py-3 pl-10 ${glassFilter} text-foreground`}
        />
        <svg
          className="absolute left-3 top-3.5 w-5 h-5 text-gray-400"
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
        >
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={2}
            d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
          />
        </svg>
      </div>

      {/* Filter Bar */}
      <TransactionFilters
        session={session}
        filters={filters}
        onFiltersChange={setFilters}
      />

      {/* Transactions List */}
      {transactions.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-20 gap-4">
          <span className="text-5xl">📋</span>
          <p className="text-lg font-semibold">No transactions found</p>
          <p className="text-sm text-gray-500 dark:text-gray-400">
            {searchText ? 'Try a different search term' : 'Upload statements to see transactions'}
          </p>
          {!searchText && (
            <button
              onClick={() => setIsUploadModalOpen(true)}
              className="mt-4 px-6 py-3 rounded-lg bg-[#D4AF37] text-black font-medium hover:bg-[#D4AF37]/90 transition-colors flex items-center gap-2"
            >
              <svg
                className="w-5 h-5"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"
                />
              </svg>
              Upload Statement
            </button>
          )}
        </div>
      ) : (
        <div className="space-y-6">
          {Object.entries(groupedTransactions).map(([date, txns]) => (
            <div key={date}>
              <h3 className="text-lg font-bold mb-3">
                {date}
                <span className="ml-2 text-sm font-normal text-gray-500 dark:text-gray-400">
                  ({txns.length} {txns.length === 1 ? 'transaction' : 'transactions'})
                </span>
              </h3>
              <div className="space-y-2">
                {txns.map((txn) => (
                  <TransactionRow
                    key={txn.txn_id}
                    transaction={txn}
                    onClick={() => handleTransactionClick(txn)}
                  />
                ))}
              </div>
            </div>
          ))}

          {/* Load More */}
          {total > transactions.length && !loading && (
            <button
              onClick={() => setPage(page + 1)}
              className={`w-full py-3 ${glassFilter} font-medium hover:bg-white/10 dark:hover:bg-white/10 transition-colors`}
            >
              Load More ({total - transactions.length} remaining)
            </button>
          )}
          {loading && transactions.length > 0 && (
            <div className="flex items-center justify-center py-4">
              <div className="animate-spin rounded-full h-8 w-8 border-t-2 border-b-2 border-foreground"></div>
            </div>
          )}
        </div>
      )}

      {/* Floating Action Buttons */}
      <div className="fixed bottom-24 right-4 md:bottom-6 md:right-6 z-20 flex flex-col gap-3">
        {/* Upload Button */}
        <button
          onClick={() => setIsUploadModalOpen(true)}
          className="w-14 h-14 rounded-full bg-white/10 backdrop-blur-sm border border-white/20 text-white shadow-lg hover:bg-white/20 transition-all hover:scale-110 flex items-center justify-center"
          title="Upload Statement"
        >
          <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"
            />
          </svg>
        </button>
        {/* Add Transaction Button */}
        <button
          onClick={() => setIsManualTransactionModalOpen(true)}
          className="w-14 h-14 rounded-full bg-[#D4AF37] text-black shadow-lg hover:bg-[#D4AF37]/90 transition-all hover:scale-110 flex items-center justify-center"
          title="Add Transaction"
        >
          <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
          </svg>
        </button>
      </div>

      {/* File Upload Modal */}
      <FileUploadModal
        session={session}
        isOpen={isUploadModalOpen}
        onClose={() => setIsUploadModalOpen(false)}
        onUploadComplete={() => {
          // Clear search text and filters to show all transactions after upload
          setSearchText('')
          setFilters({
            category_code: null,
            subcategory_code: null,
            channel: null,
            direction: null,
            start_date: null,
            end_date: null,
          })
          setPage(1)
          // loadTransactions will be called automatically by useEffect when searchText/filters change
        }}
      />

      {/* Manual Transaction Modal */}
      <ManualTransactionModal
        session={session}
        isOpen={isManualTransactionModalOpen}
        onClose={() => setIsManualTransactionModalOpen(false)}
        onSuccess={handleCreateSuccess}
      />

      {/* Transaction Detail Modal */}
      {selectedTransaction && (
        <>
          <TransactionDetailModal
            session={session}
            transaction={selectedTransaction}
            isOpen={isTransactionDetailModalOpen}
            onClose={() => {
              setIsTransactionDetailModalOpen(false)
              setSelectedTransaction(null)
            }}
            onEdit={handleEdit}
            onDelete={handleDeleteClick}
          />

          {/* Delete Confirmation */}
          {showDeleteConfirm && (
            <div className="fixed inset-0 z-[60] flex items-center justify-center bg-black/50 backdrop-blur-sm">
              <div className={`${glassCardPrimary} p-6 max-w-sm w-full mx-4`}>
                <h3 className="text-xl font-bold mb-2">Delete Transaction</h3>
                <p className="text-gray-400 mb-6">
                  Are you sure you want to delete this transaction? This action cannot be undone.
                </p>
                <div className="flex gap-3">
                  <button
                    onClick={() => setShowDeleteConfirm(false)}
                    className="flex-1 px-4 py-3 rounded-lg bg-white/5 border border-white/10 hover:bg-white/10 transition-colors"
                  >
                    Cancel
                  </button>
                  <button
                    onClick={handleDelete}
                    className="flex-1 px-4 py-3 rounded-lg bg-red-500/20 border border-red-500/30 hover:bg-red-500/30 transition-colors text-red-400 font-medium"
                  >
                    Delete
                  </button>
                </div>
              </div>
            </div>
          )}

          {/* Transaction Edit Modal */}
          <TransactionEditModal
            session={session}
            transaction={selectedTransaction}
            isOpen={isTransactionEditModalOpen}
            onClose={() => {
              setIsTransactionEditModalOpen(false)
              setSelectedTransaction(null)
            }}
            onSuccess={handleUpdateSuccess}
          />
        </>
      )}
    </div>
  )
}

function TransactionRow({
  transaction,
  onClick,
}: {
  transaction: Transaction
  onClick: () => void
}) {
  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('en-IN', {
      style: 'currency',
      currency: 'INR',
      maximumFractionDigits: 0,
    }).format(Math.abs(amount))
  }

  const formatDate = (dateString: string) => {
    const date = new Date(dateString)
    return date.toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric',
    })
  }

  const isDebit = transaction.direction === 'debit'
  const categoryColor = getCategoryColor(transaction.category || '')

  return (
    <button
      onClick={onClick}
      className={`w-full ${glassCardSecondary} p-4 text-left hover:bg-white/10 transition-colors`}
    >
      <div className="flex items-center gap-4">
        {/* Category Icon */}
        <div className={`flex-shrink-0 w-12 h-12 rounded-full flex items-center justify-center ${categoryColor.bg}`}>
          <span className={`text-lg ${categoryColor.text}`}>
            {getMerchantIcon(transaction.merchant || '')}
          </span>
        </div>

        {/* Content */}
        <div className="flex-1 min-w-0">
          <h4 className="font-semibold text-foreground truncate">
            {transaction.merchant || transaction.category || 'Transaction'}
          </h4>
          <div className="flex items-center gap-2 mt-1 flex-wrap">
            {transaction.category && (
              <span
                className={`inline-flex items-center gap-1 px-2 py-1 rounded-full text-xs font-medium ${categoryColor.badge}`}
              >
                <span className={`w-1.5 h-1.5 rounded-full ${categoryColor.dot}`} />
                {transaction.category}
              </span>
            )}
            {transaction.subcategory && (
              <>
                <span className="text-gray-500">•</span>
                <span className="text-xs text-gray-500 dark:text-gray-400">{transaction.subcategory}</span>
              </>
            )}
            {transaction.channel && (
              <>
                <span className="text-gray-500">•</span>
                <span className="text-xs text-gray-500 dark:text-gray-400">
                  {transaction.channel.toUpperCase()}
                </span>
              </>
            )}
            <span className="text-gray-500">•</span>
            <span className="text-xs text-gray-500 dark:text-gray-400">{formatDate(transaction.txn_date)}</span>
          </div>
        </div>

        {/* Amount */}
        <div className="flex-shrink-0 text-right">
          <p
            className={`text-lg font-bold ${
              isDebit ? 'text-red-600 dark:text-red-400' : 'text-green-600 dark:text-green-400'
            }`}
          >
            {isDebit ? '-' : '+'}
            {formatCurrency(transaction.amount)}
          </p>
        </div>
      </div>
    </button>
  )
}

function getCategoryColor(category: string): {
  bg: string
  text: string
  badge: string
  dot: string
} {
  const cat = category.toLowerCase()
  if (cat.includes('food') || cat.includes('dining')) {
    return {
      bg: 'bg-orange-500/20',
      text: 'text-orange-400',
      badge: 'bg-orange-500/15 text-orange-400',
      dot: 'bg-orange-400',
    }
  } else if (cat.includes('shopping')) {
    return {
      bg: 'bg-purple-500/20',
      text: 'text-purple-400',
      badge: 'bg-purple-500/15 text-purple-400',
      dot: 'bg-purple-400',
    }
  } else if (cat.includes('transport') || cat.includes('travel')) {
    return {
      bg: 'bg-blue-500/20',
      text: 'text-blue-400',
      badge: 'bg-blue-500/15 text-blue-400',
      dot: 'bg-blue-400',
    }
  } else if (cat.includes('entertainment')) {
    return {
      bg: 'bg-red-500/20',
      text: 'text-red-400',
      badge: 'bg-red-500/15 text-red-400',
      dot: 'bg-red-400',
    }
  } else if (cat.includes('income')) {
    return {
      bg: 'bg-green-500/20',
      text: 'text-green-400',
      badge: 'bg-green-500/15 text-green-400',
      dot: 'bg-green-400',
    }
  }
  return {
    bg: 'bg-[#D4AF37]/20',
    text: 'text-[#D4AF37]',
    badge: 'bg-[#D4AF37]/15 text-[#D4AF37]',
    dot: 'bg-[#D4AF37]',
  }
}

function getMerchantIcon(merchant: string): string {
  const m = merchant.toLowerCase()
  if (m.includes('amazon')) return '🛒'
  if (m.includes('netflix') || m.includes('spotify')) return '📺'
  if (m.includes('uber') || m.includes('ola')) return '🚗'
  if (m.includes('zomato') || m.includes('swiggy')) return '🍴'
  return '💳'
}
