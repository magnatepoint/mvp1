import { useMemo } from 'react'
import { Target, AlertCircle, CheckCircle2 } from 'lucide-react'
import { ResponsiveContainer, BarChart, Bar, XAxis, YAxis, Tooltip, Cell } from 'recharts'
import './BudgetTracker.css'

type BudgetCategory = {
  category: string
  budget: number
  spent: number
  limit: number
}

type BudgetTrackerProps = {
  categories?: BudgetCategory[]
  loading?: boolean
}

const defaultCategories: BudgetCategory[] = [
  { category: 'Food & Dining', budget: 10000, spent: 7500, limit: 10000 },
  { category: 'Shopping', budget: 15000, spent: 12000, limit: 15000 },
  { category: 'Transport', budget: 5000, spent: 3200, limit: 5000 },
  { category: 'Entertainment', budget: 8000, spent: 9500, limit: 8000 },
  { category: 'Utilities', budget: 3000, spent: 2800, limit: 3000 },
]

export function BudgetTracker({ categories = defaultCategories, loading = false }: BudgetTrackerProps) {
  const chartData = useMemo(() => {
    return categories.map((cat) => ({
      name: cat.category.length > 12 ? cat.category.substring(0, 12) + '...' : cat.category,
      budget: cat.budget,
      spent: cat.spent,
      remaining: Math.max(0, cat.budget - cat.spent),
      percentage: (cat.spent / cat.budget) * 100,
    }))
  }, [categories])

  const currencyFormatter = useMemo(
    () =>
      new Intl.NumberFormat('en-IN', {
        style: 'currency',
        currency: 'INR',
        maximumFractionDigits: 0,
      }),
    [],
  )

  const getStatus = (spent: number, budget: number) => {
    const percentage = (spent / budget) * 100
    if (percentage >= 100) return { type: 'exceeded', icon: AlertCircle, color: 'var(--color-error)' }
    if (percentage >= 80) return { type: 'warning', icon: AlertCircle, color: 'var(--color-warning)' }
    return { type: 'good', icon: CheckCircle2, color: 'var(--color-success)' }
  }

  if (loading) {
    return (
      <div className="budget-tracker">
        <div className="budget-tracker__header">
          <div className="skeleton" style={{ width: '200px', height: '24px' }} />
        </div>
        <div className="skeleton" style={{ width: '100%', height: '300px', marginTop: '1.5rem' }} />
      </div>
    )
  }

  return (
    <div className="budget-tracker">
      <div className="budget-tracker__header">
        <div className="budget-tracker__title">
          <Target size={20} />
          <h3>Budget Tracker</h3>
        </div>
        <button className="ghost-button" style={{ fontSize: '0.875rem' }}>
          Manage Budgets
        </button>
      </div>

      <div className="budget-tracker__chart">
        <ResponsiveContainer width="100%" height={300}>
          <BarChart data={chartData} margin={{ top: 20, right: 30, left: 20, bottom: 60 }}>
            <XAxis
              dataKey="name"
              angle={-45}
              textAnchor="end"
              height={80}
              tick={{ fill: '#93a4c2', fontSize: 12 }}
            />
            <YAxis tick={{ fill: '#93a4c2', fontSize: 12 }} />
            <Tooltip
              formatter={(value: number, name: string) => {
                if (name === 'percentage') return `${value.toFixed(1)}%`
                return currencyFormatter.format(value)
              }}
              contentStyle={{
                backgroundColor: 'rgba(8, 12, 20, 0.95)',
                border: '1px solid rgba(255, 255, 255, 0.1)',
                borderRadius: '8px',
                color: '#f9fbff',
              }}
            />
            <Bar dataKey="budget" fill="rgba(255, 255, 255, 0.1)" radius={[4, 4, 0, 0]} />
            <Bar dataKey="spent" radius={[4, 4, 0, 0]}>
              {chartData.map((entry, index) => (
                <Cell
                  key={`cell-${index}`}
                  fill={entry.percentage >= 100 ? '#ef4444' : entry.percentage >= 80 ? '#f59e0b' : '#10b981'}
                />
              ))}
            </Bar>
          </BarChart>
        </ResponsiveContainer>
      </div>

      <div className="budget-tracker__list">
        {categories.map((cat, index) => {
          const status = getStatus(cat.spent, cat.budget)
          const percentage = (cat.spent / cat.budget) * 100
          const StatusIcon = status.icon

          return (
            <div key={index} className="budget-tracker__item">
              <div className="budget-tracker__itemHeader">
                <div className="budget-tracker__itemInfo">
                  <h4 className="budget-tracker__itemCategory">{cat.category}</h4>
                  <div className="budget-tracker__itemAmounts">
                    <span className="budget-tracker__itemSpent">
                      {currencyFormatter.format(cat.spent)}
                    </span>
                    <span className="budget-tracker__itemBudget">
                      / {currencyFormatter.format(cat.budget)}
                    </span>
                  </div>
                </div>
                <div className="budget-tracker__itemStatus">
                  <StatusIcon size={18} style={{ color: status.color }} />
                  <span style={{ color: status.color, fontSize: '0.875rem', fontWeight: 600 }}>
                    {percentage.toFixed(0)}%
                  </span>
                </div>
              </div>
              <div className="budget-tracker__progressBar">
                <div
                  className="budget-tracker__progressFill"
                  style={{
                    width: `${Math.min(100, percentage)}%`,
                    backgroundColor: status.color,
                  }}
                />
              </div>
              {cat.spent > cat.budget && (
                <div className="budget-tracker__overBudget">
                  <AlertCircle size={14} />
                  <span>Over budget by {currencyFormatter.format(cat.spent - cat.budget)}</span>
                </div>
              )}
            </div>
          )
        })}
      </div>
    </div>
  )
}

