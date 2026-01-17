'use client'

interface SettingsRowProps {
  icon: string
  title: string
  subtitle: string
  onClick: () => void
}

export default function SettingsRow({ icon, title, subtitle, onClick }: SettingsRowProps) {
  return (
    <button
      onClick={onClick}
      className="w-full flex items-center gap-3 py-2 hover:opacity-80 transition-opacity"
    >
      <span className="text-[#D4AF37] text-lg flex-shrink-0 w-6 text-center">{icon}</span>
      <div className="flex-1 min-w-0 text-left">
        <p className="text-base font-medium text-white">{title}</p>
        <p className="text-sm text-gray-400">{subtitle}</p>
      </div>
      <svg
        className="w-4 h-4 text-gray-500 flex-shrink-0"
        fill="none"
        stroke="currentColor"
        viewBox="0 0 24 24"
      >
        <path
          strokeLinecap="round"
          strokeLinejoin="round"
          strokeWidth={2}
          d="M9 5l7 7-7 7"
        />
      </svg>
    </button>
  )
}
