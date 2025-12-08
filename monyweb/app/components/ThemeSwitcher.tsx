'use client'

import { useEffect, useState } from 'react'
import './ThemeSwitcher.css'

type Theme = 'dark' | 'light' | 'auto'

export function ThemeSwitcher() {
  const [theme, setTheme] = useState<Theme>('dark')
  const [mounted, setMounted] = useState(false)

  useEffect(() => {
    setMounted(true)
    const saved = localStorage.getItem('theme') as Theme | null
    if (saved) {
      setTheme(saved)
      applyTheme(saved)
    } else {
      // Detect system preference
      const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches
      const initialTheme = prefersDark ? 'dark' : 'light'
      setTheme('auto')
      applyTheme(initialTheme)
    }
  }, [])

  useEffect(() => {
    if (!mounted) return
    
    const mediaQuery = window.matchMedia('(prefers-color-scheme: dark)')
    const handleChange = (e: MediaQueryListEvent) => {
      if (theme === 'auto') {
        applyTheme(e.matches ? 'dark' : 'light')
      }
    }
    
    mediaQuery.addEventListener('change', handleChange)
    return () => mediaQuery.removeEventListener('change', handleChange)
  }, [theme, mounted])

  const applyTheme = (themeToApply: 'dark' | 'light') => {
    document.documentElement.setAttribute('data-theme', themeToApply)
  }

  const handleThemeChange = (newTheme: Theme) => {
    setTheme(newTheme)
    localStorage.setItem('theme', newTheme)
    
    if (newTheme === 'auto') {
      const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches
      applyTheme(prefersDark ? 'dark' : 'light')
    } else {
      applyTheme(newTheme)
    }
  }

  if (!mounted) return null

  return (
    <div className="theme-switcher">
      <button
        className={`theme-switcher__button ${theme === 'light' ? 'is-active' : ''}`}
        onClick={() => handleThemeChange('light')}
        aria-label="Light theme"
        title="Light theme"
      >
        ☀️
      </button>
      <button
        className={`theme-switcher__button ${theme === 'dark' ? 'is-active' : ''}`}
        onClick={() => handleThemeChange('dark')}
        aria-label="Dark theme"
        title="Dark theme"
      >
        🌙
      </button>
      <button
        className={`theme-switcher__button ${theme === 'auto' ? 'is-active' : ''}`}
        onClick={() => handleThemeChange('auto')}
        aria-label="Auto theme (follow system)"
        title="Auto theme (follow system)"
      >
        🔄
      </button>
    </div>
  )
}

