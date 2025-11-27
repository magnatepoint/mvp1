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


def parse_pdf_file(data: bytes, filename: str, password: str | None = None) -> list[dict[str, Any]]:
    buffer = io.BytesIO(data)
    bank_code = infer_bank_code(filename)
    try:
        df_raw = _extract_pdf_tables(buffer, password)
        df = structure_dataframe(df_raw, is_pdf=True)
    except SpendSenseParseError as primary_error:
        lines = _extract_lines_with_pymupdf(buffer)
        if lines:
            kotak_df = _maybe_parse_kotak_pdf(lines)
            if kotak_df is not None:
                return dataframe_to_records(kotak_df, bank_code=bank_code)
        raise primary_error
    return dataframe_to_records(df, bank_code=bank_code)

