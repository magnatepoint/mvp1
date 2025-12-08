"""
Bank-agnostic transaction parser configuration
Add new banks by simply adding a configuration entry - no code changes needed
"""
from typing import Dict, List, Optional, Any
from pydantic import BaseModel
from enum import Enum


class FileFormat(str, Enum):
    """Supported file formats"""
    CSV = "csv"
    EXCEL = "excel"
    XLS = "xls"
    XLSX = "xlsx"
    PDF = "pdf"


class FieldMapping(BaseModel):
    """Maps a canonical field to bank-specific column"""
    canonical_field: str  # Our standard field name (e.g., 'posted_at')
    bank_column: str  # Bank's column name (e.g., 'Transaction Date', 'Txn Date')
    column_index: Optional[int] = None  # Alternative: use column index (0-based)
    data_type: str = "string"  # string, date, decimal, integer
    date_format: Optional[str] = None  # e.g., '%d-%m-%Y', '%Y-%m-%d'
    required: bool = True  # Is this field mandatory?
    default_value: Optional[Any] = None  # Default if missing
    transform: Optional[str] = None  # Transformation function name


class BankConfig(BaseModel):
    """Configuration for a specific bank's transaction format"""
    bank_code: str  # Unique identifier (e.g., 'HDFC', 'ICICI', 'SBI')
    bank_name: str  # Display name
    file_formats: List[FileFormat]  # Supported formats
    
    # Field mappings
    field_mappings: List[FieldMapping]
    
    # Parsing rules
    header_row: int = 0  # Which row contains headers (0-based)
    data_start_row: int = 1  # Which row data starts (0-based)
    skip_rows: List[int] = []  # Rows to skip
    footer_rows: int = 0  # Number of footer rows to ignore
    
    # Identification rules (how to detect this bank)
    identifier_patterns: List[str] = []  # Regex patterns in file content
    identifier_columns: List[str] = []  # Expected column names
    
    # Additional metadata
    currency: str = "INR"  # Default currency
    timezone: str = "Asia/Kolkata"  # Default timezone
    
    # Custom parsing rules
    custom_rules: Dict[str, Any] = {}


# ============================================================================
# CANONICAL FIELD DEFINITIONS
# ============================================================================

CANONICAL_FIELDS = {
    "posted_at": "Transaction posting date",
    "amount": "Transaction amount (positive for credit, negative for debit)",
    "description": "Transaction description/narration",
    "merchant": "Merchant/payee name",
    "account_hint": "Last 4 digits of account/card",
    "reference_number": "Bank reference/transaction ID",
    "balance": "Account balance after transaction",
    "debit_amount": "Debit amount (if separate column)",
    "credit_amount": "Credit amount (if separate column)",
    "category": "Bank-provided category (if any)",
    "mode": "Transaction mode (UPI/NEFT/IMPS/etc)",
    "cheque_number": "Cheque number (if applicable)",
}


# ============================================================================
# BANK CONFIGURATIONS
# ============================================================================

