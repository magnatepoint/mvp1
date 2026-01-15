/* eslint-disable react-refresh/only-export-components */

import type { PropsWithChildren } from 'react'
import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
} from 'react'
import type { AuthError, Session, User } from '@supabase/supabase-js'
import { supabase } from '../supabaseClient'
import { env } from '../../env'

type AuthContextValue = {
  user: User | null
  session: Session | null
  loading: boolean
  signIn: (email: string, password: string) => Promise<AuthError | null>
  signUp: (email: string, password: string) => Promise<AuthError | null>
  signInWithGoogle: () => Promise<AuthError | null>
  signOut: () => Promise<AuthError | null>
}

const AuthContext = createContext<AuthContextValue | undefined>(undefined)

export function AuthProvider({ children }: PropsWithChildren) {
  const [session, setSession] = useState<Session | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const handleOAuthCallback = async () => {
      const url = new URL(window.location.href)
      const code = url.searchParams.get('code')
      const errorDescription = url.searchParams.get('error_description')
      const error = url.searchParams.get('error')

      // Check for OAuth errors first
      if (error || errorDescription) {
        const errorMsg = errorDescription 
          ? decodeURIComponent(errorDescription) 
          : error || 'OAuth authentication failed'
        console.error('Supabase OAuth error:', errorMsg)
        // Clear error params from URL
        window.history.replaceState({}, document.title, window.location.pathname)
        return
      }

      if (code) {
        try {
          const { data, error: exchangeError } = await supabase.auth.exchangeCodeForSession(code)
          if (exchangeError) {
            console.error('Failed to exchange OAuth code for session', exchangeError)
            // Clear any invalid session data
            await supabase.auth.signOut()
            setSession(null)
            // Clear code from URL even on error
            window.history.replaceState({}, document.title, window.location.pathname)
          } else {
            // Session successfully set, update state immediately
            if (data.session) {
              setSession(data.session)
            }
            // Clear code from URL on success
            window.history.replaceState({}, document.title, window.location.pathname)
          }
        } catch (err) {
          console.error('Unexpected error during OAuth callback:', err)
          await supabase.auth.signOut()
          setSession(null)
          window.history.replaceState({}, document.title, window.location.pathname)
        }
        return
      }

      // Handle implicit flow (#access_token=...) in case PKCE is disabled
      if (window.location.hash.includes('access_token')) {
        const hashParams = new URLSearchParams(window.location.hash.substring(1))
        const accessToken = hashParams.get('access_token')
        const refreshToken = hashParams.get('refresh_token')

        if (accessToken && refreshToken) {
          const { error: sessionError } = await supabase.auth.setSession({
            access_token: accessToken,
            refresh_token: refreshToken,
          })
          if (sessionError) {
            console.error('Failed to set session from hash tokens', sessionError)
          } else {
            // Clear hash from URL on success
            window.history.replaceState({}, document.title, window.location.pathname)
          }
        }
      }
    }

    void handleOAuthCallback()

    const loadSession = async () => {
      try {
        const { data, error } = await supabase.auth.getSession()
        
        // If there's an error with refresh token, clear the session
        if (error) {
          // Check if it's a refresh token error
          if (error.message?.includes('Refresh Token') || error.message?.includes('refresh_token')) {
            console.warn('Invalid refresh token, clearing session:', error.message)
            // Clear the invalid session
            await supabase.auth.signOut()
            setSession(null)
          } else {
            console.error('Error loading session:', error)
            setSession(null)
          }
        } else {
          setSession(data.session)
        }
      } catch (err) {
        console.error('Unexpected error loading session:', err)
        setSession(null)
      } finally {
        setLoading(false)
      }
    }

    void loadSession()

    const { data: listener } = supabase.auth.onAuthStateChange((event, newSession) => {
      // Handle token refresh errors
      if (event === 'TOKEN_REFRESHED' && !newSession) {
        // Token refresh failed, clear session
        console.warn('Token refresh failed, clearing session')
        setSession(null)
        return
      }
      
      // Handle signed out events
      if (event === 'SIGNED_OUT') {
        setSession(null)
        return
      }
      
      setSession(newSession)
    })

    return () => {
      listener.subscription.unsubscribe()
    }
  }, [])

  const signIn = useCallback(async (email: string, password: string) => {
    try {
      const { data, error } = await supabase.auth.signInWithPassword({ email, password })
      if (error) {
        console.error('Sign-in error:', {
          message: error.message,
          status: error.status,
          name: error.name,
        })
        return error
      }
      // Update session immediately on successful sign-in
      if (data.session) {
        setSession(data.session)
      }
      return null
    } catch (err) {
      console.error('Unexpected sign-in error:', err)
      return {
        message: 'An unexpected error occurred during sign-in',
        name: 'AuthError',
        status: 500,
      } as AuthError
    }
  }, [])

  const signUp = useCallback(async (email: string, password: string) => {
    try {
      const { data, error } = await supabase.auth.signUp({ email, password })
      if (error) {
        console.error('Sign-up error:', {
          message: error.message,
          status: error.status,
          name: error.name,
        })
        return error
      }
      // Update session immediately on successful sign-up (if email confirmation is disabled)
      if (data.session) {
        setSession(data.session)
      }
      return null
    } catch (err) {
      console.error('Unexpected sign-up error:', err)
      return {
        message: 'An unexpected error occurred during registration',
        name: 'AuthError',
        status: 500,
      } as AuthError
    }
  }, [])

  const signInWithGoogle = useCallback(async () => {
    try {
      // Use root path since callback handler runs on all pages
      const redirectTo = env.supabaseRedirectUrl ?? `${window.location.origin}/`
      
      console.log('Initiating Google OAuth with redirect URL:', redirectTo)
      
      const { error } = await supabase.auth.signInWithOAuth({
        provider: 'google',
        options: {
          redirectTo,
          queryParams: {
            prompt: 'select_account',
          },
        },
      })
      
      if (error) {
        console.error('Google OAuth initiation error:', {
          message: error.message,
          status: error.status,
          name: error.name,
        })
        return error
      }
      
      // OAuth redirect will happen automatically
      // The callback handler will process the result
      return null
    } catch (err) {
      console.error('Unexpected Google OAuth error:', err)
      return {
        message: 'An unexpected error occurred during Google sign-in',
        name: 'AuthError',
        status: 500,
      } as AuthError
    }
  }, [])

  const signOut = useCallback(async () => {
    const { error } = await supabase.auth.signOut()
    return error
  }, [])

  const value = useMemo<AuthContextValue>(
    () => ({
      user: session?.user ?? null,
      session,
      loading,
      signIn,
      signUp,
      signInWithGoogle,
      signOut,
    }),
    [loading, session, signIn, signUp, signInWithGoogle, signOut],
  )

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

export function useAuthContext(): AuthContextValue {
  const ctx = useContext(AuthContext)
  if (!ctx) {
    throw new Error('useAuthContext must be used within an AuthProvider')
  }
  return ctx
}

