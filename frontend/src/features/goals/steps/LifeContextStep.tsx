import { useState } from 'react'
import type { LifeContextRequest } from '../../../types/goals'

type Props = {
  initialData: LifeContextRequest | null
  onSubmit: (context: LifeContextRequest) => void
  onSkip?: () => void
}

const INDIAN_STATES = [
  'IN-AP', 'IN-AR', 'IN-AS', 'IN-BR', 'IN-CT', 'IN-GA', 'IN-GJ', 'IN-HR',
  'IN-HP', 'IN-JK', 'IN-JH', 'IN-KA', 'IN-KL', 'IN-MP', 'IN-MH', 'IN-MN',
  'IN-ML', 'IN-MZ', 'IN-NL', 'IN-OR', 'IN-PB', 'IN-RJ', 'IN-SK', 'IN-TN',
  'IN-TG', 'IN-TR', 'IN-UP', 'IN-UT', 'IN-WB', 'IN-AN', 'IN-CH', 'IN-DH',
  'IN-DL', 'IN-LD', 'IN-PY',
]

export function LifeContextStep({ initialData, onSubmit, onSkip }: Props) {
  const [formData, setFormData] = useState<LifeContextRequest>({
    age_band: (initialData?.age_band as LifeContextRequest['age_band']) || '25-34',
    dependents_spouse: initialData?.dependents_spouse || false,
    dependents_children_count: initialData?.dependents_children_count || 0,
    dependents_parents_care: initialData?.dependents_parents_care || false,
    housing: (initialData?.housing as LifeContextRequest['housing']) || 'rent',
    employment: (initialData?.employment as LifeContextRequest['employment']) || 'salaried',
    income_regularity: (initialData?.income_regularity as LifeContextRequest['income_regularity']) || 'stable',
    region_code: initialData?.region_code || '',
    emergency_opt_out: initialData?.emergency_opt_out || false,
    monthly_investible_capacity: initialData?.monthly_investible_capacity ?? null,
    total_monthly_emi_obligations: initialData?.total_monthly_emi_obligations ?? null,
    risk_profile_overall: initialData?.risk_profile_overall ?? 'balanced',
    review_frequency: initialData?.review_frequency ?? 'quarterly',
    notify_on_drift: initialData?.notify_on_drift ?? true,
    auto_adjust_on_income_change: initialData?.auto_adjust_on_income_change ?? false,
  })

  const [errors, setErrors] = useState<Record<string, string>>({})

  const validate = (): boolean => {
    const newErrors: Record<string, string> = {}
    
    if (!formData.age_band) newErrors.age_band = 'Age band is required'
    if (!formData.housing) newErrors.housing = 'Housing status is required'
    if (!formData.employment) newErrors.employment = 'Employment type is required'
    if (!formData.income_regularity) newErrors.income_regularity = 'Income regularity is required'
    if (!formData.region_code) newErrors.region_code = 'Region is required'

    setErrors(newErrors)
    return Object.keys(newErrors).length === 0
  }

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    if (validate()) {
      onSubmit(formData)
    }
  }

  return (
    <form onSubmit={handleSubmit} className="life-context-form">
      <h2>Tell Us About Yourself</h2>
      <p className="text-muted">This helps us recommend the right goals for you.</p>

      <div className="form-group">
        <label htmlFor="age_band">Age Range *</label>
        <select
          id="age_band"
          className="input-field"
          value={formData.age_band}
          onChange={(e) => setFormData({ ...formData, age_band: e.target.value })}
        >
          <option value="">Select age range</option>
          <option value="18-24">18-24</option>
          <option value="25-34">25-34</option>
          <option value="35-44">35-44</option>
          <option value="45-54">45-54</option>
          <option value="55+">55+</option>
        </select>
        {errors.age_band && <div className="error-message">{errors.age_band}</div>}
      </div>

      <div className="form-group">
        <label htmlFor="housing">Housing Status *</label>
        <select
          id="housing"
          className="input-field"
          value={formData.housing}
          onChange={(e) => setFormData({ ...formData, housing: e.target.value as LifeContextRequest['housing'] })}
        >
          <option value="">Select housing status</option>
          <option value="rent">Renting</option>
          <option value="own_mortgage">Own with Mortgage</option>
          <option value="own_nomortgage">Own without Mortgage</option>
          <option value="living_with_parents">Living with Parents</option>
        </select>
        {errors.housing && <div className="error-message">{errors.housing}</div>}
      </div>

      <div className="form-group">
        <label htmlFor="employment">Employment Type *</label>
        <select
          id="employment"
          className="input-field"
          value={formData.employment}
          onChange={(e) => setFormData({ ...formData, employment: e.target.value })}
        >
          <option value="">Select employment type</option>
          <option value="salaried">Salaried</option>
          <option value="self_employed">Self Employed</option>
          <option value="student">Student</option>
          <option value="homemaker">Homemaker</option>
          <option value="retired">Retired</option>
        </select>
        {errors.employment && <div className="error-message">{errors.employment}</div>}
      </div>

      <div className="form-group">
        <label htmlFor="income_regularity">Income Stability *</label>
        <select
          id="income_regularity"
          className="input-field"
          value={formData.income_regularity}
          onChange={(e) => setFormData({ ...formData, income_regularity: e.target.value })}
        >
          <option value="">Select income stability</option>
          <option value="very_stable">Very Stable</option>
          <option value="stable">Stable</option>
          <option value="variable">Variable</option>
        </select>
        {errors.income_regularity && <div className="error-message">{errors.income_regularity}</div>}
      </div>

      <div className="form-group">
        <label htmlFor="region_code">Region *</label>
        <select
          id="region_code"
          className="input-field"
          value={formData.region_code}
          onChange={(e) => setFormData({ ...formData, region_code: e.target.value })}
        >
          <option value="">Select region</option>
          {INDIAN_STATES.map((state) => (
            <option key={state} value={state}>
              {state}
            </option>
          ))}
        </select>
        {errors.region_code && <div className="error-message">{errors.region_code}</div>}
      </div>

      <div className="form-group">
        <label className="checkbox-label">
          <input
            type="checkbox"
            checked={formData.dependents_spouse}
            onChange={(e) => setFormData({ ...formData, dependents_spouse: e.target.checked })}
          />
          <span>I have a spouse/partner</span>
        </label>
      </div>

      <div className="form-group">
        <label htmlFor="dependents_children_count">Number of Children</label>
        <input
          id="dependents_children_count"
          type="number"
          min="0"
          className="input-field"
          value={formData.dependents_children_count}
          onChange={(e) =>
            setFormData({ ...formData, dependents_children_count: parseInt(e.target.value) || 0 })
          }
        />
      </div>

      <div className="form-group">
        <label className="checkbox-label">
          <input
            type="checkbox"
            checked={formData.dependents_parents_care}
            onChange={(e) =>
              setFormData({ ...formData, dependents_parents_care: e.target.checked })
            }
          />
          <span>I care for my parents</span>
        </label>
      </div>

      <div className="form-group">
        <label htmlFor="monthly_investible_capacity">Monthly Investible Capacity (₹)</label>
        <input
          id="monthly_investible_capacity"
          type="number"
          min="0"
          step="1000"
          className="input-field"
          value={formData.monthly_investible_capacity ?? ''}
          onChange={(e) =>
            setFormData({
              ...formData,
              monthly_investible_capacity: e.target.value ? Number(e.target.value) : null,
            })
          }
          placeholder="Amount available for goals after expenses"
        />
        <small className="text-muted">Estimated monthly amount available for goals</small>
      </div>

      <div className="form-group">
        <label htmlFor="total_monthly_emi_obligations">Total Monthly EMIs (₹)</label>
        <input
          id="total_monthly_emi_obligations"
          type="number"
          min="0"
          step="1000"
          className="input-field"
          value={formData.total_monthly_emi_obligations ?? ''}
          onChange={(e) =>
            setFormData({
              ...formData,
              total_monthly_emi_obligations: e.target.value ? Number(e.target.value) : null,
            })
          }
          placeholder="Total EMIs per month"
        />
      </div>

      <div className="form-group">
        <label htmlFor="risk_profile_overall">Overall Risk Profile</label>
        <select
          id="risk_profile_overall"
          className="input-field"
          value={formData.risk_profile_overall ?? 'balanced'}
          onChange={(e) =>
            setFormData({
              ...formData,
              risk_profile_overall: e.target.value as LifeContextRequest['risk_profile_overall'],
            })
          }
        >
          <option value="conservative">Conservative</option>
          <option value="balanced">Balanced</option>
          <option value="aggressive">Aggressive</option>
        </select>
      </div>

      <div className="form-group">
        <label className="checkbox-label">
          <input
            type="checkbox"
            checked={formData.emergency_opt_out}
            onChange={(e) => setFormData({ ...formData, emergency_opt_out: e.target.checked })}
          />
          <span>Opt out of Emergency Fund goal</span>
        </label>
      </div>

      <div className="form-actions">
        {onSkip && (
          <button type="button" className="ghost-button" onClick={onSkip}>
            Skip
          </button>
        )}
        <button type="submit" className="primary-button">
          Continue
        </button>
      </div>
    </form>
  )
}