BANK_CONFIGS: Dict[str, BankConfig] = {
    
    # HDFC Bank
    "HDFC": BankConfig(
        bank_code="HDFC",
        bank_name="HDFC Bank",
        file_formats=[FileFormat.XLS, FileFormat.XLSX, FileFormat.CSV, FileFormat.PDF],
        header_row=0,
        data_start_row=1,
        field_mappings=[
            FieldMapping(canonical_field="posted_at", bank_column="Date", data_type="date", date_format="%d/%m/%y"),
            FieldMapping(canonical_field="description", bank_column="Narration", data_type="string"),
            FieldMapping(canonical_field="reference_number", bank_column="Chq./Ref.No.", data_type="string", required=False),
            FieldMapping(canonical_field="debit_amount", bank_column="Withdrawal Amt.", data_type="decimal", required=False),
            FieldMapping(canonical_field="credit_amount", bank_column="Deposit Amt.", data_type="decimal", required=False),
            FieldMapping(canonical_field="balance", bank_column="Closing Balance", data_type="decimal", required=False),
        ],
        identifier_columns=["Date", "Narration", "Chq./Ref.No.", "Withdrawal Amt.", "Deposit Amt."],
        identifier_patterns=[r"HDFC\s+Bank", r"Chq\./Ref\.No\."],
        custom_rules={
            "amount_calculation": "credit_amount - debit_amount",  # Combine debit/credit into single amount
            "merchant_extraction": "extract_from_narration",  # Extract merchant from narration
        }
    ),
    
    # ICICI Bank
    "ICICI": BankConfig(
        bank_code="ICICI",
        bank_name="ICICI Bank",
        file_formats=[FileFormat.XLS, FileFormat.XLSX, FileFormat.CSV, FileFormat.PDF],
        header_row=0,
        data_start_row=1,
        field_mappings=[
            FieldMapping(canonical_field="posted_at", bank_column="Transaction Date", data_type="date", date_format="%d-%m-%Y"),
            FieldMapping(canonical_field="description", bank_column="Transaction Remarks", data_type="string"),
            FieldMapping(canonical_field="reference_number", bank_column="Cheque Number", data_type="string", required=False),
            FieldMapping(canonical_field="debit_amount", bank_column="Withdrawal Amount (INR )", data_type="decimal", required=False),
            FieldMapping(canonical_field="credit_amount", bank_column="Deposit Amount (INR )", data_type="decimal", required=False),
            FieldMapping(canonical_field="balance", bank_column="Balance (INR )", data_type="decimal", required=False),
        ],
        identifier_columns=["Transaction Date", "Transaction Remarks", "Withdrawal Amount (INR )", "Deposit Amount (INR )"],
        identifier_patterns=[r"ICICI\s+Bank", r"Transaction\s+Date"],
        custom_rules={
            "amount_calculation": "credit_amount - debit_amount",
            "merchant_extraction": "extract_from_narration",
        }
    ),
    
    # State Bank of India (SBI)
    "SBI": BankConfig(
        bank_code="SBI",
        bank_name="State Bank of India",
        file_formats=[FileFormat.XLS, FileFormat.XLSX, FileFormat.CSV, FileFormat.PDF],
        header_row=0,
        data_start_row=1,
        field_mappings=[
            FieldMapping(canonical_field="posted_at", bank_column="Txn Date", data_type="date", date_format="%d %b %Y"),
            FieldMapping(canonical_field="description", bank_column="Description", data_type="string"),
            FieldMapping(canonical_field="reference_number", bank_column="Ref No./Cheque No.", data_type="string", required=False),
            FieldMapping(canonical_field="debit_amount", bank_column="Debit", data_type="decimal", required=False),
            FieldMapping(canonical_field="credit_amount", bank_column="Credit", data_type="decimal", required=False),
            FieldMapping(canonical_field="balance", bank_column="Balance", data_type="decimal", required=False),
            FieldMapping(canonical_field="mode", bank_column="Mode", data_type="string", required=False),
        ],
        identifier_columns=["Txn Date", "Description", "Debit", "Credit", "Balance"],
        identifier_patterns=[r"State\s+Bank", r"Txn\s+Date"],
        custom_rules={
            "amount_calculation": "credit_amount - debit_amount",
            "merchant_extraction": "extract_from_narration",
        }
    ),
    
    # Federal Bank
    "FEDERAL": BankConfig(
        bank_code="FEDERAL",
        bank_name="Federal Bank",
        file_formats=[FileFormat.XLSX, FileFormat.CSV],
        header_row=0,
        data_start_row=1,
        field_mappings=[
            FieldMapping(canonical_field="posted_at", bank_column="Date", data_type="date", date_format="%d-%m-%Y"),
            FieldMapping(canonical_field="description", bank_column="Particulars", data_type="string"),
            FieldMapping(canonical_field="reference_number", bank_column="Instrument", data_type="string", required=False),
            FieldMapping(canonical_field="debit_amount", bank_column="Debit", data_type="decimal", required=False),
            FieldMapping(canonical_field="credit_amount", bank_column="Credit", data_type="decimal", required=False),
            FieldMapping(canonical_field="balance", bank_column="Balance", data_type="decimal", required=False),
        ],
        identifier_columns=["Date", "Particulars", "Debit", "Credit", "Balance"],
        identifier_patterns=[r"Federal\s+Bank"],
        custom_rules={
            "amount_calculation": "credit_amount - debit_amount",
            "merchant_extraction": "extract_from_narration",
        }
    ),
                
    # Kotak Mahindra Bank
    "KOTAK": BankConfig(
        bank_code="KOTAK",
        bank_name="Kotak Mahindra Bank",
        file_formats=[FileFormat.CSV, FileFormat.XLSX, FileFormat.PDF],
        header_row=0,
        data_start_row=1,
        field_mappings=[
            FieldMapping(canonical_field="posted_at", bank_column="Date", data_type="date", date_format="%d/%m/%Y"),
            FieldMapping(canonical_field="description", bank_column="Description", data_type="string"),
            FieldMapping(canonical_field="reference_number", bank_column="Reference No", data_type="string", required=False),
            FieldMapping(canonical_field="debit_amount", bank_column="Debit", data_type="decimal", required=False),
            FieldMapping(canonical_field="credit_amount", bank_column="Credit", data_type="decimal", required=False),
            FieldMapping(canonical_field="balance", bank_column="Balance", data_type="decimal", required=False),
        ],
        identifier_columns=["Date", "Description", "Debit", "Credit", "Balance"],
        identifier_patterns=[r"Kotak\s+Mahindra", r"Kotak\s+Bank"],
        custom_rules={
            "amount_calculation": "credit_amount - debit_amount",
            "merchant_extraction": "extract_from_narration",
        }
    ),
}


def get_bank_config(bank_code: str) -> Optional[BankConfig]:
    """Get configuration for a specific bank"""
    return BANK_CONFIGS.get(bank_code.upper())


def detect_bank_from_file(file_content: str, column_names: List[str]) -> Optional[str]:
    """
    Auto-detect bank from file content and column names
    Returns bank_code if detected, None otherwise
    """
    for bank_code, config in BANK_CONFIGS.items():
        # Check column name matching
        expected_cols = set(config.identifier_columns)
        actual_cols = set(column_names)
        
        # If 70% of expected columns match, it's likely this bank
        if len(expected_cols & actual_cols) / len(expected_cols) >= 0.7:
            return bank_code
    
    return None


def add_bank_config(config: BankConfig) -> None:
    """Add a new bank configuration dynamically"""
    BANK_CONFIGS[config.bank_code] = config

