"""Training system to learn from sample bank files and improve parsing/categorization."""

from __future__ import annotations

import asyncio
import hashlib
import json
import logging
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any

import asyncpg  # type: ignore[import-untyped]

from app.core.config import get_settings
from app.spendsense.etl.parsers import parse_transactions_file

settings = get_settings()
DEFAULT_SAMPLE_DIR = (settings.base_dir.parent / "sample_bank").resolve()
logger = logging.getLogger(__name__)


async def train_from_samples(sample_dir: Path, conn: asyncpg.Connection) -> dict[str, Any]:
    """Train the system by analyzing sample bank files.
    
    Returns:
        Training report with discovered patterns, merchants, and suggested rules
    """
    sample_dir = Path(sample_dir)
    if not sample_dir.exists():
        raise ValueError(f"Sample directory not found: {sample_dir}")
    
    logger.info(f"Starting training from samples in: {sample_dir}")
    
    # Discover all sample files
    sample_files = []
    for ext in [".xls", ".xlsx", ".csv", ".pdf"]:
        sample_files.extend(sample_dir.glob(f"*{ext}"))
        sample_files.extend(sample_dir.glob(f"**/*{ext}"))
    
    logger.info(f"Found {len(sample_files)} sample files")
    
    # Parse all files and collect patterns
    all_records: list[dict[str, Any]] = []
    parsing_errors: list[dict[str, str]] = []
    
    for file_path in sample_files:
        try:
            logger.info(f"Parsing {file_path.name}...")
            with open(file_path, "rb") as f:
                data = f.read()
            
            records = parse_transactions_file(data, file_path.name)
            logger.info(f"  ✓ Parsed {len(records)} transactions")
            
            # Add file metadata
            for rec in records:
                rec["_source_file"] = file_path.name
                rec["_bank_code"] = _infer_bank_from_filename(file_path.name)
            
            all_records.extend(records)
        except Exception as exc:
            logger.warning(f"  ✗ Failed to parse {file_path.name}: {exc}")
            parsing_errors.append({"file": file_path.name, "error": str(exc)})
    
    if not all_records:
        return {
            "error": "No transactions parsed from sample files",
            "parsing_errors": parsing_errors,
        }
    
    logger.info(f"Total transactions parsed: {len(all_records)}")
    
    # Analyze patterns
    analysis = _analyze_patterns(all_records)
    
    # Generate merchant suggestions
    merchant_suggestions = _generate_merchant_suggestions(all_records)
    
    # Generate categorization rules
    rule_suggestions = _generate_rule_suggestions(all_records, analysis)
    
    # Bank-specific format patterns
    bank_patterns = _analyze_bank_formats(all_records)
    
    return {
        "summary": {
            "files_processed": len(sample_files),
            "files_failed": len(parsing_errors),
            "transactions_parsed": len(all_records),
            "unique_merchants": len(merchant_suggestions),
            "rule_suggestions": len(rule_suggestions),
        },
        "merchants": merchant_suggestions,
        "rules": rule_suggestions,
        "bank_patterns": bank_patterns,
        "parsing_errors": parsing_errors,
        "analysis": analysis,
    }


def _infer_bank_from_filename(filename: str) -> str | None:
    """Infer bank code from filename."""
    filename_upper = filename.upper()
    if "HDFC" in filename_upper:
        return "HDFC"
    elif "ICICI" in filename_upper:
        return "ICICI"
    elif "FEDERAL" in filename_upper:
        return "FEDERAL"
    elif "SBI" in filename_upper:
        return "SBI"
    elif "AXIS" in filename_upper:
        return "AXIS"
    elif "KOTAK" in filename_upper:
        return "KOTAK"
    return None


