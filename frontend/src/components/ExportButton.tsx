import { Download, FileText, FileJson } from 'lucide-react'
import { useState } from 'react'
import { useToast } from './Toast'
import './ExportButton.css'

type ExportButtonProps = {
  data: any[]
  filename?: string
  onExport?: (format: 'csv' | 'json') => void
}

export function ExportButton({ data, filename = 'transactions', onExport }: ExportButtonProps) {
  const [exporting, setExporting] = useState(false)
  const [showMenu, setShowMenu] = useState(false)
  const { showToast } = useToast()

  const exportToCSV = () => {
    if (data.length === 0) return
    
    setExporting(true)
    try {
      // Get headers from first object
      const headers = Object.keys(data[0])
      
      // Create CSV content
      const csvContent = [
        headers.join(','),
        ...data.map((row) =>
          headers
            .map((header) => {
              const value = row[header]
              // Handle values that might contain commas or quotes
              if (value === null || value === undefined) return ''
              const stringValue = String(value)
              if (stringValue.includes(',') || stringValue.includes('"') || stringValue.includes('\n')) {
                return `"${stringValue.replace(/"/g, '""')}"`
              }
              return stringValue
            })
            .join(',')
        ),
      ].join('\n')

      // Create blob and download
      const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' })
      const link = document.createElement('a')
      const url = URL.createObjectURL(blob)
      link.setAttribute('href', url)
      link.setAttribute('download', `${filename}_${new Date().toISOString().split('T')[0]}.csv`)
      link.style.visibility = 'hidden'
      document.body.appendChild(link)
      link.click()
      document.body.removeChild(link)
      
      showToast('Data exported to CSV successfully!', 'success')
      onExport?.('csv')
    } catch (error) {
      console.error('Export error:', error)
    } finally {
      setExporting(false)
      setShowMenu(false)
    }
  }

  const exportToJSON = () => {
    if (data.length === 0) return
    
    setExporting(true)
    try {
      const jsonContent = JSON.stringify(data, null, 2)
      const blob = new Blob([jsonContent], { type: 'application/json;charset=utf-8;' })
      const link = document.createElement('a')
      const url = URL.createObjectURL(blob)
      link.setAttribute('href', url)
      link.setAttribute('download', `${filename}_${new Date().toISOString().split('T')[0]}.json`)
      link.style.visibility = 'hidden'
      document.body.appendChild(link)
      link.click()
      document.body.removeChild(link)
      
      showToast('Data exported to JSON successfully!', 'success')
      onExport?.('json')
    } catch (error) {
      console.error('Export error:', error)
    } finally {
      setExporting(false)
      setShowMenu(false)
    }
  }

  return (
    <div className="export-button-wrapper">
      <button
        className="export-button"
        onClick={() => setShowMenu(!showMenu)}
        disabled={exporting || data.length === 0}
        aria-label="Export data"
      >
        <Download size={18} />
        <span>{exporting ? 'Exporting...' : 'Export'}</span>
      </button>
      {showMenu && (
        <>
          <div className="export-button__overlay" onClick={() => setShowMenu(false)} />
          <div className="export-button__menu">
            <button
              className="export-button__menuItem"
              onClick={exportToCSV}
              disabled={exporting}
            >
              <FileText size={18} />
              <div>
                <div className="export-button__menuLabel">Export as CSV</div>
                <div className="export-button__menuDescription">Spreadsheet format</div>
              </div>
            </button>
            <button
              className="export-button__menuItem"
              onClick={exportToJSON}
              disabled={exporting}
            >
              <FileJson size={18} />
              <div>
                <div className="export-button__menuLabel">Export as JSON</div>
                <div className="export-button__menuDescription">Data format</div>
              </div>
            </button>
          </div>
        </>
      )}
    </div>
  )
}

