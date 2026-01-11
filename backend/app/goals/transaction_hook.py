"""Hook to process transactions through GoalRealtimeEngine after enrichment."""

import logging
from datetime import date
from uuid import UUID

import asyncpg

from .goal_realtime_engine import GoalRealtimeEngine, TransactionView
from .goals_repository import GoalsRepository
from .signals_repository import GoalSignalsRepository
from .suggestions_repository import GoalSuggestionsRepository

# Import rules to trigger auto-registration
import app.goals.rules  # noqa: F401

logger = logging.getLogger(__name__)


async def process_transactions_for_goals(
    conn: asyncpg.Connection,
    user_id: str,
    upload_id: str | None = None,
) -> None:
    """
    Process newly enriched transactions through GoalRealtimeEngine.
    
    This should be called after transactions are enriched with categories.
    """
    try:
        user_uuid = UUID(user_id)
    except (ValueError, TypeError):
        logger.warning(f"Invalid user_id format: {user_id}")
        return

    # Get enriched transactions that haven't been processed yet
    # We'll process transactions that were just enriched in this batch
    if upload_id:
        query = """
            SELECT DISTINCT
                tf.txn_id,
                tf.user_id,
                tf.txn_date,
                tf.amount,
                CASE WHEN tf.direction = 'credit' THEN 'credit' ELSE 'debit' END as direction,
                e.category_id as category,
                e.subcategory_id as subcategory,
                tf.merchant_name_norm as merchant_name
            FROM spendsense.txn_fact tf
            JOIN spendsense.txn_parsed tp ON tp.fact_txn_id = tf.txn_id
            JOIN spendsense.txn_enriched e ON e.parsed_id = tp.parsed_id
            WHERE tf.user_id = $1
              AND tf.upload_id = $2
              AND e.category_id IS NOT NULL
              AND (tf.txn_id NOT IN (
                  SELECT last_txn_id 
                  FROM goal.user_goals_master 
                  WHERE last_txn_id IS NOT NULL
              ) OR tf.txn_id IN (
                  SELECT last_txn_id 
                  FROM goal.user_goals_master 
                  WHERE last_txn_id = tf.txn_id
                  AND last_contribution_at < tf.txn_date
              ))
            ORDER BY tf.txn_date DESC
            LIMIT 100
        """
        params = (user_id, upload_id)
    else:
        # Process recent transactions if no upload_id
        query = """
            SELECT DISTINCT
                tf.txn_id,
                tf.user_id,
                tf.txn_date,
                tf.amount,
                CASE WHEN tf.direction = 'credit' THEN 'credit' ELSE 'debit' END as direction,
                e.category_id as category,
                e.subcategory_id as subcategory,
                tf.merchant_name_norm as merchant_name
            FROM spendsense.txn_fact tf
            JOIN spendsense.txn_parsed tp ON tp.fact_txn_id = tf.txn_id
            JOIN spendsense.txn_enriched e ON e.parsed_id = tp.parsed_id
            WHERE tf.user_id = $1
              AND e.category_id IS NOT NULL
              AND tf.txn_date >= CURRENT_DATE - INTERVAL '30 days'
            ORDER BY tf.txn_date DESC
            LIMIT 50
        """
        params = (user_id,)

    rows = await conn.fetch(query, *params)

    if not rows:
        logger.debug(f"No new transactions to process for goals for user {user_id}")
        return

    # Initialize repositories and engine
    goals_repo = GoalsRepository(conn)
    signals_repo = GoalSignalsRepository(conn)
    suggestions_repo = GoalSuggestionsRepository(conn)
    engine = GoalRealtimeEngine(goals_repo, signals_repo, suggestions_repo)

    # Get life context
    context_row = await conn.fetchrow(
        """
        SELECT age_band, dependents_spouse, dependents_children_count,
               dependents_parents_care, housing, employment, income_regularity,
               region_code, emergency_opt_out,
               monthly_investible_capacity, total_monthly_emi_obligations,
               risk_profile_overall, review_frequency, notify_on_drift,
               auto_adjust_on_income_change
        FROM goal.user_life_context
        WHERE user_id = $1
        """,
        user_uuid,
    )

    if not context_row:
        logger.debug(f"No life context found for user {user_id}, skipping goal processing")
        return

    context = dict(context_row)

    # Process each transaction
    processed_count = 0
    for row in rows:
        try:
            txn_view = TransactionView(
                id=UUID(str(row["txn_id"])),
                user_id=user_uuid,
                txn_date=row["txn_date"] if isinstance(row["txn_date"], date) else date.fromisoformat(str(row["txn_date"])),
                amount=float(row["amount"]),
                direction=str(row["direction"]),
                category=str(row["category"]) if row["category"] else None,
                subcategory=str(row["subcategory"]) if row["subcategory"] else None,
                merchant_name=str(row["merchant_name"]) if row["merchant_name"] else None,
            )

            await engine.process_transaction(user_uuid, txn_view, context)
            processed_count += 1
        except Exception as e:
            logger.error(
                f"Error processing transaction {row['txn_id']} for goals: {e}",
                exc_info=True,
            )
            # Continue processing other transactions
            continue

    if processed_count > 0:
        logger.info(
            f"Processed {processed_count} transactions through GoalRealtimeEngine for user {user_id}"
        )

