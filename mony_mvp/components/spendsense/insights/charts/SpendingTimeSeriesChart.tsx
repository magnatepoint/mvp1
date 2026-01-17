'use client'

import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Legend } from 'recharts'
import { glassCardPrimary } from '@/lib/theme/glass'
import type { TimeSeriesPoint } from '@/types/console'

interface SpendingTimeSeriesChartProps {
  data: TimeSeriesPoint[]
  incomeData?: TimeSeriesPoint[]
}

export default function SpendingTimeSeriesChart({ data, incomeData }: SpendingTimeSeriesChartProps) {
  const formatCurrency = (value: number | string | readonly (string | number)[] | undefined) => {
    if (value === undefined || value === null) return '₹0'
    
    // Handle arrays - take the first value
    let numValue: number
    if (Array.isArray(value)) {
      if (value.length === 0) return '₹0'
      const firstValue = value[0]
      numValue = typeof firstValue === 'string' ? parseFloat(firstValue) : (typeof firstValue === 'number' ? firstValue : 0)
    } else if (typeof value === 'string') {
      numValue = parseFloat(value)
    } else if (typeof value === 'number') {
      numValue = value
    } else {
      return '₹0'
    }
    
    if (isNaN(numValue)) return '₹0'
    return new Intl.NumberFormat('en-IN', {
      style: 'currency',
      currency: 'INR',
      maximumFractionDigits: 0,
    }).format(numValue)
  }

  // Combine data for chart
  const chartData = data.map((point) => {
    const income = incomeData?.find((i) => i.date === point.date)
    return {
      date: point.label || point.date,
      expenses: point.value,
      income: income?.value || 0,
    }
  })

  if (chartData.length === 0) {
    return (
      <div className={`${glassCardPrimary} p-8 flex items-center justify-center`}>
        <p className="text-gray-400">No time series data available</p>
      </div>
    )
  }

  return (
    <div className={`${glassCardPrimary} p-6`}>
      <h3 className="text-lg font-bold mb-4">Spending Over Time</h3>
      <ResponsiveContainer width="100%" height={300}>
        <LineChart data={chartData} margin={{ top: 5, right: 20, left: 0, bottom: 5 }}>
          <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.1)" />
          <XAxis
            dataKey="date"
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
            formatter={(value) => formatCurrency(value)}
          />
          <Legend />
          <Line
            type="monotone"
            dataKey="expenses"
            stroke="#ef4444"
            strokeWidth={2}
            name="Expenses"
            dot={{ fill: '#ef4444', r: 4 }}
            activeDot={{ r: 6 }}
          />
          {incomeData && incomeData.length > 0 && (
            <Line
              type="monotone"
              dataKey="income"
              stroke="#22c55e"
              strokeWidth={2}
              name="Income"
              dot={{ fill: '#22c55e', r: 4 }}
              activeDot={{ r: 6 }}
            />
          )}
        </LineChart>
      </ResponsiveContainer>
    </div>
  )
}
