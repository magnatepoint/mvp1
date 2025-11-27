from __future__ import annotations

import re
from typing import Any

import pandas as pd  # type: ignore[import-untyped]


class SpendSenseParseError(ValueError):
    """Custom error raised when statement parsing fails."""


COLUMN_ALIASES: dict[str, tuple[str, ...]] = {
    "txn_date": (
        "txn_date",
        "date",
        "transaction_date",
        "posted_at",
        "txn date",
        "transaction date",
        "value date",
        "valuedate",
        "value dt",
        "value dt.",
        "valuedt",
        "posting date",
        "postingdate",
        "transactiondate",
        "tdate",
        "trandate",
        "transdate",
        "entry date",
        "entrydate",
    ),
    "description": (
        "description",
        "description_raw",
        "narration",
        "details",
        "particulars",
        "remarks",
        "note",
        "memo",
        "transaction details",
        "transactiondetails",
        "narration1",
        "narration2",
        "particular",
        "desc",
    ),
    "amount": (
        "amount",
        "amt",
        "transaction_amount",
        "transaction amount",
        "transactionamount",
        "value",
        "transactionvalue",
        "txnamount",
        "txn_amount",
    ),
    "withdrawal_amt": (
        "withdrawal amt",
        "withdrawal amt.",
        "withdrawal amount",
        "withdrawal amount inr",
        "withdrawalamount",
        "withdrawalamountinr",
        "withdrawalamt",
        "withdrawal",
        "withdrawals",
        "debit amount",
        "debit amount inr",
        "debit amt.",
        "debit",
    ),
    "deposit_amt": (
        "deposit amt",
        "deposit amt.",
        "deposit amount",
        "deposit amount inr",
        "depositamount",
        "depositamountinr",
        "depositamt",
        "deposit",
        "deposits",
        "credit amount",
        "credit amount inr",
        "credit amt.",
        "credit",
    ),
    "direction": (
        "direction",
        "type",
        "dr_cr",
        "dr/cr",
        "dr/ cr",
        "drcr",
        "cr/dr",
        "crdr",
        "dr cr",
    ),
    "currency": ("currency", "curr", "ccy", "cur"),
    "merchant": ("merchant", "merchant_raw", "payee", "beneficiary", "to", "from"),
    "account_ref": (
        "account_ref",
        "account",
        "account_hint",
        "account number",
        "accountnumber",
        "accno",
    ),
    "raw_txn_id": (
        "txn_id",
        "raw_txn_id",
        "reference",
        "ref",
        "transaction id",
        "transactionid",
        "txnid",
        "tran id",
    ),
}


REQUIRED_DATE_COLUMN = "txn_date"
REQUIRED_AMOUNT_COLUMNS = {"amount", "withdrawal_amt", "deposit_amt"}
MAX_HEADER_SCAN = 500
DENSE_SCAN_ROWS = 20
SAMPLE_INTERVAL = 10


def _normalize_token(value: str) -> str:
    return "".join(ch for ch in value.lower() if ch.isalnum())


NORMALIZED_ALIASES: dict[str, set[str]] = {
    canonical: {_normalize_token(alias) for alias in (canonical, *aliases)}
    for canonical, aliases in COLUMN_ALIASES.items()
}

BANK_KEYWORDS = {
    "federal": "federal_bank",
    "hdfc": "hdfc_bank",
    "icici": "icici_bank",
    "axis": "axis_bank",
    "sbi": "sbi_bank",
    "kotak": "kotak_bank",
}

CHANNEL_KEYWORDS = [
    ("credit_card", ["CREDIT CARD", "CC PAYMENT", "CARD PAYMENT", "BILLDK", "AMEX", "VISA", "MASTERCARD"]),
    ("loan", ["EMI", "LOAN", "AUTO-DEBIT", "NACH", "ECS"]),
    ("insurance", ["INSURANCE", "PREMIUM", "LIC"]),
    ("investment", ["SIP", "MUTUAL FUND", "MF", "INVEST", "EQUITY", "DEMAT", "NSE", "BSE", "STOCK"]),
    ("upi", ["UPI", "VPA", "BHIM", "UPIPAY", "UPI OUT", "UPI IN"]),
    ("bank_transfer", ["NEFT", "RTGS", "IMPS", "ACH", "FT", "BANK TRANSFER"]),
]


