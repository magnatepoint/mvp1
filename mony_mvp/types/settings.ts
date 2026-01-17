// Settings Types

export interface DeleteDataResponse {
  transactions_deleted: number
  batches_deleted: number
  staging_deleted: number
  overrides_deleted: number
}

export interface UserInfo {
  email: string | null
  userId: string
}
