'use client'

import { useEffect, useState, useMemo, useCallback } from 'react'
import './CommandPalette.css'

export type Command = {
  id: string
  title: string
  description?: string
  icon?: string
  category: string
  action: () => void
  keywords?: string[]
}

type CommandPaletteProps = {
  commands: Command[]
  isOpen: boolean
  onClose: () => void
}

export function CommandPalette({ commands, isOpen, onClose }: CommandPaletteProps) {
  const [search, setSearch] = useState('')
  const [selectedIndex, setSelectedIndex] = useState(0)

  const filteredCommands = useMemo(() => {
    if (!search.trim()) return commands
    
    const query = search.toLowerCase()
    return commands.filter(cmd => {
      const titleMatch = cmd.title.toLowerCase().includes(query)
      const descMatch = cmd.description?.toLowerCase().includes(query)
      const keywordMatch = cmd.keywords?.some(k => k.toLowerCase().includes(query))
      const categoryMatch = cmd.category.toLowerCase().includes(query)
      
      return titleMatch || descMatch || keywordMatch || categoryMatch
    })
  }, [commands, search])

  const groupedCommands = useMemo(() => {
    const groups: Record<string, Command[]> = {}
    filteredCommands.forEach(cmd => {
      if (!groups[cmd.category]) {
        groups[cmd.category] = []
      }
      groups[cmd.category].push(cmd)
    })
    return groups
  }, [filteredCommands])

  const handleSelect = useCallback((command: Command) => {
    command.action()
    onClose()
    setSearch('')
  }, [onClose])

  useEffect(() => {
    if (!isOpen) {
      setSearch('')
      setSelectedIndex(0)
      return
    }
    
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'ArrowDown') {
        e.preventDefault()
        setSelectedIndex(prev => Math.min(prev + 1, filteredCommands.length - 1))
      } else if (e.key === 'ArrowUp') {
        e.preventDefault()
        setSelectedIndex(prev => Math.max(prev - 1, 0))
      } else if (e.key === 'Enter') {
        e.preventDefault()
        if (filteredCommands[selectedIndex]) {
          handleSelect(filteredCommands[selectedIndex])
        }
      } else if (e.key === 'Escape') {
        e.preventDefault()
        onClose()
      }
    }

    window.addEventListener('keydown', handleKeyDown)
    return () => window.removeEventListener('keydown', handleKeyDown)
  }, [isOpen, filteredCommands, selectedIndex, handleSelect, onClose])

  useEffect(() => {
    setSelectedIndex(0)
  }, [search])

  if (!isOpen) return null

  return (
    <div className="command-palette-overlay" onClick={onClose}>
      <div className="command-palette" onClick={(e) => e.stopPropagation()}>
        <div className="command-palette-header">
          <input
            type="text"
            className="command-palette-input"
            placeholder="Type a command or search..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            autoFocus
            aria-label="Command palette search"
          />
          <kbd className="command-palette-hint">ESC</kbd>
        </div>
        <div className="command-palette-results">
          {filteredCommands.length === 0 ? (
            <div className="command-palette-empty">
              <p>No commands found</p>
              <small>Try a different search term</small>
            </div>
          ) : (
            Object.entries(groupedCommands).map(([category, cmds]) => (
              <div key={category} className="command-palette-group">
                <div className="command-palette-category">{category}</div>
                {cmds.map((cmd, idx) => {
                  const globalIndex = filteredCommands.indexOf(cmd)
                  return (
                    <button
                      key={cmd.id}
                      className={`command-palette-item ${selectedIndex === globalIndex ? 'is-selected' : ''}`}
                      onClick={() => handleSelect(cmd)}
                      onMouseEnter={() => setSelectedIndex(globalIndex)}
                    >
                      {cmd.icon && <span className="command-palette-icon">{cmd.icon}</span>}
                      <div className="command-palette-content">
                        <div className="command-palette-title">{cmd.title}</div>
                        {cmd.description && (
                          <div className="command-palette-description">{cmd.description}</div>
                        )}
                      </div>
                      {selectedIndex === globalIndex && (
                        <kbd className="command-palette-enter">↵</kbd>
                      )}
                    </button>
                  )
                })}
              </div>
            ))
          )}
        </div>
        <div className="command-palette-footer">
          <div className="command-palette-shortcuts">
            <kbd>↑↓</kbd> Navigate
            <kbd>↵</kbd> Select
            <kbd>ESC</kbd> Close
          </div>
        </div>
      </div>
    </div>
  )
}

