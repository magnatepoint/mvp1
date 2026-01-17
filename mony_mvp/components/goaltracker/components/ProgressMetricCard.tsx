'use client'

interface ProgressMetricCardProps {
  icon: string
  value: string
  label: string
  color: string
}

export default function ProgressMetricCard({
  icon,
  value,
  label,
  color,
}: ProgressMetricCardProps) {
  return (
    <div
      className="flex-1 rounded-xl p-4 backdrop-blur-sm border border-white/20"
      style={{ backgroundColor: `${color}20` }}
    >
      <div className="flex items-center gap-3">
        <div
          className="w-10 h-10 rounded-lg flex items-center justify-center"
          style={{ backgroundColor: color }}
        >
          <span className="text-xl">{icon}</span>
        </div>
        <div className="flex-1 min-w-0">
          <p className="text-2xl font-bold text-white">{value}</p>
          <p className="text-sm text-gray-300 mt-1">{label}</p>
        </div>
      </div>
    </div>
  )
}
