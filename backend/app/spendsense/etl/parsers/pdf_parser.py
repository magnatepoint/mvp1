from __future__ import annotations

import io
import re
from typing import Any, Iterable, List, Tuple

import pdfplumber  # type: ignore[import-untyped]
from pdfplumber.utils.exceptions import PdfminerException  # type: ignore[import-untyped]

try:  # pdfminer exposes the password exception under this name
    from pdfminer.pdfdocument import PDFPasswordIncorrect as PDFPasswordError  # type: ignore[import-untyped]
except ImportError:  # pragma: no cover - fallback for unexpected versions
    PDFPasswordError = Exception  # type: ignore[assignment]

try:  # Optional PyMuPDF fallback
    import fitz  # type: ignore[import-untyped]
except ImportError:  # pragma: no cover - optional dependency
    fitz = None  # type: ignore[assignment]

import pandas as pd  # type: ignore[import-untyped]

from .common import SpendSenseParseError, dataframe_to_records, infer_bank_code, structure_dataframe

TABLE_SETTING_PRESETS: list[dict[str, Any] | None] = [
    None,  # default behaviour
    {
        "vertical_strategy": "lines",
        "horizontal_strategy": "lines",
        "intersection_tolerance": 5,
        "snap_tolerance": 3,
        "join_tolerance": 3,
        "edge_min_length": 3,
        "min_words_vertical": 1,
        "min_words_horizontal": 1,
    },
    {
        "vertical_strategy": "lines",
        "horizontal_strategy": "text",
        "intersection_tolerance": 5,
        "snap_tolerance": 3,
        "join_tolerance": 3,
        "min_words_vertical": 1,
        "min_words_horizontal": 1,
        "text_tolerance": 3,
    },
    {
        "vertical_strategy": "text",
        "horizontal_strategy": "text",
        "intersection_tolerance": 5,
        "snap_tolerance": 2,
        "text_tolerance": 3,
    },
]


def _extract_pdf_tables(buffer: io.BytesIO, password: str | None = None) -> pd.DataFrame:
    rows: list[list[str]] = []

    try:
        with pdfplumber.open(buffer, password=password) as pdf:
            for page in pdf.pages:
                tables: list[list[list[str | None]]] = []
                for settings in TABLE_SETTING_PRESETS:
                    if settings is None:
                        tables = page.extract_tables() or []
                    else:
                        tables = page.extract_tables(table_settings=settings) or []
                    if tables:
                        break

                for table in tables:
                    if not table:
                        continue
                    for raw_row in table:
                        if not raw_row:
                            continue
                        cleaned_row: list[str] = []
                        for cell in raw_row:
                            if cell is None:
                                cleaned_row.append("")
                            else:
                                cleaned_row.append(str(cell).strip())
                        if any(value for value in cleaned_row):
                            rows.append(cleaned_row)
    except PDFPasswordError:
        if password:
            raise SpendSenseParseError("Incorrect PDF password. Please re-enter and try again.")
        raise SpendSenseParseError("PDF is password protected. Enter the password before uploading.")
    except PdfminerException as exc:
        if exc.args and isinstance(exc.args[0], PDFPasswordError):
            if password:
                raise SpendSenseParseError("Incorrect PDF password. Please re-enter and try again.")
            raise SpendSenseParseError("PDF is password protected. Enter the password before uploading.")
        raise SpendSenseParseError(f"Unable to read PDF file: {exc}")

    if not rows:
        raise SpendSenseParseError("No tabular data found in PDF file")

    max_cols = max(len(row) for row in rows)
    normalized_rows = [row + [""] * (max_cols - len(row)) for row in rows]
    return pd.DataFrame(normalized_rows)


def _extract_lines_with_pymupdf(buffer: io.BytesIO) -> list[str] | None:
    if fitz is None:
        return None
    buffer.seek(0)
    try:
        doc = fitz.open(stream=buffer.read(), filetype="pdf")
    except Exception:
        return None

    lines: list[str] = []
    try:
        for page in doc:
            text = page.get_text("text") or ""
            for line in text.splitlines():
                stripped = line.strip()
                if stripped:
                    lines.append(stripped)
    finally:
        doc.close()
    return lines


