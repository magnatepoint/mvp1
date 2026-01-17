import { useState, useEffect } from 'react'

/**
 * Custom hook to detect screen size breakpoints
 * @param breakpoint - Breakpoint in pixels (default: 768px for tablet/desktop)
 * @returns boolean - true if screen width >= breakpoint (desktop), false otherwise (mobile)
 */
export function useMediaQuery(breakpoint: number = 768): boolean {
  const [isDesktop, setIsDesktop] = useState(false)

  useEffect(() => {
    // Check if window is available (SSR safety)
    if (typeof window === 'undefined') {
      return
    }

    const mediaQuery = window.matchMedia(`(min-width: ${breakpoint}px)`)

    // Set initial value
    setIsDesktop(mediaQuery.matches)

    // Create event listener
    const handleChange = (event: MediaQueryListEvent | MediaQueryList) => {
      setIsDesktop(event.matches)
    }

    // Add listener (using modern API if available, fallback to addListener)
    if (mediaQuery.addEventListener) {
      mediaQuery.addEventListener('change', handleChange)
    } else {
      // Fallback for older browsers
      mediaQuery.addListener(handleChange as any)
    }

    // Cleanup
    return () => {
      if (mediaQuery.removeEventListener) {
        mediaQuery.removeEventListener('change', handleChange)
      } else {
        // Fallback for older browsers
        mediaQuery.removeListener(handleChange as any)
      }
    }
  }, [breakpoint])

  return isDesktop
}
