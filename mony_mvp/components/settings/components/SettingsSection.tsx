'use client'

import { glassCardPrimary } from '@/lib/theme/glass'

interface SettingsSectionProps {
  icon: string
  title: string
  children: React.ReactNode
}

export default function SettingsSection({ icon, title, children }: SettingsSectionProps) {
  return (
    <div className={`${glassCardPrimary} p-5 space-y-4`}>
      <div className="flex items-center gap-3">
        <span className="text-2xl">{icon}</span>
        <h2 className="text-xl font-bold text-white">{title}</h2>
      </div>
      <div className="h-px bg-white/10" />
      <div className="space-y-2">{children}</div>
    </div>
  )
}
