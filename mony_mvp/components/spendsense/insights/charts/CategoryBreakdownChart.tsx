'use client'

import { PieChart, Pie, Cell, ResponsiveContainer, Tooltip, Legend } from 'recharts'
import { glassCardPrimary } from '@/lib/theme/glass'
import type { CategoryBreakdownItem } from '@/types/console'

interface CategoryBreakdownChartProps {
  data: CategoryBreakdownItem[]
  onCategoryClick?: (categoryCode: string) => void
}

const COLORS = [
  '#3b82f6', // blue
  '#ef4444', // red
  '#22c55e', // green
  '#f59e0b', // amber
  '#8b5cf6', // purple
  '#ec4899', // pink
  '#06b6d4', // cyan
  '#f97316', // orange
  '#84cc16', // lime
  '#6366f1', // indigo
]

export default function CategoryBreakdownChart({ data, onCategoryClick }: CategoryBreakdownChartProps) {
  const formatCurrency = (value: number) => {
    return new Intl.NumberFormat('en-IN', {
      style: 'currency',
      currency: 'INR',
      maximumFractionDigits: 0,
    }).format(value)
  }

  // Prepare chart data (limit to top 10, group rest as "Others")
  const sortedData = [...data].sort((a, b) => b.amount - a.amount)
  const topCategories = sortedData.slice(0, 9)
  const others = sortedData.slice(9)
  const othersTotal = others.reduce((sum, cat) => sum + cat.amount, 0)

  const chartData = [
    ...topCategories.map((cat) => ({
      name: cat.category_name,
      value: cat.amount,
      percentage: cat.percentage,
      categoryCode: cat.category_code,
    })),
    ...(othersTotal > 0
      ? [
          {
            name: 'Others',
            value: othersTotal,
            percentage: others.reduce((sum, cat) => sum + cat.percentage, 0),
            categoryCode: 'others',
          },
        ]
      : []),
  ]

  if (chartData.length === 0) {
    return (
      <div className={`${glassCardPrimary} p-8 flex items-center justify-center`}>
        <p className="text-gray-400">No category data available</p>
      </div>
    )
  }

  return (
    <div className={`${glassCardPrimary} p-6`}>
      <h3 className="text-lg font-bold mb-4">Category Breakdown</h3>
      <ResponsiveContainer width="100%" height={400}>
        <PieChart>
          <Pie
            data={chartData}
            cx="50%"
            cy="50%"
            labelLine={false}
            label={(props: any) => {
              const { name, payload } = props
              const percentage = payload?.percentage || 0
              // Only show label if percentage is significant
              if (percentage < 3) return ''
              return `${name}: ${percentage.toFixed(1)}%`
            }}
            outerRadius={120}
            fill="#8884d8"
            dataKey="value"
            onClick={(data: any) => onCategoryClick?.(data.categoryCode)}
            style={{ cursor: onCategoryClick ? 'pointer' : 'default' }}
          >
            {chartData.map((entry, index) => (
              <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
            ))}
          </Pie>
          <Tooltip
            contentStyle={{
              backgroundColor: 'rgba(0,0,0,0.8)',
              border: '1px solid rgba(255,255,255,0.2)',
              borderRadius: '8px',
            }}
            formatter={(value) => {
              const numValue = typeof value === 'number' ? value : (typeof value === 'string' ? parseFloat(value) : 0)
              return formatCurrency(numValue)
            }}
            labelFormatter={(label, payload) => {
              if (payload && payload.length > 0) {
                const percentage = payload[0].payload?.percentage || 0
                return `${label}: ${percentage.toFixed(1)}%`
              }
              return label
            }}
          />
          <Legend
            formatter={(value, entry: any) => (
              <span style={{ color: 'rgba(255,255,255,0.8)' }}>
                {value}: {formatCurrency(entry.payload.value)} ({entry.payload.percentage.toFixed(1)}%)
              </span>
            )}
          />
        </PieChart>
      </ResponsiveContainer>
    </div>
  )
}
