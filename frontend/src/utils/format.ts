/**
 * Format currency in Indian format with smart abbreviations
 */
export function formatCurrency(amount: number): string {
  const formatter = new Intl.NumberFormat('en-IN', {
    style: 'currency',
    currency: 'INR',
    maximumFractionDigits: 0,
    notation: amount >= 100000 ? 'compact' : 'standard',
  })
  return formatter.format(amount)
}

/**
 * Format large numbers with abbreviations (1.2L, 50K, etc.)
 */
export function formatNumber(num: number): string {
  if (num >= 10000000) {
    return `₹${(num / 10000000).toFixed(1)}Cr`
  }
  if (num >= 100000) {
    return `₹${(num / 100000).toFixed(1)}L`
  }
  if (num >= 1000) {
    return `₹${(num / 1000).toFixed(1)}K`
  }
  return `₹${num.toFixed(0)}`
}

/**
 * Format date in a readable format
 */
export function formatDate(date: string | Date): string {
  const d = typeof date === 'string' ? new Date(date) : date
  return d.toLocaleDateString('en-IN', {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
  })
}

/**
 * Format date with time
 */
export function formatDateTime(date: string | Date): string {
  const d = typeof date === 'string' ? new Date(date) : date
  return d.toLocaleDateString('en-IN', {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  })
}

