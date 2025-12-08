"""
Merchant Management API (CRUD + Aliases)

Provides endpoints for managing dim_merchant and merchant_alias tables.
Uses asyncpg (not SQLAlchemy) to match existing codebase patterns.
"""

from __future__ import annotations

from datetime import datetime
from typing import List, Optional
from uuid import UUID, uuid4

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field

from app.auth.dependencies import get_current_user
from app.auth.models import AuthenticatedUser
from app.dependencies.database import get_db_pool
from asyncpg import Pool

router = APIRouter(prefix="/merchants", tags=["Merchants"])

# ============================================================================
# Pydantic Schemas
# ============================================================================


class MerchantBase(BaseModel):
    merchant_code: str = Field(..., max_length=100)
    merchant_name: str = Field(..., max_length=255)
    website: Optional[str] = None
    merchant_type: Optional[str] = None
    category_code: str
    subcategory_code: Optional[str] = None
    brand_keywords: List[str] = Field(default_factory=list)
    country_code: str = "IN"
    active: bool = True


class MerchantCreate(MerchantBase):
    pass


class MerchantUpdate(BaseModel):
    merchant_name: Optional[str] = None
    website: Optional[str] = None
    merchant_type: Optional[str] = None
    category_code: Optional[str] = None
    subcategory_code: Optional[str] = None
    brand_keywords: Optional[List[str]] = None
    country_code: Optional[str] = None
    active: Optional[bool] = None


class MerchantResponse(MerchantBase):
    merchant_id: str
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class AliasCreate(BaseModel):
    alias: str


class AliasResponse(BaseModel):
    alias_id: str
    merchant_id: str
    alias: str
    normalized_alias: str
    active: bool
    created_at: datetime

    class Config:
        from_attributes = True


# ============================================================================
# Helpers
# ============================================================================


def _normalize_name(s: str) -> str:
    """Normalize merchant name for consistent matching."""
    return " ".join(s.lower().strip().split())


# ============================================================================
# CRUD Endpoints
# ============================================================================


@router.get("/", response_model=List[MerchantResponse])
async def list_merchants(
    q: Optional[str] = Query(None, description="Search by name/code"),
    active: Optional[bool] = Query(None),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=500),
    user: AuthenticatedUser = Depends(get_current_user),
    pool: Pool = Depends(get_db_pool),
):
    """List merchants with optional search and filtering."""
    conn = await pool.acquire()
    try:
        query = """
            SELECT 
                merchant_id,
                merchant_code,
                merchant_name,
                normalized_name,
                brand_keywords,
                category_code,
                subcategory_code,
                website,
                merchant_type,
                country_code,
                active,
                created_at,
                updated_at
            FROM spendsense.dim_merchant
            WHERE 1=1
        """
        params = []
        param_idx = 1

        if active is not None:
            query += f" AND active = ${param_idx}"
            params.append(active)
            param_idx += 1

        if q:
            q_norm = f"%{q.lower()}%"
            query += f" AND (normalized_name ILIKE ${param_idx} OR merchant_code ILIKE ${param_idx})"
            params.append(q_norm)
            param_idx += 1

        query += " ORDER BY merchant_name ASC"
        query += f" OFFSET ${param_idx} LIMIT ${param_idx + 1}"
        params.extend([skip, limit])

        rows = await conn.fetch(query, *params)
        return [
            MerchantResponse(
                merchant_id=str(row["merchant_id"]),
                merchant_code=row["merchant_code"],
                merchant_name=row["merchant_name"],
                website=row["website"],
                merchant_type=row["merchant_type"],
                category_code=row["category_code"],
                subcategory_code=row["subcategory_code"],
                brand_keywords=row["brand_keywords"] or [],
                country_code=row["country_code"],
                active=row["active"],
                created_at=row["created_at"],
                updated_at=row["updated_at"],
            )
            for row in rows
        ]
    finally:
        await pool.release(conn)


