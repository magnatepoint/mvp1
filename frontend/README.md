# MVP Frontend

React + Vite SPA with Supabase Auth for login and FastAPI as the backend API.

## Environment

Create a `.env` file (not committed) with:

```
VITE_SUPABASE_URL=https://your-project.supabase.co
VITE_SUPABASE_ANON_KEY=public-anon-key
VITE_API_BASE_URL=http://localhost:8000
```

## Getting Started

```bash
cd /Users/santosh/coding/mvp/frontend
npm install
npm run dev
```

Visit `http://localhost:5173` and log in with any Supabase user credentials. The UI signs in via Supabase directly and then pings the backend `/auth/session` endpoint with the returned JWT to prove the session is valid server-side.

## Key Files

- `src/env.ts` – validates required Vite env vars
- `src/auth/supabaseClient.ts` – shared Supabase client instance
- `src/auth/providers/AuthProvider.tsx` – session context + listener
- `src/auth/components/LoginForm.tsx` – credential form with inline validation
- `src/components/SessionStatus.tsx` – fetches backend `/auth/session`
- `src/features/molyconsole/MolyConsole.tsx` – authenticated home with KPIs + quick links
- `src/features/spendsense/SpendSensePanel.tsx` – SpendSense pipeline cockpit (placeholder data)
- `src/features/spendsense/SpendSenseScreen.tsx` – full SpendSense view accessible via the nav drawer
