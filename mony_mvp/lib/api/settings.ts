import type { Session } from '@supabase/supabase-js'
import { fetchWithAuth } from './client'
import type { DeleteDataResponse } from '@/types/settings'

// Delete all user data
export async function deleteAllData(session: Session): Promise<DeleteDataResponse> {
  return fetchWithAuth<DeleteDataResponse>(session, '/v1/spendsense/data', {
    method: 'DELETE',
  })
}
