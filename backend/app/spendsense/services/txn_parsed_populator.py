"""
Populate txn_parsed table from txn_fact using intelligent parsing
Extracts: UPI RRN, NEFT UTR, counterparty info, channel type, etc.
"""
import re
from typing import Dict, Any, Optional
from decimal import Decimal
import logging

logger = logging.getLogger(__name__)


class TransactionParser:
    """
    Parse transaction descriptions to extract structured metadata
    
    Extracts:
    - Channel type (UPI, IMPS, NEFT, ATM, POS, etc.)
    - Direction (IN, OUT, REV, INTERNAL)
    - Counterparty name, VPA, account, bank
    - Rail-specific IDs (UPI RRN, IMPS RRN, NEFT UTR)
    - MCC (Merchant Category Code)
    """
    
    # Channel detection patterns
    CHANNEL_PATTERNS = {
        'UPI': [
            r'TO TRANSFER-UPI',  # SBI: TO TRANSFER-UPI/DR/...
            r'BY TRANSFER-UPI',  # SBI: BY TRANSFER-UPI/CR/...
            r'UPI[/-]',
            r'UPIOUT[/-]',
            r'UPI IN[/-]',
            r'REV-UPI',
            r'MB-IMPS-DR.*UPI',  # Canara MB-IMPS-DR has UPI-like ref
            r'^IN/\d+',  # Federal Bank: IN/<rrn>/...
            r'^OUT/\d+',  # Federal Bank: OUT/<rrn>/...
        ],
        'IMPS': [
            r'MMT/IMPS',
            r'BY TRANSFER-IMPS',
            r'IMPS[-/]',
            r'Recd:IMPS',
            r'INET-IMPS',
        ],
        'NEFT': [
            r'NEFT[/-]',
            r'BY TRANSFER-NEFT',
            r'RTGS[/-]',
        ],
        'ATM': [
            r'ATM\s',
            r'NWD[-/]',
            r'CASH\s+WITHDRAWAL',
            r'ATM-WDL',
        ],
        'POS': [
            r'POS\s',
            r'CARD\s+PURCHASE',
            r'SWIPE',
        ],
        'ACH': [
            r'ACH[/-]',
            r'ACH\s+D[-/]',
        ],
        'NACH': [
            r'NACH[-/]',
            r'NACH\s',
        ],
        'CARD_BILLPAY': [
            r'BILLPAY',
            r'CREDIT\s+CARD\s+BILL',
        ],
    }
    
    def parse_transaction(self, txn: Dict[str, Any]) -> Dict[str, Any]:
        """
        Parse a transaction from txn_fact and extract metadata
        
        Args:
            txn: Dict with keys: txn_id, bank_code, txn_date, amount, direction, description
        
        Returns:
            Dict with parsed fields for txn_parsed table
        """
        description = txn.get('description', '') or ''
        bank_code_raw = txn.get('bank_code') or ''
        # Normalize bank_code: handle both "FEDERAL" and "federal_bank" formats
        bank_code = (bank_code_raw or '').upper()
        if 'FEDERAL' in bank_code:
            bank_code = 'FEDERAL'  # Normalize to FEDERAL for consistency
        direction_raw = txn.get('direction', 'debit')
        
        # Detect channel
        channel_type = self._detect_channel(description)
        
        # Determine direction (IN/OUT/REV/INTERNAL)
        direction = self._determine_direction(description, direction_raw, channel_type)
        
        # Extract counterparty info
        counterparty = self._extract_counterparty(description, bank_code, channel_type)
        
        # Extract rail-specific IDs
        rail_ids = self._extract_rail_ids(description, bank_code, channel_type)
        
        # Extract MCC if available
        mcc = self._extract_mcc(description, bank_code)
        
        return {
            'fact_txn_id': txn['txn_id'],
            'bank_code': bank_code or 'UNKNOWN',
            'txn_date': txn['txn_date'],
            'amount': txn['amount'],
            'cr_dr': 'C' if direction_raw == 'credit' else 'D',
            'channel_type': channel_type,
            'direction': direction,
            'raw_description': description,
            'counterparty_name': counterparty.get('name'),
            'counterparty_bank_code': counterparty.get('bank_code'),
            'counterparty_vpa': counterparty.get('vpa'),
            'counterparty_account': counterparty.get('account'),
            'mcc': mcc,
            'upi_rrn': rail_ids.get('upi_rrn'),
            'imps_rrn': rail_ids.get('imps_rrn'),
            'neft_utr': rail_ids.get('neft_utr'),
            'ach_nach_entity': rail_ids.get('ach_nach_entity'),
            'ach_nach_ref': rail_ids.get('ach_nach_ref'),
            'internal_ref': rail_ids.get('internal_ref'),
        }
    
    def _detect_channel(self, description: str) -> str:
        """Detect transaction channel from description"""
        if not description:
            return 'OTHER'
        desc_upper = description.upper()
        
        for channel, patterns in self.CHANNEL_PATTERNS.items():
            for pattern in patterns:
                if re.search(pattern, desc_upper, re.IGNORECASE):
                    return channel
        
        return 'OTHER'
    
    def _determine_direction(self, description: str, direction_raw: str, channel: str) -> str:
        """Determine transaction direction (IN/OUT/REV/INTERNAL)"""
        if not description:
            return direction_raw or 'debit'
        desc_upper = description.upper()
        
        # Federal Bank format: IN/<rrn>/... or OUT/<rrn>/...
        if desc_upper.startswith('IN/'):
            return 'IN'
        if desc_upper.startswith('OUT/'):
            return 'OUT'
        
        # Reversal
        if 'REV-' in desc_upper or 'REVERSAL' in desc_upper or 'REFUND' in desc_upper:
            return 'REV'
        
        # Internal transfer
        if 'INTERNAL' in desc_upper or 'SELF' in desc_upper or 'OWN ACCOUNT' in desc_upper:
            return 'INTERNAL'
        
        # IN/OUT based on credit/debit
        return 'IN' if direction_raw == 'credit' else 'OUT'
    
    def _extract_counterparty(self, description: str, bank_code: str, channel: str) -> Dict[str, Optional[str]]:
        """Extract counterparty information"""
        result = {'name': None, 'bank_code': None, 'vpa': None, 'account': None}
        
        if channel == 'UPI':
            result.update(self._extract_upi_counterparty(description, bank_code))
        elif channel == 'IMPS':
            result.update(self._extract_imps_counterparty(description, bank_code))
        elif channel in ('ATM', 'POS'):
            result.update(self._extract_card_counterparty(description))
        
        return result
    
    def _extract_upi_counterparty(self, desc: str, bank: str) -> Dict[str, Optional[str]]:
        """Extract UPI counterparty (name, VPA)"""
        desc_upper = desc.upper()
        # Check if Federal Bank - handle both 'FEDERAL' and 'federal_bank' formats
        bank_upper = (bank or '').upper()
        is_federal = 'FEDERAL' in bank_upper
        is_sbi = 'SBI' in bank_upper
        
        # SBI Bank format: TO TRANSFER-UPI/DR/<rrn>/<name>/<bank>/<vpa>/<platform>
        # Example: TO TRANSFER-UPI/DR/730765131673/CHINTALA/SBIN/chvkchanti/Payme--
        if is_sbi and "TO TRANSFER-UPI" in desc_upper:
            # Format: TO TRANSFER-UPI/DR/<rrn>/<name>/<bank>/<vpa>/<platform>
            match = re.search(r'TO TRANSFER-UPI/DR/[^/]+/([^/]+)/([^/]+)/([^/]+)', desc, re.IGNORECASE)
            if match:
                name_part = match.group(1).strip()
                bank_code = match.group(2).strip()
                vpa = match.group(3).strip()
                return {"name": name_part, "vpa": vpa, "bank_code": bank_code}
        
        # SBI Bank format: BY TRANSFER-UPI/CR/<rrn>/<name>/<bank>/<vpa>/<platform>
        if is_sbi and "BY TRANSFER-UPI" in desc_upper:
            # Format: BY TRANSFER-UPI/CR/<rrn>/<name>/<bank>/<vpa>/<platform>
            match = re.search(r'BY TRANSFER-UPI/CR/[^/]+/([^/]+)/([^/]+)/([^/]+)', desc, re.IGNORECASE)
            if match:
                name_part = match.group(1).strip()
                bank_code = match.group(2).strip()
                vpa = match.group(3).strip()
                return {"name": name_part, "vpa": vpa, "bank_code": bank_code}

        # Federal-style UPIOUT: UPIOUT/<rrn>/<vpa>/UPI/<mcc> (most common format)
        if "UPIOUT/" in desc_upper:
            if is_federal:
                # Format 1: UPIOUT/<rrn>/<vpa>/UPI/<mcc> (with /UPI/ separator) - PRIMARY FORMAT
                match = re.search(r'UPIOUT/[^/]+/([^/]+)/UPI/([^/]+)', desc, re.IGNORECASE)
                if match:
                    raw_vpa = match.group(1).strip()
                    # Handle spaces in VPA (e.g., "vyapar.170240977286@ hdfc" -> "vyapar.170240977286@hdfc")
                    raw_vpa = re.sub(r'\s+', '', raw_vpa)  # Remove all spaces
                    name_part = None
                    vpa = None
                    if "@" in raw_vpa:
                        # Extract name from VPA (part before @)
                        name_part = raw_vpa.split("@")[0]
                        vpa = raw_vpa
                    elif not raw_vpa.isdigit() and len(raw_vpa) > 3:
                        # If it's not just digits, might be a name without @
                        name_part = raw_vpa
                        vpa = None
                    return {"name": name_part, "vpa": vpa}
                
                # Format 2: UPIOUT/<rrn>/<name> UPI (with space before UPI) - FALLBACK
                # Handle formats like: UPIOUT/506007775297/ vyap UPI or UPIOUT/542768726676/q003 UPI
                match = re.search(r'UPIOUT/[^/]+/([^/\s]+)\s+UPI', desc, re.IGNORECASE)
                if match:
                    name_part = match.group(1).strip()
                    # Remove leading/trailing spaces and clean up
                    name_part = name_part.strip()
                    # Extract VPA if it's in the name (e.g., "merchant@paytm")
                    vpa = None
                    if "@" in name_part:
                        vpa = re.sub(r'\s+', '', name_part)  # Remove all spaces
                        name_part = vpa.split("@")[0]
                    elif len(name_part) > 0:
                        # If it's just a name (no @), use it as counterparty name
                        # Examples: "vyap", "q003", "q375", "payt", "puli"
                        name_part = name_part
                    return {"name": name_part if name_part else None, "vpa": vpa}
                
                # Format 3: UPIOUT/<rrn>/<name>/<mcc> (without UPI, mcc is last 4-digit part)
                # Split by / and analyze parts
                parts = [p.strip() for p in desc.split('/') if p.strip()]
                if len(parts) >= 3 and parts[0].upper() == 'UPIOUT':
                    # parts[0] = UPIOUT, parts[1] = RRN, parts[2] = name or VPA, parts[-1] might be MCC
                    name_or_vpa = parts[2] if len(parts) > 2 else None
                    if name_or_vpa:
                        # Remove any trailing "UPI" or other keywords
                        name_or_vpa = re.sub(r'\s+(UPI|OTHER)$', '', name_or_vpa, flags=re.IGNORECASE).strip()
                        vpa = None
                        name_part = None
                        if "@" in name_or_vpa:
                            vpa = name_or_vpa.replace(" ", "")
                            name_part = vpa.split("@")[0]
                        elif not name_or_vpa.isdigit() and len(name_or_vpa) > 3:
                            # Might be a merchant name
                            name_part = name_or_vpa
                        return {"name": name_part, "vpa": vpa}
            
            # Generic UPIOUT/<ref>/<vpa> (fallback for non-Federal or if Federal patterns didn't match)
            match = re.search(r'UPIOUT/[^/]+/([a-zA-Z0-9@._]+)', desc, re.IGNORECASE)
            if match:
                raw_vpa = match.group(1).strip()
                name_part = raw_vpa.split("@")[0] if "@" in raw_vpa else None
                return {"name": name_part, "vpa": raw_vpa if "@" in raw_vpa else None}

        # Federal Bank format: IN/<rrn>/<name> OTHER or OUT/<rrn>/<name> UPI
        if is_federal and (desc_upper.startswith('IN/') or desc_upper.startswith('OUT/')):
            # Format: IN/<rrn>/<name> OTHER or OUT/<rrn>/<name> UPI
            match = re.search(r'^(?:IN|OUT)/[^/]+/([^/\s]+)(?:\s+(?:UPI|OTHER))?', desc, re.IGNORECASE)
            if match:
                name_part = match.group(1).strip()
                # Extract VPA if it's in the name (e.g., "merchant@paytm")
                vpa = None
                if "@" in name_part:
                    vpa = name_part
                    name_part = name_part.split("@")[0]
                return {"name": name_part, "vpa": vpa}

        # Federal-style UPI IN: UPI IN/<rrn>/<name_or_vpa>
        if "UPI IN/" in desc_upper:
            match = re.search(r'UPI IN/[^/]+/([^/]+)', desc, re.IGNORECASE)
            if match:
                token = match.group(1).strip()
                vpa = token.replace(" ", "") if "@" in token else None
                name_part = token.split("@")[0] if "@" in token else token
                return {"name": name_part, "vpa": vpa}

        # Generic UPI: UPI/<name>/<vpa> or UPI-<name>-<vpa>
        match = re.search(r'UPI[/-]([^/-]+)[-/@]([a-zA-Z0-9@._]+)', desc, re.IGNORECASE)
        if match:
            return {'name': match.group(1).strip(), 'vpa': match.group(2).strip()}
        
        # UPIOUT/<ref>/<vpa>
        match = re.search(r'UPIOUT/[^/]+/([a-zA-Z0-9@._]+)', desc, re.IGNORECASE)
        if match:
            return {'vpa': match.group(1).strip()}

        # Fallback: scan slash/dash separated tokens for a plausible name and VPA
        tokens = [token.strip() for token in re.split(r'[/\-]', desc) if token.strip()]
        if any(tok.upper() == 'UPI' for tok in tokens):
            name: Optional[str] = None
            vpa: Optional[str] = None
            for token in tokens[1:]:
                if '@' in token and vpa is None:
                    # Take the first word containing a VPA-style handle
                    vpa = token.split()[0]
                    continue
                if name is None:
                    letters = sum(ch.isalpha() for ch in token)
                    if letters >= 3:
                        name = token
            if name or vpa:
                return {'name': name, 'vpa': vpa}

        return {}
    
    def _extract_imps_counterparty(self, desc: str, bank: str) -> Dict[str, Optional[str]]:
        """Extract IMPS counterparty (name, bank, account)"""
        # IMPS-<rrn>-<name>-<bank>-<account>
        match = re.search(r'IMPS-[^-]+-([^-]+)-([^-]+)-([^-]+)', desc, re.IGNORECASE)
        if match:
            return {
                'name': match.group(1).strip(),
                'bank_code': match.group(2).strip(),
                'account': match.group(3).strip()
            }
        
        # MMT/IMPS/<rrn>/<name>/<ifsc>
        # ICICI format example:
        #   MMT/IMPS/532001785076/SANDE EP MA/CNRB0006335
        match = re.search(r'MMT/IMPS/[^/]+/([^/]+)/([A-Z0-9]{4,11})', desc, re.IGNORECASE)
        if match:
            return {
                'name': match.group(1).strip(),
                'bank_code': match.group(2).strip()
            }
        
        return {}
    
    def _extract_card_counterparty(self, desc: str) -> Dict[str, Optional[str]]:
        """Extract card number (masked) from ATM/POS"""
        # POS <cardmask> or NWD-<cardmask>
        match = re.search(r'(?:POS|NWD)[-\s]+([\dX*]{4,16})', desc, re.IGNORECASE)
        if match:
            return {'account': match.group(1).strip()}
        
        return {}
    
    def _extract_rail_ids(self, desc: str, bank: str, channel: str) -> Dict[str, Optional[str]]:
        """Extract rail-specific reference IDs"""
        result = {}
        
        if channel == 'UPI':
            result['upi_rrn'] = self._extract_upi_rrn(desc, bank)
        elif channel == 'IMPS':
            result['imps_rrn'] = self._extract_imps_rrn(desc)
        elif channel == 'NEFT':
            result['neft_utr'] = self._extract_neft_utr(desc)
        elif channel in ('ACH', 'NACH'):
            ach_info = self._extract_ach_nach(desc)
            result['ach_nach_entity'] = ach_info.get('entity')
            result['ach_nach_ref'] = ach_info.get('ref')
        
        # Internal ref (ICI..., AXI..., SBI...)
        result['internal_ref'] = self._extract_internal_ref(desc)
        
        return result
    
    def _extract_upi_rrn(self, desc: str, bank: str) -> Optional[str]:
        """Extract UPI RRN"""
        bank_upper = (bank or '').upper()
        
        # SBI Bank: TO TRANSFER-UPI/DR/<rrn>/... or BY TRANSFER-UPI/CR/<rrn>/...
        if 'SBI' in bank_upper:
            # Format: TO TRANSFER-UPI/DR/<rrn>/... or BY TRANSFER-UPI/CR/<rrn>/...
            match = re.search(r'(?:TO|BY) TRANSFER-UPI/(?:DR|CR)/(\d{12,})', desc, re.IGNORECASE)
            if match:
                return match.group(1)
        
        # Federal Bank: UPIOUT/<rrn>/... or UPI IN/<rrn>/... or IN/<rrn>/... or OUT/<rrn>/...
        if 'FEDERAL' in bank_upper:
            # Format: UPIOUT/<rrn>/... (extract first 12+ digit number after UPIOUT/)
            # Handles both: UPIOUT/506007775297/ vyap UPI and UPIOUT/542819591188/ q375173335@ybl/UPI/5812
            match = re.search(r'UPIOUT/(\d{12,})', desc, re.IGNORECASE)
            if match:
                return match.group(1)
            
            # Format: UPI IN/<rrn>/...
            match = re.search(r'UPI IN/(\d{12,})/', desc, re.IGNORECASE)
            if match:
                return match.group(1)
            
            # Format: IN/<rrn>/... or OUT/<rrn>/...
            match = re.search(r'^(?:IN|OUT)/(\d{12,})/', desc, re.IGNORECASE)
            if match:
                return match.group(1)
        
        # UPI/<DR|CR>/<rrn>
        match = re.search(r'UPI/(?:DR|CR)/(\d{12,})', desc, re.IGNORECASE)
        if match:
            return match.group(1)
        
        # UPI-<rrn> at end
        match = re.search(r'UPI-(\d{12,})', desc, re.IGNORECASE)
        if match:
            return match.group(1)
        
        return None
    
    def _extract_imps_rrn(self, desc: str) -> Optional[str]:
        """Extract IMPS RRN"""
        # IMPS-<rrn>- or MMT/IMPS/<rrn>/
        match = re.search(r'IMPS[-/](\d{12,})', desc, re.IGNORECASE)
        if match:
            return match.group(1)
        
        return None
    
    def _extract_neft_utr(self, desc: str) -> Optional[str]:
        """Extract NEFT UTR"""
        # NEFT/<utr> or NEFT-<utr>
        match = re.search(r'NEFT[-/]([A-Z0-9]{16,})', desc, re.IGNORECASE)
        if match:
            return match.group(1)
        
        return None
    
    def _extract_ach_nach(self, desc: str) -> Dict[str, Optional[str]]:
        """Extract ACH/NACH entity and reference"""
        # ACH/<entity>/<ref> or NACH-<entity>-<ref>
        match = re.search(r'(?:ACH|NACH)[-/\s]([^/-]+)(?:[-/](.+))?', desc, re.IGNORECASE)
        if match:
            return {'entity': match.group(1).strip(), 'ref': match.group(2).strip() if match.group(2) else None}
        
        return {}
    
    def _extract_internal_ref(self, desc: str) -> Optional[str]:
        """Extract internal bank reference (ICI..., AXI..., SBI...)"""
        # Allow one or two leading slashes so we match .../IBLxxx as well as //ICIxxx
        match = re.search(r'/+(ICI|AXI|SBI|IBL|KBL)[A-Z0-9]+', desc, re.IGNORECASE)
        if match:
            value = match.group(0)
            # Strip leading slashes
            return value.lstrip('/')
        
        return None
    
    def _extract_mcc(self, desc: str, bank: str) -> Optional[str]:
        """Extract MCC (Merchant Category Code) if available"""
        # Federal Bank: UPIOUT/<rrn>/<name> UPI or UPIOUT/<rrn>/<vpa>/UPI/<mcc> or UPIOUT/<rrn>/<name>/<mcc>
        # Also: IN/<rrn>/<name> OTHER or OUT/<rrn>/<name> UPI (MCC might be in a different position)
        if not desc or not bank:
            return None
        if 'FEDERAL' in (bank or '').upper():
            # Pattern 1: /UPI/<4-digit-mcc> at end (with /UPI/ separator)
            match = re.search(r'/UPI/(\d{4})$', desc, re.IGNORECASE)
            if match:
                return match.group(1)
            
            # Pattern 2: [UPI]/<mcc> format (if it exists)
            match = re.search(r'\[UPI\]/(\d{4})$', desc)
            if match:
                return match.group(1)
            
            # Pattern 3: UPIOUT/<rrn>/<name>/<mcc> (without /UPI/, mcc is last 4-digit part)
            if desc and desc.upper().startswith('UPIOUT/'):
                parts = [p.strip() for p in desc.split('/') if p.strip()]
                if len(parts) >= 4:
                    # Check if last part is a 4-digit MCC
                    last_part = parts[-1]
                    # Remove any trailing whitespace or keywords
                    last_part = re.sub(r'\s+(UPI|OTHER)$', '', last_part, flags=re.IGNORECASE).strip()
                    if last_part.isdigit() and len(last_part) == 4:
                        return last_part
            
            # Pattern 4: IN/<rrn>/<name> OTHER or OUT/<rrn>/<name> UPI
            # For this format, MCC might not be present, but if there's a 4-digit number after the name, it could be MCC
            if desc and desc.upper().startswith(('IN/', 'OUT/')):
                parts = [p.strip() for p in desc.split('/') if p.strip()]
                if len(parts) >= 3:
                    # Check if there's a 4-digit number in the last part (after removing UPI/OTHER)
                    last_part = parts[-1]
                    last_part = re.sub(r'\s+(UPI|OTHER)$', '', last_part, flags=re.IGNORECASE).strip()
                    if last_part.isdigit() and len(last_part) == 4:
                        return last_part
        
        return None


