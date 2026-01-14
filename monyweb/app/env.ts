const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL as string | undefined
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY as string | undefined
const apiBaseUrl =
  (process.env.NEXT_PUBLIC_API_BASE_URL as string | undefined) ?? 'http://bwkcw0s0g0csk8cg8o88ckoc.192.168.68.113.sslip.io'

if (!supabaseUrl || !supabaseAnonKey) {
  throw new Error('Supabase environment variables are missing. Check NEXT_PUBLIC_SUPABASE_* values.')
}

export const env = {
  supabaseUrl,
  supabaseAnonKey,
  apiBaseUrl,
}

