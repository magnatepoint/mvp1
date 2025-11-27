/**
 * Fintech AI Theme Configuration
 * Modern, Premium, Readable color system with gold accents
 */

export const theme = {
  colors: {
    // Primary - Trust Blue
    primary: {
      DEFAULT: 'var(--color-primary)',
      foreground: 'var(--color-primary-foreground)',
      hover: 'var(--color-primary-hover)',
      light: 'var(--color-primary-light)',
    },
    
    // Premium Gold
    gold: {
      DEFAULT: 'var(--color-gold)',
      foreground: 'var(--color-gold-foreground)',
      hover: 'var(--color-gold-hover)',
      light: 'var(--color-gold-light)',
    },
    
    // AI Accent - Cyan/Teal
    ai: {
      DEFAULT: 'var(--color-ai-accent)',
      foreground: 'var(--color-ai-accent-foreground)',
      hover: 'var(--color-ai-accent-hover)',
      light: 'var(--color-ai-accent-light)',
    },
    
    // Status Colors
    success: {
      DEFAULT: 'var(--color-success)',
      foreground: 'var(--color-success-foreground)',
      light: 'var(--color-success-light)',
    },
    
    warning: {
      DEFAULT: 'var(--color-warning)',
      foreground: 'var(--color-warning-foreground)',
      light: 'var(--color-warning-light)',
    },
    
    error: {
      DEFAULT: 'var(--color-error)',
      foreground: 'var(--color-error-foreground)',
      light: 'var(--color-error-light)',
    },
    
    // Accent Purple
    accent: {
      DEFAULT: 'var(--color-accent)',
      foreground: 'var(--color-accent-foreground)',
      light: 'var(--color-accent-light)',
    },
    
    // Base Colors
    background: 'var(--color-background)',
    foreground: 'var(--color-foreground)',
    card: 'var(--color-card)',
    cardForeground: 'var(--color-card-foreground)',
    border: 'var(--color-border)',
    input: 'var(--color-input)',
    ring: 'var(--color-ring)',
    
    // Text Colors
    text: {
      primary: 'var(--color-text-primary)',
      secondary: 'var(--color-text-secondary)',
      tertiary: 'var(--color-text-tertiary)',
    },
    
    // Neutral Colors
    muted: {
      DEFAULT: 'var(--color-muted)',
      foreground: 'var(--color-muted-foreground)',
    },
    
    secondary: {
      DEFAULT: 'var(--color-secondary)',
      foreground: 'var(--color-secondary-foreground)',
    },
  },
  
  // Typography
  typography: {
    fontSans: 'var(--font-sans)',
    fontMono: 'var(--font-mono)',
  },
  
  // Shadows
  shadows: {
    sm: 'var(--shadow-sm)',
    DEFAULT: 'var(--shadow)',
    md: 'var(--shadow-md)',
    lg: 'var(--shadow-lg)',
    gold: 'var(--shadow-gold)',
  },
} as const;

/**
 * Tailwind CSS class utilities for common fintech patterns
 */
export const fintechClasses = {
  // Premium Gold Button
  btnGold: 'bg-gold text-gold-foreground hover:bg-gold-hover shadow-gold font-semibold',
  
  // Primary Button
  btnPrimary: 'bg-primary text-primary-foreground hover:bg-primary-hover font-semibold',
  
  // AI Accent Button
  btnAI: 'bg-ai-accent text-ai-accent-foreground hover:bg-ai-accent-hover font-semibold',
  
  // Premium Card with Gold Border
  cardPremium: 'bg-card border-2 border-gold shadow-lg rounded-xl p-6',
  
  // Glass Card
  cardGlass: 'glass rounded-xl p-6 shadow-md',
  
  // Financial Metric Card
  metricCard: 'bg-card border border-border rounded-lg p-4 shadow-sm hover:shadow-md transition-shadow',
  
  // Success Badge
  badgeSuccess: 'bg-success-light text-success px-3 py-1 rounded-full text-sm font-medium',
  
  // Warning Badge
  badgeWarning: 'bg-warning-light text-warning px-3 py-1 rounded-full text-sm font-medium',
  
  // Error Badge
  badgeError: 'bg-error-light text-error px-3 py-1 rounded-full text-sm font-medium',
  
  // Gold Badge (Premium)
  badgeGold: 'bg-gold-light text-gold px-3 py-1 rounded-full text-sm font-medium',
} as const;

