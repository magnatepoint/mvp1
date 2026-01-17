'use client'

import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Legend, Cell } from 'recharts'
import { glassCardPrimary } from '@/lib/theme/glass'
import type { BudgetVariance } from '@/types/budget'

interface BudgetVarianceChartProps {
  variance: BudgetVariance
}

export default function BudgetVarianceChart({ variance }: BudgetVarianceChartProps) {
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

  const data = [
    {
      name: 'Needs',
      planned: variance.planned_needs_amt,
      actual: variance.needs_amt,
      variance: variance.variance_needs_amt,
    },
    {
      name: 'Wants',
      planned: variance.planned_wants_amt,
      actual: variance.wants_amt,
      variance: variance.variance_wants_amt,
    },
    {
      name: 'Savings',
      planned: variance.planned_assets_amt,
      actual: variance.assets_amt,
      variance: variance.variance_assets_amt,
    },
  ]

  return (
    <div className={`${glassCardPrimary} p-6`}>
      <h3 className="text-lg font-bold mb-4">Budget Performance: Actual vs Planned</h3>
      <ResponsiveContainer width="100%" height={300}>
        <BarChart data={data} margin={{ top: 5, right: 20, left: 0, bottom: 5 }}>
          <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.1)" />
          <XAxis
            dataKey="name"
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
            formatter={(value) => formatCurrency(value)}
          />
          <Legend />
          <Bar dataKey="planned" name="Planned" fill="#3b82f6" />
          <Bar dataKey="actual" name="Actual" fill="#ef4444" />
        </BarChart>
      </ResponsiveContainer>
      
      {/* Variance Summary */}
      <div className="mt-4 grid grid-cols-3 gap-4">
        {data.map((item) => {
          const isOver = item.variance < 0
          const variancePct = item.planned > 0 ? (Math.abs(item.variance) / item.planned) * 100 : 0
          return (
            <div key={item.name} className="text-center">
              <p className="text-xs text-gray-400 mb-1">{item.name}</p>
              <p className={`text-sm font-semibold ${isOver ? 'text-red-400' : 'text-green-400'}`}>
                {isOver ? '↑' : '↓'} {formatCurrency(Math.abs(item.variance))}
              </p>
              <p className="text-xs text-gray-500">{variancePct.toFixed(1)}% {isOver ? 'over' : 'under'}</p>
            </div>
          )
        })}
      </div>
    </div>
  )
}