def infer_bank_code(filename: str, sample_text: str | None = None) -> str | None:
    haystack = filename.lower()
    if sample_text:
        haystack += f" {sample_text.lower()}"
    for keyword, code in BANK_KEYWORDS.items():
        if keyword in haystack:
            return code
    return None


def detect_channel(description: str | None, direction: str | None) -> str:
    text = (description or "").upper()
    for channel, keywords in CHANNEL_KEYWORDS:
        if any(keyword in text for keyword in keywords):
            return channel
    return "bank_transfer" if direction != "credit" else "upi" if "UPI" in text else "bank_transfer"


def _expand_multiline_rows(df: pd.DataFrame) -> pd.DataFrame:
    expanded_rows: list[dict[str, Any]] = []
    columns = list(df.columns)

    for _, row in df.iterrows():
        values = [str(row[col]) if row[col] is not None else "" for col in columns]
        if not any("\n" in value for value in values):
            expanded_rows.append({col: row[col] for col in columns})
            continue

        split_cells = [value.split("\n") for value in values]
        max_len = max(len(parts) for parts in split_cells)

        for idx in range(max_len):
            new_row: dict[str, Any] = {}
            for col, parts in zip(columns, split_cells):
                if idx < len(parts):
                    new_row[col] = parts[idx].strip()
                else:
                    new_row[col] = ""
            expanded_rows.append(new_row)

    return pd.DataFrame(expanded_rows, columns=columns)


def structure_dataframe(df_raw: pd.DataFrame, *, is_pdf: bool) -> pd.DataFrame:
    """Detect headers and return a structured dataframe."""
    if df_raw.empty:
        raise SpendSenseParseError("File has no rows")

    max_search = min(MAX_HEADER_SCAN, len(df_raw))
    sample_columns: list[str] = []
    found_header_row: int | None = None

    def check_row_for_header(row_idx: int) -> bool:
        row_values = df_raw.iloc[row_idx].astype(str).tolist()
        if all(not val or val.lower() in ("nan", "none", "") for val in row_values):
            return False

        nonlocal sample_columns
        if not sample_columns and len(row_values) > 0:
            sample_columns = [str(val) for val in row_values[:10]]

        rename_map: dict[str, str] = {}
        for col_val in row_values:
            token = _normalize_token(str(col_val).strip())
            for canonical, alias_tokens in NORMALIZED_ALIASES.items():
                if token in alias_tokens:
                    rename_map[col_val] = canonical
                    break

        normalized_cols = set(rename_map.values())
        has_date = REQUIRED_DATE_COLUMN in normalized_cols
        has_amount = bool(normalized_cols & REQUIRED_AMOUNT_COLUMNS)
        return has_date and has_amount

    for header_row in range(min(DENSE_SCAN_ROWS, max_search)):
        if check_row_for_header(header_row):
            found_header_row = header_row
            break

    if found_header_row is None:
        extended_dense = min(50, max_search)
        for header_row in range(DENSE_SCAN_ROWS, extended_dense):
            if check_row_for_header(header_row):
                found_header_row = header_row
                break

    if found_header_row is None and max_search > 50:
        for header_row in range(50, max_search, SAMPLE_INTERVAL):
            if check_row_for_header(header_row):
                found_header_row = header_row
                break

    if found_header_row is not None:
        df = df_raw.copy()
        df.columns = df.iloc[found_header_row].astype(str)
        df = df.iloc[found_header_row + 1 :].reset_index(drop=True)
        if is_pdf:
            df = _expand_multiline_rows(df)
        else:
            df = df.apply(lambda col: col.map(lambda val: str(val).replace("\n", " ").strip() if isinstance(val, str) else val))
        return df

    error_msg = (
        f"Could not find required columns (date and amount/withdrawal/deposit) "
        f"in the first {max_search} rows of the file. "
    )
    if sample_columns:
        error_msg += f"Sample columns found: {', '.join(sample_columns[:10])}"
    else:
        error_msg += "No valid column headers detected."
    raise SpendSenseParseError(error_msg)


