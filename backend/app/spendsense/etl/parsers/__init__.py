from __future__ import annotations

from pathlib import Path
from typing import Any

from .common import SpendSenseParseError
from .excel_parser import parse_excel_file
from .pdf_parser import parse_pdf_file
from .email_parser import parse_email_payload


def parse_transactions_file(
    data: bytes,
    filename: str,
    pdf_password: str | None = None,
) -> list[dict[str, Any]]:
    """
    Dispatch parsing based on file extension.
    Supports CSV/XLS/XLSX, PDF, and (future) email sources.
    """
    ext = Path(filename).suffix.lower()

    if ext in {".csv", ".xls", ".xlsx"}:
        return parse_excel_file(data, filename)
    if ext == ".pdf":
        return parse_pdf_file(data, filename, pdf_password)
    if ext in {".eml", ".msg"}:
        return parse_email_payload(data, filename, pdf_password=pdf_password)

    raise SpendSenseParseError(f"Unsupported file extension: {ext}")


__all__ = ["parse_transactions_file", "SpendSenseParseError"]

