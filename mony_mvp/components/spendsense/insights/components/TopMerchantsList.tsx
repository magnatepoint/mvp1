'use client'

import { glassCardSecondary } from '@/lib/theme/glass'
import type { InsightsResponse } from '@/types/console'

interface TopMerchantsListProps {
  merchants: InsightsResponse['top_merchants']
  limit?: number
}

export default function TopMerchantsList({ merchants, limit = 10 }: TopMerchantsListProps) {
  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('en-IN', {
      style: 'currency',
      currency: 'INR',
      maximumFractionDigits: 0,
    }).format(amount)
  }

  if (!merchants || merchants.length === 0) {
    return (
      <div className={`${glassCardSecondary} p-6 text-center`}>
        <p className="text-gray-400">No merchant data available</p>
      </div>
    )
  }

  const topMerchants = merchants.slice(0, limit)

  return (
    <div className={`${glassCardSecondary} p-6`}>
      <h3 className="text-lg font-bold mb-4">Top Merchants</h3>
      <div className="space-y-3">
        {topMerchants.map((merchant: any, index) => (
          <div key={index} className="flex items-center justify-between p-3 bg-white/5 rounded-lg">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-full bg-[#D4AF37]/20 flex items-center justify-center font-bold text-[#D4AF37]">
                {index + 1}
              </div>
              <div>
                <p className="font-semibold">{merchant.merchant_name || 'Unknown'}</p>
                <p className="text-xs text-gray-400">
                  {merchant.transaction_count} transactions
                  {merchant.last_transaction && (
                    <> • Last: {new Date(merchant.last_transaction).toLocaleDateString('en-IN', { month: 'short', day: 'numeric' })}</>
                  )}
                </p>
              </div>
            </div>
            <div className="text-right">
              <p className="font-bold">{formatCurrency(merchant.total_spend || 0)}</p>
              <p className="text-xs text-gray-400">Avg: {formatCurrency(merchant.avg_spend || 0)}</p>
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