@router.post("/", response_model=MerchantResponse, status_code=201)
async def create_merchant(
    data: MerchantCreate,
    user: AuthenticatedUser = Depends(get_current_user),
    pool: Pool = Depends(get_db_pool),
):
    """Create a new merchant."""
    conn = await pool.acquire()
    try:
        # Check uniqueness
        existing = await conn.fetchrow(
            "SELECT merchant_id FROM spendsense.dim_merchant WHERE merchant_code = $1",
            data.merchant_code,
        )
        if existing:
            raise HTTPException(
                status_code=400,
                detail=f"Merchant code '{data.merchant_code}' already exists",
            )

        # Validate category exists
        category = await conn.fetchrow(
            "SELECT category_code FROM spendsense.dim_category WHERE category_code = $1",
            data.category_code,
        )
        if not category:
            raise HTTPException(
                status_code=400,
                detail=f"Category '{data.category_code}' does not exist",
            )

        # Validate subcategory if provided
        if data.subcategory_code:
            subcategory = await conn.fetchrow(
                "SELECT subcategory_code FROM spendsense.dim_subcategory WHERE subcategory_code = $1",
                data.subcategory_code,
            )
            if not subcategory:
                raise HTTPException(
                    status_code=400,
                    detail=f"Subcategory '{data.subcategory_code}' does not exist",
                )

        normalized_name = _normalize_name(data.merchant_name)
        brand_keywords = data.brand_keywords or [normalized_name]

        row = await conn.fetchrow(
            """
            INSERT INTO spendsense.dim_merchant (
                merchant_code, merchant_name, normalized_name, brand_keywords,
                category_code, subcategory_code, website, merchant_type,
                country_code, active
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
            RETURNING 
                merchant_id, merchant_code, merchant_name, normalized_name,
                brand_keywords, category_code, subcategory_code, website,
                merchant_type, country_code, active, created_at, updated_at
            """,
            data.merchant_code,
            data.merchant_name,
            normalized_name,
            brand_keywords,
            data.category_code,
            data.subcategory_code,
            data.website,
            data.merchant_type,
            data.country_code,
            data.active,
        )

        # Auto-create aliases from brand_keywords
        for keyword in brand_keywords:
            norm_alias = _normalize_name(keyword)
            await conn.execute(
                """
                INSERT INTO spendsense.merchant_alias (merchant_id, alias, normalized_alias)
                VALUES ($1, $2, $3)
                ON CONFLICT (merchant_id, normalized_alias) DO NOTHING
                """,
                row["merchant_id"],
                keyword,
                norm_alias,
            )

        return MerchantResponse(
            merchant_id=str(row["merchant_id"]),
            merchant_code=row["merchant_code"],
            merchant_name=row["merchant_name"],
            website=row["website"],
            merchant_type=row["merchant_type"],
            category_code=row["category_code"],
            subcategory_code=row["subcategory_code"],
            brand_keywords=row["brand_keywords"] or [],
            country_code=row["country_code"],
            active=row["active"],
            created_at=row["created_at"],
            updated_at=row["updated_at"],
        )
    finally:
        await pool.release(conn)


@router.get("/{merchant_id}", response_model=MerchantResponse)
async def get_merchant(
    merchant_id: str,
    user: AuthenticatedUser = Depends(get_current_user),
    pool: Pool = Depends(get_db_pool),
):
    """Get a merchant by ID."""
    conn = await pool.acquire()
    try:
        mid = UUID(merchant_id)
        row = await conn.fetchrow(
            """
            SELECT 
                merchant_id, merchant_code, merchant_name, normalized_name,
                brand_keywords, category_code, subcategory_code, website,
                merchant_type, country_code, active, created_at, updated_at
            FROM spendsense.dim_merchant
            WHERE merchant_id = $1
            """,
            mid,
        )
        if not row:
            raise HTTPException(status_code=404, detail="Merchant not found")

        return MerchantResponse(
            merchant_id=str(row["merchant_id"]),
            merchant_code=row["merchant_code"],
            merchant_name=row["merchant_name"],
            website=row["website"],
            merchant_type=row["merchant_type"],
            category_code=row["category_code"],
            subcategory_code=row["subcategory_code"],
            brand_keywords=row["brand_keywords"] or [],
            country_code=row["country_code"],
            active=row["active"],
            created_at=row["created_at"],
            updated_at=row["updated_at"],
        )
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid merchant_id format")
    finally:
        await pool.release(conn)


