# Budget Feature for iOS

## Overview

Create a Budget feature for iOS that integrates BudgetPilot (budget recommendations and commitment) and BudgetTracker (category-wise budget tracking) from the frontend, wired to the backend API endpoints at `/v1/budget/*`.

## Key Features

### 1. BudgetPilot Screen
- **Budget Recommendations**: Display top 3 budget plan recommendations
  - Plan name, description, score
  - Needs/Wants/Savings allocation percentages
  - Recommendation reason
  - Goal allocation preview
- **Committed Budget**: Display current committed budget if exists
  - Allocation percentages
  - Goal allocations list
- **Commit Action**: Allow user to commit to a budget plan

### 2. BudgetTracker Component (Optional - can be integrated into BudgetPilot or separate)
- **Category-wise Tracking**: Show budget vs spent for each category
- **Visual Charts**: Bar chart showing budget vs spent
- **Progress Indicators**: Progress bars with status (good/warning/exceeded)
- **Status Colors**: Green (good), Yellow (warning), Red (exceeded)

### 3. Budget Variance View
- **Actual vs Planned**: Show variance between actual spending and planned budget
- **Needs/Wants/Assets Comparison**: Display planned vs actual for each category
- **Variance Indicators**: Show positive/negative variances

## Implementation Details

### Files to Create

1. **ios_monytix/ios_monytix/budget/BudgetService.swift** (NEW)
   - API service for budget endpoints
   - Methods: getRecommendations, commitBudget, getCommittedBudget, getVariance

2. **ios_monytix/ios_monytix/budget/Models/BudgetModels.swift** (NEW)
   - BudgetRecommendation
   - GoalAllocationPreview
   - BudgetCommitRequest
   - GoalAllocation
   - CommittedBudget
   - BudgetVariance

3. **ios_monytix/ios_monytix/budget/BudgetViewModel.swift** (NEW)
   - ViewModel for managing budget state
   - Data fetching, commit actions
   - Loading and error states

4. **ios_monytix/ios_monytix/budget/BudgetPilotView.swift** (NEW)
   - Main BudgetPilot screen
   - Shows recommendations and committed budget
   - Handles commit action

5. **ios_monytix/ios_monytix/budget/Components/BudgetRecommendationCard.swift** (NEW)
   - Card component for displaying budget recommendations
   - Allocation visualization
   - Commit button

6. **ios_monytix/ios_monytix/budget/Components/CommittedBudgetCard.swift** (NEW)
   - Card component for displaying committed budget
   - Allocation summary
   - Goal allocations list

7. **ios_monytix/ios_monytix/budget/Components/BudgetAllocationBar.swift** (NEW)
   - Visual bar showing Needs/Wants/Savings allocation
   - Color-coded segments

8. **ios_monytix/ios_monytix/budget/Views/BudgetVarianceView.swift** (NEW)
   - View for displaying budget variance
   - Actual vs planned comparison

9. **ios_monytix/ios_monytix/ContentView.swift** (MODIFY)
   - Add BudgetPilotView as new tab (or integrate into existing tab)

### Backend API Endpoints

- `GET /v1/budget/recommendations?month=YYYY-MM` - Get budget recommendations
- `POST /v1/budget/commit` - Commit to a budget plan
- `GET /v1/budget/commit?month=YYYY-MM` - Get committed budget
- `GET /v1/budget/variance?month=YYYY-MM` - Get budget variance

### Design Specifications

**Color Scheme:**
- Background: Dark charcoal (#2E2E2E)
- Accent: Gold (#D4AF37)
- Needs: Blue/Green
- Wants: Orange/Yellow
- Savings: Green
- Exceeded: Red
- Warning: Yellow

**Layout Structure:**
```
BudgetPilotView
  ├─ Header (Title and subtitle)
  ├─ Committed Budget Section (if exists)
  │   └─ CommittedBudgetCard
  └─ Recommendations Section
      └─ BudgetRecommendationCard(s)
```

### Data Flow

1. **Initial Load**:
   - Load budget recommendations
   - Load committed budget (if exists)
   - Display recommendations with allocation bars

2. **Commit Flow**:
   - User selects a plan
   - Call commit API
   - Update committed budget display
   - Refresh recommendations

3. **Variance View**:
   - Load variance data
   - Display actual vs planned comparison
   - Show variance amounts

## Implementation Steps

1. Create BudgetModels with all data structures
2. Create BudgetService with API methods
3. Create BudgetViewModel for state management
4. Create BudgetRecommendationCard component
5. Create CommittedBudgetCard component
6. Create BudgetAllocationBar component
7. Create BudgetPilotView (main screen)
8. Create BudgetVarianceView (optional)
9. Update ContentView to add Budget tab
10. Test API integration and error handling
11. Polish UI and animations

