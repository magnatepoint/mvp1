'use client'

import { useEffect, useState } from 'react'
import type { Session } from '@supabase/supabase-js'
import { fetchKPIs, generateMockAccounts } from '@/lib/api/console'
import { fetchTransactions } from '@/lib/api/spendsense'
import type { Account } from '@/types/console'
import { glassCardPrimary } from '@/lib/theme/glass'

interface AccountsTabProps {
  session: Session
}

export default function AccountsTab({ session }: AccountsTabProps) {
  const [accounts, setAccounts] = useState<Account[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const loadAccounts = async () => {
    setLoading(true)
    setError(null)
    try {
      // First check if there are any transactions at all
      const transactionsResponse = await fetchTransactions(session, { limit: 1 })
      const hasTransactions = transactionsResponse.total > 0

      if (!hasTransactions) {
        // No transactions - show empty state
        setAccounts([])
        setLoading(false)
        return
      }

      const kpis = await fetchKPIs(session)
      const mockAccounts = generateMockAccounts(kpis)
      setAccounts(mockAccounts)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load accounts')
      console.error('Error loading accounts:', err)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    loadAccounts()
  }, [session])

  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('en-IN', {
      style: 'currency',
      currency: 'INR',
      maximumFractionDigits: 0,
    }).format(amount)
  }

  const getAccountIcon = (type: string) => {
    const icons: Record<string, string> = {
      CHECKING: '💳',
      SAVINGS: '🏦',
      INVESTMENT: '📈',
      CREDIT: '💳',
    }
    return icons[type] || '💳'
  }

  const getAccountColor = (type: string) => {
    const colors: Record<string, string> = {
      CHECKING: 'text-blue-400',
      SAVINGS: 'text-green-400',
      INVESTMENT: 'text-purple-400',
      CREDIT: 'text-red-400',
    }
    return colors[type] || 'text-gray-400'
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center py-20">
        <div className="animate-spin rounded-full h-12 w-12 border-t-2 border-b-2 border-[#D4AF37]"></div>
      </div>
    )
  }

  if (error) {
    return (
      <div className="flex flex-col items-center justify-center py-20 gap-4">
        <div className="text-red-400 text-center">
          <p className="text-lg font-bold mb-2">Unable to Load Accounts</p>
          <p className="text-sm">{error}</p>
        </div>
        <button
          onClick={loadAccounts}
          className="px-6 py-2 bg-[#D4AF37] text-black rounded-lg font-medium hover:bg-[#D4AF37]/90 transition-colors"
        >
          Retry
        </button>
      </div>
    )
  }

  if (accounts.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center py-20 gap-4">
        <span className="text-5xl">💳</span>
        <p className="text-lg font-semibold text-white">No Accounts</p>
        <p className="text-sm text-gray-400">Link your bank accounts to see balances</p>
      </div>
    )
  }

  return (
    <div className="max-w-7xl mx-auto space-y-4">
      <h2 className="text-xl font-bold text-white mb-4">Your Accounts</h2>
      {accounts.map((account) => (
        <AccountCard key={account.id} account={account} />
      ))}
    </div>
  )

  function AccountCard({ account }: { account: Account }) {
    return (
      <div className={`${glassCardPrimary} p-6`}>
        <div className="flex items-center gap-4">
          <div className={`text-4xl ${getAccountColor(account.account_type)}`}>
            {getAccountIcon(account.account_type)}
          </div>
          <div className="flex-1">
            <h3 className="text-lg font-bold text-white mb-1">{account.bank_name}</h3>
            <div className="flex items-center gap-2 text-sm text-gray-400">
              <span>{account.account_type}</span>
              {account.account_number && <span>• {account.account_number}</span>}
            </div>
          </div>
          <div className="text-right">
            <p className="text-lg font-bold text-white">{formatCurrency(account.balance)}</p>
          </div>
        </div>
      </div>
    )
  }
}
