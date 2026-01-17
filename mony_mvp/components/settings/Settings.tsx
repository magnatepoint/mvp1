'use client'

import { useState, useEffect } from 'react'
import type { Session } from '@supabase/supabase-js'
import SettingsSection from './components/SettingsSection'
import SettingsRow from './components/SettingsRow'
import DeleteDataModal from './components/DeleteDataModal'

interface SettingsProps {
  session: Session
  onSignOut: () => void
  onBack?: () => void
}

export default function Settings({ session, onSignOut }: SettingsProps) {
  const [showDeleteModal, setShowDeleteModal] = useState(false)
  const [showSignOutConfirm, setShowSignOutConfirm] = useState(false)
  const [deleteSuccess, setDeleteSuccess] = useState(false)

  const userEmail = session.user.email || 'Not available'
  const userId = session.user.id

  const handleDeleteSuccess = () => {
    setDeleteSuccess(true)
    setShowDeleteModal(false)
  }

  const handleSignOut = () => {
    setShowSignOutConfirm(false)
    onSignOut()
  }

  return (
    <div className="min-h-screen bg-[#2E2E2E] text-white">
      {/* Header */}
      <div className="px-4 pt-4 pb-2">
        <div className="flex items-start justify-between gap-4">
          <div className="flex-1">
            <h1 className="text-3xl font-bold text-white mb-2">Settings</h1>
            <p className="text-base text-gray-400">Manage your account and preferences</p>
          </div>

        </div>
      </div>

      {/* Content */}
      <div className="space-y-6 p-4 pb-6">
        {/* Account Section */}
        <SettingsSection icon="👤" title="Account">
          <div className="space-y-3">
            <div className="flex items-center justify-between">
              <span className="text-base text-gray-400">Email</span>
              <span className="text-base font-medium text-white">{userEmail}</span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-base text-gray-400">User ID</span>
              <span className="text-sm font-medium text-gray-500">
                {userId.substring(0, 8)}...
              </span>
            </div>
          </div>
        </SettingsSection>

        {/* Preferences Section */}
        <SettingsSection icon="⚙️" title="Preferences">
          <SettingsRow
            icon="🔔"
            title="Notifications"
            subtitle="Manage notification preferences"
            onClick={() => {
              // Future: Open notification settings
              alert('Notification settings coming soon!')
            }}
          />
          <SettingsRow
            icon="💰"
            title="Currency"
            subtitle="INR (Indian Rupee)"
            onClick={() => {
              // Future: Change currency
              alert('Currency settings coming soon!')
            }}
          />
          <SettingsRow
            icon="🎨"
            title="Theme"
            subtitle="Dark"
            onClick={() => {
              // Future: Change theme
              alert('Theme settings coming soon!')
            }}
          />
        </SettingsSection>

        {/* Data Management Section */}
        <SettingsSection icon="💾" title="Data Management">
          <button
            onClick={() => setShowDeleteModal(true)}
            className="w-full flex items-center gap-3 py-2 hover:opacity-80 transition-opacity"
          >
            <span className="text-red-500 text-lg flex-shrink-0 w-6 text-center">🗑️</span>
            <div className="flex-1 min-w-0 text-left">
              <p className="text-base font-semibold text-red-500">Delete All Data</p>
              <p className="text-sm text-gray-400">Permanently delete all your data</p>
            </div>
          </button>
        </SettingsSection>

        {/* About Section */}
        <SettingsSection icon="ℹ️" title="About">
          <div className="space-y-3">
            <div className="flex items-center justify-between">
              <span className="text-base text-gray-400">App Version</span>
              <span className="text-base font-medium text-white">1.0.0</span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-base text-gray-400">Build</span>
              <span className="text-base font-medium text-white">
                {process.env.NEXT_PUBLIC_BUILD_NUMBER || '1'}
              </span>
            </div>
          </div>
        </SettingsSection>

        {/* Sign Out Section */}
        <button
          onClick={() => setShowSignOutConfirm(true)}
          className="w-full py-4 rounded-xl font-semibold bg-red-500/20 text-white hover:bg-red-500/30 transition-colors border border-red-500/50"
        >
          Sign Out
        </button>
      </div>

      {/* Delete Data Modal */}
      <DeleteDataModal
        isOpen={showDeleteModal}
        session={session}
        onClose={() => setShowDeleteModal(false)}
        onSuccess={handleDeleteSuccess}
      />

      {/* Sign Out Confirmation Modal */}
      {showSignOutConfirm && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm">
          <div className="bg-[#2E2E2E] rounded-2xl p-6 max-w-md w-full mx-4 border border-white/20">
            <h3 className="text-xl font-bold text-white mb-2">Sign Out</h3>
            <p className="text-sm text-gray-300 mb-6">Are you sure you want to sign out?</p>
            <div className="flex gap-3">
              <button
                onClick={() => setShowSignOutConfirm(false)}
                className="flex-1 py-3 px-4 rounded-xl font-semibold bg-white/10 text-white hover:bg-white/20 transition-colors"
              >
                Cancel
              </button>
              <button
                onClick={handleSignOut}
                className="flex-1 py-3 px-4 rounded-xl font-semibold bg-red-500 text-white hover:bg-red-600 transition-colors"
              >
                Sign Out
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Delete Success Message */}
      {deleteSuccess && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm">
          <div className="bg-[#2E2E2E] rounded-2xl p-6 max-w-md w-full mx-4 border border-white/20">
            <h3 className="text-xl font-bold text-white mb-2">Data Deleted</h3>
            <p className="text-sm text-gray-300 mb-6">
              All your data has been successfully deleted. The page will reload shortly.
            </p>
            <button
              onClick={() => window.location.reload()}
              className="w-full py-3 px-4 rounded-xl font-semibold bg-[#D4AF37] text-black hover:bg-[#D4AF37]/90 transition-colors"
            >
              OK
            </button>
          </div>
        </div>
      )}
    </div>
  )
}
