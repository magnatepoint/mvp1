'use client'

import { useState, useEffect } from 'react'
import type { Session } from '@supabase/supabase-js'
import { fetchTransactions } from '@/lib/api/spendsense'
import type { Transaction } from '@/types/spendsense'
import { glassCardSecondary } from '@/lib/theme/glass'
import BulkCategorizeModal from './BulkCategorizeModal'

interface UncategorizedTransactionsProps {
  session: Session
  onCategorize: (txnId: string, categoryCode: string, subcategoryCode?: string) => Promise<void>
}

export default function UncategorizedTransactions({ session, onCategorize }: UncategorizedTransactionsProps) {
  const [transactions, setTransactions] = useState<Transaction[]>([])
  const [loading, setLoading] = useState(true)
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set())
  const [showBulkModal, setShowBulkModal] = useState(false)

  useEffect(() => {
    loadUncategorizedTransactions()
  }, [session])

  const loadUncategorizedTransactions = async () => {
    try {
      const response = await fetchTransactions(session, {
        category_code: 'uncategorized',
        limit: 100,
      })
      setTransactions(response.transactions)
    } catch (err) {
      console.error('Failed to load uncategorized transactions:', err)
    } finally {
      setLoading(false)
    }
  }

  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('en-IN', {
      style: 'currency',
      currency: 'INR',
      maximumFractionDigits: 0,
    }).format(amount)
  }

  const toggleSelection = (txnId: string) => {
    const newSelected = new Set(selectedIds)
    if (newSelected.has(txnId)) {
      newSelected.delete(txnId)
    } else {
      newSelected.add(txnId)
    }
    setSelectedIds(newSelected)
  }

  const selectAll = () => {
    if (selectedIds.size === transactions.length) {
      setSelectedIds(new Set())
    } else {
      setSelectedIds(new Set(transactions.map((t) => t.txn_id)))
    }
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center py-20">
        <div className="animate-spin rounded-full h-12 w-12 border-t-2 border-b-2 border-foreground"></div>
      </div>
    )
  }

  if (transactions.length === 0) {
    return (
      <div className={`${glassCardSecondary} p-8 text-center`}>
        <span className="text-5xl mb-4 block">🎉</span>
        <p className="text-lg font-semibold">All transactions are categorized!</p>
        <p className="text-sm text-gray-400 mt-2">Great job keeping your finances organized.</p>
      </div>
    )
  }

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <div>
          <h3 className="text-lg font-bold">Uncategorized Transactions</h3>
          <p className="text-sm text-gray-400 mt-1">
            {transactions.length} transactions need categorization
          </p>
        </div>
        <button
          onClick={selectAll}
          className="px-4 py-2 bg-white/10 hover:bg-white/20 rounded-lg text-sm font-medium transition-colors"
        >
          {selectedIds.size === transactions.length ? 'Deselect All' : 'Select All'}
        </button>
      </div>

      <div className="space-y-2 max-h-[600px] overflow-y-auto">
        {transactions.map((transaction) => (
          <TransactionRow
            key={transaction.txn_id}
            transaction={transaction}
            isSelected={selectedIds.has(transaction.txn_id)}
            onToggleSelect={() => toggleSelection(transaction.txn_id)}
            onCategorize={onCategorize}
            formatCurrency={formatCurrency}
          />
        ))}
      </div>

      {selectedIds.size > 0 && (
        <div className="sticky bottom-0 p-4 bg-black/50 backdrop-blur-md border-t border-white/10 rounded-t-lg">
          <p className="text-sm text-gray-300 mb-2">
            {selectedIds.size} transaction{selectedIds.size !== 1 ? 's' : ''} selected
          </p>
          <button
            onClick={() => setShowBulkModal(true)}
            className="px-6 py-2 bg-[#D4AF37] hover:bg-[#D4AF37]/90 text-black font-semibold rounded-lg transition-colors"
          >
            Bulk Categorize
          </button>
        </div>
      )}

      <BulkCategorizeModal
        session={session}
        transactionIds={Array.from(selectedIds)}
        isOpen={showBulkModal}
        onClose={() => {
          setShowBulkModal(false)
          setSelectedIds(new Set())
        }}
        onSuccess={() => {
          loadUncategorizedTransactions()
          setShowBulkModal(false)
          setSelectedIds(new Set())
        }}
      />
    </div>
  )
}

function TransactionRow({
  transaction,
  isSelected,
  onToggleSelect,
  onCategorize,
  formatCurrency,
}: {
  transaction: Transaction
  isSelected: boolean
  onToggleSelect: () => void
  onCategorize: (txnId: string, categoryCode: string, subcategoryCode?: string) => Promise<void>
  formatCurrency: (amount: number) => string
}) {
  return (
    <div
      className={`${glassCardSecondary} p-4 flex items-center gap-4 cursor-pointer hover:bg-white/10 transition-colors ${
        isSelected ? 'ring-2 ring-[#D4AF37]' : ''
      }`}
      onClick={onToggleSelect}
    >
      <input
        type="checkbox"
        checked={isSelected}
        onChange={onToggleSelect}
        onClick={(e) => e.stopPropagation()}
        className="w-5 h-5 rounded border-white/20"
      />
      <div className="flex-1">
        <div className="flex items-center justify-between">
          <div>
            <p className="font-semibold">{transaction.merchant || 'Unknown Merchant'}</p>
            <p className="text-sm text-gray-400">
              {new Date(transaction.txn_date).toLocaleDateString('en-IN', {
                month: 'short',
                day: 'numeric',
                year: 'numeric',
              })}
            </p>
          </div>
          <p className={`font-bold ${transaction.direction === 'debit' ? 'text-red-400' : 'text-green-400'}`}>
            {transaction.direction === 'debit' ? '-' : '+'}
            {formatCurrency(transaction.amount)}
          </p>
        </div>
      </div>
    </div>
  )
}
