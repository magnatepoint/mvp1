"""
Unified bank transaction parser
Works with any bank by using configuration from bank_parser_config.py
"""
import re
import csv
import io
from datetime import datetime
from decimal import Decimal
from typing import List, Dict, Any, Optional, BinaryIO
import logging

from .bank_parser_config import (
    BankConfig, 
    get_bank_config, 
    detect_bank_from_file,
    CANONICAL_FIELDS,
    FileFormat
)

logger = logging.getLogger(__name__)


class BankTransactionParser:
    """
    Unified parser that works with any bank configuration
    No bank-specific code - all logic driven by configuration
    """
    
    def __init__(self, bank_code: Optional[str] = None):
        """
        Initialize parser
        
        Args:
            bank_code: Bank identifier (e.g., 'HDFC', 'ICICI'). If None, will auto-detect
        """
        self.bank_code = bank_code
        self.config: Optional[BankConfig] = None
        
        if bank_code:
            self.config = get_bank_config(bank_code)
            if not self.config:
                raise ValueError(f"Unknown bank code: {bank_code}")
    
    def parse_file(self, file_content: BinaryIO, file_format: str = "csv") -> List[Dict[str, Any]]:
        """
        Parse bank statement file into standardized transactions
        
        Args:
            file_content: File content (binary)
            file_format: File format (csv, excel, xls, xlsx, pdf)
        
        Returns:
            List of parsed transactions in canonical format
        """
        # Read file based on format
        if file_format.lower() in ['csv']:
            raw_data, column_names = self._parse_csv(file_content)
        elif file_format.lower() in ['xls', 'xlsx', 'excel']:
            raw_data, column_names = self._parse_excel(file_content, file_format)
        elif file_format.lower() == 'pdf':
            raw_data, column_names = self._parse_pdf(file_content)
        else:
            raise ValueError(f"Unsupported file format: {file_format}")
        
        # Auto-detect bank if not specified
        if not self.config:
            detected_bank = detect_bank_from_file("", column_names)
            if detected_bank:
                self.bank_code = detected_bank
                self.config = get_bank_config(detected_bank)
                logger.info(f"Auto-detected bank: {self.config.bank_name}")
            else:
                raise ValueError("Could not auto-detect bank. Please specify bank_code.")
        
        # Parse transactions using configuration
        transactions = self._parse_transactions(raw_data, column_names)
        
        return transactions
    
    def _parse_csv(self, file_content: BinaryIO) -> tuple[List[List[str]], List[str]]:
        """Parse CSV file"""
        content = file_content.read().decode('utf-8')
        reader = csv.reader(io.StringIO(content))
        rows = list(reader)
        
        if not rows:
            return [], []
        
        # Extract headers and data based on config
        header_row = self.config.header_row if self.config else 0
        data_start = self.config.data_start_row if self.config else 1
        
        column_names = rows[header_row] if len(rows) > header_row else []
        data_rows = rows[data_start:] if len(rows) > data_start else []
        
        return data_rows, column_names
    
    def _parse_excel(self, file_content: BinaryIO, file_format: str) -> tuple[List[List[Any]], List[str]]:
        """Parse Excel file (xls or xlsx)"""
        try:
            import openpyxl
            import xlrd
        except ImportError:
            raise ImportError("openpyxl and xlrd required for Excel parsing. Install with: pip install openpyxl xlrd")
        
        if file_format.lower() == 'xlsx':
            # Use openpyxl for .xlsx
            wb = openpyxl.load_workbook(file_content)
            ws = wb.active
            rows = list(ws.iter_rows(values_only=True))
        else:
            # Use xlrd for .xls
            wb = xlrd.open_workbook(file_contents=file_content.read())
            ws = wb.sheet_by_index(0)
            rows = [ws.row_values(i) for i in range(ws.nrows)]
        
        if not rows:
            return [], []
        
        header_row = self.config.header_row if self.config else 0
        data_start = self.config.data_start_row if self.config else 1
        
        column_names = [str(c) if c else "" for c in rows[header_row]] if len(rows) > header_row else []
        data_rows = rows[data_start:] if len(rows) > data_start else []
        
        return data_rows, column_names
    
    def _parse_pdf(self, file_content: BinaryIO) -> tuple[List[List[str]], List[str]]:
        """Parse PDF file (requires pdfplumber or similar)"""
        try:
            import pdfplumber
        except ImportError:
            raise ImportError("pdfplumber required for PDF parsing. Install with: pip install pdfplumber")
        
        # PDF parsing logic here
        # This is a placeholder - actual implementation depends on PDF structure
        raise NotImplementedError("PDF parsing not yet implemented")
    
    def _parse_transactions(self, raw_data: List[List[Any]], column_names: List[str]) -> List[Dict[str, Any]]:
        """
        Parse raw data into canonical transaction format
        This is the core parsing logic - completely configuration-driven
        """
        transactions = []
        
        # Create column name to index mapping
        col_map = {name.strip(): idx for idx, name in enumerate(column_names)}
        
        for row_idx, row in enumerate(raw_data):
            # Skip empty rows
            if not row or all(not cell for cell in row):
                continue
            
            # Skip rows specified in config
            if row_idx in self.config.skip_rows:
                continue
            
            # Parse transaction using field mappings
            txn = self._parse_single_transaction(row, col_map)
            
            if txn:
                transactions.append(txn)
        
        return transactions
    
    def _parse_single_transaction(self, row: List[Any], col_map: Dict[str, int]) -> Optional[Dict[str, Any]]:
        """Parse a single transaction row into canonical format"""
        txn = {}
        
        # Temporary storage for debit/credit amounts
        debit_amount = None
        credit_amount = None
        
        for field_mapping in self.config.field_mappings:
            canonical_field = field_mapping.canonical_field
            bank_column = field_mapping.bank_column
            
            # Get value from row
            value = None
            if bank_column in col_map:
                col_idx = col_map[bank_column]
                if col_idx < len(row):
                    value = row[col_idx]
            elif field_mapping.column_index is not None:
                if field_mapping.column_index < len(row):
                    value = row[field_mapping.column_index]
            
            # Handle missing required fields
            if value is None or value == '':
                if field_mapping.required:
                    if field_mapping.default_value is not None:
                        value = field_mapping.default_value
                    else:
                        # Skip this transaction if required field is missing
                        return None
                else:
                    value = field_mapping.default_value
                    continue
            
            # Convert value based on data type
            converted_value = self._convert_value(value, field_mapping)
            
            # Store debit/credit for later calculation
            if canonical_field == "debit_amount":
                debit_amount = converted_value
            elif canonical_field == "credit_amount":
                credit_amount = converted_value
            else:
                txn[canonical_field] = converted_value
        
        # Apply custom rules
        txn = self._apply_custom_rules(txn, debit_amount, credit_amount)

        return txn if txn else None

    def _convert_value(self, value: Any, field_mapping) -> Any:
        """Convert value to appropriate data type"""
        if value is None or value == '':
            return None

        data_type = field_mapping.data_type

        try:
            if data_type == "date":
                # Handle date conversion
                if isinstance(value, datetime):
                    return value

                date_str = str(value).strip()
                if field_mapping.date_format:
                    return datetime.strptime(date_str, field_mapping.date_format)
                else:
                    # Try common formats
                    for fmt in ['%d/%m/%Y', '%d-%m-%Y', '%Y-%m-%d', '%d/%m/%y', '%d-%m-%y']:
                        try:
                            return datetime.strptime(date_str, fmt)
                        except ValueError:
                            continue
                    raise ValueError(f"Could not parse date: {date_str}")

            elif data_type == "decimal":
                # Handle decimal/amount conversion
                if isinstance(value, (int, float, Decimal)):
                    return Decimal(str(value))

                # Clean string (remove currency symbols, commas, etc.)
                amount_str = str(value).strip()
                amount_str = re.sub(r'[^\d.-]', '', amount_str)

                if amount_str == '' or amount_str == '-':
                    return Decimal('0')

                return Decimal(amount_str)

            elif data_type == "integer":
                return int(float(str(value).strip()))

            else:  # string
                return str(value).strip()

        except Exception as e:
            logger.warning(f"Error converting value '{value}' to {data_type}: {e}")
            return None

    def _apply_custom_rules(self, txn: Dict[str, Any], debit_amount: Optional[Decimal],
                           credit_amount: Optional[Decimal]) -> Dict[str, Any]:
        """Apply bank-specific custom rules"""
        custom_rules = self.config.custom_rules

        # Calculate amount from debit/credit if needed
        if "amount_calculation" in custom_rules:
            rule = custom_rules["amount_calculation"]

            if rule == "credit_amount - debit_amount":
                # Standard: credit is positive, debit is negative
                credit = credit_amount if credit_amount else Decimal('0')
                debit = debit_amount if debit_amount else Decimal('0')
                txn["amount"] = credit - debit

            elif rule == "debit_amount - credit_amount":
                # Reverse: debit is positive, credit is negative
                debit = debit_amount if debit_amount else Decimal('0')
                credit = credit_amount if credit_amount else Decimal('0')
                txn["amount"] = debit - credit

        # Extract merchant from description/narration
        if "merchant_extraction" in custom_rules:
            rule = custom_rules["merchant_extraction"]

            if rule == "extract_from_narration" and "description" in txn:
                merchant = self._extract_merchant_from_narration(txn["description"])
                if merchant:
                    txn["merchant"] = merchant

        # Add bank metadata
        txn["bank_code"] = self.config.bank_code
        txn["bank_name"] = self.config.bank_name
        txn["currency"] = self.config.currency

        return txn

    def _extract_merchant_from_narration(self, narration: str) -> Optional[str]:
        """
        Extract merchant name from transaction narration
        Common patterns:
        - SBI: TO TRANSFER-UPI/DR/<rrn>/<name>/<bank>/<vpa>/<platform>
        - SBI: BY TRANSFER-UPI/CR/<rrn>/<name>/<bank>/<vpa>/<platform>
        - UPI/MERCHANT_NAME/REF
        - NEFT/MERCHANT_NAME
        - POS MERCHANT_NAME
        """
        if not narration:
            return None

        # SBI Bank format: TO TRANSFER-UPI/DR/<rrn>/<name>/<bank>/<vpa>/<platform>
        # Example: TO TRANSFER-UPI/DR/730765131673/CHINTALA/SBIN/chvkchanti/Payme--
        sbi_to_match = re.search(r'TO TRANSFER-UPI/DR/[^/]+/([^/]+)/', narration, re.IGNORECASE)
        if sbi_to_match:
            merchant = sbi_to_match.group(1).strip()
            # Remove trailing spaces and normalize
            return merchant.strip() if merchant else None

        # SBI Bank format: BY TRANSFER-UPI/CR/<rrn>/<name>/<bank>/<vpa>/<platform>
        sbi_by_match = re.search(r'BY TRANSFER-UPI/CR/[^/]+/([^/]+)/', narration, re.IGNORECASE)
        if sbi_by_match:
            merchant = sbi_by_match.group(1).strip()
            return merchant.strip() if merchant else None

        # UPI pattern (generic, but avoid matching "TRANSFER" from SBI)
        upi_match = re.search(r'UPI[/-]([^/-]+)', narration, re.IGNORECASE)
        if upi_match:
            merchant = upi_match.group(1).strip()
            # Skip if it's just "TRANSFER" (SBI format)
            if merchant.upper() != 'TRANSFER':
                return merchant

        # NEFT/IMPS pattern
        neft_match = re.search(r'(?:NEFT|IMPS)[/-]([^/-]+)', narration, re.IGNORECASE)
        if neft_match:
            return neft_match.group(1).strip()

        # POS pattern
        pos_match = re.search(r'POS\s+(.+?)(?:\s+\d{4}|$)', narration, re.IGNORECASE)
        if pos_match:
            return pos_match.group(1).strip()

        # Default: take first meaningful part (but skip "TO TRANSFER" or "BY TRANSFER")
        parts = narration.split('/')
        if len(parts) > 1:
            first_part = parts[0].strip().upper()
            if first_part not in ('TO TRANSFER-UPI', 'BY TRANSFER-UPI', 'TO TRANSFER', 'BY TRANSFER'):
                # For SBI format, try to get the name part (4th segment)
                if len(parts) >= 4 and ('TRANSFER-UPI' in first_part):
                    merchant = parts[3].strip() if len(parts) > 3 else None
                    if merchant:
                        return merchant
            return parts[1].strip()

        return None


# ============================================================================
# CONVENIENCE FUNCTIONS
# ============================================================================

def parse_bank_statement(file_content: BinaryIO, bank_code: Optional[str] = None,
                        file_format: str = "csv") -> List[Dict[str, Any]]:
    """
    Convenience function to parse bank statement

    Args:
        file_content: File content (binary)
        bank_code: Bank identifier (optional, will auto-detect if not provided)
        file_format: File format (csv, excel, xls, xlsx, pdf)

    Returns:
        List of parsed transactions in canonical format

    Example:
        with open('statement.csv', 'rb') as f:
            transactions = parse_bank_statement(f, bank_code='HDFC', file_format='csv')
    """
    parser = BankTransactionParser(bank_code)
    return parser.parse_file(file_content, file_format)


def get_supported_banks() -> List[Dict[str, str]]:
    """Get list of all supported banks"""
    from .bank_parser_config import BANK_CONFIGS

    return [
        {
            "bank_code": config.bank_code,
            "bank_name": config.bank_name,
            "formats": [fmt.value for fmt in config.file_formats]
        }
        for config in BANK_CONFIGS.values()
    ]

