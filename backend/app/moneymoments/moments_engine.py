"""MoneyMoments computation engine - ports pandas logic to async Python."""

import logging
import re
from datetime import date, datetime, timedelta
from typing import Any
from uuid import UUID

from .money_moments_repository import MoneyMomentsRepository

logger = logging.getLogger(__name__)


def _safe_div(a: float, b: float) -> float | None:
    """Safe division, returns None if division by zero."""
    if b and float(b) != 0.0:
        return float(a) / float(b)
    return None


def _time_to_minutes(t: str | datetime | None) -> float | None:
    """Convert time string or datetime to minutes since midnight."""
    if t is None:
        return None
    
    if isinstance(t, str):
        # Allow HH:MM:SS(.ffffff)
        m = re.match(r"^\s*(\d{1,2}):(\d{2})(?::(\d{2}))?", t)
        if not m:
            return None
        hh = int(m.group(1))
        mm = int(m.group(2))
        return hh * 60 + mm
    
    if isinstance(t, datetime):
        return int(t.hour) * 60 + int(t.minute)
    
    return None


def _canonical_merchant(row: dict[str, Any]) -> str:
    """Extract canonical merchant name from transaction row."""
    # Prefer normalized merchant name
    for col in ["merchant_name_norm", "merchant_name", "counterparty_name"]:
        val = row.get(col)
        if isinstance(val, str) and val.strip():
            return val.strip().upper()
    
    # Fallback: parse from description/raw_description
    text = str(row.get("description", "") or row.get("raw_description", "") or "")
    text = text.upper()
    
    m = re.search(r"(UPI|CARD|POS|IMPS|NEFT|NACH)[\-\:]\s*([A-Z0-9 &_.]{3,40})", text)
    if m:
        return m.group(2).strip()
    
    parts = re.split(r"[\-\|/]", text)
    return parts[0].strip()[:40] if text else "UNKNOWN"


def _confidence(
    n_debits: int,
    required_time: bool = False,
    has_time: bool = True,
    required_credits: bool = False,
    has_credits: bool = True,
) -> float:
    """Compute confidence score for a moment."""
    c = 0.55
    if n_debits >= 20:
        c += 0.25
    elif n_debits >= 10:
        c += 0.15
    elif n_debits >= 5:
        c += 0.05
    else:
        c -= 0.20
    
    if required_time and not has_time:
        c -= 0.25
    if required_credits and not has_credits:
        c -= 0.30
    
    return max(0.05, min(0.98, c))