def _analyze_patterns(records: list[dict[str, Any]]) -> dict[str, Any]:
    """Analyze transaction patterns."""
    descriptions = [r.get("description_raw", "") for r in records]
    merchants = [r.get("merchant_raw") for r in records if r.get("merchant_raw")]
    
    # Common description patterns
    upi_patterns = Counter()
    ach_patterns = Counter()
    neft_patterns = Counter()
    
    for desc in descriptions:
        desc_upper = desc.upper()
        if desc_upper.startswith("UPI-"):
            parts = desc.split("-", 2)
            if len(parts) >= 2:
                merchant_part = parts[1].split("@")[0].split(".")[0].strip()
                if merchant_part:
                    upi_patterns[merchant_part] += 1
        elif desc_upper.startswith("ACH"):
            parts = desc.split("-", 2)
            if len(parts) >= 2:
                merchant_part = parts[1].strip()
                if merchant_part:
                    ach_patterns[merchant_part] += 1
        elif "NEFT" in desc_upper or "IMPS" in desc_upper:
            neft_patterns[desc[:50]] += 1
    
    # Merchant frequency
    merchant_freq = Counter(merchants)
    
    # Amount ranges
    amounts = [r["amount"] for r in records]
    amount_stats = {
        "min": min(amounts) if amounts else 0,
        "max": max(amounts) if amounts else 0,
        "avg": sum(amounts) / len(amounts) if amounts else 0,
    }
    
    return {
        "upi_merchants": dict(upi_patterns.most_common(50)),
        "ach_merchants": dict(ach_patterns.most_common(50)),
        "neft_patterns": dict(neft_patterns.most_common(20)),
        "merchant_frequency": dict(merchant_freq.most_common(100)),
        "amount_stats": amount_stats,
        "total_transactions": len(records),
    }


