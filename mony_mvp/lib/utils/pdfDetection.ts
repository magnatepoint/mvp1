/**
 * PDF Password Detection Utilities
 * 
 * Detects if a PDF file is password-protected by checking for encryption markers.
 * Uses a simple approach that doesn't require external dependencies.
 */

/**
 * Simplified check without PDF.js dependency
 * Checks PDF structure for encryption markers
 */
export function checkPDFPasswordProtectionSimple(file: File): Promise<boolean> {
  return new Promise((resolve) => {
    const reader = new FileReader()
    
    reader.onload = (e) => {
      try {
        const arrayBuffer = e.target?.result as ArrayBuffer
        const pdfText = new TextDecoder('latin1').decode(
          arrayBuffer.slice(0, Math.min(8192, arrayBuffer.byteLength))
        )
        
        // Check for encryption markers
        const hasEncrypt = pdfText.includes('/Encrypt') || pdfText.includes('/Filter/Standard')
        resolve(hasEncrypt)
      } catch (error) {
        console.error('Error in simple PDF check:', error)
        resolve(false) // Assume not protected if we can't determine
      }
    }
    
    reader.onerror = () => {
      resolve(false)
    }
    
    reader.readAsArrayBuffer(file)
  })
}
