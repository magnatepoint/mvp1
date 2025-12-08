"""
Category inference helpers for transaction categorization.

Provides heuristics to infer categories when merchant rules don't match,
with special handling for Indian personal names (P2P transfers).
"""

import re
import logging
from typing import Optional

logger = logging.getLogger(__name__)


def _looks_like_personal_name(text: str) -> bool:
    """
    Heuristic: Indian personal name vs business.
    
    Word-based classification that detects:
    - Indian tribal/personal names (Mudavath, Nallapu, Kurva, Sudarsha, Chintala, etc.)
    - Ignores abbreviations like "int", "imps", transaction IDs
    - Strips UPI/IMPS prefixes and transaction numbers
    
    Args:
        text: Text to check (should be lowercase)
        
    Returns:
        True if text looks like a personal name
    """
    if not text:
        return False
    
    t = text.lower().strip()
    
    # Strip common UPI/IMPS prefixes and transaction IDs
    # Remove patterns like: "upi/", "upi-", "imps/", "by transfer-imps/xxxxx/", etc.
    t = re.sub(r'(upi|imps|neft|rtgs)[-/]?', '', t, flags=re.IGNORECASE)
    t = re.sub(r'by\s+transfer[-/]?', '', t, flags=re.IGNORECASE)
    t = re.sub(r'/\d{6,}/', '', t)  # Remove transaction IDs like /529516578056/
    t = re.sub(r'\d{6,}', '', t)  # Remove long number sequences
    t = re.sub(r'/[a-z0-9-]+/', '', t)  # Remove path-like segments
    t = t.strip()
    
    # Split into tokens (words)
    tokens = [w for w in re.split(r'[\s/]+', t) if w]
    
    # Filter out common non-name tokens
    ignore_tokens = {
        'int', 'to', 'by', 'transfer', 'upi', 'imps', 'neft', 'rtgs',
        'gpay', 'phonepe', 'paytm', 'google', 'pay', 'wallet',
        'dr', 'cr', 'debit', 'credit', 'out', 'in',
        'hsb', 'cams', 'xx', 'xxx', 'xxxx', 'xxxxx',
    }
    tokens = [w for w in tokens if w not in ignore_tokens and len(w) > 1]
    
    if len(tokens) == 0:
        return False
    
    # Single token must be at least 3 characters and not an abbreviation
    if len(tokens) == 1:
        token = tokens[0]
        # Ignore single-letter or very short abbreviations
        if len(token) < 3:
            return False
        # Ignore if it's all uppercase (likely abbreviation)
        if token.isupper() and len(token) <= 4:
            return False
        # Ignore common abbreviations
        if token in ['int', 'amt', 'ref', 'id', 'no', 'num']:
            return False
    
    # Too many tokens (likely a business or description)
    if len(tokens) > 4:
        return False
    
    # Check if any token contains digits (transaction IDs, account numbers)
    # BUT allow single digits at the end (like "2 hp pet" - though this is likely a merchant)
    # Actually, if it has digits, it's probably not a personal name
    if any(any(ch.isdigit() for ch in token) for token in tokens):
        # Exception: single digit at start might be part of name (rare, but allow it)
        # But "2 hp pet" is clearly not a name - it's a merchant
        return False
    
    # Check if any token looks like a domain or email
    if any('.' in token or '@' in token for token in tokens):
        return False
    
    # Business keywords that indicate it's NOT a personal name
    business_keywords = [
        "enterprises", "enterprise", "industries", "industry", "services",
        "solutions", "traders", "trading", "store", "mart", "bazaar",
        "supermarket", "electronics", "digital", "tech", "technologies",
        "private", "pvt", "limited", "ltd", "hotel", "resort", "lounge",
        "finance", "bank", "fresh", "chicken", "meat", "srtc", "rtc", "transport",
        "service", "corporation", "corp", "company", "co", "inc",
        "amazon", "flipkart", "swiggy", "zomato",  # Known merchants
        "pan", "shop", "parlour", "parlor", "vendor", "thela",  # Pan shop and vendor keywords
    ]
    
    # Check if any token matches business keywords
    if any(any(kw in token for kw in business_keywords) for token in tokens):
        return False
    
    # Word-based classification: Check if tokens look like Indian names
    # Indian names typically:
    # - Start with capital letters (but we're working with lowercase)
    # - Have 2-4 syllables
    # - Don't contain numbers or special business terms
    # - Common patterns: Mudavath, Nallapu, Kurva, Sudarsha, Chintala, Vijetha
    
    # If we have 1-4 meaningful tokens with no business indicators, it's likely a name
    # Additional check: if it's a single word and looks like a name pattern
    if len(tokens) == 1:
        token = tokens[0]
        # Single word names are usually 4+ characters
        if len(token) >= 4 and not any(ch.isdigit() for ch in token):
            # Check if it matches common Indian name patterns (ends with common suffixes)
            name_suffixes = ['ath', 'apu', 'ala', 'sha', 'tha', 'ma', 'ra', 'na', 'ka', 'ya']
            if any(token.endswith(suffix) for suffix in name_suffixes):
                return True
            # Or if it's a reasonable length and no business keywords
            if 4 <= len(token) <= 15:
                return True
    
    # Multiple tokens: if all are reasonable length and no business indicators
    if all(3 <= len(token) <= 15 for token in tokens):
        return True
    
    # If it reached here, it *probably* is a personal name
    return True


