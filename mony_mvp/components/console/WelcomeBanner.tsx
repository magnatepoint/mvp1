'use client'

import Image from 'next/image'

interface WelcomeBannerProps {
  username: string
}

export default function WelcomeBanner({ username }: WelcomeBannerProps) {
  const displayName = username.split('@')[0] || 'User'

  return (
    <div className="relative overflow-hidden bg-gradient-to-r from-[#D4AF37]/20 to-[#D4AF37]/10 border-b border-[#D4AF37]/30 px-4 py-6">
      {/* Hanuman watermark */}
      <div className="absolute inset-0 flex items-center justify-end pointer-events-none">
        <Image
          src="/hanuman.png"
          alt=""
          width={120}
          height={160}
          className="object-contain opacity-[0.06] h-full max-h-[72px] w-auto"
          aria-hidden
        />
      </div>
      <div className="relative z-10 max-w-7xl mx-auto">
        <h1 className="text-2xl font-bold text-white">
          Welcome back, <span className="text-[#D4AF37]">{displayName}</span>!
        </h1>
        <p className="text-gray-400 text-sm mt-1">Here's your financial overview</p>
      </div>
    </div>
  )
}
