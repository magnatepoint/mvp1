import { useEffect, useRef, useState } from 'react'
import type React from 'react'

interface UsePullToRefreshOptions {
  onRefresh: () => Promise<void> | void
  threshold?: number
  disabled?: boolean
}

export function usePullToRefresh({ onRefresh, threshold = 80, disabled = false }: UsePullToRefreshOptions) {
  const [isPulling, setIsPulling] = useState(false)
  const [pullDistance, setPullDistance] = useState(0)
  const [isRefreshing, setIsRefreshing] = useState(false)
  const startY = useRef<number>(0)
  const currentY = useRef<number>(0)
  const elementRef = useRef<HTMLElement | null>(null) as React.MutableRefObject<HTMLElement | null>

  useEffect(() => {
    if (disabled) return

    const element = elementRef.current
    if (!element) return

    const handleTouchStart = (e: TouchEvent) => {
      // Only trigger if at the top of the scrollable area
      if (element.scrollTop === 0) {
        startY.current = e.touches[0].clientY
        setIsPulling(true)
      }
    }

    const handleTouchMove = (e: TouchEvent) => {
      if (!isPulling) return

      currentY.current = e.touches[0].clientY
      const distance = Math.max(0, currentY.current - startY.current)

      if (distance > 0 && element.scrollTop === 0) {
        e.preventDefault()
        setPullDistance(distance)
      } else if (element.scrollTop > 0) {
        setIsPulling(false)
        setPullDistance(0)
      }
    }

    const handleTouchEnd = async () => {
      if (!isPulling) return

      if (pullDistance >= threshold) {
        setIsRefreshing(true)
        try {
          await onRefresh()
        } finally {
          setIsRefreshing(false)
        }
      }

      setIsPulling(false)
      setPullDistance(0)
    }

    // Mouse events for desktop (drag support)
    const handleMouseDown = (e: MouseEvent) => {
      if (element.scrollTop === 0) {
        startY.current = e.clientY
        setIsPulling(true)
      }
    }

    const handleMouseMove = (e: MouseEvent) => {
      if (!isPulling) return

      currentY.current = e.clientY
      const distance = Math.max(0, currentY.current - startY.current)

      if (distance > 0 && element.scrollTop === 0) {
        e.preventDefault()
        setPullDistance(distance)
      } else if (element.scrollTop > 0) {
        setIsPulling(false)
        setPullDistance(0)
      }
    }

    const handleMouseUp = async () => {
      if (!isPulling) return

      if (pullDistance >= threshold) {
        setIsRefreshing(true)
        try {
          await onRefresh()
        } finally {
          setIsRefreshing(false)
        }
      }

      setIsPulling(false)
      setPullDistance(0)
    }

    // Touch events
    element.addEventListener('touchstart', handleTouchStart, { passive: false })
    element.addEventListener('touchmove', handleTouchMove, { passive: false })
    element.addEventListener('touchend', handleTouchEnd)

    // Mouse events
    element.addEventListener('mousedown', handleMouseDown)
    element.addEventListener('mousemove', handleMouseMove)
    element.addEventListener('mouseup', handleMouseUp)
    element.addEventListener('mouseleave', handleMouseUp)

    return () => {
      element.removeEventListener('touchstart', handleTouchStart)
      element.removeEventListener('touchmove', handleTouchMove)
      element.removeEventListener('touchend', handleTouchEnd)
      element.removeEventListener('mousedown', handleMouseDown)
      element.removeEventListener('mousemove', handleMouseMove)
      element.removeEventListener('mouseup', handleMouseUp)
      element.removeEventListener('mouseleave', handleMouseUp)
    }
  }, [disabled, isPulling, pullDistance, threshold, onRefresh])

  const progress = Math.min(pullDistance / threshold, 1)

  return {
    elementRef,
    isPulling,
    isRefreshing,
    pullDistance,
    progress,
  }
}

