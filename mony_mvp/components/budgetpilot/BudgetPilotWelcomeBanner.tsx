'use client'

interface BudgetPilotWelcomeBannerProps {
  username?: string | null
}

export default function BudgetPilotWelcomeBanner({ username }: BudgetPilotWelcomeBannerProps) {
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
        {/* Airplane Icon */}
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
              d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8"
            />
          </svg>
        </div>

        {/* Text Content */}
        <div className="flex-1 min-w-0">
          <p className="text-base font-bold text-white leading-tight">
            Smart budget recommendations tailored to your spending patterns and goals.
          </p>
          <p className="text-sm text-white/90 mt-1">Welcome back, {displayName}!</p>
        </div>
      </div>
    </div>
  )
}
