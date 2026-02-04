#!/usr/bin/env python3
"""
Generate the Monytix statement upload Excel template.
Run from repo root: python -m app.spendsense.scripts.generate_statement_template
Output: backend/static/Monytix_Statement_Template.xlsx (and optionally copied to frontend public)
"""

from __future__ import annotations

import asyncio
import sys
from pathlib import Path

# Add backend to path when run as script
backend_path = Path(__file__).resolve().parent.parent.parent.parent
sys.path.insert(0, str(backend_path))

import pandas as pd  # type: ignore[import-untyped]
import asyncpg
from openpyxl import load_workbook  # type: ignore[import-untyped]
from openpyxl.worksheet.datavalidation import DataValidation  # type: ignore[import-untyped]

from app.core.config import get_settings

# Column headers that the spendsense parser recognizes (see common.COLUMN_ALIASES)
HEADERS = [
    "Date",           # → txn_date
    "Amount",         # → amount (positive number)
    "Direction",      # → debit or credit
    "Description",   # → description_raw
    "Merchant",       # → merchant_raw (optional; can be inferred from description)
    "Category",       # → category_code (MANDATORY)
    "Subcategory",    # → subcategory_code (MANDATORY)
    "Currency",       # → optional, default INR
    "Reference",      # → raw_txn_id (optional)
]

SAMPLE_ROWS = [
    ("2025-01-15", 450.00, "debit", "UPI-Swiggy-ORDER123", "Swiggy", "dining", "zomato", "INR", "TXN001"),
    ("2025-01-16", 1200.50, "debit", "Amazon Pay-ORDER456", "Amazon", "shopping", "amazon", "INR", "TXN002"),
    ("2025-01-20", 50000.00, "credit", "Salary credit Jan 2025", "", "income", "", "INR", "SAL001"),
]

INSTRUCTIONS = """
Monytix Statement Upload Template
=================================

Required columns:
• Date         – Transaction date (YYYY-MM-DD or DD/MM/YYYY)
• Amount       – Amount as a positive number
• Direction    – "debit" (money out) or "credit" (money in)
• Category     – Select from dropdown (MANDATORY)
• Subcategory  – Select from dropdown (MANDATORY, depends on Category)

Optional columns:
• Description  – Narration/details (used to infer merchant if Merchant is empty)
• Merchant     – Payee or merchant name (e.g. Swiggy, Amazon)
• Currency     – e.g. INR (defaults to INR if empty)
• Reference    – Your reference or transaction ID

Tips:
• Keep the header row as-is so the file is recognized.
• Category and Subcategory are MANDATORY - use the dropdowns to select values.
• Subcategory options change based on the selected Category.
• You can add more rows below the sample data.
• Save as .xlsx or .csv and upload via SpendSense → Upload.
• Dates can be in YYYY-MM-DD or DD/MM/YYYY format.
""".strip()


async def fetch_categories_and_subcategories() -> tuple[list[tuple[str, str]], dict[str, list[tuple[str, str]]]]:
    """Fetch categories and subcategories from database."""
    settings = get_settings()
    conn = await asyncpg.connect(
        str(settings.postgres_dsn),
        statement_cache_size=0,
    )
    try:
        # Fetch categories
        category_rows = await conn.fetch("""
            SELECT category_code, category_name
            FROM spendsense.dim_category
            WHERE active = TRUE
            ORDER BY display_order, category_name
        """)
        categories = [(row['category_code'], row['category_name']) for row in category_rows]

        # Fetch subcategories grouped by category
        subcat_rows = await conn.fetch("""
            SELECT category_code, subcategory_code, subcategory_name
            FROM spendsense.dim_subcategory
            WHERE active = TRUE
            ORDER BY category_code, display_order, subcategory_name
        """)
        subcategories_by_category: dict[str, list[tuple[str, str]]] = {}
        for row in subcat_rows:
            cat_code = row['category_code']
            if cat_code not in subcategories_by_category:
                subcategories_by_category[cat_code] = []
            subcategories_by_category[cat_code].append(
                (row['subcategory_code'], row['subcategory_name'])
            )

        return categories, subcategories_by_category
    finally:
        await conn.close()