class MomentsEngine:
    """Engine that computes behavioral money moments from transactions."""

    def __init__(self, repo: MoneyMomentsRepository):
        self.repo = repo

    async def compute_moments(
        self, user_id: UUID, target_month: date | None = None
    ) -> list[dict[str, Any]]:
        """
        Compute money moments for a user for a specific month.
        
        Returns list of moments with:
        - habit_id, value, label, insight_text, confidence
        """
        if target_month is None:
            target_month = date.today().replace(day=1)
        else:
            target_month = target_month.replace(day=1)
        
        month_str = target_month.strftime("%Y-%m")
        
        # Fetch transactions for the month and previous months for context
        start_date = target_month - timedelta(days=90)
        end_date = target_month + timedelta(days=32)  # Next month start
        
        logger.info(
            f"Computing moments for user {user_id}, month {month_str}. "
            f"Querying transactions from {start_date} to {end_date}"
        )
        
        try:
            rows = await self.repo.conn.fetch(
                """
                SELECT 
                    txn_date,
                    amount,
                    direction,
                    txn_type,
                    category_code,
                    subcategory_code,
                    merchant_name_norm,
                    description,
                    raw_description,
                    txn_time,
                    channel_type
                FROM spendsense.vw_txn_effective
                WHERE user_id = $1
                  AND txn_date >= $2
                  AND txn_date < $3
                ORDER BY txn_date ASC
                """,
                user_id,
                start_date,
                end_date,
            )
            logger.info(f"Query executed successfully. Found {len(rows)} total rows from spendsense.vw_txn_effective for user {user_id}")
            
            # Diagnostic: Check if any rows were found for this user at all
            if len(rows) == 0:
                # Check if user exists in the table at all
                user_check = await self.repo.conn.fetchval(
                    "SELECT COUNT(*) FROM spendsense.vw_txn_effective WHERE user_id = $1",
                    user_id
                )
                logger.warning(
                    f"No transactions found for user {user_id} in period {start_date} to {end_date}. "
                    f"Total transactions for this user in entire table: {user_check}. "
                    f"This suggests either: 1) Wrong user_id, 2) Transactions are outside date range, or 3) User has no transactions."
                )
        except Exception as e:
            logger.error(
                f"Error fetching transactions from spendsense.vw_txn_effective for user {user_id}: {e}",
                exc_info=True
            )
            raise
        
        if not rows:
            return []
        
        logger.info(f"Found {len(rows)} transactions for user {user_id} in period {start_date} to {end_date}")
        
        # Filter to target month
        month_rows = []
        for row in rows:
            row_dict = dict(row)
            txn_date = row_dict["txn_date"]
            if isinstance(txn_date, date):
                month_start = txn_date.replace(day=1)
            else:
                month_start = txn_date.date().replace(day=1)
            if month_start == target_month:
                month_rows.append(row_dict)
        
        if not month_rows:
            logger.warning(f"No transactions found for user {user_id} in month {month_str}")
            return []
        
        logger.info(f"Found {len(month_rows)} transactions for user {user_id} in month {month_str}")
        
        # Process transactions
        debits = [r for r in month_rows if r.get("direction", "").lower() == "debit"]
        credits = [r for r in month_rows if r.get("direction", "").lower() == "credit"]
        
        n_debits = len(debits)
        total_spend = sum(float(r.get("amount", 0)) for r in debits)
        income = sum(float(r.get("amount", 0)) for r in credits)
        
        if total_spend <= 0 or n_debits == 0:
            logger.warning(f"User {user_id} has no valid spending data for month {month_str}: total_spend={total_spend}, n_debits={n_debits}")
            return []
        
        logger.info(f"Processing {n_debits} debit transactions totaling {total_spend} for user {user_id} in month {month_str}")
        
        moments = []
        
        # Helper to get day from txn_date
        def get_day(r: dict[str, Any]) -> int:
            txn_date = r.get("txn_date")
            if isinstance(txn_date, date):
                return txn_date.day
            return txn_date.date().day if hasattr(txn_date, "date") else 1
        
        # Helper to get date from txn_date
        def get_date(r: dict[str, Any]) -> date:
            txn_date = r.get("txn_date")
            if isinstance(txn_date, date):
                return txn_date
            return txn_date.date() if hasattr(txn_date, "date") else date.today()
        
        # Helper to get weekday
        def get_weekday(r: dict[str, Any]) -> int:
            d = get_date(r)
            return d.weekday()  # Mon=0, Sun=6
        
        # 1. Early-month burn rate
        spend_d1_5 = sum(float(r.get("amount", 0)) for r in debits if get_day(r) <= 5)
        spend_d1_15 = sum(float(r.get("amount", 0)) for r in debits if get_day(r) <= 15)
        burn5 = _safe_div(spend_d1_5, total_spend)
        
        if burn5 is not None:
            if burn5 >= 0.45:
                label = "Front-loaded spending"
            elif burn5 <= 0.20:
                label = "Back-loaded spending"
            else:
                label = "Balanced early-month spending"
            
            burn15 = _safe_div(spend_d1_15, total_spend) or 0
            moments.append({
                "habit_id": "burn_rate_early_month",
                "value": round(burn5, 4),
                "label": label,
                "insight_text": (
                    f"{burn5*100:.0f}% of your monthly spend happened in the first 5 days "
                    f"(and {burn15*100:.0f}% in the first 15 days)."
                ),
                "confidence": _confidence(n_debits),
            })
        
        # 2. Spend-to-income ratio
        if income > 0:
            ratio = _safe_div(total_spend, income)
            if ratio is not None:
                if ratio < 0.60:
                    label = "Comfortable month"
                elif ratio < 0.85:
                    label = "Watch zone"
                elif ratio <= 1.00:
                    label = "Tight month"
                else:
                    label = "Overspent vs income"
                
                moments.append({
                    "habit_id": "spend_to_income_ratio",
                    "value": round(ratio, 4),
                    "label": label,
                    "insight_text": f"You spent {ratio*100:.0f}% of your credited income this month.",
                    "confidence": _confidence(n_debits, required_credits=True, has_credits=True),
                })
        
        # 3. Top-3 spend days share
        daily_spend: dict[date, float] = {}
        for r in debits:
            day = get_date(r)
            daily_spend[day] = daily_spend.get(day, 0) + float(r.get("amount", 0))
        
        sorted_days = sorted(daily_spend.items(), key=lambda x: x[1], reverse=True)
        top3_total = sum(amt for _, amt in sorted_days[:3])
        top3_share = _safe_div(top3_total, total_spend)
        
        if top3_share is not None:
            if top3_share >= 0.35:
                label = "Spiky spending"
            elif top3_share <= 0.20:
                label = "Steady spending"
            else:
                label = "Moderate spikes"
            
            moments.append({
                "habit_id": "top3_day_spend_share",
                "value": round(top3_share, 4),
                "label": label,
                "insight_text": f"Your top 3 spend days contributed {top3_share*100:.0f}% of monthly spend.",
                "confidence": _confidence(n_debits),
            })
        
        # 4. Micro-spend share (≤ ₹200)
        threshold = 200.0
        micro_spend = sum(float(r.get("amount", 0)) for r in debits if float(r.get("amount", 0)) <= threshold)
        micro_share = _safe_div(micro_spend, total_spend)
        micro_count = sum(1 for r in debits if float(r.get("amount", 0)) <= threshold)
        
        if micro_share is not None:
            if micro_share >= 0.25 and micro_count >= 20:
                label = "Micro-spend heavy"
            elif micro_share >= 0.15:
                label = "Some micro-spend"
            else:
                label = "Low micro-spend"
            
            moments.append({
                "habit_id": "micro_spend_share",
                "value": round(micro_share, 4),
                "label": label,
                "insight_text": (
                    f"{micro_share*100:.0f}% of spend came from {micro_count} transactions of ≤₹{int(threshold)}."
                ),
                "confidence": _confidence(n_debits),
            })
        
        # 5. Weekend multiplier
        weekend_spend = sum(
            float(r.get("amount", 0))
            for r in debits
            if get_weekday(r) in [5, 6]  # Sat, Sun
        )
        weekday_spend = sum(
            float(r.get("amount", 0))
            for r in debits
            if get_weekday(r) not in [5, 6]
        )
        
        weekend_days = len(set(get_date(r) for r in debits if get_weekday(r) in [5, 6]))
        weekday_days = len(set(get_date(r) for r in debits if get_weekday(r) not in [5, 6]))
        
        avg_weekend = _safe_div(weekend_spend, weekend_days) if weekend_days else None
        avg_weekday = _safe_div(weekday_spend, weekday_days) if weekday_days else None
        weekend_mult = _safe_div(avg_weekend, avg_weekday) if (avg_weekend and avg_weekday) else None
        
        if weekend_mult is not None:
            if weekend_mult >= 1.25:
                label = "Weekend spender"
            elif weekend_mult <= 0.85:
                label = "Weekday spender"
            else:
                label = "Balanced across week"
            
            moments.append({
                "habit_id": "weekend_spend_multiplier",
                "value": round(weekend_mult, 4),
                "label": label,
                "insight_text": f"Avg weekend spend/day is {weekend_mult:.2f}× your avg weekday spend/day.",
                "confidence": _confidence(n_debits),
            })
        
        # 6. Late-night spend share (22:00–05:00)
        has_time_any = any(_time_to_minutes(r.get("txn_time")) is not None for r in debits)
        if has_time_any:
            late_spend = 0.0
            for r in debits:
                mins = _time_to_minutes(r.get("txn_time"))
                if mins is not None and ((mins >= 22 * 60) or (mins < 5 * 60)):
                    late_spend += float(r.get("amount", 0))
            
            late_share = _safe_div(late_spend, total_spend)
            if late_share is not None:
                if late_share >= 0.12:
                    label = "Late-night spender"
                elif late_share >= 0.06:
                    label = "Some late-night spend"
                else:
                    label = "Rare late-night spend"
                
                moments.append({
                    "habit_id": "late_night_spend_share",
                    "value": round(late_share, 4),
                    "label": label,
                    "insight_text": f"{late_share*100:.0f}% of your spend happened after 10 PM (or before 5 AM).",
                    "confidence": _confidence(n_debits, required_time=True, has_time=True),
                })
        
        # 7. Cash-like spend share
        cash_spend = 0.0
        for r in debits:
            cat = str(r.get("category_code", "")).lower()
            channel = str(r.get("channel_type", "") or "").upper()
            desc = str(r.get("description", "") or "" + " " + str(r.get("raw_description", "") or "")).upper()
            
            is_cash = (
                cat in ["cash_withdrawal", "atm_withdrawal"]
                or channel in ["ATM", "CASH"]
                or bool(re.search(r"\bATM\b|\bCASH\b|WDL|WITHDRAW", desc))
            )
            if is_cash:
                cash_spend += float(r.get("amount", 0))
        
        cash_share = _safe_div(cash_spend, total_spend)
        if cash_share is not None:
            if cash_share >= 0.15:
                label = "Cash-reliant"
            elif cash_share >= 0.07:
                label = "Some cash usage"
            else:
                label = "Mostly digital"
            
            moments.append({
                "habit_id": "cash_spend_share",
                "value": round(cash_share, 4),
                "label": label,
                "insight_text": f"Cash-like transactions contributed {cash_share*100:.0f}% of your monthly spend.",
                "confidence": _confidence(n_debits),
            })
        
        # 8. Transfers-out share
        transfer_spend = 0.0
        for r in debits:
            cat = str(r.get("category_code", "")).lower()
            desc = str(r.get("description", "") + " " + str(r.get("raw_description", ""))).upper()
            
            is_transfer = (
                cat in ["transfers_out", "transfer_out", "p2p_transfer_out"]
                or bool(re.search(r"\bUPI\b|\bIMPS\b|\bNEFT\b|\bRTGS\b", desc))
            )
            if is_transfer:
                transfer_spend += float(r.get("amount", 0))
        
        transfer_share = _safe_div(transfer_spend, total_spend)
        if transfer_share is not None:
            if transfer_share >= 0.25:
                label = "Heavy transfers out"
            elif transfer_share >= 0.12:
                label = "Moderate transfers out"
            else:
                label = "Low transfers out"
            
            moments.append({
                "habit_id": "transfer_out_share",
                "value": round(transfer_share, 4),
                "label": label,
                "insight_text": f"Transfers out contributed {transfer_share*100:.0f}% of your monthly spend.",
                "confidence": _confidence(n_debits),
            })
        
        # 9. Repeating payments count
        merchant_groups: dict[str, list[float]] = {}
        for r in debits:
            merchant_key = _canonical_merchant(r)
            if merchant_key not in merchant_groups:
                merchant_groups[merchant_key] = []
            merchant_groups[merchant_key].append(float(r.get("amount", 0)))
        
        sub_count = 0
        for amounts in merchant_groups.values():
            if len(amounts) < 2:
                continue
            mean_amt = sum(amounts) / len(amounts)
            if mean_amt <= 0:
                continue
            if (max(amounts) - min(amounts)) <= max(50.0, 0.10 * mean_amt):
                sub_count += 1
        
        if sub_count >= 4:
            label = "Many repeating payments"
        elif sub_count >= 2:
            label = "Some repeating payments"
        else:
            label = "Few repeating payments"
        
        moments.append({
            "habit_id": "repeating_payments_count",
            "value": float(sub_count),
            "label": label,
            "insight_text": f"Detected {sub_count} likely repeating merchants this month (heuristic).",
            "confidence": max(0.05, _confidence(n_debits) - 0.05),
        })
        
        # 10. Top category concentration
        category_spend: dict[str, float] = {}
        for r in debits:
            cat = str(r.get("category_code", "unknown"))
            category_spend[cat] = category_spend.get(cat, 0) + float(r.get("amount", 0))
        
        if category_spend:
            sorted_cats = sorted(category_spend.items(), key=lambda x: x[1], reverse=True)
            top_cat = sorted_cats[0][0]
            top_share = _safe_div(sorted_cats[0][1], total_spend)
            
            if top_share is not None:
                if top_share >= 0.45:
                    label = "Category concentrated"
                elif top_share >= 0.30:
                    label = "Category leaning"
                else:
                    label = "Well distributed"
                
                moments.append({
                    "habit_id": "top_category_spend_share",
                    "value": round(top_share, 4),
                    "label": label,
                    "insight_text": f"Top category '{top_cat}' was {top_share*100:.0f}% of your spend.",
                    "confidence": _confidence(n_debits),
                })
        
        # Store moments
        if moments:
            logger.info(f"Storing {len(moments)} moments for user {user_id}, month {month_str}")
            await self.repo.store_moments(user_id, month_str, moments)
            logger.info(f"Successfully stored {len(moments)} moments for user {user_id}, month {month_str}")
        else:
            logger.warning(f"No moments computed for user {user_id}, month {month_str}")
        
        # Add user_id, month, and created_at to each moment for API response
        from datetime import datetime, timezone
        now_iso = datetime.now(timezone.utc).isoformat()
        for moment in moments:
            moment["user_id"] = str(user_id)
            moment["month"] = month_str
            moment["created_at"] = now_iso
        
        return moments

