# Coolify Deployment Guide for Monytix Frontend

This guide explains how to deploy the Monytix Next.js frontend to Coolify.

## Prerequisites

- Coolify instance running
- Access to the repository
- Environment variables configured

## Deployment Steps

### 1. Create New Application in Coolify

1. Go to your Coolify dashboard
2. Navigate to **Projects** → Select your project
3. Click **New Resource** → **Application**
4. Choose **Docker Compose** or **Dockerfile** deployment method

### 2. Configure Application

**If using Dockerfile method:**
- **Build Context**: `mony_mvp/`
- **Dockerfile Path**: `Dockerfile` (relative to build context)
- **Port**: `3000`

**If using Docker Compose method:**
- Use the provided `docker-compose.yml` file

### 3. Set Environment Variables

Add the following environment variables in Coolify:

```
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key
NEXT_PUBLIC_API_URL=https://api.monytix.ai
NEXT_PUBLIC_SUPABASE_REDIRECT_URL=https://your-frontend-domain.com/auth/callback
NODE_ENV=production
```

**Important Notes:**
- `NEXT_PUBLIC_SUPABASE_REDIRECT_URL` should match your deployed frontend URL
- Update Supabase OAuth redirect URLs to include your production domain
- All `NEXT_PUBLIC_*` variables are embedded at build time

### 4. Configure Build Settings

- **Build Command**: (not needed, handled by Dockerfile)
- **Start Command**: (not needed, handled by Dockerfile)
- **Build Timeout**: 600 seconds (10 minutes) recommended

### 5. Deploy

1. Click **Deploy** or **Redeploy**
2. Monitor the build logs
3. Once deployed, access your application at the provided URL

## Troubleshooting

### Build Fails

- Check build logs for specific errors
- Verify all environment variables are set
- Ensure Node.js version is compatible (20.x)

### Application Won't Start

- Check container logs in Coolify
- Verify port 3000 is exposed
- Ensure environment variables are correctly set

### Environment Variables Not Working

- Remember: `NEXT_PUBLIC_*` variables are embedded at **build time**
- You must rebuild the image after changing these variables
- Runtime-only variables (without `NEXT_PUBLIC_`) can be changed without rebuild

### Port Issues

- Default port is 3000
- Ensure Coolify is configured to use port 3000
- Check firewall/network settings

## Updating Supabase OAuth Settings

After deploying, update your Supabase project:

1. Go to Supabase Dashboard → Authentication → URL Configuration
2. Add your production frontend URL to **Redirect URLs**:
   - `https://your-frontend-domain.com/auth/callback`
3. Update **Site URL** to your production frontend URL

## Health Check

The application runs on port 3000. Coolify can use the root path `/` for health checks.

## Notes

- The Dockerfile uses Next.js standalone output for optimal image size
- The application runs as a non-root user (`nextjs`) for security
- Build uses multi-stage Docker build for smaller final image
- Production optimizations are enabled automatically
