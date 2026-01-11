"""MoneyMoments service layer."""

import logging
from datetime import date
from typing import Any
from uuid import UUID

import asyncpg

from .money_moments_repository import MoneyMomentsRepository
from .moments_engine import MomentsEngine
from .nudge_engine import NudgeEngine

logger = logging.getLogger(__name__)


class MoneyMomentsService:
    """Service for MoneyMoments operations."""

    def __init__(self, pool: asyncpg.Pool):
        self.pool = pool

    async def get_moments(
        self, user_id: UUID, month: str | None = None, all_months: bool = False
    ) -> list[dict[str, Any]]:
        """Get money moments (behavioral insights) for a user."""
        async with self.pool.acquire() as conn:
            repo = MoneyMomentsRepository(conn)
            return await repo.get_user_moments(user_id, month, all_months)

    async def compute_moments(
        self, user_id: UUID, target_month: date | None = None
    ) -> list[dict[str, Any]]:
        """Compute and store money moments for a user."""
        try:
            async with self.pool.acquire() as conn:
                repo = MoneyMomentsRepository(conn)
                engine = MomentsEngine(repo)
                moments = await engine.compute_moments(user_id, target_month)
                logger.info(f"Computed {len(moments)} moments for user {user_id}, month {target_month}")
                return moments
        except Exception as e:
            logger.error(f"Error computing moments for user {user_id}: {e}", exc_info=True)
            raise

    async def get_nudges(
        self, user_id: UUID, limit: int = 20
    ) -> list[dict[str, Any]]:
        """Get recent nudges delivered to a user."""
        async with self.pool.acquire() as conn:
            repo = MoneyMomentsRepository(conn)
            nudges = await repo.get_user_nudges(user_id, limit)
            
            # Render templates if metadata contains rendered content
            # Otherwise, render templates on-the-fly
            rendered_nudges = []
            if nudges:
                engine = NudgeEngine(repo)
                for nudge in nudges:
                    # Check if metadata has rendered title/body
                    metadata = nudge.get("metadata_json") or {}
                    if isinstance(metadata, dict) and metadata.get("rendered_title") and metadata.get("rendered_body"):
                        nudge["title"] = metadata["rendered_title"]
                        nudge["body"] = metadata["rendered_body"]
                    else:
                        # Render template on-the-fly
                        try:
                            signal = await engine._get_user_signal(
                                UUID(nudge["user_id"]),
                                date.today()
                            )
                            template = {
                                "title_template": nudge.get("title_template", ""),
                                "body_template": nudge.get("body_template", ""),
                                "cta_text": nudge.get("cta_text"),
                                "cta_deeplink": nudge.get("cta_deeplink"),
                            }
                            rendered = await engine.render_template(
                                template, UUID(nudge["user_id"]), signal
                            )
                            nudge["title"] = rendered["title"]
                            nudge["body"] = rendered["body"]
                        except Exception as e:
                            logger.warning(f"Failed to render nudge template: {e}")
                            nudge["title"] = nudge.get("title_template", "")
                            nudge["body"] = nudge.get("body_template", "")
                    
                    rendered_nudges.append(nudge)
            
            return rendered_nudges

    async def log_interaction(
        self,
        user_id: UUID,
        delivery_id: UUID,
        event_type: str,
        metadata: dict[str, Any] | None = None,
    ) -> None:
        """Log user interaction with a nudge."""
        async with self.pool.acquire() as conn:
            repo = MoneyMomentsRepository(conn)
            await repo.log_nudge_interaction(user_id, delivery_id, event_type, metadata)

    async def evaluate_and_queue_nudges(
        self, user_id: UUID, as_of_date: date | None = None
    ) -> dict[str, Any]:
        """
        Evaluate rules and create nudge candidates for a user.
        Returns count of candidates created.
        """
        if as_of_date is None:
            as_of_date = date.today()

        async with self.pool.acquire() as conn:
            repo = MoneyMomentsRepository(conn)
            engine = NudgeEngine(repo)

            # Evaluate rules
            candidates = await engine.evaluate_rules(user_id, as_of_date)

            if not candidates:
                return {"status": "no_candidates", "count": 0}

            # Create candidates in DB
            candidate_ids = await repo.create_nudge_candidates(
                user_id, as_of_date, candidates
            )

            return {
                "status": "queued",
                "count": len(candidate_ids),
                "candidates": candidates,
            }

    async def compute_daily_signal(
        self, user_id: UUID, as_of_date: date | None = None
    ) -> dict[str, Any] | None:
        """Compute daily signal for a user (required for nudge evaluation)."""
        if as_of_date is None:
            as_of_date = date.today()

        async with self.pool.acquire() as conn:
            repo = MoneyMomentsRepository(conn)
            return await repo.compute_daily_signal(user_id, as_of_date)

    async def process_pending_nudges(
        self, user_id: UUID | None = None, limit: int = 10
    ) -> list[dict[str, Any]]:
        """
        Process pending nudge candidates and deliver them.
        Returns list of delivered nudges.
        """
        async with self.pool.acquire() as conn:
            repo = MoneyMomentsRepository(conn)
            engine = NudgeEngine(repo)

            # Get pending candidates
            candidates = await repo.get_pending_candidates(user_id, limit)

            delivered = []

            for candidate in candidates:
                cand_user_id = UUID(candidate["user_id"])
                candidate_id = UUID(candidate["candidate_id"])

                # Check suppression
                suppression = await repo.get_user_suppression(cand_user_id, "in_app")
                if suppression and suppression.get("muted_until"):
                    # Skip if muted
                    await conn.execute(
                        """
                        UPDATE moneymoments.mm_nudge_candidate
                        SET status = 'suppressed'
                        WHERE candidate_id = $1
                        """,
                        candidate_id,
                    )
                    continue

                # Get signal for template rendering
                signal = await engine._get_user_signal(cand_user_id, candidate["as_of_date"])

                # Get full template
                template = await engine._get_template_for_rule(candidate["rule_id"])
                if not template:
                    continue

                # Render template
                rendered = await engine.render_template(
                    template, cand_user_id, signal
                )

                # Deliver nudge
                delivery_id = await repo.deliver_nudge(
                    candidate_id,
                    cand_user_id,
                    candidate["rule_id"],
                    candidate["template_code"],
                    candidate["channel"],
                    rendered["title"],
                    rendered["body"],
                    {
                        "cta_text": rendered.get("cta_text"),
                        "cta_deeplink": rendered.get("cta_deeplink"),
                        "rendered_title": rendered["title"],
                        "rendered_body": rendered["body"],
                    },
                )

                delivered.append({
                    "delivery_id": str(delivery_id),
                    "user_id": str(cand_user_id),
                    "title": rendered["title"],
                    "body": rendered["body"],
                    "cta_text": rendered.get("cta_text"),
                    "cta_deeplink": rendered.get("cta_deeplink"),
                })

            return delivered

