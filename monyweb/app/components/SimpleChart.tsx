'use client'

import { useMemo } from 'react'
import './SimpleChart.css'

type DataPoint = {
  date: string
  value: number
  label?: string
}

type SimpleChartProps = {
  data: DataPoint[]
  width?: number
  height?: number
  color?: string
  showGrid?: boolean
  showPoints?: boolean
}

export function SimpleLineChart({ 
  data, 
  width = 400, 
  height = 200, 
  color = 'var(--color-gold)',
  showGrid = true,
  showPoints = true,
}: SimpleChartProps) {
  // Filter out invalid values and ensure we have valid numbers
  const validData = useMemo(() => {
    return data.filter(d => typeof d.value === 'number' && !isNaN(d.value) && isFinite(d.value))
  }, [data])

  const { path, points, min, max, xScale, yScale } = useMemo(() => {
    if (validData.length === 0) {
      return { path: '', points: [], min: 0, max: 0, xScale: 0, yScale: 0 }
    }

    const padding = 40
    const chartWidth = width - padding * 2
    const chartHeight = height - padding * 2

    const values = validData.map(d => d.value)
    const min = Math.min(...values)
    const max = Math.max(...values)
    const range = max - min || 1

    const xScale = chartWidth / (validData.length - 1 || 1)
    const yScale = chartHeight / range

    let path = ''
    const points: Array<{ x: number; y: number; value: number }> = []

    validData.forEach((point, index) => {
      const x = padding + index * xScale
      const y = padding + chartHeight - (point.value - min) * yScale

      // Ensure x and y are valid numbers
      if (isNaN(x) || isNaN(y) || !isFinite(x) || !isFinite(y)) {
        return
      }

      if (index === 0) {
        path += `M ${x} ${y}`
      } else {
        path += ` L ${x} ${y}`
      }

      points.push({ x, y, value: point.value })
    })

    return { path, points, min, max, xScale, yScale }
  }, [validData, width, height])

  if (validData.length === 0) {
    return (
      <div className="simple-chart-empty">
        <p>No data available</p>
      </div>
    )
  }

  const pathLength = useMemo(() => {
    if (points.length < 2) return 0
    let length = 0
    for (let i = 1; i < points.length; i++) {
      const dx = points[i].x - points[i - 1].x
      const dy = points[i].y - points[i - 1].y
      const segmentLength = Math.sqrt(dx * dx + dy * dy)
      if (isNaN(segmentLength) || !isFinite(segmentLength)) continue
      length += segmentLength
    }
    return length || 0
  }, [points])

  return (
    <svg
      className="simple-chart"
      width={width}
      height={height}
      viewBox={`0 0 ${width} ${height}`}
    >
      {showGrid && (
        <g className="simple-chart-grid">
          {[0, 0.25, 0.5, 0.75, 1].map((ratio) => {
            const y = 40 + (height - 80) * (1 - ratio)
            return (
              <g key={ratio}>
                <line
                  x1={40}
                  y1={y}
                  x2={width - 40}
                  y2={y}
                  stroke="rgba(255, 255, 255, 0.05)"
                  strokeWidth="1"
                />
                <text
                  x={35}
                  y={y + 4}
                  fill="var(--color-muted)"
                  fontSize="10"
                  textAnchor="end"
                >
                  {Math.round(min + (max - min) * ratio).toLocaleString()}
                </text>
              </g>
            )
          })}
        </g>
      )}
      <path
        d={path}
        fill="none"
        stroke={color}
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
        className="simple-chart-line"
        strokeDasharray={pathLength}
        strokeDashoffset={pathLength}
        style={{
          animation: `chart-line-draw 1.2s ease-out forwards`,
        }}
      />
      {showPoints &&
        points.map((point, index) => (
          <circle
            key={index}
            cx={point.x}
            cy={point.y}
            r="4"
            fill={color}
            className="simple-chart-point"
            style={{
              animationDelay: `${0.8 + index * 0.05}s`,
            }}
          />
        ))}
      {validData.map((point, index) => {
        const x = 40 + index * xScale
        if (isNaN(x) || !isFinite(x)) return null
        return (
          <text
            key={index}
            x={x}
            y={height - 10}
            fill="var(--color-muted)"
            fontSize="9"
            textAnchor="middle"
            className="simple-chart-label"
          >
            {point.label || (point.date ? new Date(point.date).toLocaleDateString('en-IN', { month: 'short' }) : '')}
          </text>
        )
      })}
    </svg>
  )
}

type SparklineProps = {
  data: number[]
  width?: number
  height?: number
  color?: string
}

export function Sparkline({ data, width = 100, height = 30, color = 'var(--color-teal)' }: SparklineProps) {
  const { path, pathLength, points } = useMemo(() => {
    if (data.length === 0) return { path: '', pathLength: 0, points: [] }

    const padding = 2
    const chartWidth = width - padding * 2
    const chartHeight = height - padding * 2

    const min = Math.min(...data)
    const max = Math.max(...data)
    const range = max - min || 1

    const xScale = chartWidth / (data.length - 1 || 1)
    const yScale = chartHeight / range

    let pathStr = ''
    const points: Array<{ x: number; y: number }> = []
    
    data.forEach((value, index) => {
      const x = padding + index * xScale
      const y = padding + chartHeight - (value - min) * yScale

      if (index === 0) {
        pathStr += `M ${x} ${y}`
      } else {
        pathStr += ` L ${x} ${y}`
      }
      
      points.push({ x, y })
    })

    // Calculate approximate path length for animation
    let pathLength = 0
    for (let i = 1; i < points.length; i++) {
      const dx = points[i].x - points[i - 1].x
      const dy = points[i].y - points[i - 1].y
      pathLength += Math.sqrt(dx * dx + dy * dy)
    }

    return { path: pathStr, pathLength, points }
  }, [data, width, height])

  if (data.length === 0) return null

  return (
    <svg width={width} height={height} viewBox={`0 0 ${width} ${height}`} className="sparkline">
      <defs>
        <linearGradient id={`sparkline-gradient-${color}`} x1="0%" y1="0%" x2="100%" y2="0%">
          <stop offset="0%" stopColor={color} stopOpacity="0.3" />
          <stop offset="100%" stopColor={color} stopOpacity="1" />
        </linearGradient>
      </defs>
      <path
        d={path}
        fill="none"
        stroke={color}
        strokeWidth="1.5"
        strokeLinecap="round"
        strokeLinejoin="round"
        strokeDasharray={pathLength}
        strokeDashoffset={pathLength}
        className="sparkline-path"
        style={{
          animation: `sparkline-draw 1.5s ease-out forwards`,
        }}
      />
      {points.map((point, index) => (
        <circle
          key={index}
          cx={point.x}
          cy={point.y}
          r="1.5"
          fill={color}
          className="sparkline-point"
          style={{
            animation: `sparkline-point-appear 0.3s ease-out ${index * 0.1}s forwards`,
            opacity: 0,
          }}
        />
      ))}
    </svg>
  )
}

