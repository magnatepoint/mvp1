const supabaseUrl = import.meta.env.VITE_SUPABASE_URL as string | undefined
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY as string | undefined
const supabaseRedirectUrl = import.meta.env.VITE_SUPABASE_REDIRECT_URL as string | undefined
const apiBaseUrl =
  (import.meta.env.VITE_API_URL as string | undefined) ?? 'https://api.monytix.ai'

if (!supabaseUrl || !supabaseAnonKey) {
  const missing = []
  if (!supabaseUrl) missing.push('VITE_SUPABASE_URL')
  if (!supabaseAnonKey) missing.push('VITE_SUPABASE_ANON_KEY')
  
  throw new Error(
    `Missing required environment variables: ${missing.join(', ')}\n\n` +
    `Please create a .env file in the frontend directory with:\n` +
    `VITE_SUPABASE_URL=https://your-project.supabase.co\n` +
    `VITE_SUPABASE_ANON_KEY=your-anon-key\n\n` +
    `Get these from: https://supabase.com/dashboard → Your Project → Settings → API`
  )
}

// Validate Supabase URL format
if (!supabaseUrl.startsWith('https://') || !supabaseUrl.includes('.supabase.co')) {
  console.warn('⚠️  VITE_SUPABASE_URL does not look like a valid Supabase URL:', supabaseUrl)
}

export const env = {
  supabaseUrl,
  supabaseAnonKey,
  supabaseRedirectUrl,
  apiBaseUrl,
}

