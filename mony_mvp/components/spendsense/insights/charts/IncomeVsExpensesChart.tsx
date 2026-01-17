'use client'

import { AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Legend } from 'recharts'
import { glassCardPrimary } from '@/lib/theme/glass'
import type { SpendingTrend } from '@/types/console'

interface IncomeVsExpensesChartProps {
  data: SpendingTrend[]
}

export default function IncomeVsExpensesChart({ data }: IncomeVsExpensesChartProps) {
  const formatCurrency = (value: number) => {
    return new Intl.NumberFormat('en-IN', {
      style: 'currency',
      currency: 'INR',
      maximumFractionDigits: 0,
    }).format(value)
  }

  if (data.length === 0) {
    return (
      <div className={`${glassCardPrimary} p-8 flex items-center justify-center`}>
        <p className="text-gray-400">No income/expense data available</p>
      </div>
    )
  }

  return (
    <div className={`${glassCardPrimary} p-6`}>
      <h3 className="text-lg font-bold mb-4">Income vs Expenses</h3>
      <ResponsiveContainer width="100%" height={350}>
        <AreaChart data={data} margin={{ top: 5, right: 20, left: 0, bottom: 5 }}>
          <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.1)" />
          <XAxis
            dataKey="period"
            stroke="rgba(255,255,255,0.5)"
            style={{ fontSize: '12px' }}
            angle={-45}
            textAnchor="end"
            height={80}
          />
          <YAxis
            stroke="rgba(255,255,255,0.5)"
            style={{ fontSize: '12px' }}
            tickFormatter={formatCurrency}
          />
          <Tooltip
            contentStyle={{
              backgroundColor: 'rgba(0,0,0,0.8)',
              border: '1px solid rgba(255,255,255,0.2)',
              borderRadius: '8px',
            }}
            formatter={(value: number) => formatCurrency(value)}
          />
          <Legend />
          <Area
            type="monotone"
            dataKey="income"
            stackId="1"
            stroke="#22c55e"
            fill="#22c55e"
            fillOpacity={0.6}
            name="Income"
          />
          <Area
            type="monotone"
            dataKey="expenses"
            stackId="2"
            stroke="#ef4444"
            fill="#ef4444"
            fillOpacity={0.6}
            name="Expenses"
          />
        </AreaChart>
      </ResponsiveContainer>
    </div>
  )
}
