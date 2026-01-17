'use client'

import type { InsightsResponse } from '@/types/console'
import InsightCard from './InsightCard'

interface ActionableInsightsProps {
  insights: InsightsResponse
  onFixUncategorized: () => void
}

export default function ActionableInsights({ insights, onFixUncategorized }: ActionableInsightsProps) {
  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('en-IN', {
      style: 'currency',
      currency: 'INR',
      maximumFractionDigits: 0,
    }).format(amount)
  }

  const insightsList: Array<{
    type: 'spending_alert' | 'trend' | 'recommendation' | 'achievement'
    title: string
    message: string
    actionLabel?: string
    onAction?: () => void
  }> = []

  // Uncategorized insight
  const uncategorized = insights.category_breakdown?.find((cat) => cat.category_code === 'uncategorized')
  if (uncategorized && uncategorized.percentage > 10) {
    insightsList.push({
      type: 'spending_alert',
      title: 'High Uncategorized Spending',
      message: `${uncategorized.percentage.toFixed(1)}% of your spending (${formatCurrency(uncategorized.amount)}) is uncategorized. Categorize transactions to unlock better insights.`,
      actionLabel: 'Fix Now',
      onAction: onFixUncategorized,
    })
  }

  // Top merchants insight
  if (insights.top_merchants && insights.top_merchants.length > 0) {
    const top3Total = insights.top_merchants
      .slice(0, 3)
      .reduce((sum, m: any) => sum + (m.total_spend || 0), 0)
    const totalSpending = insights.category_breakdown?.reduce((sum, cat) => sum + cat.amount, 0) || 1
    const top3Percentage = (top3Total / totalSpending) * 100

    if (top3Percentage > 30) {
      insightsList.push({
        type: 'trend',
        title: 'Concentrated Spending',
        message: `Your top 3 merchants account for ${top3Percentage.toFixed(1)}% of your spending. Consider diversifying your purchases.`,
      })
    }
  }

  // Recurring subscriptions insight
  if (insights.recurring_transactions && insights.recurring_transactions.length > 0) {
    const recurringTotal = insights.recurring_transactions.reduce((sum, r) => sum + r.total_amount, 0)
    insightsList.push({
      type: 'recommendation',
      title: 'Recurring Subscriptions',
      message: `You have ${insights.recurring_transactions.length} recurring subscriptions totaling ${formatCurrency(recurringTotal)}/month. Review them regularly to optimize spending.`,
    })
  }

  // Spending trends insight
  if (insights.spending_trends && insights.spending_trends.length >= 2) {
    const latest = insights.spending_trends[insights.spending_trends.length - 1]
    const previous = insights.spending_trends[insights.spending_trends.length - 2]
    const wantsChange = previous ? ((latest.wants - previous.wants) / previous.wants) * 100 : 0

    if (wantsChange > 20) {
      insightsList.push({
        type: 'spending_alert',
        title: 'Increased Discretionary Spending',
        message: `Your "wants" spending increased by ${wantsChange.toFixed(1)}% compared to last month. Consider reviewing your discretionary expenses.`,
      })
    } else if (wantsChange < -20) {
      insightsList.push({
        type: 'achievement',
        title: 'Reduced Discretionary Spending',
        message: `Great job! You reduced your "wants" spending by ${Math.abs(wantsChange).toFixed(1)}% compared to last month.`,
      })
    }
  }

  if (insightsList.length === 0) {
    return null
  }

  return (
    <div className="space-y-3">
      <h3 className="text-lg font-bold">Actionable Insights</h3>
      {insightsList.map((insight, index) => (
        <InsightCard key={index} {...insight} />
      ))}
    </div>
  )
}
