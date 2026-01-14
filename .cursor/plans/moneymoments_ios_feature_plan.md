# MoneyMoments Feature for iOS

## Overview

Create a MoneyMoments feature for iOS that displays behavioral insights (money moments) and personalized nudges based on spending patterns, wired to the backend API endpoints at `/v1/moneymoments/*`.

## Key Features

### 1. MoneyMoments Screen
- **Behavioral Insights Section**: Display computed money moments
  - Moment cards with:
    - Icon (based on habit_id)
    - Label and insight text
    - Value (formatted based on type: percentage, count, or currency)
    - Confidence badge (high/medium/low)
    - Habit ID
- **Compute Moments Button**: Trigger computation of moments for current month
- **Empty State**: Message when no moments are computed

### 2. Nudges Section
- **Recent Nudges List**: Display delivered nudges
  - Nudge cards with:
    - Rule name
    - Title and body (rendered templates)
    - CTA button (if available)
    - Sent date
    - Interaction tracking (view/click/dismiss)
- **Evaluate & Deliver Button**: Trigger nudge evaluation and delivery
- **Empty State**: Message when no nudges are delivered

### 3. Actions
- **Compute Moments**: POST to `/v1/moneymoments/moments/compute`
- **Evaluate Nudges**: POST to `/v1/moneymoments/nudges/evaluate`
- **Process Nudges**: POST to `/v1/moneymoments/nudges/process`
- **Compute Signal**: POST to `/v1/moneymoments/signals/compute` (optional, for nudge evaluation)

## Implementation Details

### Files to Create

1. **ios_monytix/ios_monytix/moneymoments/MoneyMomentsService.swift** (NEW)
   - API service for MoneyMoments endpoints
   - Methods: getMoments, computeMoments, getNudges, logNudgeInteraction, evaluateNudges, processNudges, computeSignal

2. **ios_monytix/ios_monytix/moneymoments/Models/MoneyMomentsModels.swift** (NEW)
   - MoneyMoment model
   - Nudge model
   - API response wrappers

3. **ios_monytix/ios_monytix/moneymoments/MoneyMomentsViewModel.swift** (NEW)
   - ViewModel for managing moments and nudges state
   - Data fetching, compute actions
   - Loading and error states

4. **ios_monytix/ios_monytix/moneymoments/MoneyMomentsView.swift** (NEW)
   - Main MoneyMoments screen
   - Shows moments and nudges sections
   - Action buttons for compute/evaluate

5. **ios_monytix/ios_monytix/moneymoments/Components/MoneyMomentCard.swift** (NEW)
   - Card component for displaying money moments
   - Icon, label, insight text, value, confidence badge

6. **ios_monytix/ios_monytix/moneymoments/Components/NudgeCard.swift** (NEW)
   - Card component for displaying nudges
   - Title, body, CTA button, interaction tracking

7. **ios_monytix/ios_monytix/ContentView.swift** (MODIFY)
   - Add MoneyMomentsView as new tab (or integrate into existing tab)

### Backend API Endpoints

- `GET /v1/moneymoments/moments?month=YYYY-MM` - Get money moments
- `POST /v1/moneymoments/moments/compute?target_month=YYYY-MM-DD` - Compute moments
- `GET /v1/moneymoments/nudges?limit=20` - Get recent nudges
- `POST /v1/moneymoments/nudges/{delivery_id}/interact` - Log nudge interaction
- `POST /v1/moneymoments/nudges/evaluate?as_of_date=YYYY-MM-DD` - Evaluate nudges
- `POST /v1/moneymoments/nudges/process?limit=10` - Process and deliver nudges
- `POST /v1/moneymoments/signals/compute?as_of_date=YYYY-MM-DD` - Compute signal

### Design Specifications

**Color Scheme:**
- Background: Dark charcoal (#2E2E2E)
- Accent: Gold (#D4AF37)
- Confidence Badges:
  - High (≥70%): Green
  - Medium (50-69%): Yellow
  - Low (<50%): Red/Orange
- Moment Icons: Based on habit_id type

**Layout Structure:**
```
MoneyMomentsView
  ├─ Header (Title, subtitle, action buttons)
  ├─ Behavioral Insights Section
  │   └─ MoneyMomentCard(s)
  └─ Nudges Section
      └─ NudgeCard(s)
```

**Components:**
- Reuse GlassCard for containers
- Confidence badges with color coding
- Action buttons for compute/evaluate
- Empty states for moments and nudges

### Data Flow

1. **Initial Load**:
   - Load money moments
   - Load recent nudges
   - Display moments and nudges

2. **Compute Moments Flow**:
   - User taps "Compute Moments"
   - Call compute API
   - Show success message
   - Reload moments

3. **Evaluate & Deliver Nudges Flow**:
   - User taps "Evaluate & Deliver Nudges"
   - Optionally compute signal
   - Evaluate nudges
   - Process and deliver nudges
   - Reload nudges list

4. **Nudge Interaction**:
   - Track view when nudge is displayed
   - Track click when CTA is tapped
   - Track dismiss when user dismisses

## Implementation Steps

1. Create MoneyMomentsModels with all data structures
2. Create MoneyMomentsService with API methods
3. Create MoneyMomentsViewModel for state management
4. Create MoneyMomentCard component
5. Create NudgeCard component
6. Create MoneyMomentsView (main screen)
7. Update ContentView to add MoneyMoments tab
8. Test API integration and error handling
9. Polish UI and animations

