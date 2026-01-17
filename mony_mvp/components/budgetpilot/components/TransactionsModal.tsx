'use client'

import type { Transaction } from '@/types/spendsense'
import { glassCardPrimary } from '@/lib/theme/glass'

interface TransactionsModalProps {
  transactions: Transaction[]
  categoryName: string
  isOpen: boolean
  onClose: () => void
}

export default function TransactionsModal({
  transactions,
  categoryName,
  isOpen,
  onClose,
}: TransactionsModalProps) {
  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('en-IN', {
      style: 'currency',
      currency: 'INR',
      maximumFractionDigits: 0,
    }).format(amount)
  }

  if (!isOpen) return null

  const total = transactions.reduce((sum, t) => sum + t.amount, 0)

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm">
      <div className={`${glassCardPrimary} p-6 max-w-2xl w-full mx-4 max-h-[80vh] overflow-hidden flex flex-col`}>
        <div className="flex items-center justify-between mb-4">
          <div>
            <h2 className="text-xl font-bold">{categoryName} Transactions</h2>
            <p className="text-sm text-gray-400 mt-1">
              {transactions.length} transactions • Total: {formatCurrency(total)}
            </p>
          </div>
          <button
            onClick={onClose}
            className="p-2 rounded-lg hover:bg-white/10 transition-colors"
          >
            <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        <div className="flex-1 overflow-y-auto space-y-2">
          {transactions.length === 0 ? (
            <p className="text-gray-400 text-center py-8">No transactions found</p>
          ) : (
            transactions.map((transaction) => (
              <div
                key={transaction.txn_id}
                className="bg-white/5 p-3 rounded-lg flex items-center justify-between"
              >
                <div className="flex-1">
                  <p className="font-semibold">{transaction.merchant || 'Unknown'}</p>
                  <p className="text-xs text-gray-400">
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
            ))
          )}
        </div>

        <div className="mt-4 pt-4 border-t border-white/10">
          <button
            onClick={onClose}
            className="w-full px-4 py-2 bg-[#D4AF37] hover:bg-[#D4AF37]/90 text-black font-semibold rounded-lg transition-colors"
          >
            Close
          </button>
        </div>
      </div>
    </div>
  )
}