@router.patch("/{merchant_id}", response_model=MerchantResponse)
async def update_merchant(
    merchant_id: str,
    data: MerchantUpdate,
    user: AuthenticatedUser = Depends(get_current_user),
    pool: Pool = Depends(get_db_pool),
):
    """Update a merchant."""
    conn = await pool.acquire()
    try:
        mid = UUID(merchant_id)
        row = await conn.fetchrow(
            "SELECT merchant_id FROM spendsense.dim_merchant WHERE merchant_id = $1",
            mid,
        )
        if not row:
            raise HTTPException(status_code=404, detail="Merchant not found")

        # Build update query dynamically
        updates = []
        params = []
        param_idx = 1

        if data.merchant_name is not None:
            normalized_name = _normalize_name(data.merchant_name)
            updates.append(f"merchant_name = ${param_idx}")
            params.append(data.merchant_name)
            param_idx += 1
            updates.append(f"normalized_name = ${param_idx}")
            params.append(normalized_name)
            param_idx += 1

        if data.website is not None:
            updates.append(f"website = ${param_idx}")
            params.append(data.website)
            param_idx += 1

        if data.merchant_type is not None:
            updates.append(f"merchant_type = ${param_idx}")
            params.append(data.merchant_type)
            param_idx += 1

        if data.category_code is not None:
            # Validate category exists
            category = await conn.fetchrow(
                "SELECT category_code FROM spendsense.dim_category WHERE category_code = $1",
                data.category_code,
            )
            if not category:
                raise HTTPException(
                    status_code=400,
                    detail=f"Category '{data.category_code}' does not exist",
                )
            updates.append(f"category_code = ${param_idx}")
            params.append(data.category_code)
            param_idx += 1

        if data.subcategory_code is not None:
            # Validate subcategory exists
            if data.subcategory_code:
                subcategory = await conn.fetchrow(
                    "SELECT subcategory_code FROM spendsense.dim_subcategory WHERE subcategory_code = $1",
                    data.subcategory_code,
                )
                if not subcategory:
                    raise HTTPException(
                        status_code=400,
                        detail=f"Subcategory '{data.subcategory_code}' does not exist",
                    )
            updates.append(f"subcategory_code = ${param_idx}")
            params.append(data.subcategory_code)
            param_idx += 1

        if data.brand_keywords is not None:
            updates.append(f"brand_keywords = ${param_idx}")
            params.append(data.brand_keywords)
            param_idx += 1

        if data.country_code is not None:
            updates.append(f"country_code = ${param_idx}")
            params.append(data.country_code)
            param_idx += 1

        if data.active is not None:
            updates.append(f"active = ${param_idx}")
            params.append(data.active)
            param_idx += 1

        if not updates:
            # No updates, return current row
            row = await conn.fetchrow(
                """
                SELECT 
                    merchant_id, merchant_code, merchant_name, normalized_name,
                    brand_keywords, category_code, subcategory_code, website,
                    merchant_type, country_code, active, created_at, updated_at
                FROM spendsense.dim_merchant
                WHERE merchant_id = $1
                """,
                mid,
            )
        else:
            updates.append(f"updated_at = NOW()")
            params.append(mid)
            query = f"""
                UPDATE spendsense.dim_merchant
                SET {', '.join(updates)}
                WHERE merchant_id = ${param_idx}
                RETURNING 
                    merchant_id, merchant_code, merchant_name, normalized_name,
                    brand_keywords, category_code, subcategory_code, website,
                    merchant_type, country_code, active, created_at, updated_at
            """
            row = await conn.fetchrow(query, *params)

        return MerchantResponse(
            merchant_id=str(row["merchant_id"]),
            merchant_code=row["merchant_code"],
            merchant_name=row["merchant_name"],
            website=row["website"],
            merchant_type=row["merchant_type"],
            category_code=row["category_code"],
            subcategory_code=row["subcategory_code"],
            brand_keywords=row["brand_keywords"] or [],
            country_code=row["country_code"],
            active=row["active"],
            created_at=row["created_at"],
            updated_at=row["updated_at"],
        )
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid merchant_id format")
    finally:
        await pool.release(conn)


@router.post("/{merchant_id}/archive")
async def archive_merchant(
    merchant_id: str,
    user: AuthenticatedUser = Depends(get_current_user),
    pool: Pool = Depends(get_db_pool),
):
    """Soft-delete merchant (set active = false)."""
    conn = await pool.acquire()
    try:
        mid = UUID(merchant_id)
        row = await conn.fetchrow(
            "SELECT merchant_id FROM spendsense.dim_merchant WHERE merchant_id = $1",
            mid,
        )
        if not row:
            raise HTTPException(status_code=404, detail="Merchant not found")

        await conn.execute(
            "UPDATE spendsense.dim_merchant SET active = FALSE, updated_at = NOW() WHERE merchant_id = $1",
            mid,
        )

        return {"status": "ok", "merchant_id": merchant_id, "active": False}
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid merchant_id format")
    finally:
        await pool.release(conn)


