'use client'

interface GoalTrackerWelcomeBannerProps {
  username?: string | null
}

export default function GoalTrackerWelcomeBanner({ username }: GoalTrackerWelcomeBannerProps) {
  const displayName = username
    ? username.split('@')[0].charAt(0).toUpperCase() + username.split('@')[0].slice(1)
    : 'User'

  return (
    <div className="mx-4 my-3">
      <div
        className="flex items-center gap-4 p-4 rounded-2xl shadow-lg"
        style={{
          background: 'linear-gradient(to right, #FFD700, #8B5CF6)',
        }}
      >
        {/* Flag Icon */}
        <div className="flex-shrink-0 w-12 h-12 rounded-full bg-white/20 flex items-center justify-center">
          <svg
            className="w-6 h-6 text-white"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M3 21v-4m0 0V5a2 2 0 012-2h6.5l1 1H21l-3 6 3 6h-8.5l-1-1H5a2 2 0 00-2 2zm9-13.5V9"
            />
          </svg>
        </div>

        {/* Text Content */}
        <div className="flex-1 min-w-0">
          <p className="text-base font-bold text-white leading-tight">
            Turn dreams into reality. Smart goal tracking and AI insights.
          </p>
          <p className="text-sm text-white/90 mt-1">Welcome back, {displayName}!</p>
        </div>
      </div>
    </div>
  )
}
