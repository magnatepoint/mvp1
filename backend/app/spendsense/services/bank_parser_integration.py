"""
Integration layer between new bank-agnostic parser and existing SpendSense system
"""
import io
from typing import List, Dict, Any, BinaryIO
from datetime import datetime
import logging

from .bank_parser import BankTransactionParser, parse_bank_statement
from .bank_parser_config import get_bank_config, BANK_CONFIGS

logger = logging.getLogger(__name__)


def parse_bank_file_to_spendsense_format(
    file_content: bytes,
    filename: str,
    bank_code: str | None = None
) -> List[Dict[str, Any]]:
    """
    Parse bank statement file and convert to SpendSense staging format
    
    This bridges the new bank-agnostic parser with the existing SpendSense pipeline
    
    Args:
        file_content: Raw file bytes
        filename: Original filename
        bank_code: Optional bank code (will auto-detect if not provided)
    
    Returns:
        List of records in SpendSense staging format
    
    Example output format:
        {
            "txn_date": date(2024, 1, 15),
            "description_raw": "UPI/AMAZON/REF123",
            "amount": 500.00,
            "direction": "debit",
            "currency": "INR",
            "merchant_raw": "AMAZON",
            "account_ref": "*1234",
            "raw_txn_id": "REF123",
            "bank_code": "HDFC",
            "channel": "upi"
        }
    """
    # Determine file format from extension
    file_format = _get_file_format(filename)
    
    # Parse using bank-agnostic parser
    file_obj = io.BytesIO(file_content)
    canonical_transactions = parse_bank_statement(file_obj, bank_code, file_format)
    
    # Convert to SpendSense format
    spendsense_records = []
    for txn in canonical_transactions:
        record = _convert_to_spendsense_format(txn)
        spendsense_records.append(record)
    
    logger.info(f"Parsed {len(spendsense_records)} transactions from {filename} (bank: {bank_code or 'auto-detected'})")
    
    return spendsense_records


def _get_file_format(filename: str) -> str:
    """Extract file format from filename"""
    ext = filename.lower().split('.')[-1]
    
    format_map = {
        'csv': 'csv',
        'xls': 'xls',
        'xlsx': 'xlsx',
        'pdf': 'pdf'
    }
    
    return format_map.get(ext, 'csv')


def _convert_to_spendsense_format(canonical_txn: Dict[str, Any]) -> Dict[str, Any]:
    """
    Convert canonical transaction format to SpendSense staging format
    
    Canonical format (from bank parser):
        {
            'posted_at': datetime,
            'amount': Decimal (positive for credit, negative for debit),
            'description': str,
            'merchant': str,
            'reference_number': str,
            'balance': Decimal,
            'bank_code': str,
            'currency': str
        }
    
    SpendSense format:
        {
            'txn_date': date,
            'description_raw': str,
            'amount': float (absolute value),
            'direction': 'debit' | 'credit',
            'currency': str,
            'merchant_raw': str,
            'account_ref': str,
            'raw_txn_id': str,
            'bank_code': str,
            'channel': str
        }
    """
    amount = canonical_txn.get('amount', 0)
    
    # Determine direction from amount sign
    if amount < 0:
        direction = 'debit'
        abs_amount = abs(float(amount))
    else:
        direction = 'credit'
        abs_amount = float(amount)
    
    # Extract date (convert datetime to date if needed)
    posted_at = canonical_txn.get('posted_at')
    if isinstance(posted_at, datetime):
        txn_date = posted_at.date()
    else:
        txn_date = posted_at
    
    # Detect channel from description
    description = canonical_txn.get('description', '')
    channel = _detect_channel(description, direction)
    
    return {
        'txn_date': txn_date,
        'description_raw': description,
        'amount': abs_amount,
        'direction': direction,
        'currency': canonical_txn.get('currency', 'INR'),
        'merchant_raw': canonical_txn.get('merchant'),
        'account_ref': canonical_txn.get('account_hint'),
        'raw_txn_id': canonical_txn.get('reference_number'),
        'bank_code': canonical_txn.get('bank_code'),
        'channel': channel,
    }


def _detect_channel(description: str, direction: str) -> str:
    """
    Detect transaction channel from description
    
    Channels: upi, neft, imps, atm, pos, cheque, online, other
    """
    if not description:
        return 'other'
    
    desc_upper = description.upper()
    
    # UPI
    if 'UPI' in desc_upper or 'UNIFIED PAYMENT' in desc_upper:
        return 'upi'
    
    # NEFT
    if 'NEFT' in desc_upper:
        return 'neft'
    
    # IMPS
    if 'IMPS' in desc_upper:
        return 'imps'
    
    # ATM
    if 'ATM' in desc_upper or 'CASH WITHDRAWAL' in desc_upper:
        return 'atm'
    
    # POS (Point of Sale)
    if 'POS' in desc_upper or 'CARD PURCHASE' in desc_upper:
        return 'pos'
    
    # Cheque
    if 'CHQ' in desc_upper or 'CHEQUE' in desc_upper or 'CHECK' in desc_upper:
        return 'cheque'
    
    # Online banking
    if 'ONLINE' in desc_upper or 'INTERNET' in desc_upper:
        return 'online'
    
    # Default
    return 'other'


def get_supported_banks_info() -> List[Dict[str, Any]]:
    """
    Get information about all supported banks
    
    Returns:
        List of bank information dictionaries
    """
    return [
        {
            'bank_code': config.bank_code,
            'bank_name': config.bank_name,
            'supported_formats': [fmt.value for fmt in config.file_formats],
            'currency': config.currency,
        }
        for config in BANK_CONFIGS.values()
    ]

