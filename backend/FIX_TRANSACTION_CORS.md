# Fix Transaction Creation CORS and 500 Error

## Issue
When trying to manually add a transaction, you're getting:
1. **CORS Error**: `Access to fetch at 'https://api.monytix.ai/v1/spendsense/transactions' from origin 'https://mvp.monytix.ai' has been blocked by CORS policy`
2. **500 Internal Server Error**: Backend returns 500 when processing the transaction

## Fix 1: Update CORS Configuration

The backend needs to allow requests from `https://mvp.monytix.ai`.

### In Coolify (Backend Environment Variables):

1. Go to your backend service in Coolify
2. Navigate to **Environment Variables**
3. Find or add `FRONTEND_ORIGIN`
4. Set it to include your Cloudflare Pages domain:
   ```
   https://mvp.monytix.ai
   ```
   
   **OR** if you have multiple frontends (comma-separated):
   ```
   https://mvp.monytix.ai,https://your-other-frontend.com
   ```

5. **Save** and **restart** the backend service

### Verify CORS is Working:

After restarting, check the backend logs. You should see successful requests from `https://mvp.monytix.ai` without CORS errors.

## Fix 2: Check Backend Logs for 500 Error

The 500 error indicates a server-side issue. Check the backend logs to see the actual error:

```bash
# If using Docker
docker logs mvp-backend --tail 100

# Or in Coolify, check the backend service logs
```

Look for errors related to:
- Database connection issues
- Missing columns or tables
- SQL errors in the transaction creation

## Common Causes of 500 Error:

1. **Database Schema Issue**: The `spendsense.txn_fact` table or `spendsense.txn_override` table might be missing columns
2. **View Missing**: The effective transaction view might not exist
3. **Database Connection**: Connection pool might be exhausted

## After Fixing:

1. Restart the backend service
2. Try creating a transaction again
3. Check browser console - CORS error should be gone
4. If 500 persists, check backend logs for the specific error message