def _normalize_columns(df: pd.DataFrame) -> pd.DataFrame:
    rename_map: dict[str, str] = {}
    used_canonicals: set[str] = set()

    priority_order = [
        "txn_date",
        "amount",
        "description",
        "direction",
        "currency",
        "merchant",
        "account_ref",
        "raw_txn_id",
        "withdrawal_amt",
        "deposit_amt",
    ]

    for column in df.columns:
        token = _normalize_token(str(column).strip())
        for canonical in priority_order:
            if canonical not in NORMALIZED_ALIASES:
                continue
            alias_tokens = NORMALIZED_ALIASES[canonical]
            if token in alias_tokens:
                if canonical in used_canonicals:
                    break
                rename_map[column] = canonical
                used_canonicals.add(canonical)
                break

    df = df.rename(columns=rename_map)

    if df.columns.duplicated().any():
        df = df.loc[:, ~df.columns.duplicated(keep="first")]

    has_date = REQUIRED_DATE_COLUMN in set(df.columns)
    has_amount = bool(set(df.columns) & REQUIRED_AMOUNT_COLUMNS)

    if not has_date:
        raise SpendSenseParseError(f"Missing required date column. Found columns: {', '.join(df.columns)}")
    if not has_amount:
        raise SpendSenseParseError(
            f"Missing required amount column (need one of: {', '.join(REQUIRED_AMOUNT_COLUMNS)}). "
            f"Found columns: {', '.join(df.columns)}"
        )
    return df


def _normalize_direction_series(df: pd.DataFrame) -> pd.Series:
    def _from_sign(val: Any) -> str | None:
        try:
            v = float(val)
        except (TypeError, ValueError):
            return None
        if v < 0:
            return "debit"
        return None

    def _from_text(val: Any) -> str | None:
        if val is None:
            return None
        s = str(val).strip().lower()
        if not s:
            return None

        if s.startswith(("c", "+")) or s in {"cr", "credit", "in", "inflow"}:
            return "credit"
        if s.startswith(("d", "-")) or s in {"dr", "debit", "out", "outflow"}:
            return "debit"
        return None

    def _from_description(desc: Any) -> str | None:
        if desc is None:
            return None
        desc_str = str(desc).upper()
        credit_keywords = ["SALARY", "CREDIT", "REFUND", "INTEREST", "DIVIDEND", "DEPOSIT", "CR"]
        if any(kw in desc_str for kw in credit_keywords):
            return "credit"
        return None

    amount_sign = df["amount"].map(_from_sign)
    desc_direction = None
    if "description" in df.columns:
        desc_direction = df["description"].map(_from_description)

    if "direction" in df.columns:
        dir_text = df["direction"].map(_from_text)
        final = dir_text.where(dir_text.notna(), desc_direction)
        final = final.where(final.notna(), amount_sign)
    else:
        final = desc_direction.where(desc_direction.notna(), amount_sign)

    final = final.fillna("debit")
    return final


def _normalize_currency(df: pd.DataFrame, default: str = "INR") -> pd.Series:
    if "currency" in df.columns:
        series = df["currency"].fillna(default).astype(str)
    else:
        series = pd.Series([default] * len(df), index=df.index)

    return series.str.upper()


def _extract_merchant_from_description(description: str) -> str | None:
    if not description or not isinstance(description, str):
        return None

    desc = description.strip()
    if not desc:
        return None

    if desc.upper().startswith("UPI-"):
        parts = desc.split("-", 2)
        if len(parts) >= 2:
            merchant = parts[1].strip()
            merchant = merchant.split("@")[0]
            merchant = merchant.split(".")[0]
            for processor in ["PAYU", "PAYTM", "RAZORPAY", "BILLDESK", "ICICI", "HDFC", "SBI"]:
                if merchant.upper().endswith(processor):
                    merchant = merchant[: -len(processor)].rstrip()
            return merchant.strip() if merchant else None

    if desc.upper().startswith("ACH "):
        parts = desc.split("-", 2)
        if len(parts) >= 2:
            merchant = parts[1].strip()
            return merchant.split("@")[0].split(".")[0].strip() or None

    if desc.upper().startswith("REV-") and "UPI-" in desc:
        rev_parts = desc.split("UPI-", 1)
        if len(rev_parts) == 2:
            merchant_part = rev_parts[1].split("-")[0] if "-" in rev_parts[1] else rev_parts[1]
            merchant = merchant_part.split("@")[0].split(".")[0].strip()
            return merchant or None

    if "UPI" in desc.upper() and "/" in desc:
        tokens = [token.strip() for token in re.split(r"[/\-]", desc) if token.strip()]
        skipped = {"UPI", "UPIOUT", "UPIIN", "UPIINTENT", "UPIPAY", "UPIPAYMENT", "UPIPAYMENTS"}
        for token in tokens:
            upper = token.upper()
            upper_compact = upper.replace(" ", "")
            if upper in skipped or upper_compact in skipped:
                continue
            if token.isdigit():
                continue
            cleaned = token.split("@")[0].replace(".", " ").strip()
            letter_count = sum(ch.isalpha() for ch in cleaned)
            digit_count = sum(ch.isdigit() for ch in cleaned)
            if cleaned and letter_count >= 3 and letter_count > digit_count and len(cleaned) <= 50:
                return cleaned

    merchant = desc.split("@")[0].split(".")[0].strip()
    if len(merchant) > 50 or merchant.isdigit():
        return None

    return merchant if merchant else None