def _infer_category_from_keywords(text: str, direction: str) -> str:
    """
    Infer category from keywords when no merchant rule matches.
    
    Args:
        text: Transaction description/merchant text (lowercase)
        direction: Transaction direction ('debit' or 'credit')
        
    Returns:
        Category code (e.g., 'transfers_out', 'transfers_in', 'shopping', 'banks')
    """
    if not text:
        return "transfers_out" if direction == "debit" else "transfers_in"  # better default than shopping
    
    text_lower = text.lower()
    
    # ---------- strong keyword buckets ----------
    
    # CRITICAL: Check for personal names FIRST (before ANY other detection)
    # This prevents names like "Mudavath", "Rehana", "Sudarsha", "Chintala" from being mis-categorized
    # Extract merchant name part (before description) for better detection
    merchant_part = text_lower.split()[0] if text_lower and text_lower.split() else ""
    is_personal_name = _looks_like_personal_name(merchant_part) or _looks_like_personal_name(text_lower)
    
    # If it's a personal name, it's ALWAYS a transfer (highest priority)
    if is_personal_name:
        return "transfers_out" if direction == "debit" else "transfers_in"
    
    # bank interest / fees - check for strong signals
    # Only categorize as banks if there are explicit interest/fee keywords
    # Note: We already checked personal names above, so we don't need to check again
    has_strong_interest_signal = any(k in text_lower for k in [
        "interest credit", "int. credit", "int credit", "fd interest", 
        "rd interest", "savings interest", "deposit interest", "interest on"
    ])
    
    if has_strong_interest_signal:
        return "banks"  # Use 'banks' category code
    
    # Check for charges/fees (but be careful - "int" alone is not a fee)
    has_fee_keywords = any(k in text_lower for k in ["charges", "fee", "fees", "penalty", "service charge"])
    # Don't match "int" alone - it's too ambiguous
    if has_fee_keywords and "int" not in text_lower.split():
        return "banks"  # Use 'banks' category code
    
    # food & dining
    if any(k in text_lower for k in ["swiggy", "zomato", "uber eats", "food", "restaurant", "cafe", "dining"]):
        return "food_dining"
    
    # groceries (including meat/poultry)
    if any(k in text_lower for k in ["bigbasket", "grofers", "dunzo", "grocery", "supermarket", "mart", "fresh chicken", "chicken", "meat", "poultry"]):
        return "groceries"
    
    # utilities
    if any(k in text_lower for k in ["electricity", "water", "gas", "phone", "internet", "broadband", "mobile"]):
        return "utilities"
    
    # travel / transport
    if any(k in text_lower for k in ["uber", "ola", "rapido", "train", "flight", "hotel", "booking", "srtc", "rtc", "apsrtc", "bus"]):
        return "transport"
    
    # fuel
    if any(k in text_lower for k in ["petrol", "diesel", "fuel", "gas station", "bunk"]):
        return "transport"
    
    # pets / veterinary
    if any(k in text_lower for k in ["pet", "veterinary", "vet", "animal clinic", "pets"]):
        return "pets"
    
    # ---------- UPI / transfers special handling ----------
    # This is the key logic: UPI + personal name = P2P transfer
    # Unknown UPI names → transfers_out (debit) / transfers_in (credit)
    
    if any(k in text_lower for k in ["upi", "imps", "neft", "rtgs", "gpay", "google pay", "phonepe", "paytm"]):
        # if it *looks like a person*, treat as P2P transfer
        if _looks_like_personal_name(text_lower):
            return "transfers_out" if direction == "debit" else "transfers_in"
        # unknown but not name → treat as generic merchant (but this should be rare)
        # Most real merchants should be in dim_merchant
        return "shopping"
    
    # ---------- looks like a personal name even without UPI keyword ----------
    # This catches names like "Vasanthi Kancha", "Kurva Padma", "Tadi Bhavani De"
    if _looks_like_personal_name(text_lower):
        return "transfers_out" if direction == "debit" else "transfers_in"
    
    # ---------- very last resort ----------
    # Only if nothing else matched and it doesn't look like a personal name
    return "shopping"  # only if nothing else matched

