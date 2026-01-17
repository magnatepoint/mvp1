'use client'

import { useState } from 'react'

export type DateRangePreset = '30d' | '3m' | '6m' | '1y' | 'custom'

export interface DateRange {
  startDate: string | null
  endDate: string | null
  preset: DateRangePreset
}

interface DateRangeSelectorProps {
  value: DateRange
  onChange: (range: DateRange) => void
}

export default function DateRangeSelector({ value, onChange }: DateRangeSelectorProps) {
  const [showCustom, setShowCustom] = useState(value.preset === 'custom')

  const applyPreset = (preset: DateRangePreset) => {
    // Handle custom preset separately
    if (preset === 'custom') {
      setShowCustom(true)
      return
    }

    const today = new Date()
    let startDate: Date

    switch (preset) {
      case '30d':
        startDate = new Date(today)
        startDate.setDate(today.getDate() - 30)
        break
      case '3m':
        startDate = new Date(today)
        startDate.setMonth(today.getMonth() - 3)
        break
      case '6m':
        startDate = new Date(today)
        startDate.setMonth(today.getMonth() - 6)
        break
      case '1y':
        startDate = new Date(today)
        startDate.setFullYear(today.getFullYear() - 1)
        break
      default:
        return
    }

    onChange({
      startDate: startDate.toISOString().split('T')[0],
      endDate: today.toISOString().split('T')[0],
      preset,
    })
    setShowCustom(false)
  }

  const handleCustomDates = () => {
    if (value.startDate && value.endDate) {
      onChange({ ...value, preset: 'custom' })
    }
  }

  const formatDateRange = () => {
    if (!value.startDate || !value.endDate) return 'Select date range'
    const start = new Date(value.startDate).toLocaleDateString('en-IN', { month: 'short', day: 'numeric' })
    const end = new Date(value.endDate).toLocaleDateString('en-IN', { month: 'short', day: 'numeric', year: 'numeric' })
    return `${start} - ${end}`
  }

  return (
    <div className="flex flex-col sm:flex-row gap-3 items-start sm:items-center">
      <div className="flex gap-2 flex-wrap">
        {(['30d', '3m', '6m', '1y'] as DateRangePreset[]).map((preset) => (
          <button
            key={preset}
            onClick={() => applyPreset(preset)}
            className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors ${
              value.preset === preset
                ? 'bg-[#D4AF37] text-black'
                : 'bg-white/5 hover:bg-white/10 text-white border border-white/10'
            }`}
          >
            {preset === '30d' ? '30 Days' : preset === '3m' ? '3 Months' : preset === '6m' ? '6 Months' : '1 Year'}
          </button>
        ))}
        <button
          onClick={() => setShowCustom(!showCustom)}
          className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors ${
            showCustom || value.preset === 'custom'
              ? 'bg-[#D4AF37] text-black'
              : 'bg-white/5 hover:bg-white/10 text-white border border-white/10'
          }`}
        >
          Custom
        </button>
      </div>

      {showCustom && (
        <div className="flex gap-2 items-center">
          <input
            type="date"
            value={value.startDate || ''}
            onChange={(e) => onChange({ ...value, startDate: e.target.value, preset: 'custom' })}
            className="px-3 py-2 bg-white/5 border border-white/10 rounded-lg text-white text-sm"
          />
          <span className="text-gray-400">to</span>
          <input
            type="date"
            value={value.endDate || ''}
            onChange={(e) => onChange({ ...value, endDate: e.target.value, preset: 'custom' })}
            max={new Date().toISOString().split('T')[0]}
            className="px-3 py-2 bg-white/5 border border-white/10 rounded-lg text-white text-sm"
          />
        </div>
      )}

      {value.preset !== 'custom' && (
        <span className="text-sm text-gray-400">{formatDateRange()}</span>
      )}
    </div>
  )
}