def main() -> None:
    out_dir = backend_path / "static"
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / "Monytix_Statement_Template.xlsx"

    # Fetch categories and subcategories from database
    print("Fetching categories and subcategories from database...")
    categories, subcategories_by_category = asyncio.run(fetch_categories_and_subcategories())
    print(f"Found {len(categories)} categories and {sum(len(subs) for subs in subcategories_by_category.values())} subcategories")

    # Create DataFrame
    df = pd.DataFrame(SAMPLE_ROWS, columns=HEADERS)

    # Write to Excel first
    with pd.ExcelWriter(out_path, engine="openpyxl") as writer:
        df.to_excel(writer, sheet_name="Transactions", index=False)
        # Instructions sheet
        inst_df = pd.DataFrame([line for line in INSTRUCTIONS.split("\n")], columns=["Instructions"])
        inst_df.to_excel(writer, sheet_name="Instructions", index=False)

    # Now add data validation dropdowns using openpyxl
    wb = load_workbook(out_path)
    ws = wb["Transactions"]

    # Category column (column F, index 5)
    category_codes = [cat[0] for cat in categories]
    category_display = [f"{cat[0]} - {cat[1]}" for cat in categories]
    category_formula = f'"{",".join(category_codes)}"'
    
    # Create a helper sheet for category lookup (hidden)
    helper_sheet = wb.create_sheet("_CategoryLookup")
    helper_sheet.append(["category_code"])
    for cat_code in category_codes:
        helper_sheet.append([cat_code])
    
    # Category dropdown (column F)
    category_dv = DataValidation(
        type="list",
        formula1=f'_CategoryLookup!$A$2:$A${len(category_codes) + 1}',
        allow_blank=False,
        showErrorMessage=True,
        errorTitle="Invalid Category",
        error="Please select a category from the dropdown list.",
    )
    category_dv.add(f"F2:F1048576")  # Apply to all rows (Excel max rows)
    ws.add_data_validation(category_dv)

    # Subcategory column (column G, index 6)
    # We'll use INDIRECT to make it dynamic based on category
    # First, create a named range for each category's subcategories
    for cat_code, subcats in subcategories_by_category.items():
        if not subcats:
            continue
        # Create a sheet for this category's subcategories
        subcat_sheet_name = f"_Subcat_{cat_code[:20]}"  # Excel sheet name limit
        if subcat_sheet_name in wb.sheetnames:
            wb.remove(wb[subcat_sheet_name])
        subcat_sheet = wb.create_sheet(subcat_sheet_name)
        subcat_sheet.append(["subcategory_code"])
        for sub_code, _ in subcats:
            subcat_sheet.append([sub_code])
        
        # Create named range (Excel doesn't support dynamic INDIRECT easily, so we'll use a simpler approach)
        # For now, we'll create a validation that allows all subcategories (user must pick valid one for category)
    
    # Create a combined subcategory lookup sheet
    all_subcat_sheet = wb.create_sheet("_SubcategoryLookup")
    all_subcat_sheet.append(["category_code", "subcategory_code"])
    for cat_code, subcats in subcategories_by_category.items():
        for sub_code, sub_name in subcats:
            all_subcat_sheet.append([cat_code, sub_code])
    
    # Subcategory dropdown - simpler: allow all subcategories (validation happens on backend)
    all_subcat_codes = []
    for subcats in subcategories_by_category.values():
        all_subcat_codes.extend([sub[0] for sub in subcats])
    
    if all_subcat_codes:
        subcat_lookup_sheet = wb.create_sheet("_AllSubcats")
        subcat_lookup_sheet.append(["subcategory_code"])
        for sub_code in sorted(set(all_subcat_codes)):
            subcat_lookup_sheet.append([sub_code])
        
        subcategory_dv = DataValidation(
            type="list",
            formula1=f'_AllSubcats!$A$2:$A${len(set(all_subcat_codes)) + 1}',
            allow_blank=False,
            showErrorMessage=True,
            errorTitle="Invalid Subcategory",
            error="Please select a subcategory from the dropdown list.",
        )
        subcategory_dv.add(f"G2:G1048576")
        ws.add_data_validation(subcategory_dv)

    # Hide helper sheets
    for sheet_name in wb.sheetnames:
        if sheet_name.startswith("_"):
            wb[sheet_name].sheet_state = "hidden"

    # Direction dropdown (column C)
    direction_dv = DataValidation(
        type="list",
        formula1='"debit,credit"',
        allow_blank=False,
    )
    direction_dv.add("C2:C1048576")
    ws.add_data_validation(direction_dv)

    wb.save(out_path)
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
