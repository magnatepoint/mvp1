'use client'

import type { InsightsResponse } from '@/types/console'
import SpendingPatternsChart from '../charts/SpendingPatternsChart'
import TopMerchantsList from '../components/TopMerchantsList'
import { glassCardSecondary } from '@/lib/theme/glass'

interface PatternsTabProps {
  insights: InsightsResponse
}

export default function PatternsTab({ insights }: PatternsTabProps) {
  return (
    <div className="space-y-6">
      {/* Spending Patterns Chart */}
      {insights.spending_patterns && insights.spending_patterns.length > 0 && (
        <SpendingPatternsChart data={insights.spending_patterns} />
      )}

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Top Merchants */}
        {insights.top_merchants && insights.top_merchants.length > 0 && (
          <TopMerchantsList merchants={insights.top_merchants} limit={10} />
        )}

        {/* Recurring Transactions */}
        {insights.recurring_transactions && insights.recurring_transactions.length > 0 && (
          <div className={`${glassCardSecondary} p-6`}>
            <h3 className="text-lg font-bold mb-4">Recurring Transactions</h3>
            <div className="space-y-3">
              {insights.recurring_transactions.map((recurring, index) => (
                <RecurringTransactionCard key={index} transaction={recurring} />
              ))}
            </div>
          </div>
        )}
      </div>
    </div>
  )
}

function RecurringTransactionCard({ transaction }: { transaction: any }) {
  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('en-IN', {
      style: 'currency',
      currency: 'INR',
      maximumFractionDigits: 0,
    }).format(amount)
  }

  return (
    <div className="p-3 bg-white/5 rounded-lg">
      <div className="flex items-center justify-between">
        <div>
          <h4 className="font-semibold">{transaction.merchant_name}</h4>
          <div className="flex items-center gap-2 mt-1 text-sm text-gray-400">
            {transaction.category_name && <span>{transaction.category_name}</span>}
            <span>•</span>
            <span className="capitalize">{transaction.frequency}</span>
            <span>•</span>
            <span>{transaction.transaction_count} occurrences</span>
          </div>
        </div>
        <div className="text-right">
          <p className="font-bold">{formatCurrency(transaction.avg_amount)}</p>
          <p className="text-xs text-gray-400">
            Total: {formatCurrency(transaction.total_amount)}
          </p>
        </div>
      </div>
    </div>
  )
}
