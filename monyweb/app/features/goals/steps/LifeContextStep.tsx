'use client'

import { useState, useEffect } from 'react'

type LifeContext = {
  age_band: string
  dependents_spouse: boolean
  dependents_children_count: number
  dependents_parents_care: boolean
  housing: string
  employment: string
  income_regularity: string
  region_code: string
  emergency_opt_out: boolean
}

type Props = {
  initialData: LifeContext | null
  onSubmit: (context: LifeContext) => void
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
  const [formData, setFormData] = useState<LifeContext>({
    age_band: initialData?.age_band || '',
    dependents_spouse: initialData?.dependents_spouse || false,
    dependents_children_count: initialData?.dependents_children_count || 0,
    dependents_parents_care: initialData?.dependents_parents_care || false,
    housing: initialData?.housing || '',
    employment: initialData?.employment || '',
    income_regularity: initialData?.income_regularity || '',
    region_code: initialData?.region_code || '',
    emergency_opt_out: initialData?.emergency_opt_out || false,
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
          onChange={(e) => setFormData({ ...formData, housing: e.target.value })}
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

