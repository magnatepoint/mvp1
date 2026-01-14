---
name: SpendSense iOS Screen
overview: Create an innovative SpendSense screen for iOS with modern SwiftUI design, featuring three tabs (KPIs, Insights, Transactions), interactive charts, glass morphism cards, and file upload functionality. The design will use dark charcoal theme with gold accents, smooth animations, and a premium feel.
todos:
  - id: create_models
    content: Create SpendSenseModels.swift with KPIs, Transaction, Insight, ChartData, and related structs
    status: completed
  - id: create_service
    content: Create SpendSenseService.swift with API methods for KPIs, insights, transactions, and file upload
    status: completed
    dependencies:
      - create_models
  - id: create_glass_card
    content: Create GlassCard component with blur effect, gold border, and shadow
    status: completed
  - id: create_kpi_card
    content: Create KPICard component with animated values, icon, and gradient background
    status: completed
    dependencies:
      - create_glass_card
  - id: create_pie_chart
    content: Create ExpensePieChart using SwiftUI Charts with interactive segments and legend
    status: completed
    dependencies:
      - create_models
  - id: create_wants_gauge
    content: Create WantsGaugeView with circular progress, percentage display, and threshold colors
    status: completed
    dependencies:
      - create_glass_card
  - id: create_kpis_tab
    content: Build KPIsTabView with month filter, KPI cards, pie chart, gauge, and top categories
    status: completed
    dependencies:
      - create_kpi_card
      - create_pie_chart
      - create_wants_gauge
      - create_service
  - id: create_category_progress
    content: Create CategoryProgressBar component with animated progress and percentage
    status: completed
    dependencies:
      - create_glass_card
  - id: create_insights_tab
    content: Build InsightsTabView with category breakdown and recurring transactions
    status: completed
    dependencies:
      - create_category_progress
      - create_service
  - id: create_transaction_row
    content: Create TransactionRow with avatar, swipe actions, and color-coded amounts
    status: completed
    dependencies:
      - create_models
  - id: create_file_upload
    content: Create FileUploadCard with drag-drop, file picker, progress indicator, and PDF password field
    status: completed
    dependencies:
      - create_glass_card
  - id: create_transactions_tab
    content: Build TransactionsTabView with upload section, transaction list, and pagination
    status: completed
    dependencies:
      - create_transaction_row
      - create_file_upload
      - create_service
  - id: create_main_view
    content: Create SpendSenseView with custom tab bar, pull-to-refresh, and tab switching
    status: completed
    dependencies:
      - create_kpis_tab
      - create_insights_tab
      - create_transactions_tab
  - id: add_animations
    content: Add fade-in, slide-up animations, spring transitions, and value counting animations
    status: completed
    dependencies:
      - create_main_view
  - id: integrate_navigation
    content: Integrate SpendSenseView into main app navigation and update ContentView
    status: completed
    dependencies:
      - create_main_view
---

# SpendSense

iOS Screen Implementation

## Overview

Create a premium SpendSense screen matching the Flutter app's functionality with an innovative iOS-native design using SwiftUI, Charts framework, and modern UI patterns.

## Architecture

### 1. Data Models (`SpendSenseModels.swift`)

- `SpendSenseKPIs`: Income, needs, wants, assets amounts, wants_gauge, top_categories
- `Transaction`: Merchant, category, amount, date, direction
- `Insight`: Category breakdown, recurring transactions
- `ChartData`: For pie chart visualization
- `WantsGauge`: Ratio, threshold_crossed, label
- `CategoryBreakdown`: Category name, amount, percentage, transaction_count

### 2. API Service (`SpendSenseService.swift`)

- `getKPIs(month:)` - Fetch KPIs with optional month filter
- `getAvailableMonths()` - Get list of available months
- `getInsights()` - Fetch insights data
- `getTransactions(limit:offset:)` - Fetch paginated transactions
- `uploadFile(file:password:onProgress:)` - Upload statement files
- Uses `AuthService.supabase` for authenticated requests to backend API

### 3. Main Screen (`SpendSenseView.swift`)

- Custom segmented control for tabs (KPIs, Insights, Transactions)
- Pull-to-refresh functionality
- Loading states with shimmer effects
- Error handling with retry options
- Month filter picker (when available)

### 4. Tab Views

#### KPIs Tab (`KPIsTabView.swift`)

