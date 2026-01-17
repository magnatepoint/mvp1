'use client'

import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Legend } from 'recharts'
import { glassCardPrimary } from '@/lib/theme/glass'
import type { SpendingPattern } from '@/types/console'

interface SpendingPatternsChartProps {
  data: SpendingPattern[]
}

const DAY_ORDER = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']

export default function SpendingPatternsChart({ data }: SpendingPatternsChartProps) {
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

  // Sort data by day of week
  const sortedData = [...data].sort((a, b) => {
    const aIndex = DAY_ORDER.indexOf(a.day_of_week || '')
    const bIndex = DAY_ORDER.indexOf(b.day_of_week || '')
    return aIndex - bIndex
  })

  if (sortedData.length === 0) {
    return (
      <div className={`${glassCardPrimary} p-8 flex items-center justify-center`}>
        <p className="text-gray-400">No pattern data available</p>
      </div>
    )
  }

  return (
    <div className={`${glassCardPrimary} p-6`}>
      <h3 className="text-lg font-bold mb-4">Spending by Day of Week</h3>
      <ResponsiveContainer width="100%" height={300}>
        <BarChart data={sortedData} margin={{ top: 5, right: 20, left: 0, bottom: 5 }}>
          <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.1)" />
          <XAxis
            dataKey="day_of_week"
            stroke="rgba(255,255,255,0.5)"
            style={{ fontSize: '12px' }}
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
            formatter={(value, name) => {
              if (value === undefined || value === null) return ['₹0', name === 'amount' ? 'Spending' : 'Transactions']
              
              // Handle value conversion
              let numValue: number
              if (Array.isArray(value)) {
                if (value.length === 0) return ['₹0', name === 'amount' ? 'Spending' : 'Transactions']
                const firstValue = value[0]
                numValue = typeof firstValue === 'string' ? parseFloat(firstValue) : (typeof firstValue === 'number' ? firstValue : 0)
              } else if (typeof value === 'string') {
                numValue = parseFloat(value)
              } else if (typeof value === 'number') {
                numValue = value
              } else {
                return ['₹0', name === 'amount' ? 'Spending' : 'Transactions']
              }
              
              if (isNaN(numValue)) return ['₹0', name === 'amount' ? 'Spending' : 'Transactions']
              
              return [
                name === 'amount' ? formatCurrency(numValue) : numValue.toString(),
                name === 'amount' ? 'Spending' : 'Transactions',
              ]
            }}
          />
          <Legend />
          <Bar dataKey="amount" fill="#3b82f6" name="Spending" />
          <Bar dataKey="transaction_count" fill="#8b5cf6" name="Transactions" />
        </BarChart>
      </ResponsiveContainer>
    </div>
  )
}
