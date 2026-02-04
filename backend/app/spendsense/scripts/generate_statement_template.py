#!/usr/bin/env python3
"""
Generate the Monytix statement upload Excel template.
Run from repo root: python -m app.spendsense.scripts.generate_statement_template
Output: backend/static/Monytix_Statement_Template.xlsx (and optionally copied to frontend public)
"""

from __future__ import annotations

import sys
from pathlib import Path

# Add backend to path when run as script
backend_path = Path(__file__).resolve().parent.parent.parent.parent
sys.path.insert(0, str(backend_path))

import pandas as pd  # type: ignore[import-untyped]

# Column headers that the spendsense parser recognizes (see common.COLUMN_ALIASES)
HEADERS = [
    "Date",           # → txn_date
    "Amount",         # → amount (positive number)
    "Direction",      # → debit or credit
    "Description",   # → description_raw
    "Merchant",       # → merchant_raw (optional; can be inferred from description)
    "Currency",       # → optional, default INR
    "Reference",      # → raw_txn_id (optional)
]

SAMPLE_ROWS = [
    ("2025-01-15", 450.00, "debit", "UPI-Swiggy-ORDER123", "Swiggy", "INR", "TXN001"),
    ("2025-01-16", 1200.50, "debit", "Amazon Pay-ORDER456", "Amazon", "INR", "TXN002"),
    ("2025-01-20", 50000.00, "credit", "Salary credit Jan 2025", "", "INR", "SAL001"),
]

INSTRUCTIONS = """
Monytix Statement Upload Template
=================================

Required columns:
• Date       – Transaction date (YYYY-MM-DD or DD/MM/YYYY)
• Amount     – Amount as a positive number
• Direction  – "debit" (money out) or "credit" (money in)

Optional columns:
• Description – Narration/details (used to infer merchant if Merchant is empty)
• Merchant   – Payee or merchant name (e.g. Swiggy, Amazon)
• Currency   – e.g. INR (defaults to INR if empty)
• Reference  – Your reference or transaction ID

Tips:
• Keep the header row as-is so the file is recognized.
• You can add more rows below the sample data.
• Save as .xlsx or .csv and upload via SpendSense → Upload.
• Dates can be in YYYY-MM-DD or DD/MM/YYYY format.
""".strip()


def main() -> None:
    out_dir = backend_path / "static"
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / "Monytix_Statement_Template.xlsx"

    df = pd.DataFrame(SAMPLE_ROWS, columns=HEADERS)

    with pd.ExcelWriter(out_path, engine="openpyxl") as writer:
        df.to_excel(writer, sheet_name="Transactions", index=False)
        # Instructions sheet
        inst_df = pd.DataFrame([line for line in INSTRUCTIONS.split("\n")], columns=["Instructions"])
        inst_df.to_excel(writer, sheet_name="Instructions", index=False)

    print(f"Generated: {out_path}")

    # Optionally copy to frontend public for direct download
    import shutil
    frontend_public = backend_path.parent / "mony_mvp" / "public"
    if frontend_public.is_dir():
        dest = frontend_public / "Monytix_Statement_Template.xlsx"
        shutil.copy2(out_path, dest)
        print(f"Copied to: {dest}")


if __name__ == "__main__":
    main()
