import { useEffect, useRef, useState, useCallback } from 'react'
import { env } from '../env'

type WebSocketMessage = {
  type: string
  data: any
}

type UseWebSocketOptions = {
  url?: string
  enabled?: boolean
  onMessage?: (message: WebSocketMessage) => void
  onError?: (error: Event) => void
  onOpen?: () => void
  onClose?: () => void
  reconnect?: boolean
  reconnectInterval?: number
}

export function useWebSocket({
  url,
  enabled = true,
  onMessage,
  onError,
  onOpen,
  onClose,
  reconnect = true,
  reconnectInterval = 3000,
}: UseWebSocketOptions = {}) {
  const [isConnected, setIsConnected] = useState(false)
  const [lastMessage, setLastMessage] = useState<WebSocketMessage | null>(null)
  const wsRef = useRef<WebSocket | null>(null)
  const reconnectTimeoutRef = useRef<number | null>(null)
  const shouldReconnectRef = useRef(true)
  const retryCountRef = useRef(0)
  const maxRetriesRef = useRef(10) // Maximum retry attempts
  const lastFailureTimeRef = useRef<number | null>(null)
  const isConnectingRef = useRef(false)
  const lastUrlRef = useRef<string | undefined>(undefined) // Track URL changes to reset retries

  const connect = useCallback(() => {
    if (!enabled || !url) return

    // Prevent multiple simultaneous connection attempts
    if (isConnectingRef.current || (wsRef.current && wsRef.current.readyState === WebSocket.CONNECTING)) {
      return
    }

    // Close existing connection if any
    if (wsRef.current) {
      try {
        wsRef.current.close()
      } catch (e) {
        // Ignore errors when closing
      }
      wsRef.current = null
    }

    // Validate URL format
    if (!url.startsWith('ws://') && !url.startsWith('wss://') && !url.startsWith('http://') && !url.startsWith('https://')) {
      console.error('Invalid WebSocket URL format:', url)
      return
    }

    // Check if we've exceeded max retries
    if (retryCountRef.current >= maxRetriesRef.current) {
      console.warn('WebSocket: Maximum retry attempts reached. Stopping reconnection.')
      shouldReconnectRef.current = false
      return
    }

    // Exponential backoff: wait longer after each failure
    const backoffDelay = Math.min(reconnectInterval * Math.pow(2, retryCountRef.current), 30000) // Max 30 seconds
    
    // If we failed recently, wait before retrying
    if (lastFailureTimeRef.current) {
      const timeSinceFailure = Date.now() - lastFailureTimeRef.current
      if (timeSinceFailure < backoffDelay) {
        reconnectTimeoutRef.current = window.setTimeout(() => {
          connect()
        }, backoffDelay - timeSinceFailure)
        return
      }
    }

    try {
      isConnectingRef.current = true
      
      // URL should already be in ws:// or wss:// format
      // Only convert if it's still http/https
      const wsUrl = url.startsWith('ws://') || url.startsWith('wss://') 
        ? url 
        : url.replace(/^http/, 'ws')
      
      const ws = new WebSocket(wsUrl)
      
      ws.onopen = () => {
        isConnectingRef.current = false
        setIsConnected(true)
        shouldReconnectRef.current = true
        retryCountRef.current = 0 // Reset retry count on successful connection
        lastFailureTimeRef.current = null
        onOpen?.()
      }

      ws.onmessage = (event) => {
        try {
          const message = JSON.parse(event.data) as WebSocketMessage
          setLastMessage(message)
          onMessage?.(message)
        } catch (err) {
          console.error('Failed to parse WebSocket message:', err)
        }
      }

      ws.onerror = (error) => {
        console.error('WebSocket error:', error)
        lastFailureTimeRef.current = Date.now()
        onError?.(error)
      }

      ws.onclose = (event) => {
        isConnectingRef.current = false
        setIsConnected(false)
        lastFailureTimeRef.current = Date.now()
        onClose?.()
        
        // Don't reconnect for policy violations (auth failures) or normal closures
        if (event.code === 1008) {
          console.warn('WebSocket connection closed due to policy violation (likely authentication failure). Not reconnecting.')
          shouldReconnectRef.current = false
          retryCountRef.current = maxRetriesRef.current // Prevent further retries
          return
        }
        
        if (event.code === 1000) {
          // Normal closure
          shouldReconnectRef.current = false
          return
        }
        
        // Only reconnect if enabled and we haven't exceeded max retries
        if (shouldReconnectRef.current && reconnect && retryCountRef.current < maxRetriesRef.current) {
          retryCountRef.current++
          const backoffDelay = Math.min(reconnectInterval * Math.pow(2, retryCountRef.current - 1), 30000)
          reconnectTimeoutRef.current = window.setTimeout(() => {
            connect()
          }, backoffDelay)
        } else if (retryCountRef.current >= maxRetriesRef.current) {
          console.warn('WebSocket: Maximum retry attempts reached. Connection failed.')
        }
      }

      wsRef.current = ws
    } catch (error) {
      isConnectingRef.current = false
      console.error('WebSocket connection error:', error)
      lastFailureTimeRef.current = Date.now()
      retryCountRef.current++
      
      // Retry after error with backoff
      if (shouldReconnectRef.current && reconnect && retryCountRef.current < maxRetriesRef.current) {
        const backoffDelay = Math.min(reconnectInterval * Math.pow(2, retryCountRef.current - 1), 30000)
        reconnectTimeoutRef.current = window.setTimeout(() => {
          connect()
        }, backoffDelay)
      }
    }
  }, [url, enabled, onMessage, onError, onOpen, onClose, reconnect, reconnectInterval])

  const disconnect = useCallback(() => {
    shouldReconnectRef.current = false
    retryCountRef.current = 0
    lastFailureTimeRef.current = null
    if (reconnectTimeoutRef.current) {
      clearTimeout(reconnectTimeoutRef.current)
      reconnectTimeoutRef.current = null
    }
    if (wsRef.current) {
      wsRef.current.close()
      wsRef.current = null
    }
    setIsConnected(false)
  }, [])

  const sendMessage = useCallback((message: WebSocketMessage) => {
    if (wsRef.current?.readyState === WebSocket.OPEN) {
      wsRef.current.send(JSON.stringify(message))
    }
  }, [])

  useEffect(() => {
    // Reset retry count if URL changed (new token, etc.)
    if (url && url !== lastUrlRef.current) {
      retryCountRef.current = 0
      lastFailureTimeRef.current = null
      shouldReconnectRef.current = true
      lastUrlRef.current = url
    }

    // Only connect if enabled, URL is available, and we haven't exceeded max retries
    if (enabled && url && retryCountRef.current < maxRetriesRef.current) {
      connect()
    } else if (!enabled || !url) {
      disconnect()
    }

    return () => {
      // Cleanup on unmount or when dependencies change significantly
      if (!enabled || !url) {
        disconnect()
      }
    }
  }, [enabled, url]) // Removed connect/disconnect from dependencies to prevent infinite loops

  return {
    isConnected,
    lastMessage,
    sendMessage,
    connect,
    disconnect,
  }
}

