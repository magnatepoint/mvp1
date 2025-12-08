import './SkeletonLoader.css'

type SkeletonLoaderProps = {
  width?: string | number
  height?: string | number
  className?: string
  variant?: 'text' | 'circular' | 'rectangular'
  lines?: number
}

export function SkeletonLoader({
  width,
  height,
  className = '',
  variant = 'rectangular',
  lines = 1,
}: SkeletonLoaderProps) {
  if (variant === 'text' && lines > 1) {
    return (
      <div className={`skeleton-text-container ${className}`}>
        {Array.from({ length: lines }).map((_, i) => (
          <div
            key={i}
            className="skeleton skeleton-text"
            style={{
              width: i === lines - 1 ? '60%' : '100%',
            }}
          />
        ))}
      </div>
    )
  }

  const style: React.CSSProperties = {}
  if (width) style.width = typeof width === 'number' ? `${width}px` : width
  if (height) style.height = typeof height === 'number' ? `${height}px` : height

  const variantClass = variant === 'circular' ? 'skeleton-circular' : variant === 'text' ? 'skeleton-text' : 'skeleton-rectangular'

  return <div className={`skeleton ${variantClass} ${className}`} style={style} />
}

export function SkeletonTable({ rows = 5, columns = 6 }: { rows?: number; columns?: number }) {
  return (
    <div className="skeleton-table">
      <div className="skeleton-table-header">
        {Array.from({ length: columns }).map((_, i) => (
          <SkeletonLoader key={i} height={20} width="100%" />
        ))}
      </div>
      {Array.from({ length: rows }).map((_, rowIdx) => (
        <div key={rowIdx} className="skeleton-table-row">
          {Array.from({ length: columns }).map((_, colIdx) => (
            <SkeletonLoader key={colIdx} height={16} width="100%" />
          ))}
        </div>
      ))}
    </div>
  )
}

export function SkeletonCard() {
  return (
    <div className="skeleton-card">
      <SkeletonLoader height={24} width="60%" variant="text" />
      <SkeletonLoader height={32} width="100%" className="skeleton-card-spacing" />
      <SkeletonLoader height={16} width="80%" variant="text" lines={2} />
    </div>
  )
}

