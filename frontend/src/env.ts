const supabaseUrl = import.meta.env.VITE_SUPABASE_URL as string | undefined
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY as string | undefined
const apiBaseUrl =
  (import.meta.env.VITE_API_URL as string | undefined) ?? 'http://bwkcw0s0g0csk8cg8o88ckoc.192.168.68.113.sslip.io'

if (!supabaseUrl || !supabaseAnonKey) {
  throw new Error('Supabase environment variables are missing. Check VITE_SUPABASE_* values.')
}

export const env = {
  supabaseUrl,
  supabaseAnonKey,
  apiBaseUrl,
}

