# Cloudflare Pages Root Directory Configuration

## Issue

If you see build errors like:
```
Module not found: Can't resolve '@/components/budgetpilot/BudgetPilot'
Module not found: Can't resolve '@/components/goaltracker/GoalTracker'
```

This means Cloudflare Pages is building from the wrong directory.

## Solution

**Set the Root Directory in Cloudflare Pages:**

1. Go to your Cloudflare Pages project
2. Navigate to **Settings** → **Builds & deployments**
3. Find **Root directory** setting
4. Set it to: `mony_mvp`
5. Save and redeploy

## Verification

After setting the root directory, the build should:
- Find `package.json` in the root
- Find `next.config.ts` in the root
- Find `app/` directory in the root
- Find `components/` directory in the root

## Alternative: Move files to repository root

If you prefer not to use a root directory, you could move all `mony_mvp/` files to the repository root, but this is not recommended if you have other projects in the same repository.
