from __future__ import annotations

import io
from pathlib import Path

import pandas as pd  # type: ignore[import-untyped]

from .common import SpendSenseParseError, dataframe_to_records, structure_dataframe, infer_bank_code

try:  # xlrd raises XLRDError for malformed XLS files
    from xlrd.biffh import XLRDError  # type: ignore[import-untyped]
except Exception:  # pragma: no cover
    class XLRDError(Exception):  # type: ignore
        pass


def parse_excel_file(data: bytes, filename: str) -> list[dict]:
    """Parse CSV/XLS/XLSX statements into normalized records."""
    ext = Path(filename).suffix.lower()
    buffer = io.BytesIO(data)

    if ext == ".csv":
        buffer.seek(0)
        df_raw = pd.read_csv(buffer, header=None, keep_default_na=False)
    elif ext in {".xls", ".xlsx"}:
        buffer.seek(0)
        try:
            df_raw = pd.read_excel(buffer, header=None, keep_default_na=False)
        except (ValueError, UnicodeDecodeError, XLRDError):
            df_raw = _read_text_like_spreadsheet(data)
            if df_raw is None:
                raise SpendSenseParseError(
                    f"Unable to read spreadsheet contents from {filename}. "
                    "Please upload a valid Excel/CSV export."
                )
    else:
        raise SpendSenseParseError(f"Unsupported Excel extension: {ext}")

    sample_text = " ".join(df_raw.head(5).astype(str).values.ravel().tolist())
    bank_code = infer_bank_code(filename, sample_text)
    df = structure_dataframe(df_raw, is_pdf=False)
    return dataframe_to_records(df, bank_code=bank_code)


def _read_text_like_spreadsheet(data: bytes) -> pd.DataFrame | None:
    """Fallback for XLS files that are actually tab/space-delimited text."""
    text = _decode_bytes(data)
    if not text.strip():
        return None
    rows: list[list[str]] = []
    has_tab = "\t" in text
    for raw_line in text.splitlines():
        if not raw_line.strip():
            continue
        if has_tab:
            cells = [cell.strip() for cell in raw_line.split("\t")]
        else:
            # Fallback: collapse multiple spaces
            cells = [segment.strip() for segment in raw_line.split("  ") if segment.strip()]
            if not cells:
                cells = [raw_line.strip()]
        rows.append(cells)

    if not rows:
        return None

    max_cols = max(len(row) for row in rows)
    normalized = [row + [""] * (max_cols - len(row)) for row in rows]
    return pd.DataFrame(normalized)


def _decode_bytes(data: bytes) -> str:
    for encoding in ("utf-8", "latin-1"):
        try:
            return data.decode(encoding)
        except UnicodeDecodeError:
            continue
    return data.decode("utf-8", errors="ignore")