def _maybe_parse_kotak_pdf(lines: list[str]) -> pd.DataFrame | None:
    if not lines:
        return None

    if not any("kotak" in line.lower() for line in lines):
        return None

    date_regex = re.compile(r"^(\d{2}-\d{2}-\d{4})$")
    amount_regex = re.compile(r"([\d,.]+)\((Cr|Dr)\)", re.IGNORECASE)
    parsed_rows: list[dict[str, Any]] = []
    i = 0

    while i < len(lines):
        line = lines[i]
        date_match = date_regex.match(line)
        if not date_match:
            i += 1
            continue

        txn_date = date_match.group(1)
        i += 1
        narration_parts: list[str] = []

        # Collect narration until we encounter an amount line
        amount_line = None
        while i < len(lines):
            candidate = lines[i]
            if amount_regex.search(candidate):
                amount_line = candidate
                break
            if date_regex.match(candidate):
                # Next date encountered unexpectedly; rewind one step
                break
            narration_parts.append(candidate)
            i += 1

        if amount_line is None or i >= len(lines):
            # Could not find amount/balance lines; continue scanning
            continue

        amount_match = amount_regex.search(amount_line)
        balance_line_index = i + 1
        if not amount_match or balance_line_index >= len(lines):
            i += 1
            continue

        balance_line = lines[balance_line_index]
        balance_match = amount_regex.search(balance_line)
        if not balance_match:
            i += 1
            continue

        description = " ".join(part.strip() for part in narration_parts if part.strip())
        amount_val = amount_match.group(1).replace(",", "")
        balance_val = balance_match.group(1).replace(",", "")
        try:
            amount_float = float(amount_val)
            balance_float = float(balance_val)
        except ValueError:
            i += 1
            continue

        amount_dir = amount_match.group(2).lower()
        balance_dir = balance_match.group(2).lower()

        row: dict[str, Any] = {
            "txn_date": txn_date,
            "description": description,
            "withdrawal_amt": None,
            "deposit_amt": None,
            "balance": balance_float if balance_dir == "cr" else -balance_float,
        }

        if amount_dir == "dr":
            row["withdrawal_amt"] = amount_float
        else:
            row["deposit_amt"] = amount_float

        parsed_rows.append(row)
        i = balance_line_index + 1  # Move past balance line

    if not parsed_rows:
        return None

    return pd.DataFrame(parsed_rows)


