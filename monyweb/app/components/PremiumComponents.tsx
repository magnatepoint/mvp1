/**
 * Premium Component Examples
 * Showcase of premium fintech UI components
 */

import React from 'react';

export function PremiumButton() {
  return (
    <button className="btn-premium">
      Premium Action
    </button>
  );
}

export function PremiumCard({ children, title }: { children: React.ReactNode; title?: string }) {
  return (
    <div className="card-premium">
      {title && <h3 className="text-xl font-semibold mb-4 text-text-primary">{title}</h3>}
      {children}
    </div>
  );
}

export function PremiumBadge({ children }: { children: React.ReactNode }) {
  return (
    <span className="badge-premium">
      {children}
    </span>
  );
}

export function PremiumInput({ placeholder, type = "text" }: { placeholder: string; type?: string }) {
  return (
    <input
      type={type}
      placeholder={placeholder}
      className="input-premium"
    />
  );
}

export function PremiumMetric({ value, label, trend }: { value: string; label: string; trend?: string }) {
  return (
    <div className="card-premium">
      <p className="text-sm text-text-secondary mb-2">{label}</p>
      <p className="number-premium text-4xl mb-2">{value}</p>
      {trend && (
        <p className="text-sm text-success flex items-center gap-1">
          <span>↑</span> {trend}
        </p>
      )}
    </div>
  );
}

export function PremiumStatusIndicator({ status = "active" }: { status?: "active" | "inactive" }) {
  return (
    <div className="flex items-center gap-2">
      <div className={`status-indicator ${status === "active" ? "bg-success" : "bg-error"}`}></div>
      <span className="text-sm text-text-secondary capitalize">{status}</span>
    </div>
  );
}

export function PremiumLoadingSkeleton() {
  return (
    <div className="space-y-4">
      <div className="skeleton h-8 w-3/4"></div>
      <div className="skeleton h-4 w-full"></div>
      <div className="skeleton h-4 w-5/6"></div>
    </div>
  );
}

export function PremiumDivider({ gold = false }: { gold?: boolean }) {
  return <div className={gold ? "divider-premium-gold" : "divider-premium"}></div>;
}