# ============================================================================
# Alias Management
# ============================================================================


@router.get("/{merchant_id}/aliases", response_model=List[AliasResponse])
async def list_aliases(
    merchant_id: str,
    user: AuthenticatedUser = Depends(get_current_user),
    pool: Pool = Depends(get_db_pool),
):
    """List aliases for a merchant."""
    conn = await pool.acquire()
    try:
        mid = UUID(merchant_id)
        rows = await conn.fetch(
            """
            SELECT 
                alias_id, merchant_id, alias, normalized_alias, active, created_at
            FROM spendsense.merchant_alias
            WHERE merchant_id = $1 AND active = TRUE
            ORDER BY created_at ASC
            """,
            mid,
        )

        return [
            AliasResponse(
                alias_id=str(row["alias_id"]),
                merchant_id=str(row["merchant_id"]),
                alias=row["alias"],
                normalized_alias=row["normalized_alias"],
                active=row["active"],
                created_at=row["created_at"],
            )
            for row in rows
        ]
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid merchant_id format")
    finally:
        await pool.release(conn)


@router.post("/{merchant_id}/aliases", response_model=AliasResponse, status_code=201)
async def create_alias(
    merchant_id: str,
    data: AliasCreate,
    user: AuthenticatedUser = Depends(get_current_user),
    pool: Pool = Depends(get_db_pool),
):
    """Create an alias for a merchant."""
    conn = await pool.acquire()
    try:
        mid = UUID(merchant_id)
        merchant = await conn.fetchrow(
            "SELECT merchant_id FROM spendsense.dim_merchant WHERE merchant_id = $1",
            mid,
        )
        if not merchant:
            raise HTTPException(status_code=404, detail="Merchant not found")

        norm = _normalize_name(data.alias)

        # Check if alias already exists
        existing = await conn.fetchrow(
            """
            SELECT alias_id, merchant_id, alias, normalized_alias, active, created_at
            FROM spendsense.merchant_alias
            WHERE merchant_id = $1 AND normalized_alias = $2 AND active = TRUE
            """,
            mid,
            norm,
        )
        if existing:
            return AliasResponse(
                alias_id=str(existing["alias_id"]),
                merchant_id=str(existing["merchant_id"]),
                alias=existing["alias"],
                normalized_alias=existing["normalized_alias"],
                active=existing["active"],
                created_at=existing["created_at"],
            )

        row = await conn.fetchrow(
            """
            INSERT INTO spendsense.merchant_alias (merchant_id, alias, normalized_alias)
            VALUES ($1, $2, $3)
            RETURNING alias_id, merchant_id, alias, normalized_alias, active, created_at
            """,
            mid,
            data.alias,
            norm,
        )

        return AliasResponse(
            alias_id=str(row["alias_id"]),
            merchant_id=str(row["merchant_id"]),
            alias=row["alias"],
            normalized_alias=row["normalized_alias"],
            active=row["active"],
            created_at=row["created_at"],
        )
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid merchant_id format")
    finally:
        await pool.release(conn)


@router.delete("/aliases/{alias_id}")
async def delete_alias(
    alias_id: str,
    user: AuthenticatedUser = Depends(get_current_user),
    pool: Pool = Depends(get_db_pool),
):
    """Soft-delete an alias (set active = false)."""
    conn = await pool.acquire()
    try:
        aid = UUID(alias_id)
        alias = await conn.fetchrow(
            """
            SELECT alias_id FROM spendsense.merchant_alias
            WHERE alias_id = $1 AND active = TRUE
            """,
            aid,
        )
        if not alias:
            raise HTTPException(status_code=404, detail="Alias not found")

        await conn.execute(
            "UPDATE spendsense.merchant_alias SET active = FALSE WHERE alias_id = $1",
            aid,
        )

        return {"status": "ok", "alias_id": alias_id, "active": False}
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid alias_id format")
    finally:
        await pool.release(conn)