def _normalize_merchant_name(merchant: str | None) -> str | None:
    if not merchant:
        return None

    normalized = " ".join(merchant.split()).title()
    replacements = {
        "Limited": "Ltd",
        "Private Limited": "Pvt Ltd",
        "Incorporated": "Inc",
    }

    for old, new in replacements.items():
        normalized = normalized.replace(old, new)

    return normalized if normalized else None


def dataframe_to_records(df: pd.DataFrame, *, bank_code: str | None = None) -> list[dict[str, Any]]:
    df = _normalize_columns(df)

    dates = pd.to_datetime(df["txn_date"], errors="coerce", dayfirst=True)
    invalid_dates = dates.isna()
    if invalid_dates.any():
        df = df[~invalid_dates].copy()
        dates = dates[~invalid_dates]
        if len(df) == 0:
            raise SpendSenseParseError("All rows had invalid dates. Could not parse any transactions.")
    df["txn_date"] = dates.dt.date

    if "amount" not in df.columns:
        withdrawal_col = df.get("withdrawal_amt")
        deposit_col = df.get("deposit_amt")

        if withdrawal_col is not None or deposit_col is not None:
            withdrawal = (
                pd.to_numeric(withdrawal_col, errors="coerce").fillna(0)
                if withdrawal_col is not None
                else pd.Series([0] * len(df), index=df.index)
            )
            deposit = (
                pd.to_numeric(deposit_col, errors="coerce").fillna(0)
                if deposit_col is not None
                else pd.Series([0] * len(df), index=df.index)
            )

            df["amount"] = withdrawal.where(withdrawal > 0, 0)
            df["amount"] = df["amount"].where(df["amount"] > 0, deposit)
            df["direction"] = withdrawal.apply(lambda x: "debit" if x > 0 else "credit")
            mask_summary = (withdrawal == 0) & (deposit == 0)
            df = df[~mask_summary].copy()
        elif withdrawal_col is not None:
            df["amount"] = pd.to_numeric(withdrawal_col, errors="coerce")
            df["direction"] = "debit"
        elif deposit_col is not None:
            df["amount"] = pd.to_numeric(deposit_col, errors="coerce")
            df["direction"] = "credit"
        else:
            raise SpendSenseParseError("No amount, withdrawal_amt, or deposit_amt column found")
    else:
        df["amount"] = pd.to_numeric(df["amount"], errors="coerce")

    invalid_amounts = df["amount"].isna()
    if invalid_amounts.any():
        df = df[~invalid_amounts].copy()
        if len(df) == 0:
            raise SpendSenseParseError("All rows had invalid amounts. Could not parse any transactions.")

    df["direction"] = _normalize_direction_series(df)
    df["currency"] = _normalize_currency(df, default="INR")

    if "merchant" in df.columns and not df["merchant"].isna().all():
        df["merchant"] = df["merchant"].apply(_normalize_merchant_name)
    else:
        df["merchant"] = None

    if "description" in df.columns:
        missing_merchant = df["merchant"].isna()
        if missing_merchant.any():
            df.loc[missing_merchant, "merchant"] = df.loc[missing_merchant, "description"].apply(
                _extract_merchant_from_description
            )

    records: list[dict[str, Any]] = []
    for row in df.to_dict(orient="records"):
        amount = float(row["amount"])
        description = str(row.get("description", "") or "")
        channel = detect_channel(description, row["direction"])
        records.append(
            {
                "txn_date": row["txn_date"],
                "description_raw": description,
                "amount": abs(amount),
                "direction": row["direction"],
                "currency": row["currency"],
                "merchant_raw": row.get("merchant"),
                "account_ref": row.get("account_ref"),
                "raw_txn_id": row.get("raw_txn_id"),
                "bank_code": bank_code,
                "channel": channel,
            }
        )

    return records