- **Glass morphism cards** for Income, Needs, Wants, Assets
- **Interactive pie chart** using SwiftUI Charts for expense breakdown
- **Circular gauge** for Wants vs Needs ratio with animated progress
- **Top categories list** with expandable cards
- Month filter dropdown with custom styling
- Smooth fade-in animations

#### Insights Tab (`InsightsTabView.swift`)

- **Category breakdown** with animated progress bars
- **Recurring transactions** list with frequency indicators
- Glass cards with gradient overlays
- Swipe gestures for interactions

#### Transactions Tab (`TransactionsTabView.swift`)

- **File upload section** with drag-and-drop support
- **PDF password field** (optional)
- **Upload progress** with animated progress bar
- **Transaction list** with:
- Swipe actions (categorize, delete)
- Color-coded amounts (green/red)
- Merchant avatars with initials
- Category badges
- Date formatting
- **Pagination controls** with smooth page transitions

### 5. Custom Components

#### `GlassCard.swift`

- Blur background effect
- Subtle border with gold accent
- Shadow effects
- Configurable padding and corner radius

#### `KPICard.swift`

- Large number display with currency formatting
- Icon with gradient background
- Animated value changes
- Tap interactions

#### `ExpensePieChart.swift`

- SwiftUI Charts implementation
- Interactive segments
- Legend with percentages
- Smooth animations

#### `WantsGaugeView.swift`

- Circular progress indicator
- Center percentage display
- Color changes based on threshold
- Animated value updates

#### `CategoryProgressBar.swift`

- Animated progress bar
- Category name and amount
- Percentage display
- Gold accent color

#### `TransactionRow.swift`

- Merchant name with avatar
- Category and subcategory display
- Amount with color coding
- Date formatting
- Swipe actions

#### `FileUploadCard.swift`

- Drag-and-drop zone
- File picker button
- Progress indicator
- Error display
- PDF password input

### 6. Design Features

**Color Palette:**

- Background: Dark charcoal (#2E2E2E, #262626)
- Accent: Gold (#D4AF37)
- Income: Green (#4CAF50)
- Needs: Orange (#FF9800)
- Wants: Purple (#9C27B0)
- Assets: Blue (#2196F3)
- Debit: Red (#F44336)
- Credit: Green (#4CAF50)

**Animations:**

- Fade-in slide-up for cards
- Spring animations for value changes
- Smooth tab transitions
- Pull-to-refresh bounce
- Progress bar animations
- Chart segment animations

**Layout:**

- Spacing: 16px between cards, 12px within cards
- Corner radius: 16px for cards, 12px for buttons
- Padding: 20px screen edges, 16px card padding
- Typography: SF Pro with varying weights

### 7. Integration Points

- **AuthManager**: Access authenticated user session
- **Config**: Backend API base URL
- **Supabase**: For authenticated API calls (if needed)
- **SwiftUI Charts**: For visualizations
- **UniformTypeIdentifiers**: For file picker

### 8. File Structure

```javascript
ios_monytix/
├── SpendSenseView.swift (main screen)
├── Views/
│   ├── KPIsTabView.swift
│   ├── InsightsTabView.swift
│   └── TransactionsTabView.swift
├── Components/
│   ├── GlassCard.swift
│   ├── KPICard.swift
│   ├── ExpensePieChart.swift
│   ├── WantsGaugeView.swift
│   ├── CategoryProgressBar.swift
│   ├── TransactionRow.swift
│   └── FileUploadCard.swift
├── Services/
│   └── SpendSenseService.swift
└── Models/
    └── SpendSenseModels.swift
```



## Implementation Order

1. Create data models
2. Create API service with authentication
3. Build custom components (GlassCard, KPICard)
4. Implement KPIs tab with charts
5. Implement Insights tab
6. Implement Transactions tab with file upload
7. Integrate into main navigation
8. Add animations and polish

## Key Innovations

1. **Glass Morphism**: Modern blur effects on cards
2. **Interactive Charts**: Tap to highlight segments
3. **Swipe Actions**: Quick actions on transactions
4. **Drag & Drop**: File upload with visual feedback
5. **Shimmer Loading**: Premium loading states
6. **Animated Values**: Numbers count up on load
7. **Custom Tab Bar**: Gold-accented segmented control
8. **Gradient Overlays**: Subtle gradients on cards