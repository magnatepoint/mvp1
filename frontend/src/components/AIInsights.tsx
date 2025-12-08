import { TrendingUp, TrendingDown, AlertCircle, Lightbulb, Sparkles } from 'lucide-react'
import './AIInsights.css'

type Insight = {
  type: 'spending' | 'trend' | 'alert' | 'tip'
  title: string
  description: string
  value?: string
  trend?: 'up' | 'down'
  priority?: 'high' | 'medium' | 'low'
}

type AIInsightsProps = {
  insights?: Insight[]
  loading?: boolean
}

const defaultInsights: Insight[] = [
  {
    type: 'trend',
    title: 'Spending Trend',
    description: 'You spent 23% more on dining this month compared to last month',
    value: '+23%',
    trend: 'up',
    priority: 'medium',
  },
  {
    type: 'alert',
    title: 'Unusual Spending',
    description: 'Detected ₹5,000 transaction at Electronics Store - higher than usual',
    priority: 'high',
  },
  {
    type: 'spending',
    title: 'Savings Progress',
    description: 'You\'re on track to save ₹50K this month based on current spending patterns',
    value: '₹50K',
    trend: 'up',
    priority: 'low',
  },
  {
    type: 'tip',
    title: 'Smart Tip',
    description: 'Consider setting a monthly budget for "Food & Dining" to better track expenses',
    priority: 'low',
  },
]

export function AIInsights({ insights = defaultInsights, loading = false }: AIInsightsProps) {
  if (loading) {
    return (
      <div className="ai-insights">
        <div className="ai-insights__header">
          <div className="ai-insights__title">
            <Sparkles size={20} />
            <h3>AI Insights</h3>
          </div>
        </div>
        <div className="ai-insights__list">
          {Array.from({ length: 3 }).map((_, i) => (
            <div key={i} className="ai-insight ai-insight--loading">
              <div className="ai-insight__icon" />
              <div className="ai-insight__content">
                <div className="ai-insight__title" style={{ width: '60%', height: '16px', marginBottom: '8px' }} />
                <div className="ai-insight__description" style={{ width: '100%', height: '14px' }} />
              </div>
            </div>
          ))}
        </div>
      </div>
    )
  }

  const getIcon = (type: Insight['type'], trend?: 'up' | 'down') => {
    switch (type) {
      case 'trend':
        return trend === 'up' ? <TrendingUp size={18} /> : <TrendingDown size={18} />
      case 'alert':
        return <AlertCircle size={18} />
      case 'tip':
        return <Lightbulb size={18} />
      default:
        return <Sparkles size={18} />
    }
  }

  const getPriorityClass = (priority?: Insight['priority']) => {
    switch (priority) {
      case 'high':
        return 'ai-insight--high'
      case 'medium':
        return 'ai-insight--medium'
      default:
        return 'ai-insight--low'
    }
  }

  return (
    <div className="ai-insights">
      <div className="ai-insights__header">
        <div className="ai-insights__title">
          <Sparkles size={20} />
          <h3>AI Insights</h3>
        </div>
        <span className="ai-insights__badge">{insights.length} insights</span>
      </div>
      <div className="ai-insights__list">
        {insights.map((insight, index) => (
          <div
            key={index}
            className={`ai-insight ${getPriorityClass(insight.priority)}`}
          >
            <div className={`ai-insight__icon ai-insight__icon--${insight.type}`}>
              {getIcon(insight.type, insight.trend)}
            </div>
            <div className="ai-insight__content">
              <div className="ai-insight__header">
                <h4 className="ai-insight__title">{insight.title}</h4>
                {insight.value && (
                  <span className={`ai-insight__value ai-insight__value--${insight.trend || 'neutral'}`}>
                    {insight.value}
                  </span>
                )}
              </div>
              <p className="ai-insight__description">{insight.description}</p>
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}

