'use client'

interface NavigationItemProps {
  icon: React.ReactNode
  label: string
  isActive: boolean
  onClick: () => void
  badge?: number | string
  showLabel?: boolean // For responsive label display
}

export default function NavigationItem({
  icon,
  label,
  isActive,
  onClick,
  badge,
  showLabel = true,
}: NavigationItemProps) {
  return (
    <button
      onClick={onClick}
      className={`flex flex-col items-center justify-center gap-1 px-2 py-2 rounded-lg transition-all relative min-w-0 flex-1 ${
        isActive
          ? 'text-[#D4AF37]'
          : 'text-gray-400 hover:text-white'
      }`}
      aria-label={label}
      aria-current={isActive ? 'page' : undefined}
    >
      <div className="relative flex-shrink-0">
        <div className={`${isActive ? 'text-[#D4AF37]' : 'text-current'}`}>{icon}</div>
        {badge !== undefined && (
          <span className="absolute -top-1 -right-1 min-w-[18px] h-[18px] px-1 rounded-full bg-red-500 text-white text-[10px] font-bold flex items-center justify-center">
            {badge}
          </span>
        )}
      </div>
      {showLabel && (
        <span
          className={`text-[10px] font-medium leading-tight text-center truncate w-full ${
            isActive ? 'text-[#D4AF37]' : 'text-current'
          }`}
        >
          {label}
        </span>
      )}
    </button>
  )
}
