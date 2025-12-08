import { useState, useMemo } from 'react'
import { Target, Home, Car, GraduationCap, Heart, Plane, Briefcase, PiggyBank, Shield, Sparkles } from 'lucide-react'

type GoalCatalogItem = {
  goal_category: string
  goal_name: string
  default_horizon: string
  policy_linked_txn_type: string
  is_mandatory_flag: boolean
  suggested_min_amount_formula: string | null
  display_order: number
}

type Props = {
  catalog: GoalCatalogItem[]
  recommended: GoalCatalogItem[]
  onSelect: (goals: GoalCatalogItem[]) => void
  onBack: () => void
}

const GOAL_ICONS: Record<string, any> = {
  'Emergency Fund': Shield,
  'Home': Home,
  'Vehicle': Car,
  'Education': GraduationCap,
  'Health': Heart,
  'Travel': Plane,
  'Business': Briefcase,
  'Retirement': PiggyBank,
  'default': Target,
}

const getGoalIcon = (goalName: string) => {
  for (const [key, Icon] of Object.entries(GOAL_ICONS)) {
    if (goalName.toLowerCase().includes(key.toLowerCase())) {
      return Icon
    }
  }
  return GOAL_ICONS.default
}

export function GoalSelectionStep({ catalog, recommended, onSelect, onBack }: Props) {
  const [selected, setSelected] = useState<Set<string>>(new Set())
  const [filter, setFilter] = useState<'all' | 'short_term' | 'medium_term' | 'long_term'>('all')

  // Group goals by horizon
  const groupedGoals = useMemo(() => {
    const groups: Record<string, GoalCatalogItem[]> = {
      short_term: [],
      medium_term: [],
      long_term: [],
      other: [],
    }

    catalog.forEach((goal) => {
      const horizon = goal.default_horizon
      if (horizon in groups) {
        groups[horizon].push(goal)
      } else {
        groups.other.push(goal)
      }
    })

    return groups
  }, [catalog])

  const filteredGoals = useMemo(() => {
    if (filter === 'all') {
      return catalog
    }
    return catalog.filter((g) => g.default_horizon === filter)
  }, [catalog, filter])

  const toggleGoal = (goal: GoalCatalogItem) => {
    const key = `${goal.goal_category}:${goal.goal_name}`
    const newSelected = new Set(selected)
    if (newSelected.has(key)) {
      newSelected.delete(key)
    } else {
      newSelected.add(key)
    }
    setSelected(newSelected)
  }

  const handleSubmit = () => {
    const selectedGoals = catalog.filter(
      (g) => selected.has(`${g.goal_category}:${g.goal_name}`)
    )
    if (selectedGoals.length === 0) {
      alert('Please select at least one goal')
      return
    }
    onSelect(selectedGoals)
  }

  const selectRecommended = () => {
    const recommendedKeys = new Set(
      recommended.map((g) => `${g.goal_category}:${g.goal_name}`)
    )
    setSelected(recommendedKeys)
  }

  return (
    <div className="goal-selection-step">
      <h2>Select Your Financial Goals</h2>
      <p className="text-muted">Choose one or more goals that matter to you.</p>

      {recommended.length > 0 && (
        <div className="recommended-banner glass-card">
          <p>💡 Based on your profile, we recommend:</p>
          <button type="button" className="ghost-button" onClick={selectRecommended}>
            Select Recommended Goals
          </button>
        </div>
      )}

      <div className="filter-tabs">
        <button
          type="button"
          className={`filter-tab ${filter === 'all' ? 'filter-tab--active' : ''}`}
          onClick={() => setFilter('all')}
        >
          All
        </button>
        <button
          type="button"
          className={`filter-tab ${filter === 'short_term' ? 'filter-tab--active' : ''}`}
          onClick={() => setFilter('short_term')}
        >
          Short Term (0-2y)
        </button>
        <button
          type="button"
          className={`filter-tab ${filter === 'medium_term' ? 'filter-tab--active' : ''}`}
          onClick={() => setFilter('medium_term')}
        >
          Medium Term (2-5y)
        </button>
        <button
          type="button"
          className={`filter-tab ${filter === 'long_term' ? 'filter-tab--active' : ''}`}
          onClick={() => setFilter('long_term')}
        >
          Long Term (5y+)
        </button>
      </div>

      <div className="goals-grid">
        {filteredGoals.map((goal) => {
          const key = `${goal.goal_category}:${goal.goal_name}`
          const isSelected = selected.has(key)
          const isRecommended = recommended.some(
            (r) => r.goal_category === goal.goal_category && r.goal_name === goal.goal_name
          )

          return (
            <div
              key={key}
              className={`goal-card glass-card ${isSelected ? 'goal-card--selected' : ''} ${
                isRecommended ? 'goal-card--recommended' : ''
              }`}
              onClick={() => toggleGoal(goal)}
            >
              <div className="goal-card__header">
                <div className="goal-card__icon">
                  {(() => {
                    const GoalIcon = getGoalIcon(goal.goal_name)
                    return <GoalIcon size={24} />
                  })()}
                </div>
                <div className="goal-card__checkboxes">
                  {isRecommended && (
                    <span className="goal-card__badge goal-card__badge--recommended">
                      <Sparkles size={12} />
                      Recommended
                    </span>
                  )}
                  {goal.is_mandatory_flag && (
                    <span className="goal-card__badge goal-card__badge--essential">Essential</span>
                  )}
                </div>
                <input
                  type="checkbox"
                  checked={isSelected}
                  onChange={() => toggleGoal(goal)}
                  onClick={(e) => e.stopPropagation()}
                  className="goal-card__checkbox"
                />
              </div>
              <div className="goal-card__body">
                <h3>{goal.goal_name}</h3>
                <p className="goal-card__category">{goal.goal_category}</p>
                {goal.suggested_min_amount_formula && (
                  <p className="goal-card__hint text-muted">
                    💡 {goal.suggested_min_amount_formula}
                  </p>
                )}
              </div>
            </div>
          )
        })}
      </div>

      <div className="form-actions">
        <button type="button" className="ghost-button" onClick={onBack}>
          Back
        </button>
        <button type="button" className="primary-button" onClick={handleSubmit}>
          Continue ({selected.size} selected)
        </button>
      </div>
    </div>
  )
}

