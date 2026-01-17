# Cloudflare Pages Deployment Guide for Monytix Frontend

This guide explains how to deploy the Monytix Next.js frontend to Cloudflare Pages.

## Prerequisites

- Cloudflare account (free tier works)
- Access to the GitHub repository
- Supabase project configured
- Backend API accessible

## Deployment Steps

### 1. Connect Repository to Cloudflare Pages

1. Go to [Cloudflare Dashboard](https://dash.cloudflare.com/)
2. Navigate to **Pages** → **Create a project**
3. Click **Connect to Git**
4. Select your Git provider (GitHub, GitLab, or Bitbucket)
5. Authorize Cloudflare to access your repositories
6. Select the repository: `magnatepoint/mvp1` (or your repo)
7. Click **Begin setup**

### 2. Configure Build Settings

**Project name**: `monytix-frontend` (or your preferred name)

**Production branch**: `main`

**Root directory** (if your Next.js app is in a subdirectory):
```
mony_mvp
```

**Build command**:
```bash
npm run build
```

**Build output directory**:
```
.next
```

**Important**: If you set the root directory to `mony_mvp`, make sure the build command runs from that directory. The build output will be in `mony_mvp/.next`.

**Node.js version**: `20` (or latest LTS)

### 3. Configure Compatibility Flags

**IMPORTANT**: Cloudflare Pages requires the `nodejs_compat` compatibility flag for Next.js applications.

1. Go to your Cloudflare Pages project
2. Navigate to **Settings** → **Functions** → **Compatibility Flags**
3. Add the following compatibility flag:
   - **Flag name**: `nodejs_compat`
4. Enable it for both:
   - **Production environment**
   - **Preview environment**
5. Click **Save**

**Why this is needed**: Next.js on Cloudflare Pages uses `@cloudflare/next-on-pages` which requires Node.js compatibility to run server-side code.

### 4. Set Environment Variables

In the Cloudflare Pages project settings, go to **Settings** → **Environment variables** and add:

**Production environment variables:**

```
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key
NEXT_PUBLIC_API_URL=https://api.monytix.ai
NEXT_PUBLIC_SUPABASE_REDIRECT_URL=https://your-pages-domain.pages.dev/auth/callback
NODE_ENV=production
```

**Important Notes:**
- `NEXT_PUBLIC_SUPABASE_REDIRECT_URL` should match your Cloudflare Pages URL
- Update Supabase OAuth redirect URLs to include your production domain
- All `NEXT_PUBLIC_*` variables are embedded at **build time**
- You can also set these for Preview deployments if needed

### 5. Framework Preset

Cloudflare Pages will automatically detect Next.js, but you can explicitly set:
- **Framework preset**: `Next.js`

### 6. Deploy

1. Click **Save and Deploy**
2. Cloudflare Pages will:
   - Clone your repository
   - Install dependencies (`npm ci`)
   - Run the build command
   - Deploy the application
3. Monitor the build logs in real-time
4. Once deployed, your app will be available at: `https://your-project-name.pages.dev`

### 7. Custom Domain (Optional)

1. Go to **Custom domains** in your Pages project
2. Click **Set up a custom domain**
3. Enter your domain (e.g., `app.monytix.ai`)
4. Follow DNS configuration instructions
5. Update `NEXT_PUBLIC_SUPABASE_REDIRECT_URL` to match your custom domain

## Build Configuration Details

### Build Command
```bash
npm run build
```

### Build Output
Cloudflare Pages uses Next.js's standard output (`.next` directory). The `output: 'standalone'` option in `next.config.ts` is disabled for Cloudflare Pages as it uses its own Next.js runtime.

### Node.js Version
Cloudflare Pages supports Node.js 18.x and 20.x. The build will use the version specified in your project or default to a compatible version.

## Environment Variables

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `NEXT_PUBLIC_SUPABASE_URL` | Your Supabase project URL | `https://xxxxx.supabase.co` |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Supabase anonymous key | `eyJhbGci...` |
| `NEXT_PUBLIC_API_URL` | Backend API URL | `https://api.monytix.ai` |
| `NEXT_PUBLIC_SUPABASE_REDIRECT_URL` | OAuth callback URL | `https://app.monytix.ai/auth/callback` |

### Build-time vs Runtime

- **`NEXT_PUBLIC_*` variables**: Embedded at build time. Changes require a new deployment.
- **Other variables**: Available at runtime. Can be changed without redeploying (if not used during build).

## Updating Supabase OAuth Settings

After deploying to Cloudflare Pages:

1. Go to Supabase Dashboard → **Authentication** → **URL Configuration**
2. Add your Cloudflare Pages URL to **Redirect URLs**:
   - `https://your-project-name.pages.dev/auth/callback`
   - `https://your-custom-domain.com/auth/callback` (if using custom domain)
3. Update **Site URL** to your Cloudflare Pages URL

## Automatic Deployments

Cloudflare Pages automatically deploys:
- **Production**: On every push to `main` branch
- **Preview**: On every pull request (creates a unique preview URL)

### Preview Deployments

Preview deployments use the same environment variables as production by default. You can:
- Set different environment variables for preview deployments
- Use preview URLs for testing before merging to main

## Troubleshooting

### Node.js Compatibility Error

**Error**: "Node.JS Compatibility Error - no nodejs_compat compatibility flag set"

**Solution**:
1. Go to your Cloudflare Pages project dashboard
2. Navigate to **Settings** → **Functions** → **Compatibility Flags**
3. Click **Add compatibility flag**
4. Enter: `nodejs_compat`
5. Enable it for both **Production** and **Preview** environments
6. Click **Save**
7. Redeploy your application

This flag is required for Next.js applications using `@cloudflare/next-on-pages` to enable Node.js compatibility in Cloudflare Workers.

### Build Fails

**Error: Missing Supabase environment variables**
- Ensure all `NEXT_PUBLIC_*` variables are set in Cloudflare Pages settings
- Check that variables are set for the correct environment (Production/Preview)

**Error: Build timeout**
- Cloudflare Pages has a 30-minute build timeout
- Optimize your build process if it's taking too long
- Check for unnecessary dependencies

**Error: TypeScript errors**
- Fix TypeScript errors locally first
- Ensure `npm run build` succeeds locally before deploying

### Application Won't Load

**404 errors**
- Verify the build output directory is correct (`.next`)
- Check that Next.js routes are properly configured

**Environment variables not working**
- Remember: `NEXT_PUBLIC_*` variables are embedded at build time
- Redeploy after changing these variables
- Check variable names for typos

### Authentication Issues

**OAuth redirect not working**
- Verify `NEXT_PUBLIC_SUPABASE_REDIRECT_URL` matches your Cloudflare Pages URL
- Update Supabase redirect URLs to include your Cloudflare Pages domain
- Check that the callback route exists: `/app/auth/callback/route.ts`

## Performance Optimization

Cloudflare Pages automatically provides:
- **Global CDN**: Your app is served from Cloudflare's edge network
- **Automatic HTTPS**: SSL certificates are provisioned automatically
- **Edge Functions**: Next.js API routes run on Cloudflare's edge
- **Image Optimization**: Next.js Image component works with Cloudflare's image optimization

## Monitoring and Analytics

- **Build logs**: Available in the Cloudflare Pages dashboard
- **Deployment history**: View all deployments and their status
- **Analytics**: Available in Cloudflare dashboard (may require paid plan)

## Rollback

To rollback to a previous deployment:
1. Go to **Deployments** in your Pages project
2. Find the deployment you want to rollback to
3. Click the three dots menu → **Retry deployment** or **Promote to production**

## Cost

Cloudflare Pages is **free** for:
- Unlimited sites
- Unlimited requests
- Unlimited bandwidth
- 500 builds per month
- Preview deployments

For higher limits, consider Cloudflare Pages Pro ($20/month).

## Additional Resources

- [Cloudflare Pages Documentation](https://developers.cloudflare.com/pages/)
- [Next.js on Cloudflare Pages](https://developers.cloudflare.com/pages/framework-guides/nextjs/)
- [Cloudflare Pages Environment Variables](https://developers.cloudflare.com/pages/platform/build-configuration/#environment-variables)