# Singleton instance
_parser = TransactionParser()


def parse_transaction_metadata(txn: Dict[str, Any]) -> Dict[str, Any]:
    """
    Parse transaction metadata for txn_parsed table

    Args:
        txn: Transaction dict from txn_fact

    Returns:
        Parsed metadata dict
    """
    return _parser.parse_transaction(txn)


async def populate_txn_parsed_from_fact(conn, batch_id: str = None):
    """
    Populate txn_parsed table from txn_fact using Python parser

    Args:
        conn: Database connection
        batch_id: Optional upload_id to process specific batch

    Returns:
        Number of records populated
    """
    # Fetch transactions that need parsing (include existing ones to re-parse with updated logic)
    if batch_id:
        # Query transactions from this batch that haven't been parsed yet
        # Use upload_id directly since txn_fact stores it for new inserts
        query = """
        SELECT DISTINCT
            tf.txn_id,
            tf.bank_code,
            tf.txn_date,
            tf.amount,
            tf.direction,
            tf.description
        FROM spendsense.txn_fact tf
        WHERE tf.upload_id = $1
            AND NOT EXISTS (
                SELECT 1 FROM spendsense.txn_parsed tp
                WHERE tp.fact_txn_id = tf.txn_id
            )
        """
        rows = await conn.fetch(query, batch_id)
        
        # Log how many transactions need parsing
        total_in_fact = await conn.fetchval("""
            SELECT COUNT(*) FROM spendsense.txn_fact WHERE upload_id = $1
        """, batch_id)
        already_parsed = await conn.fetchval("""
            SELECT COUNT(DISTINCT tp.parsed_id)
            FROM spendsense.txn_fact tf
            JOIN spendsense.txn_parsed tp ON tp.fact_txn_id = tf.txn_id
            WHERE tf.upload_id = $1
        """, batch_id)
        logger.info(f"[PARSING] Batch {batch_id}: {len(rows)} need parsing, {already_parsed} already parsed, {total_in_fact} total in txn_fact for this batch")
    else:
        query = """
        SELECT
            tf.txn_id,
            tf.bank_code,
            tf.txn_date,
            tf.amount,
            tf.direction,
            tf.description
        FROM spendsense.txn_fact tf
        WHERE NOT EXISTS (
            SELECT 1 FROM spendsense.txn_parsed tp
            WHERE tp.fact_txn_id = tf.txn_id
        )
        LIMIT 1000
        """
        rows = await conn.fetch(query)

    if not rows:
        logger.info("No transactions to parse")
        return 0

    # Parse each transaction
    parsed_records = []
    federal_count = 0
    for row in rows:
        txn = dict(row)
        bank_code_raw = txn.get('bank_code') or ''
        # Safely handle None case
        bank_code_upper = (bank_code_raw or '').upper()
        if 'FEDERAL' in bank_code_upper:
            federal_count += 1
            logger.debug(f"Parsing Federal Bank txn: {txn.get('description', '')[:50]}... (bank_code: {bank_code_raw})")
        try:
            parsed = parse_transaction_metadata(txn)
            # Log if counterparty_name was extracted for Federal Bank
            if 'FEDERAL' in bank_code_upper and parsed.get('counterparty_name'):
                logger.info(f"✅ Extracted counterparty_name '{parsed.get('counterparty_name')}' from: {txn.get('description', '')[:50]}")
            elif 'FEDERAL' in bank_code_upper and not parsed.get('counterparty_name'):
                logger.warning(f"⚠️  No counterparty_name extracted from Federal Bank txn: {txn.get('description', '')[:50]}")
            parsed_records.append(parsed)
        except Exception as e:
            logger.error(f"Failed to parse txn {txn.get('txn_id')}: {e}")
            continue
    
    if federal_count > 0:
        logger.info(f"Found {federal_count} Federal Bank transactions to parse")

    if not parsed_records:
        return 0

    # Bulk insert into txn_parsed with UPDATE on conflict to refresh parsed data
    insert_query = """
    INSERT INTO spendsense.txn_parsed (
        fact_txn_id, bank_code, txn_date, amount, cr_dr,
        channel_type, direction, raw_description,
        counterparty_name, counterparty_bank_code, counterparty_vpa, counterparty_account,
        mcc, upi_rrn, imps_rrn, neft_utr,
        ach_nach_entity, ach_nach_ref, internal_ref
    ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19)
    ON CONFLICT (fact_txn_id) DO UPDATE SET
        bank_code = EXCLUDED.bank_code,
        txn_date = EXCLUDED.txn_date,
        amount = EXCLUDED.amount,
        cr_dr = EXCLUDED.cr_dr,
        channel_type = EXCLUDED.channel_type,
        direction = EXCLUDED.direction,
        raw_description = EXCLUDED.raw_description,
        counterparty_name = EXCLUDED.counterparty_name,
        counterparty_bank_code = EXCLUDED.counterparty_bank_code,
        counterparty_vpa = EXCLUDED.counterparty_vpa,
        counterparty_account = EXCLUDED.counterparty_account,
        mcc = EXCLUDED.mcc,
        upi_rrn = EXCLUDED.upi_rrn,
        imps_rrn = EXCLUDED.imps_rrn,
        neft_utr = EXCLUDED.neft_utr,
        ach_nach_entity = EXCLUDED.ach_nach_entity,
        ach_nach_ref = EXCLUDED.ach_nach_ref,
        internal_ref = EXCLUDED.internal_ref
    """

    # Bulk insert using a single INSERT with multiple VALUES
    # This avoids prepared statements which don't work with pgbouncer in transaction mode
    if not parsed_records:
        logger.info("No records to insert into txn_parsed")
        return 0
    
    # Build a single INSERT statement with all VALUES
    # This is more efficient and works with pgbouncer (no prepared statements)
    values_parts = []
    params = []
    
    for record in parsed_records:
        # Use sequential parameter numbers
        start_param = len(params) + 1
        values_parts.append(
            f"(${start_param}, ${start_param+1}, ${start_param+2}, ${start_param+3}, ${start_param+4}, "
            f"${start_param+5}, ${start_param+6}, ${start_param+7}, ${start_param+8}, ${start_param+9}, "
            f"${start_param+10}, ${start_param+11}, ${start_param+12}, ${start_param+13}, ${start_param+14}, "
            f"${start_param+15}, ${start_param+16}, ${start_param+17}, ${start_param+18})"
        )
        params.extend([
            record['fact_txn_id'],
            record['bank_code'],
            record['txn_date'],
            record['amount'],
            record['cr_dr'],
            record['channel_type'],
            record['direction'],
            record['raw_description'],
            record['counterparty_name'],
            record['counterparty_bank_code'],
            record['counterparty_vpa'],
            record['counterparty_account'],
            record['mcc'],
            record['upi_rrn'],
            record['imps_rrn'],
            record['neft_utr'],
            record['ach_nach_entity'],
            record['ach_nach_ref'],
            record['internal_ref'],
        ])
    
    bulk_insert_query = f"""
    INSERT INTO spendsense.txn_parsed (
        fact_txn_id, bank_code, txn_date, amount, cr_dr,
        channel_type, direction, raw_description,
        counterparty_name, counterparty_bank_code, counterparty_vpa, counterparty_account,
        mcc, upi_rrn, imps_rrn, neft_utr,
        ach_nach_entity, ach_nach_ref, internal_ref
    ) VALUES {', '.join(values_parts)}
    ON CONFLICT (fact_txn_id) DO UPDATE SET
        bank_code = EXCLUDED.bank_code,
        txn_date = EXCLUDED.txn_date,
        amount = EXCLUDED.amount,
        cr_dr = EXCLUDED.cr_dr,
        channel_type = EXCLUDED.channel_type,
        direction = EXCLUDED.direction,
        raw_description = EXCLUDED.raw_description,
        counterparty_name = EXCLUDED.counterparty_name,
        counterparty_bank_code = EXCLUDED.counterparty_bank_code,
        counterparty_vpa = EXCLUDED.counterparty_vpa,
        counterparty_account = EXCLUDED.counterparty_account,
        mcc = EXCLUDED.mcc,
        upi_rrn = EXCLUDED.upi_rrn,
        imps_rrn = EXCLUDED.imps_rrn,
        neft_utr = EXCLUDED.neft_utr,
        ach_nach_entity = EXCLUDED.ach_nach_entity,
        ach_nach_ref = EXCLUDED.ach_nach_ref,
        internal_ref = EXCLUDED.internal_ref
    """
    
    try:
        await conn.execute(bulk_insert_query, *params)
        count = len(parsed_records)
        logger.info(f"Populated {count} records in txn_parsed (bulk insert)")
    except Exception as e:
        logger.error(f"Failed to bulk insert parsed records: {e}", exc_info=True)
        # Fallback to individual inserts if bulk fails
        logger.warning("Falling back to individual inserts...")
        count = 0
        for record in parsed_records:
            try:
                await conn.execute(
                    insert_query,
                    record['fact_txn_id'],
                    record['bank_code'],
                    record['txn_date'],
                    record['amount'],
                    record['cr_dr'],
                    record['channel_type'],
                    record['direction'],
                    record['raw_description'],
                    record['counterparty_name'],
                    record['counterparty_bank_code'],
                    record['counterparty_vpa'],
                    record['counterparty_account'],
                    record['mcc'],
                    record['upi_rrn'],
                    record['imps_rrn'],
                    record['neft_utr'],
                    record['ach_nach_entity'],
                    record['ach_nach_ref'],
                    record['internal_ref'],
                )
                count += 1
            except Exception as e2:
                logger.error(f"Failed to insert parsed record for txn {record['fact_txn_id']}: {e2}")
                continue
        logger.info(f"Populated {count} records in txn_parsed (fallback mode)")

    return count