def _maybe_parse_hdfc_pdf(lines: list[str]) -> pd.DataFrame | None:
    """Parse HDFC bank PDF statements with vertical transaction format."""
    if not lines:
        return None

    # Detect HDFC bank
    if not any("hdfc" in line.lower() for line in lines[:50]):
        return None

    # HDFC date format: DD/MM/YY
    date_regex = re.compile(r"^(\d{2}/\d{2}/\d{2})$")
    # Amount format: numbers with commas and decimals (e.g., 140,000.00)
    amount_regex = re.compile(r"([\d,]+\.?\d*)")
    parsed_rows: list[dict[str, Any]] = []
    i = 0

    while i < len(lines):
        line = lines[i].strip()
        date_match = date_regex.match(line)
        if not date_match:
            i += 1
            continue

        txn_date = date_match.group(1)
        i += 1

        # Collect narration (may span multiple lines)
        narration_parts: list[str] = []
        chq_ref_no: str | None = None
        value_date: str | None = None
        withdrawal_amt: float | None = None
        deposit_amt: float | None = None
        closing_balance: float | None = None

        # Look for transaction components
        while i < len(lines):
            candidate = lines[i].strip()
            
            # Check if we hit the next transaction (new date)
            if date_regex.match(candidate):
                break

            # Check for Chq/Ref No (usually starts with digits or UPI-)
            if not chq_ref_no and (candidate.startswith("UPI-") or candidate.startswith("0000") or re.match(r"^\d+", candidate)):
                chq_ref_no = candidate
                i += 1
                continue

            # Check for Value Date
            value_date_match = date_regex.match(candidate)
            if value_date_match and not value_date:
                value_date = value_date_match.group(1)
                i += 1
                continue

            # Check for amount (numbers with commas)
            amount_match = amount_regex.search(candidate)
            if amount_match and len(candidate.split()) <= 2:  # Simple amount line
                amount_val = amount_match.group(1).replace(",", "")
                try:
                    amount_float = float(amount_val)
                    # If we haven't set withdrawal/deposit yet, this might be it
                    # Next line should be closing balance
                    if i + 1 < len(lines):
                        next_line = lines[i + 1].strip()
                        next_amount_match = amount_regex.search(next_line)
                        if next_amount_match and len(next_line.split()) <= 2:
                            # This is withdrawal/deposit, next is balance
                            # We need to determine if it's withdrawal or deposit
                            # In HDFC format, if there's a withdrawal, deposit is empty and vice versa
                            # We'll check the balance change to determine direction
                            balance_val = next_amount_match.group(1).replace(",", "")
                            try:
                                balance_float = float(balance_val)
                                closing_balance = balance_float
                                
                                # Determine direction based on context
                                # If we see "Withdrawal" in nearby lines, it's withdrawal
                                # Otherwise, check if amount increases balance (deposit) or decreases (withdrawal)
                                # For now, we'll use a heuristic: if previous balance exists, compare
                                if parsed_rows:
                                    prev_balance = parsed_rows[-1].get("balance", 0) or 0
                                    if balance_float > prev_balance:
                                        deposit_amt = amount_float
                                    else:
                                        withdrawal_amt = amount_float
                                else:
                                    # First transaction - assume deposit if balance is positive
                                    if amount_float > 0:
                                        deposit_amt = amount_float
                                    else:
                                        withdrawal_amt = abs(amount_float)
                                
                                i += 2  # Skip both amount and balance lines
                                break
                            except ValueError:
                                pass
                except ValueError:
                    pass

            # Collect as narration if not matched above
            if candidate and not date_regex.match(candidate):
                narration_parts.append(candidate)
            
            i += 1

        # Build transaction row
        if txn_date and (withdrawal_amt is not None or deposit_amt is not None):
            description = " ".join(part.strip() for part in narration_parts if part.strip())
            
            row: dict[str, Any] = {
                "txn_date": value_date if value_date else txn_date,
                "description": description,
                "withdrawal_amt": withdrawal_amt,
                "deposit_amt": deposit_amt,
                "balance": closing_balance,
            }
            
            if chq_ref_no:
                row["raw_txn_id"] = chq_ref_no

            parsed_rows.append(row)

    if not parsed_rows:
        return None

    return pd.DataFrame(parsed_rows)