def _generate_merchant_suggestions(records: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Generate merchant suggestions from parsed records."""
    merchant_data: dict[str, dict[str, Any]] = {}
    
    for rec in records:
        merchant = rec.get("merchant_raw")
        if not merchant:
            continue
        
        merchant_lower = merchant.lower().strip()
        if not merchant_lower or len(merchant_lower) < 3:
            continue
        
        if merchant_lower not in merchant_data:
            merchant_data[merchant_lower] = {
                "normalized_name": merchant.strip().title(),
                "variations": set(),
                "descriptions": [],
                "count": 0,
                "total_amount": 0.0,
                "avg_amount": 0.0,
            }
        
        merchant_data[merchant_lower]["count"] += 1
        merchant_data[merchant_lower]["total_amount"] += rec["amount"]
        
        desc = rec.get("description_raw", "")
        if desc:
            merchant_data[merchant_lower]["descriptions"].append(desc[:100])
        
        # Collect variations
        if desc:
            desc_upper = desc.upper()
            if "UPI-" in desc_upper:
                parts = desc.split("-", 2)
                if len(parts) >= 2:
                    variation = parts[1].split("@")[0].split(".")[0].strip()
                    if variation and variation.lower() != merchant_lower:
                        merchant_data[merchant_lower]["variations"].add(variation)
    
    # Convert to list and calculate averages
    suggestions = []
    for merchant_lower, data in merchant_data.items():
        if data["count"] >= 2:  # Only suggest merchants with 2+ transactions
            data["avg_amount"] = data["total_amount"] / data["count"]
            suggestions.append({
                "normalized_name": data["normalized_name"],
                "variations": sorted(list(data["variations"]))[:5],  # Top 5 variations
                "transaction_count": data["count"],
                "total_amount": round(data["total_amount"], 2),
                "avg_amount": round(data["avg_amount"], 2),
                "sample_descriptions": list(set(data["descriptions"]))[:3],  # Top 3 unique
            })
    
    # Sort by frequency
    suggestions.sort(key=lambda x: x["transaction_count"], reverse=True)
    return suggestions


def _normalize_alias_text(value: str | None) -> str | None:
    if not value:
        return None
    normalized = " ".join(value.strip().split())
    return normalized if normalized else None


def _generate_rule_suggestions(
    records: list[dict[str, Any]], analysis: dict[str, Any]
) -> list[dict[str, Any]]:
    """Generate categorization rule suggestions based on merchant patterns."""
    suggestions = []
    
    # Category keywords mapping
    category_keywords = {
        "food_dining": ["zomato", "swiggy", "uber eats", "food", "restaurant", "cafe", "coffee", "pizza", "burger"],
        "shopping": ["amazon", "flipkart", "myntra", "shop", "store", "mall"],
        "transport": ["uber", "ola", "rapido", "metro", "bus", "train", "taxi"],
        "entertainment": ["netflix", "spotify", "prime", "hotstar", "cinema", "movie"],
        "utilities": ["electricity", "water", "gas", "internet", "phone", "broadband"],
        "loan_payments": ["emi", "loan", "credit card", "repayment"],
        "healthcare": ["hospital", "clinic", "pharmacy", "doctor", "medical"],
        "education": ["school", "college", "university", "tuition", "course"],
    }
    
    # Analyze merchants and suggest categories
    merchant_categories: dict[str, Counter] = defaultdict(Counter)
    
    for rec in records:
        merchant = (rec.get("merchant_raw") or "").lower()
        desc = (rec.get("description_raw") or "").lower()
        
        if not merchant and not desc:
            continue
        
        text = f"{merchant} {desc}"
        
        # Match against category keywords
        for category, keywords in category_keywords.items():
            for keyword in keywords:
                if keyword in text:
                    if merchant:
                        merchant_categories[merchant][category] += 1
                    break
    
    # Generate rule suggestions
    for merchant, category_counts in merchant_categories.items():
        if not category_counts:
            continue
        
        top_category = category_counts.most_common(1)[0]
        category = top_category[0]
        confidence = top_category[1]
        
        # Only suggest if high confidence (3+ matches)
        if confidence >= 3:
            suggestions.append({
                "pattern": merchant,
                "applies_to": "merchant",
                "category_code": category,
                "subcategory_code": None,  # Can be refined later
                "confidence": confidence,
                "sample_count": confidence,
            })
    
    # Also suggest description-based rules for common patterns
    desc_patterns = analysis.get("neft_patterns", {})
    for pattern, count in list(desc_patterns.items())[:10]:
        if count >= 3:
            # Try to infer category from pattern
            pattern_lower = pattern.lower()
            category = None
            for cat, keywords in category_keywords.items():
                if any(kw in pattern_lower for kw in keywords):
                    category = cat
                    break
            
            if category:
                suggestions.append({
                    "pattern": pattern[:100],  # Truncate long patterns
                    "applies_to": "description",
                    "category_code": category,
                    "subcategory_code": None,
                    "confidence": count,
                    "sample_count": count,
                })
    
    return suggestions


def _analyze_bank_formats(records: list[dict[str, Any]]) -> dict[str, Any]:
    """Analyze bank-specific format patterns."""
    bank_data: dict[str, dict[str, Any]] = defaultdict(lambda: {
        "transaction_count": 0,
        "description_patterns": Counter(),
        "merchant_extraction_rate": 0,
        "common_columns": set(),
    })
    
    for rec in records:
        bank = rec.get("_bank_code", "UNKNOWN")
        bank_data[bank]["transaction_count"] += 1
        
        desc = rec.get("description_raw", "")
        if desc:
            # Extract pattern type
            if desc.upper().startswith("UPI-"):
                bank_data[bank]["description_patterns"]["UPI"] += 1
            elif desc.upper().startswith("ACH"):
                bank_data[bank]["description_patterns"]["ACH"] += 1
            elif "NEFT" in desc.upper():
                bank_data[bank]["description_patterns"]["NEFT"] += 1
            elif "IMPS" in desc.upper():
                bank_data[bank]["description_patterns"]["IMPS"] += 1
        
        if rec.get("merchant_raw"):
            bank_data[bank]["merchant_extraction_rate"] += 1
    
    # Calculate extraction rates
    for bank, data in bank_data.items():
        total = data["transaction_count"]
        if total > 0:
            data["merchant_extraction_rate"] = round(
                (data["merchant_extraction_rate"] / total) * 100, 2
            )
        data["description_patterns"] = dict(data["description_patterns"])
        data["common_columns"] = list(data["common_columns"])
    
    return dict(bank_data)


async def apply_training_results(
    conn: asyncpg.Connection,
    training_report: dict[str, Any],
    dry_run: bool = True,
) -> dict[str, Any]:
    """Apply training results to database (merchants and rules).
    
    Args:
        conn: Database connection
        training_report: Output from train_from_samples()
        dry_run: If True, only return what would be applied without making changes
    """
    applied = {
        "merchants_inserted": 0,
        "merchants_updated": 0,
        "rules_inserted": 0,
        "rules_updated": 0,
    }
    
    if dry_run:
        logger.info("DRY RUN: Would apply the following changes...")
    
    # Insert/update merchants
    merchants = training_report.get("merchants", [])
    for merchant in merchants[:100]:  # Limit to top 100
        normalized = merchant["normalized_name"]
        normalized_lower = normalized.lower()
        
        if dry_run:
            applied["merchants_inserted"] += 1
            continue
        
        # Check if merchant exists
        existing = await conn.fetchrow(
            "SELECT merchant_id FROM spendsense.dim_merchant WHERE normalized_name = $1",
            normalized_lower,
        )
        
        if existing:
            applied["merchants_updated"] += 1
        else:
            await conn.execute(
                """
                INSERT INTO spendsense.dim_merchant (normalized_name, merchant_name, active)
                VALUES ($1, $2, TRUE)
                ON CONFLICT (normalized_name) DO UPDATE SET
                    merchant_name = EXCLUDED.merchant_name,
                    active = TRUE
                """,
                normalized_lower,
                normalized,
            )
            applied["merchants_inserted"] += 1
    
    # Insert/update rules
    rules = training_report.get("rules", [])
    for rule in rules[:50]:  # Limit to top 50
        pattern = rule["pattern"]
        applies_to = rule["applies_to"]
        category = rule["category_code"]
        
        # Convert pattern to regex (simple version)
        pattern_regex = pattern.replace(" ", "\\s+").replace(".", "\\.")
        
        # Calculate pattern hash (matching migration 012)
        pattern_hash = hashlib.sha1(pattern_regex.encode("utf-8")).hexdigest()
        
        if dry_run:
            applied["rules_inserted"] += 1
            continue
        
        # Check if rule with same hash exists (unique constraint is on pattern_hash)
        existing = await conn.fetchrow(
            """
            SELECT rule_id FROM spendsense.merchant_rules
            WHERE pattern_hash = $1 AND applies_to = $2 AND active = TRUE
            """,
            pattern_hash,
            applies_to,
        )
        
        if existing:
            applied["rules_updated"] += 1
        else:
            try:
                await conn.execute(
                    """
                    INSERT INTO spendsense.merchant_rules (
                        pattern_regex, pattern_hash, applies_to, category_code, subcategory_code,
                        priority, active, source
                    )
                    VALUES ($1, $2, $3, $4, $5, 100, TRUE, 'learned')
                    """,
                    pattern_regex,
                    pattern_hash,
                    applies_to,
                    category,
                    rule.get("subcategory_code"),
                )
            except asyncpg.UniqueViolationError:
                # Rule already exists (unique constraint violation), skip
                applied["rules_updated"] += 1
                continue
            applied["rules_inserted"] += 1
    
    return applied


async def apply_merchant_feedback(conn: asyncpg.Connection) -> dict[str, Any]:
    """Convert user merchant/channel edits into alias mappings."""
    rows = await conn.fetch(
        """
        SELECT feedback_id,
               user_id,
               original_merchant,
               corrected_merchant,
               original_channel,
               corrected_channel,
               merchant_hash
        FROM spendsense.ml_merchant_feedback
        WHERE used_in_training = FALSE
        ORDER BY feedback_at
        LIMIT 500
        """
    )
    if not rows:
        return {"processed": 0, "applied": 0}

    processed_ids: list[str] = []
    applied_count = 0

    for row in rows:
        original = _normalize_alias_text(row["original_merchant"])
        corrected = _normalize_alias_text(row["corrected_merchant"]) or original
        if not corrected:
            continue

        merchant_hash = row["merchant_hash"]
        if not merchant_hash:
            base = original or corrected
            merchant_hash = hashlib.md5(base.lower().encode("utf-8")).hexdigest()

        channel_override = row["corrected_channel"] or row["original_channel"]
        await conn.execute(
            """
            INSERT INTO spendsense.merchant_alias (
                user_id,
                merchant_hash,
                alias_pattern,
                normalized_name,
                channel_override,
                usage_count
            )
            VALUES ($1, $2, COALESCE($3, $4), $4, $5, 1)
            ON CONFLICT (user_id, merchant_hash) DO UPDATE
            SET normalized_name = COALESCE(EXCLUDED.normalized_name, spendsense.merchant_alias.normalized_name),
                channel_override = COALESCE(EXCLUDED.channel_override, spendsense.merchant_alias.channel_override),
                usage_count = spendsense.merchant_alias.usage_count + 1,
                updated_at = NOW()
            """,
            row["user_id"],
            merchant_hash,
            original,
            corrected,
            channel_override,
        )
        processed_ids.append(row["feedback_id"])
        applied_count += 1

    if processed_ids:
        await conn.execute(
            """
            UPDATE spendsense.ml_merchant_feedback
            SET used_in_training = TRUE
            WHERE feedback_id = ANY($1::uuid[])
            """,
            processed_ids,
        )

    return {"processed": len(rows), "applied": applied_count}


async def run_training(
    sample_dir: str | Path | None = None, apply: bool = False
) -> dict[str, Any]:
    """Run training pipeline.
    
    Args:
        sample_dir: Path to sample bank files directory
        apply: If True, apply results to database. If False, only generate report.
    """
    sample_path = Path(sample_dir) if sample_dir else DEFAULT_SAMPLE_DIR
    if not sample_path.exists():
        raise FileNotFoundError(f"Sample directory not found: {sample_path}")
    
    # Connect with retry logic
    max_retries = 3
    retry_delay = 2
    conn = None
    
    for attempt in range(max_retries):
        try:
            conn = await asyncio.wait_for(
                asyncpg.connect(
                    str(settings.postgres_dsn),
                    statement_cache_size=0,
                    timeout=30,
                ),
                timeout=35.0,
            )
            break
        except (asyncio.TimeoutError, OSError, Exception) as exc:
            if attempt < max_retries - 1:
                logger.warning(f"Database connection attempt {attempt + 1} failed: {exc}. Retrying...")
                await asyncio.sleep(retry_delay)
                retry_delay *= 2
            else:
                logger.error(f"Failed to connect to database after {max_retries} attempts: {exc}")
                raise
    
    if conn is None:
        raise RuntimeError("Failed to establish database connection")
    
    try:
        # Train from samples
        report = await train_from_samples(sample_path, conn)
        
        # Apply results if requested
        if apply:
            applied = await apply_training_results(conn, report, dry_run=False)
            report["applied"] = applied
            report["merchant_feedback"] = await apply_merchant_feedback(conn)
        else:
            would_apply = await apply_training_results(conn, report, dry_run=True)
            report["would_apply"] = would_apply
        
        return report
    finally:
        await conn.close()


if __name__ == "__main__":
    import sys
    
    logging.basicConfig(level=logging.INFO)
    
    cli_sample_dir = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_SAMPLE_DIR
    apply_changes = "--apply" in sys.argv
    
    report = asyncio.run(run_training(cli_sample_dir, apply=apply_changes))
    
    print("\n" + "=" * 80)
    print("TRAINING REPORT")
    print("=" * 80)
    print(json.dumps(report, indent=2, default=str))

