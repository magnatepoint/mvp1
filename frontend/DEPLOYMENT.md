# Deploying to Cloudflare Pages

This frontend application is configured for deployment on [Cloudflare Pages](https://pages.cloudflare.com/).

## Prerequisites

- A Cloudflare account.
- This repository connected to your Cloudflare account.

## Build Settings

Configure the following settings in your Cloudflare Pages project dashboard:

| Setting | Value |
|Str |---|
| **Framework Preset** | `Vite` |
| **Build Command** | `npm run build` |
| **Build Output Directory** | `dist` |
| **Root Directory** | `frontend` |

## Environment Variables

You must configure the following environment variables in **Settings > Environment variables > Production** (and Preview if needed):

- `VITE_API_URL`: The URL of your backend API (e.g., `https://api.yourdomain.com/v1`).
- `VITE_SUPABASE_URL`: Your Supabase Project URL.
- `VITE_SUPABASE_ANON_KEY`: Your Supabase Anonymous Key.
- `VITE_SUPABASE_REDIRECT_URL`: Optional override for OAuth callback (e.g., `https://mvp.monytix.ai/auth/callback`).

## Routing

A `_redirects` file is included in `public/_redirects` to handle Single Page Application (SPA) routing:

```
/* /index.html 200
```

This ensures that deep links (e.g., `/dashboard`) work correctly by redirecting all traffic to the React app.

## Manual Verification

After deployment, verify the following:
1.  **Navigation**: Click through the app tabs. Reload the page on a deep link (e.g., `/goal-compass`) to ensure 404s are not returned.
2.  **API Calls**: Open the Network tab and check that requests are going to your configured `VITE_API_URL`.
