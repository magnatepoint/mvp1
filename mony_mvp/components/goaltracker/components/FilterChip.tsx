'use client'

interface FilterChipProps {
  title: string
  isSelected: boolean
  action: () => void
}

export default function FilterChip({ title, isSelected, action }: FilterChipProps) {
  return (
    <button
      onClick={action}
      className={`px-4 py-2 rounded-lg font-medium transition-all whitespace-nowrap ${
        isSelected
          ? 'bg-[#D4AF37] text-black'
          : 'bg-white/10 text-gray-400 hover:text-white hover:bg-white/15'
      }`}
    >
      {title}
    </button>
  )
}
