import { TrendingUp, TrendingDown, Calendar } from 'lucide-react'
import { ResponsiveContainer, LineChart, Line, XAxis, YAxis, Tooltip, ReferenceLine } from 'recharts'
import './SpendingPredictions.css'

type Prediction = {
  month: string
  predicted: number
  actual?: number
  confidence: number
}

type SpendingPredictionsProps = {
  predictions?: Prediction[]
  loading?: boolean
}

const defaultPredictions: Prediction[] = [
  { month: 'Jan', predicted: 45000, actual: 42000, confidence: 0.85 },
  { month: 'Feb', predicted: 48000, actual: 46000, confidence: 0.88 },
  { month: 'Mar', predicted: 50000, actual: 51000, confidence: 0.82 },
  { month: 'Apr', predicted: 52000, confidence: 0.75 },
  { month: 'May', predicted: 55000, confidence: 0.70 },
  { month: 'Jun', predicted: 58000, confidence: 0.65 },
]

export function SpendingPredictions({ predictions = defaultPredictions, loading = false }: SpendingPredictionsProps) {
  const currencyFormatter = new Intl.NumberFormat('en-IN', {
    style: 'currency',
    currency: 'INR',
    maximumFractionDigits: 0,
  })

  const currentMonth = predictions.find((p) => !p.actual)
  const trend = currentMonth
    ? predictions
      .filter((p) => p.actual)
      .slice(-3)
      .reduce((acc, p) => acc + (p.actual! - p.predicted) / p.predicted, 0) / 3
    : 0

  if (loading) {
    return (
      <div className="spending-predictions">
        <div className="skeleton" style={{ width: '100%', height: '300px' }} />
      </div>
    )
  }

  return (
    <div className="spending-predictions">
      <div className="spending-predictions__header">
        <div className="spending-predictions__title">
          <TrendingUp size={20} />
          <h3>Spending Predictions</h3>
        </div>
        {currentMonth && (
          <div className="spending-predictions__current">
            <span className="spending-predictions__currentLabel">Next Month</span>
            <span className="spending-predictions__currentValue">
              {currencyFormatter.format(currentMonth.predicted)}
            </span>
          </div>
        )}
      </div>

      <div className="spending-predictions__chart">
        <ResponsiveContainer width="100%" height={250}>
          <LineChart data={predictions} margin={{ top: 10, right: 30, left: 20, bottom: 10 }}>
            <XAxis
              dataKey="month"
              tick={{ fill: '#93a4c2', fontSize: 12 }}
            />
            <YAxis
              tick={{ fill: '#93a4c2', fontSize: 12 }}
              tickFormatter={(value) => `₹${(value / 1000).toFixed(0)}K`}
            />
            <Tooltip
              formatter={(value: number) => currencyFormatter.format(value)}
              contentStyle={{
                backgroundColor: 'rgba(8, 12, 20, 0.95)',
                border: '1px solid rgba(255, 255, 255, 0.1)',
                borderRadius: '8px',
                color: '#f9fbff',
              }}
            />
            <ReferenceLine y={predictions[0]?.predicted} stroke="rgba(255, 255, 255, 0.2)" strokeDasharray="3 3" />
            <Line
              type="monotone"
              dataKey="predicted"
              stroke="#34f5c5"
              strokeWidth={2}
              dot={{ fill: '#34f5c5', r: 4 }}
              strokeDasharray="5 5"
              name="Predicted"
            />
            <Line
              type="monotone"
              dataKey="actual"
              stroke="#f7c873"
              strokeWidth={2}
              dot={{ fill: '#f7c873', r: 4 }}
              name="Actual"
            />
          </LineChart>
        </ResponsiveContainer>
      </div>

      <div className="spending-predictions__insights">
        {currentMonth && (
          <div className="spending-predictions__insight">
            <Calendar size={18} />
            <div>
              <div className="spending-predictions__insightTitle">
                Predicted spending for {currentMonth.month}
              </div>
              <div className="spending-predictions__insightValue">
                {currencyFormatter.format(currentMonth.predicted)}
                <span className="spending-predictions__confidence">
                  ({Math.round(currentMonth.confidence * 100)}% confidence)
                </span>
              </div>
            </div>
          </div>
        )}

        {Math.abs(trend) > 0.05 && (
          <div className="spending-predictions__insight spending-predictions__insight--trend">
            {trend > 0 ? <TrendingUp size={18} /> : <TrendingDown size={18} />}
            <div>
              <div className="spending-predictions__insightTitle">
                {trend > 0 ? 'Spending increasing' : 'Spending decreasing'}
              </div>
              <div className="spending-predictions__insightValue">
                {Math.abs(trend * 100).toFixed(1)}% {trend > 0 ? 'above' : 'below'} predictions
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  )
}

