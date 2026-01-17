'use client'

import { glassCardPrimary, glassCardSecondary } from '@/lib/theme/glass'

export function ChartSkeleton() {
  return (
    <div className={`${glassCardPrimary} p-6`}>
      <div className="h-8 w-48 bg-white/10 rounded mb-4 animate-pulse" />
      <div className="h-[300px] bg-white/5 rounded animate-pulse" />
    </div>
  )
}

export function MetricCardSkeleton() {
  return (
    <div className={`${glassCardPrimary} p-5`}>
      <div className="h-4 w-24 bg-white/10 rounded mb-3 animate-pulse" />
      <div className="h-8 w-32 bg-white/10 rounded mb-2 animate-pulse" />
      <div className="h-3 w-20 bg-white/10 rounded animate-pulse" />
    </div>
  )
}

export function ListItemSkeleton() {
  return (
    <div className={`${glassCardSecondary} p-4`}>
      <div className="flex items-center justify-between">
        <div className="flex-1">
          <div className="h-5 w-32 bg-white/10 rounded mb-2 animate-pulse" />
          <div className="h-4 w-24 bg-white/10 rounded animate-pulse" />
        </div>
        <div className="h-6 w-20 bg-white/10 rounded animate-pulse" />
      </div>
    </div>
  )
}
