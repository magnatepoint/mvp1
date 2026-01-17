'use client'

interface MoneyMomentsWelcomeBannerProps {
  username?: string | null
}

export default function MoneyMomentsWelcomeBanner({ username }: MoneyMomentsWelcomeBannerProps) {
  const displayName = username
    ? username.split('@')[0].charAt(0).toUpperCase() + username.split('@')[0].slice(1)
    : 'User'

  return (
    <div className="mx-4 my-3">
      <div
        className="flex items-center gap-4 p-4 rounded-2xl shadow-lg"
        style={{
          background: 'linear-gradient(to right, #FFD700, #FFA500)',
        }}
      >
        {/* Bell Icon */}
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
              d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9"
            />
          </svg>
        </div>

        {/* Text Content */}
        <div className="flex-1 min-w-0">
          <p className="text-base font-bold text-white leading-tight">
            Gentle reminders for smarter habits.
          </p>
          <p className="text-sm text-white/90 mt-1">
            Smart nudges and personalized prompts. Welcome back, {displayName}!
          </p>
        </div>
      </div>
    </div>
  )
}
