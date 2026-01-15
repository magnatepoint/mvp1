'use client'

interface SpendSenseWelcomeBannerProps {
  username: string
}

export default function SpendSenseWelcomeBanner({ username }: SpendSenseWelcomeBannerProps) {
  const displayName = username.split('@')[0] || 'User'
  const capitalizedName = displayName.charAt(0).toUpperCase() + displayName.slice(1)

  return (
    <div className="mx-4 my-3">
      <div className="relative bg-gradient-to-br from-[#A0821A]/80 to-[#C9A030]/80 backdrop-blur-md rounded-2xl p-5 shadow-lg border border-white/20">
        <div className="flex items-center gap-4 relative z-10">
          {/* Chart Icon */}
          <div className="flex-shrink-0">
            <div className="w-12 h-12 rounded-full bg-white/20 flex items-center justify-center">
              <svg
                className="w-6 h-6 text-white"
                fill="currentColor"
                viewBox="0 0 24 24"
              >
                <path d="M3 13h8V3H3v10zm0 8h8v-6H3v6zm10 0h8V11h-8v10zm0-18v6h8V3h-8z" />
              </svg>
            </div>
          </div>

          {/* Text Content */}
          <div className="flex-1 min-w-0">
            <h2 className="text-base font-bold text-white mb-1">
              See where your money really goes.
            </h2>
            <p className="text-sm text-white/90 leading-snug line-clamp-2">
              Automatically categorized insights. Welcome back, {capitalizedName}!
            </p>
          </div>
        </div>
      </div>
    </div>
  )
}
