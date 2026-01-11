"""Pydantic models for Goals API."""

from datetime import date
from typing import Any, Literal
from uuid import UUID

from pydantic import BaseModel, Field, field_validator


RiskProfile = Literal["conservative", "balanced", "aggressive"]
TimelineFlexibility = Literal["rigid", "somewhat_flexible", "flexible"]
ReviewFrequency = Literal["monthly", "quarterly", "yearly"]


class LifeContextRequest(BaseModel):
    """Life context questionnaire data."""

    age_band: str = Field(..., description="Age range: 18-24, 25-34, 35-44, 45-54, 55+")
    dependents_spouse: bool = Field(default=False, description="Has spouse/partner")
    dependents_children_count: int = Field(default=0, ge=0, description="Number of children")
    dependents_parents_care: bool = Field(default=False, description="Caring for parents")
    housing: str = Field(..., description="Housing status: rent, own_mortgage, own_nomortgage, living_with_parents")
    employment: str = Field(
        ...,
        description="Employment type: salaried, self_employed, student, homemaker, retired",
    )
    income_regularity: str = Field(
        ..., description="Income stability: very_stable, stable, variable"
    )
    region_code: str = Field(..., description="Region code (e.g., IN-KA, IN-TG)")
    emergency_opt_out: bool = Field(
        default=False, description="Opt out of emergency fund goal"
    )

    # Financial capacity (user-input or inferred)
    monthly_investible_capacity: float | None = Field(
        default=None,
        ge=0,
        description="Estimated monthly amount available for goals after expenses & EMIs",
    )
    total_monthly_emi_obligations: float | None = Field(
        default=None,
        ge=0,
        description="Approximate total of EMIs per month (loans, credit cards, etc.)",
    )

    # Overall risk & behavior preferences
    risk_profile_overall: RiskProfile | None = Field(
        default=None,
        description="Overall risk profile: conservative, balanced, aggressive",
    )
    review_frequency: ReviewFrequency | None = Field(
        default="quarterly", description="How often user wants to review goals"
    )
    notify_on_drift: bool = Field(
        default=True, description="Alert user when they fall behind the goal plan"
    )
    auto_adjust_on_income_change: bool = Field(
        default=False,
        description="Auto-suggest increasing contributions when income increases",
    )

    @field_validator("age_band")
    @classmethod
    def validate_age_band(cls, v: str) -> str:
        """Validate age band."""
        allowed = {"18-24", "25-34", "35-44", "45-54", "55+"}
        if v not in allowed:
            raise ValueError(f"age_band must be one of {allowed}")
        return v

    @field_validator("housing")
    @classmethod
    def validate_housing(cls, v: str) -> str:
        """Validate housing status."""
        allowed = {"rent", "own_mortgage", "own_nomortgage", "living_with_parents"}
        if v not in allowed:
            raise ValueError(f"housing must be one of {allowed}")
        return v

    @field_validator("employment")
    @classmethod
    def validate_employment(cls, v: str) -> str:
        """Validate employment type."""
        allowed = {"salaried", "self_employed", "student", "homemaker", "retired"}
        if v not in allowed:
            raise ValueError(f"employment must be one of {allowed}")
        return v

    @field_validator("income_regularity")
    @classmethod
    def validate_income_regularity(cls, v: str) -> str:
        """Validate income regularity."""
        allowed = {"very_stable", "stable", "variable"}
        if v not in allowed:
            raise ValueError(f"income_regularity must be one of {allowed}")
        return v


class GoalDetailRequest(BaseModel):
    """Goal detail form data."""

    goal_category: str = Field(..., description="Goal category (e.g., Emergency, Insurance)")
    goal_name: str = Field(..., description="Goal name (e.g., Emergency Fund)")
    estimated_cost: float = Field(..., gt=0, description="Target amount in INR")
    target_date: date | None = Field(None, description="Target completion date")
    current_savings: float = Field(default=0.0, ge=0, description="Current savings amount")
    importance: int = Field(..., ge=1, le=5, description="Importance rating (1-5)")
    notes: str | None = Field(None, description="Optional notes")

    # Per-goal risk and flexibility
    risk_profile_for_goal: RiskProfile | None = Field(
        default=None,
        description="Risk profile for this specific goal (if different from overall)",
    )
    is_must_have: bool = Field(
        default=True,
        description="True if this is a non-negotiable goal vs good-to-have",
    )
    timeline_flexibility: TimelineFlexibility | None = Field(
        default="somewhat_flexible",
        description="Flexibility of the target date for this goal",
    )


class GoalsSubmitRequest(BaseModel):
    """Complete goals submission with context and selected goals."""

    context: LifeContextRequest
    selected_goals: list[GoalDetailRequest] = Field(default_factory=list)


class GoalResponse(BaseModel):
    """Goal response model."""

    goal_id: UUID
    goal_category: str
    goal_name: str
    goal_type: str
    linked_txn_type: str | None
    estimated_cost: float
    target_date: date | None
    current_savings: float
    importance: int | None
    priority_rank: int | None
    status: str
    notes: str | None
    created_at: str
    updated_at: str


class GoalCatalogItem(BaseModel):
    """Goal catalog item from master."""

    goal_category: str
    goal_name: str
    default_horizon: str
    policy_linked_txn_type: str
    is_mandatory_flag: bool
    suggested_min_amount_formula: str | None
    display_order: int


class GoalsSubmitResponse(BaseModel):
    """Response after submitting goals."""

    goals_created: list[dict[str, Any]] = Field(
        ..., description="List of created goals with goal_id and priority_rank"
    )


class GoalUpdateRequest(BaseModel):
    """Request to update a goal."""

    estimated_cost: float | None = Field(None, gt=0)
    target_date: date | None = None
    current_savings: float | None = Field(None, ge=0)
    importance: int | None = Field(None, ge=1, le=5)
    notes: str | None = None
    is_must_have: bool | None = None
    timeline_flexibility: TimelineFlexibility | None = None
    risk_profile_for_goal: RiskProfile | None = None


class GoalProgressItem(BaseModel):
    """Goal progress item for progress endpoint."""

    goal_id: UUID
    goal_name: str
    progress_pct: float = Field(..., description="Progress percentage (0-100)")
    current_savings_close: float = Field(..., description="Current total savings")
    remaining_amount: float = Field(..., description="Remaining amount to reach goal")
    projected_completion_date: date | None = Field(None, description="Projected completion date")
    milestones: list[int] = Field(default_factory=list, description="List of milestone percentages achieved (e.g., [25, 50])")


class GoalsProgressResponse(BaseModel):
    """Response for goals progress endpoint."""

    goals: list[GoalProgressItem]