def _maybe_parse_icici_pdf(lines: list[str]) -> pd.DataFrame | None:
    """Parse ICICI bank PDF statements as fallback when generic extraction fails."""
    if not lines:
        return None

    # Detect ICICI bank
    if not any("icici" in line.lower() for line in lines[:50]):
        return None

    # ICICI date format: DD/MM/YYYY
    date_regex = re.compile(r"^(\d{2}/\d{2}/\d{4})$")
    # Amount format: numbers with commas (e.g., 21.00, 3,035.00)
    amount_regex = re.compile(r"([\d,]+\.?\d*)")
    parsed_rows: list[dict[str, Any]] = []
    i = 0

    # Look for transaction table start
    # ICICI statements have a table with headers
    header_found = False
    for j, line in enumerate(lines[:100]):
        if "value date" in line.lower() or "transaction date" in line.lower():
            header_found = True
            i = j + 1
            break

    if not header_found:
        # Try to find transactions by date pattern
        i = 0

    while i < len(lines):
        line = lines[i].strip()
        date_match = date_regex.match(line)
        if not date_match:
            i += 1
            continue

        # Found a date - could be Value Date or Transaction Date
        first_date = date_match.group(1)
        i += 1

        # Look for second date (Transaction Date if first was Value Date)
        second_date: str | None = None
        if i < len(lines):
            second_date_match = date_regex.match(lines[i].strip())
            if second_date_match:
                second_date = second_date_match.group(1)
                i += 1

        # Use Transaction Date if available, otherwise Value Date
        txn_date = second_date if second_date else first_date

        # Collect description/remarks (may span multiple lines)
        description_parts: list[str] = []
        withdrawal_amt: float | None = None
        deposit_amt: float | None = None
        balance: float | None = None

        # Look for amounts and description
        while i < len(lines):
            candidate = lines[i].strip()
            
            # Check if we hit the next transaction (new date)
            if date_regex.match(candidate):
                break

            # Check for amount (withdrawal or deposit)
            amount_match = amount_regex.search(candidate)
            if amount_match:
                amount_val = amount_match.group(1).replace(",", "")
                try:
                    amount_float = float(amount_val)
                    # Check if this is withdrawal or deposit
                    # In ICICI format, amounts are in separate columns
                    # We need to determine based on position or context
                    # For now, we'll check the next few lines for balance
                    if i + 1 < len(lines):
                        next_candidate = lines[i + 1].strip()
                        next_amount_match = amount_regex.search(next_candidate)
                        if next_amount_match:
                            next_amount_val = next_amount_match.group(1).replace(",", "")
                            try:
                                next_amount_float = float(next_amount_val.replace(",", ""))
                                # If next is also a number, first might be withdrawal, second deposit, or vice versa
                                # Or first could be withdrawal, second balance
                                # Let's check if there's a pattern
                                if not withdrawal_amt and not deposit_amt:
                                    # First amount - could be withdrawal or deposit
                                    # Check if there's a balance later
                                    if i + 2 < len(lines):
                                        balance_candidate = lines[i + 2].strip()
                                        balance_match = amount_regex.search(balance_candidate)
                                        if balance_match:
                                            balance_val = balance_match.group(1).replace(",", "")
                                            try:
                                                balance = float(balance_val.replace(",", ""))
                                                # Heuristic: if we have previous balance, determine direction
                                                if parsed_rows:
                                                    prev_balance = parsed_rows[-1].get("balance", 0) or 0
                                                    if balance > prev_balance:
                                                        deposit_amt = amount_float
                                                    else:
                                                        withdrawal_amt = amount_float
                                                else:
                                                    # First transaction
                                                    withdrawal_amt = amount_float
                                                i += 3
                                                break
                                            except ValueError:
                                                pass
                            except ValueError:
                                pass
                    
                    # If we haven't determined yet, collect as description
                    if not withdrawal_amt and not deposit_amt:
                        description_parts.append(candidate)
                except ValueError:
                    description_parts.append(candidate)
            else:
                # Not an amount, collect as description
                description_parts.append(candidate)
            
            i += 1

        # Build transaction row
        if txn_date:
            description = " ".join(part.strip() for part in description_parts if part.strip())
            
            # Only add if we have at least an amount or description
            if withdrawal_amt is not None or deposit_amt is not None or description:
                row: dict[str, Any] = {
                    "txn_date": txn_date,
                    "description": description,
                    "withdrawal_amt": withdrawal_amt,
                    "deposit_amt": deposit_amt,
                    "balance": balance,
                }
                parsed_rows.append(row)

    if not parsed_rows:
        return None

    return pd.DataFrame(parsed_rows)


def _maybe_parse_federal_pdf(lines: list[str]) -> pd.DataFrame | None:
    """Parse Federal Bank PDF statements as fallback when generic extraction fails."""
    if not lines:
        return None

    # Detect Federal bank
    if not any("federal" in line.lower() for line in lines[:50]):
        return None

    # Federal Bank typically uses standard formats
    # This is a placeholder - will be enhanced once we have sample PDF
    # For now, return None to let generic parser handle it
    return None


def _maybe_parse_axis_pdf(lines: list[str]) -> pd.DataFrame | None:
    """Parse Axis Bank PDF statements as fallback when generic extraction fails."""
    if not lines:
        return None

    # Detect Axis bank
    if not any("axis" in line.lower() for line in lines[:50]):
        return None

    # Axis Bank typically uses standard formats
    # This is a placeholder - will be enhanced once we have sample PDF
    # For now, return None to let generic parser handle it
    return None


def parse_pdf_file(data: bytes, filename: str, password: str | None = None) -> list[dict[str, Any]]:
    buffer = io.BytesIO(data)
    bank_code = infer_bank_code(filename)
    try:
        df_raw = _extract_pdf_tables(buffer, password)
        df = structure_dataframe(df_raw, is_pdf=True)
    except SpendSenseParseError as primary_error:
        lines = _extract_lines_with_pymupdf(buffer)
        if lines:
            # Try bank-specific parsers in order
            bank_parsers = [
                _maybe_parse_kotak_pdf,
                _maybe_parse_hdfc_pdf,
                _maybe_parse_icici_pdf,
                _maybe_parse_federal_pdf,
                _maybe_parse_axis_pdf,
            ]
            
            for parser in bank_parsers:
                df = parser(lines)
                if df is not None:
                    return dataframe_to_records(df, bank_code=bank_code)
        raise primary_error
    return dataframe_to_records(df, bank_code=bank_code)

