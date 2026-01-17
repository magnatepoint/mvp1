'use client'

import { useState, useEffect } from 'react'
import type { Session } from '@supabase/supabase-js'
import type { LifeContextRequest } from '@/types/goals'
import { INDIAN_STATES } from '@/types/goals'
import { glassFilter } from '@/lib/theme/glass'

interface LifeContextStepProps {
  session: Session
  initialContext: LifeContextRequest | null
  onNext: (context: LifeContextRequest) => void
  onClose: () => void
}

export default function LifeContextStep({
  session,
  initialContext,
  onNext,
  onClose,
}: LifeContextStepProps) {
  const [formData, setFormData] = useState<LifeContextRequest>({
    age_band: initialContext?.age_band || '',
    dependents_spouse: initialContext?.dependents_spouse || false,
    dependents_children_count: initialContext?.dependents_children_count || 0,
    dependents_parents_care: initialContext?.dependents_parents_care || false,
    housing: initialContext?.housing || '',
    employment: initialContext?.employment || '',
    income_regularity: initialContext?.income_regularity || '',
    region_code: initialContext?.region_code || '',
    emergency_opt_out: initialContext?.emergency_opt_out || false,
    monthly_investible_capacity: initialContext?.monthly_investible_capacity || null,
    total_monthly_emi_obligations: initialContext?.total_monthly_emi_obligations || null,
    risk_profile_overall: initialContext?.risk_profile_overall || null,
    review_frequency: initialContext?.review_frequency || 'quarterly',
    notify_on_drift: initialContext?.notify_on_drift ?? true,
    auto_adjust_on_income_change: initialContext?.auto_adjust_on_income_change || false,
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
      onNext(formData)
    }
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      <div className="mb-6">
        <h2 className="text-2xl font-bold text-white mb-2">Life Context</h2>
        <p className="text-sm text-gray-400">
          Help us understand your financial situation to recommend the best goals for you.
        </p>
      </div>

      <div className="space-y-4 max-h-[60vh] overflow-y-auto pr-2">
        {/* Age Band */}
        <div>
          <label className="block text-sm font-medium text-white mb-2">Age Band *</label>
          <select
            value={formData.age_band}
            onChange={(e) => setFormData({ ...formData, age_band: e.target.value })}
            className={`w-full ${glassFilter} px-4 py-3 rounded-lg text-white`}
          >
            <option value="">Select age band</option>
            <option value="18-24">18-24</option>
            <option value="25-34">25-34</option>
            <option value="35-44">35-44</option>
            <option value="45-54">45-54</option>
            <option value="55+">55+</option>
          </select>
          {errors.age_band && <p className="text-red-400 text-xs mt-1">{errors.age_band}</p>}
        </div>

        {/* Dependents */}
        <div className="space-y-3">
          <label className="block text-sm font-medium text-white mb-2">Dependents</label>
          <label className="flex items-center gap-2">
            <input
              type="checkbox"
              checked={formData.dependents_spouse}
              onChange={(e) =>
                setFormData({ ...formData, dependents_spouse: e.target.checked })
              }
              className="w-4 h-4 rounded"
            />
            <span className="text-sm text-gray-300">Spouse/Partner</span>
          </label>
          <div>
            <label className="block text-sm text-gray-300 mb-1">Number of Children</label>
            <input
              type="number"
              min="0"
              value={formData.dependents_children_count}
              onChange={(e) =>
                setFormData({
                  ...formData,
                  dependents_children_count: parseInt(e.target.value) || 0,
                })
              }
              className={`w-full ${glassFilter} px-4 py-2 rounded-lg text-white`}
            />
          </div>
          <label className="flex items-center gap-2">
            <input
              type="checkbox"
              checked={formData.dependents_parents_care}
              onChange={(e) =>
                setFormData({ ...formData, dependents_parents_care: e.target.checked })
              }
              className="w-4 h-4 rounded"
            />
            <span className="text-sm text-gray-300">Caring for Parents</span>
          </label>
        </div>

        {/* Housing */}
        <div>
          <label className="block text-sm font-medium text-white mb-2">Housing Status *</label>
          <select
            value={formData.housing}
            onChange={(e) => setFormData({ ...formData, housing: e.target.value })}
            className={`w-full ${glassFilter} px-4 py-3 rounded-lg text-white`}
          >
            <option value="">Select housing status</option>
            <option value="rent">Rent</option>
            <option value="own_mortgage">Own with Mortgage</option>
            <option value="own_nomortgage">Own without Mortgage</option>
            <option value="living_with_parents">Living with Parents</option>
          </select>
          {errors.housing && <p className="text-red-400 text-xs mt-1">{errors.housing}</p>}
        </div>

        {/* Employment */}
        <div>
          <label className="block text-sm font-medium text-white mb-2">Employment Type *</label>
          <select
            value={formData.employment}
            onChange={(e) => setFormData({ ...formData, employment: e.target.value })}
            className={`w-full ${glassFilter} px-4 py-3 rounded-lg text-white`}
          >
            <option value="">Select employment type</option>
            <option value="salaried">Salaried</option>
            <option value="self_employed">Self Employed</option>
            <option value="student">Student</option>
            <option value="homemaker">Homemaker</option>
            <option value="retired">Retired</option>
          </select>
          {errors.employment && <p className="text-red-400 text-xs mt-1">{errors.employment}</p>}
        </div>

        {/* Income Regularity */}
        <div>
          <label className="block text-sm font-medium text-white mb-2">Income Regularity *</label>
          <select
            value={formData.income_regularity}
            onChange={(e) => setFormData({ ...formData, income_regularity: e.target.value })}
            className={`w-full ${glassFilter} px-4 py-3 rounded-lg text-white`}
          >
            <option value="">Select income regularity</option>
            <option value="very_stable">Very Stable</option>
            <option value="stable">Stable</option>
            <option value="variable">Variable</option>
          </select>
          {errors.income_regularity && (
            <p className="text-red-400 text-xs mt-1">{errors.income_regularity}</p>
          )}
        </div>

        {/* Region Code */}
        <div>
          <label className="block text-sm font-medium text-white mb-2">Region *</label>
          <select
            value={formData.region_code}
            onChange={(e) => setFormData({ ...formData, region_code: e.target.value })}
            className={`w-full ${glassFilter} px-4 py-3 rounded-lg text-white`}
          >
            <option value="">Select region</option>
            {INDIAN_STATES.map((state) => (
              <option key={state.code} value={state.code}>
                {state.name}
              </option>
            ))}
          </select>
          {errors.region_code && <p className="text-red-400 text-xs mt-1">{errors.region_code}</p>}
        </div>

        {/* Emergency Opt Out */}
        <label className="flex items-center gap-2">
          <input
            type="checkbox"
            checked={formData.emergency_opt_out}
            onChange={(e) => setFormData({ ...formData, emergency_opt_out: e.target.checked })}
            className="w-4 h-4 rounded"
          />
          <span className="text-sm text-gray-300">Opt out of emergency fund goal</span>
        </label>

        {/* Monthly Investible Capacity */}
        <div>
          <label className="block text-sm font-medium text-white mb-2">
            Monthly Investible Capacity (₹) <span className="text-gray-400">(Optional)</span>
          </label>
          <input
            type="number"
            min="0"
            step="1000"
            value={formData.monthly_investible_capacity || ''}
            onChange={(e) =>
              setFormData({
                ...formData,
                monthly_investible_capacity: e.target.value ? parseFloat(e.target.value) : null,
              })
            }
            className={`w-full ${glassFilter} px-4 py-2 rounded-lg text-white`}
            placeholder="Enter amount"
          />
        </div>

        {/* Total Monthly EMI Obligations */}
        <div>
          <label className="block text-sm font-medium text-white mb-2">
            Total Monthly EMI Obligations (₹) <span className="text-gray-400">(Optional)</span>
          </label>
          <input
            type="number"
            min="0"
            step="1000"
            value={formData.total_monthly_emi_obligations || ''}
            onChange={(e) =>
              setFormData({
                ...formData,
                total_monthly_emi_obligations: e.target.value ? parseFloat(e.target.value) : null,
              })
            }
            className={`w-full ${glassFilter} px-4 py-2 rounded-lg text-white`}
            placeholder="Enter amount"
          />
        </div>

        {/* Risk Profile */}
        <div>
          <label className="block text-sm font-medium text-white mb-2">
            Risk Profile <span className="text-gray-400">(Optional)</span>
          </label>
          <select
            value={formData.risk_profile_overall || ''}
            onChange={(e) =>
              setFormData({
                ...formData,
                risk_profile_overall: e.target.value as 'conservative' | 'balanced' | 'aggressive' | null,
              })
            }
            className={`w-full ${glassFilter} px-4 py-3 rounded-lg text-white`}
          >
            <option value="">Select risk profile</option>
            <option value="conservative">Conservative</option>
            <option value="balanced">Balanced</option>
            <option value="aggressive">Aggressive</option>
          </select>
        </div>

        {/* Review Frequency */}
        <div>
          <label className="block text-sm font-medium text-white mb-2">
            Review Frequency <span className="text-gray-400">(Optional)</span>
          </label>
          <select
            value={formData.review_frequency || 'quarterly'}
            onChange={(e) =>
              setFormData({
                ...formData,
                review_frequency: e.target.value as 'monthly' | 'quarterly' | 'yearly',
              })
            }
            className={`w-full ${glassFilter} px-4 py-3 rounded-lg text-white`}
          >
            <option value="monthly">Monthly</option>
            <option value="quarterly">Quarterly</option>
            <option value="yearly">Yearly</option>
          </select>
        </div>

        {/* Notify on Drift */}
        <label className="flex items-center gap-2">
          <input
            type="checkbox"
            checked={formData.notify_on_drift ?? true}
            onChange={(e) => setFormData({ ...formData, notify_on_drift: e.target.checked })}
            className="w-4 h-4 rounded"
          />
          <span className="text-sm text-gray-300">Notify on drift</span>
        </label>

        {/* Auto Adjust on Income Change */}
        <label className="flex items-center gap-2">
          <input
            type="checkbox"
            checked={formData.auto_adjust_on_income_change || false}
            onChange={(e) =>
              setFormData({ ...formData, auto_adjust_on_income_change: e.target.checked })
            }
            className="w-4 h-4 rounded"
          />
          <span className="text-sm text-gray-300">Auto-adjust on income change</span>
        </label>
      </div>

      {/* Navigation Buttons */}
      <div className="flex gap-3 pt-4 border-t border-white/10">
        <button
          type="button"
          onClick={onClose}
          className="flex-1 px-4 py-3 rounded-lg bg-white/5 border border-white/10 hover:bg-white/10 transition-colors text-white"
        >
          Cancel
        </button>
        <button
          type="submit"
          className="flex-1 px-4 py-3 rounded-lg bg-[#D4AF37] text-black font-medium hover:bg-[#D4AF37]/90 transition-colors"
        >
          Next
        </button>
      </div>
    </form>
  )
}
