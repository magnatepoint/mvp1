'use client'

import { useCallback, useEffect, useRef, useState } from 'react'
import type { Session } from '@supabase/supabase-js'
import './SettingsScreen.css'
import { env } from '../../env'

type Props = {
  session: Session
}

type GmailJobStatus = {
  job_id: string
  status: 'queued' | 'authorizing' | 'syncing' | 'completed' | 'failed'
  progress: number
  error?: string | null
  created_at: string
  updated_at: string
}

type DeleteResponse = {
  batches_deleted: number
  staging_deleted: number
  transactions_deleted: number
  overrides_deleted: number
}

const POLLABLE_STATUSES: GmailJobStatus['status'][] = ['queued', 'authorizing', 'syncing']

export function SettingsScreen({ session }: Props) {
  const [deleting, setDeleting] = useState(false)
  const [showConfirm, setShowConfirm] = useState(false)
  const [deleteError, setDeleteError] = useState<string | null>(null)
  const [success, setSuccess] = useState<DeleteResponse | null>(null)
  const [gmailStatus, setGmailStatus] = useState<GmailJobStatus | null>(null)
  const [gmailError, setGmailError] = useState<string | null>(null)
  const [connecting, setConnecting] = useState(false)
  const [syncing, setSyncing] = useState(false)
  const popupWatcher = useRef<number | null>(null)

  const handleDeleteClick = () => {
    setShowConfirm(true)
    setDeleteError(null)
    setSuccess(null)
  }

  const handleConfirmDelete = async () => {
    setDeleting(true)
    setDeleteError(null)
    setSuccess(null)
    try {
      const response = await fetch(`${env.apiBaseUrl}/spendsense/data`, {
        method: 'DELETE',
        headers: {
          Authorization: `Bearer ${session.access_token}`,
        },
      })
      if (!response.ok) {
        const body = await response.json().catch(() => ({}))
        throw new Error(body.detail ?? 'Failed to delete data')
      }
      const result = (await response.json()) as DeleteResponse
      setSuccess(result)
      setShowConfirm(false)
    } catch (err) {
      setDeleteError(err instanceof Error ? err.message : 'Unknown error')
    } finally {
      setDeleting(false)
    }
  }

  const handleCancelDelete = () => {
    setShowConfirm(false)
    setDeleteError(null)
  }

  const fetchGmailStatus = useCallback(async () => {
    try {
      const response = await fetch(`${env.apiBaseUrl}/gmail/sync/status`, {
        headers: {
          Authorization: `Bearer ${session.access_token}`,
        },
      })
      if (!response.ok) {
        if (response.status === 404) {
          setGmailStatus(null)
          return
        }
        throw new Error('Failed to fetch Gmail status')
      }
      const data = (await response.json()) as GmailJobStatus | null
      setGmailStatus(data)
    } catch (err) {
      setGmailError(err instanceof Error ? err.message : 'Unable to reach Gmail status')
    }
  }, [session.access_token])

  useEffect(() => {
    void fetchGmailStatus()
    return () => {
      if (popupWatcher.current) {
        window.clearInterval(popupWatcher.current)
        popupWatcher.current = null
      }
    }
  }, [fetchGmailStatus])

  useEffect(() => {
    if (!gmailStatus || !POLLABLE_STATUSES.includes(gmailStatus.status)) {
      return undefined
    }
    const intervalId = window.setInterval(() => {
      void fetchGmailStatus()
    }, 4000)
    return () => window.clearInterval(intervalId)
  }, [fetchGmailStatus, gmailStatus])

  const handleConnectGmail = async () => {
    setConnecting(true)
    setGmailError(null)
    try {
      const response = await fetch(`${env.apiBaseUrl}/gmail/connect`, {
        headers: {
          Authorization: `Bearer ${session.access_token}`,
        },
      })
      if (!response.ok) {
        const body = await response.json().catch(() => ({}))
        throw new Error(body.detail ?? 'Failed to initiate Gmail connect')
      }
      const data = (await response.json()) as { auth_url: string }
      const popup = window.open(
        data.auth_url,
        'gmail-connect',
        'width=520,height=680,noopener',
      )
      if (!popup) {
        throw new Error('Popup blocked. Please allow popups for this site.')
      }
      popup.focus()
      popupWatcher.current = window.setInterval(() => {
        if (popup.closed) {
          if (popupWatcher.current) {
            window.clearInterval(popupWatcher.current)
            popupWatcher.current = null
          }
          void fetchGmailStatus()
        }
      }, 1500)
    } catch (err) {
      setGmailError(err instanceof Error ? err.message : 'Unable to open Gmail connect')
    } finally {
      setConnecting(false)
    }
  }

  const handleSyncGmail = async () => {
    setSyncing(true)
    setGmailError(null)
    try {
      const response = await fetch(`${env.apiBaseUrl}/gmail/sync`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${session.access_token}`,
          'Content-Type': 'application/json',
        },
      })
      if (!response.ok) {
        const body = await response.json().catch(() => ({}))
        throw new Error(body.detail ?? 'Failed to start Gmail sync')
      }
      const data = (await response.json()) as GmailJobStatus
      setGmailStatus(data)
    } catch (err) {
      setGmailError(err instanceof Error ? err.message : 'Unable to start sync')
    } finally {
      setSyncing(false)
    }
  }

  const gmailStatusLabel = gmailStatus
    ? {
        queued: 'Queued — waiting to start',
        authorizing: 'Authorizing with Google…',
        syncing: 'Syncing alerts…',
        completed: 'Sync completed',
        failed: 'Sync failed',
      }[gmailStatus.status]
    : 'No sync history yet'

  const disableSyncButton =
    connecting || syncing || (gmailStatus ? POLLABLE_STATUSES.includes(gmailStatus.status) : false)

  return (
    <section className="settings-screen glass-card">
      <header className="settings-screen__header">
        <div>
          <p className="eyebrow">Settings</p>
          <h3>Account & Data Management</h3>
        </div>
      </header>

      <div className="settings-screen__content">
        <div className="settings-screen__section">
          <h4 className="settings-screen__sectionTitle">Gmail Automation</h4>
          <p className="settings-screen__sectionDescription">
            Connect Gmail to ingest real-time bank alerts automatically. We only request read-only access and never send
            email on your behalf.
          </p>

          {gmailError && <p className="error-message">{gmailError}</p>}

          <div className="settings-screen__gmailCard">
            <div className="settings-screen__gmailActions">
              <button className="primary-button" onClick={handleConnectGmail} disabled={connecting}>
                {connecting ? 'Opening Google…' : gmailStatus ? 'Reconnect Gmail' : 'Connect Gmail Account'}
              </button>
              <button className="ghost-button" onClick={handleSyncGmail} disabled={disableSyncButton}>
                {disableSyncButton ? 'Sync in Progress…' : 'Sync Latest Alerts'}
              </button>
            </div>

            <div className="settings-screen__progress">
              <div className="settings-screen__progressMeta">
                <span className="settings-screen__statusLabel">{gmailStatusLabel}</span>
                {gmailStatus?.error && <span className="settings-screen__statusError">{gmailStatus.error}</span>}
              </div>
              <div className="settings-screen__progressBar">
                <div
                  className="settings-screen__progressFill"
                  style={{ width: `${gmailStatus?.progress ?? 0}%` }}
                />
              </div>
              {gmailStatus && (
                <p className="settings-screen__progressTimestamp">
                  Updated {new Date(gmailStatus.updated_at).toLocaleString()}
                </p>
              )}
            </div>
          </div>
        </div>

        <div className="settings-screen__section">
          <h4 className="settings-screen__sectionTitle">Transaction Data</h4>
          <p className="settings-screen__sectionDescription">
            Permanently delete all your transaction data, including uploaded files, parsed transactions, and categorizations.
            This action cannot be undone.
          </p>

          {success && (
            <div className="settings-screen__success">
              <p className="settings-screen__successTitle">Data deleted successfully</p>
              <ul className="settings-screen__successList">
                <li>{success.transactions_deleted} transactions deleted</li>
                <li>{success.batches_deleted} upload batches deleted</li>
                <li>{success.staging_deleted} staging records deleted</li>
                <li>{success.overrides_deleted} overrides deleted</li>
              </ul>
            </div>
          )}

          {deleteError && <p className="error-message">{deleteError}</p>}

          {!showConfirm ? (
            <button
              className="primary-button settings-screen__deleteButton"
              onClick={handleDeleteClick}
              disabled={deleting}
            >
              Delete All Transaction Data
            </button>
          ) : (
            <div className="settings-screen__confirm">
              <p className="settings-screen__confirmWarning">
                ⚠️ Are you sure you want to delete all your transaction data? This action is permanent and cannot be undone.
              </p>
              <div className="settings-screen__confirmActions">
                <button
                  className="ghost-button"
                  onClick={handleCancelDelete}
                  disabled={deleting}
                >
                  Cancel
                </button>
                <button
                  className="primary-button settings-screen__confirmDelete"
                  onClick={handleConfirmDelete}
                  disabled={deleting}
                >
                  {deleting ? 'Deleting…' : 'Yes, Delete Everything'}
                </button>
              </div>
            </div>
          )}
        </div>
      </div>
    </section>
  )
}

