from __future__ import annotations

import base64
import logging
import re
from dataclasses import dataclass, field
from datetime import datetime, date
from email import message_from_bytes
from email.message import Message
from pathlib import Path
from typing import Any, Dict, Literal, Optional
from zoneinfo import ZoneInfo

from .common import SpendSenseParseError, detect_channel, infer_bank_code
from .excel_parser import parse_excel_file
from .pdf_parser import parse_pdf_file

SUPPORTED_EXTS = {".csv", ".xls", ".xlsx", ".pdf"}
IST = ZoneInfo("Asia/Kolkata")
logger = logging.getLogger(__name__)

Direction = Literal["debit", "credit"]


@dataclass
class AlertParseResult:
    txn_date: date
    description_raw: str
    amount: float
    direction: Direction
    currency: str = "INR"
    merchant_raw: str | None = None
    account_ref: str | None = None
    raw_txn_id: str | None = None
    bank_code: str | None = None
    channel: str | None = None
    confidence: float = 0.0
    meta: Dict[str, Any] = field(default_factory=dict)


def _clean_text(body: str) -> tuple[str, str]:
    lines = body.replace("\r", "").split("\n")
    text = " ".join(line.strip() for line in lines if line.strip())
    return text, text.upper()


def _parse_decimal(value: str | None) -> float | None:
    if not value:
        return None
    try:
        return float(value.replace(",", ""))
    except ValueError:
        return None


def _parse_date(value: str | None) -> date:
    patterns = [
        "%d-%m-%y",
        "%d-%m-%Y",
        "%d/%m/%y",
        "%d/%m/%Y",
        "%d %b %Y",
        "%d %b, %Y",
        "%b %d, %Y",
    ]
    if value:
        normalized = value.strip().title()
        for pattern in patterns:
            try:
                return datetime.strptime(normalized, pattern).date()
            except ValueError:
                continue
    return datetime.now(IST).date()


def extract_merchant_from_description(description: str, existing: str | None) -> str | None:
    if existing:
        return existing

    patterns = [
        r"UPI/[0-9A-Z]+/[A-Z0-9\-]+-(?P<merchant>[A-Z0-9 &./']+)",
        r"POS\s+\d+\s+(?P<merchant>[A-Z0-9 &./']+)\s+(?:IN|IND|INDIA)",
        r"NEFT\s+(?:CR|DR)\s+(?:FROM|TO)\s+(?P<merchant>[A-Z0-9 &./']+)",
    ]
    upper = description.upper()
    for pattern in patterns:
        match = re.search(pattern, upper)
        if match:
            name = match.group("merchant").strip(" -/")
            if name:
                return re.sub(r"\s+", " ", name.title())
    return existing


class BaseAlertParser:
    def parse(self, text: str, upper: str) -> AlertParseResult | None:  # pragma: no cover - interface
        raise NotImplementedError


class GenericUPIParser(BaseAlertParser):
    amount_pattern = re.compile(r"(?:RS\.?|INR|₹)\s*([\d,]+\.?\d*)")
    account_pattern = re.compile(r"ACCOUNT\s+(\*?\d+)")
    vpa_pattern = re.compile(r"VPA\s+([A-Z0-9.@_-]+)")
    reference_pattern = re.compile(r"(?:REFERENCE|REF(?:ERENCE)?(?:\s+NO(?:MBER)?)?)\s+([A-Z0-9]+)")
    date_pattern = re.compile(
        r"(?:ON|DATE|DT)\s+([\d]{1,2}[-/][\d]{1,2}[-/][\d]{2,4}|[A-Z]{3}\s+\d{1,2},\s+\d{4})"
    )
    vpa_name_pattern = re.compile(
        r"TO\s+VPA\s+[A-Z0-9.@_-]+\s+([A-Z0-9 &'./]+?)\s+ON\s+\d{2}[-/]\d{2}[-/]\d{2,4}"
    )

    def parse(self, text: str, upper: str) -> AlertParseResult | None:
        if not any(k in upper for k in ("UPI", "IMPS", "NEFT", "MONEY RECEIVED", "DEBITED", "CREDITED")):
            return None
        amount_match = self.amount_pattern.search(upper)
        amount = _parse_decimal(amount_match.group(1)) if amount_match else None
        if not amount:
            return None

        direction: Direction = "credit"
        if any(word in upper for word in ("DEBIT", "DEDUCT", "WITHDRAW")):
            direction = "debit"

        account = None
        account_match = self.account_pattern.search(upper)
        if account_match:
            account = account_match.group(1)

        merchant: Optional[str] = None
        vpa_name_match = self.vpa_name_pattern.search(upper)
        if vpa_name_match:
            merchant = vpa_name_match.group(1).strip().title()

        reference = None
        reference_match = self.reference_pattern.search(upper)
        if reference_match:
            reference = reference_match.group(1)

        date_value = None
        date_match = self.date_pattern.search(upper)
        if date_match:
            date_value = date_match.group(1)
        txn_date = _parse_date(date_value)

        bank_code = infer_bank_code("", text)
        channel = detect_channel(text, direction)
        if not channel:
            if "UPI" in upper:
                channel = "upi"
            elif "IMPS" in upper:
                channel = "imps"
            elif "NEFT" in upper:
                channel = "neft"

        confidence = 0.5
        if reference:
            confidence += 0.2
        if merchant:
            confidence += 0.1
        confidence = min(confidence, 0.95)

        vpa = None
        vpa_match = self.vpa_pattern.search(upper)
        if vpa_match:
            vpa = vpa_match.group(1)
            if not merchant:
                merchant = vpa.split("@")[0].replace("-", " ").title()

        merchant = extract_merchant_from_description(text, merchant)

        return AlertParseResult(
            txn_date=txn_date,
            description_raw=text,
            amount=amount,
            direction=direction,
            merchant_raw=merchant,
            account_ref=account,
            raw_txn_id=reference,
            bank_code=bank_code,
            channel=channel,
            confidence=confidence,
            meta={"vpa": vpa},
        )


class CreditCardAlertParser(BaseAlertParser):
    amount_pattern = GenericUPIParser.amount_pattern
    card_pattern = re.compile(r"(?:CREDIT\s+CARD.*?(?:ENDING|XX|XXXX)\s*([0-9]{3,4}))")
    date_pattern = GenericUPIParser.date_pattern

    def parse(self, text: str, upper: str) -> AlertParseResult | None:
        if "CREDIT CARD" not in upper:
            return None

        amount_match = self.amount_pattern.search(upper)
        amount = _parse_decimal(amount_match.group(1)) if amount_match else None
        if not amount:
            return None

        card_match = self.card_pattern.search(upper)
        account_ref = card_match.group(1) if card_match else None

        merchant = None
        m1 = re.search(r"\bAT\s+([A-Z0-9 &./'-]+)", upper)
        if m1:
            merchant = m1.group(1).strip(" .-")

        date_value = None
        date_match = self.date_pattern.search(upper)
        if date_match:
            date_value = date_match.group(1)
        txn_date = _parse_date(date_value)

        bank_code = infer_bank_code("", text)
        channel = "card"
        direction: Direction = "debit"

        confidence = 0.7
        if account_ref:
            confidence += 0.1
        if merchant:
            confidence += 0.1
        confidence = min(confidence, 0.99)

        merchant = extract_merchant_from_description(text, merchant)

        return AlertParseResult(
            txn_date=txn_date,
            description_raw=text,
            amount=amount,
            direction=direction,
            merchant_raw=merchant,
            account_ref=account_ref,
            raw_txn_id=None,
            bank_code=bank_code,
            channel=channel,
            confidence=confidence,
        )


class MutualFundAlertParser(BaseAlertParser):
    amount_pattern = GenericUPIParser.amount_pattern
    date_pattern = GenericUPIParser.date_pattern

    def parse(self, text: str, upper: str) -> AlertParseResult | None:
        if not any(k in upper for k in ("MUTUAL FUND", "SIP", "REDEMPTION", "REDEEMED")):
            return None

        amount_match = self.amount_pattern.search(upper)
        amount = _parse_decimal(amount_match.group(1)) if amount_match else None
        if not amount:
            return None

        if "REDEMPTION" in upper or "REDEEMED" in upper:
            direction: Direction = "credit"
        else:
            direction = "debit"

        scheme = None
        m1 = re.search(r"(?:IN|OF)\s+([A-Z0-9 &./'-]+FUND)", upper)
        if m1:
            scheme = m1.group(1).strip(" .-")

        date_value = None
        date_match = self.date_pattern.search(upper)
        if date_match:
            date_value = date_match.group(1)
        txn_date = _parse_date(date_value)

        bank_code = infer_bank_code("", text)
        channel = "mutual_fund"

        confidence = 0.7
        if scheme:
            confidence += 0.1
        confidence = min(confidence, 0.95)

        merchant = extract_merchant_from_description(text, scheme)

        return AlertParseResult(
            txn_date=txn_date,
            description_raw=text,
            amount=amount,
            direction=direction,
            merchant_raw=merchant,
            account_ref=None,
            raw_txn_id=None,
            bank_code=bank_code,
            channel=channel,
            confidence=confidence,
        )


ALERT_PARSERS: list[BaseAlertParser] = [
    CreditCardAlertParser(),
    MutualFundAlertParser(),
    GenericUPIParser(),
]


def _extract_attachments(raw_email: bytes) -> list[tuple[str, bytes]]:
    msg: Message = message_from_bytes(raw_email)
    attachments: list[tuple[str, bytes]] = []

    if msg.is_multipart():
        for part in msg.walk():
            disposition = part.get("Content-Disposition", "") or ""
            if "attachment" not in disposition.lower():
                continue
            filename = part.get_filename()
            payload = part.get_payload(decode=True)
            if not filename or payload is None:
                # Some providers embed attachments base64-encoded in the body
                encoded = part.get_payload()
                if isinstance(encoded, str):
                    payload = base64.b64decode(encoded)
            if filename and payload:
                attachments.append((filename, payload))
    else:
        filename = msg.get_filename()
        payload = msg.get_payload(decode=True)
        if filename and payload:
            attachments.append((filename, payload))

    return attachments


def parse_email_payload(
    data: bytes,
    filename: str,
    pdf_password: str | None = None,
    alerts_only: bool = False,
) -> list[dict[str, Any]]:
    """
    Parse .eml/.msg payloads.

    When alerts_only=True we skip attachments and only parse alert bodies
    (for Gmail real-time / backfill). When False, attachments are processed first.
    """
    records: list[dict[str, Any]] = []
    errors: list[str] = []

    if not alerts_only:
        attachments = _extract_attachments(data)
        for attachment_name, payload in attachments:
            ext = Path(attachment_name).suffix.lower()
            if ext not in SUPPORTED_EXTS:
                continue
            try:
                if ext in {".csv", ".xls", ".xlsx"}:
                    records.extend(parse_excel_file(payload, attachment_name))
                elif ext == ".pdf":
                    records.extend(parse_pdf_file(payload, attachment_name, pdf_password))
            except SpendSenseParseError as exc:
                errors.append(f"{attachment_name}: {exc}")

        if records:
            return _dedupe_records(records)

    body_text = _extract_body_text(data)
    if body_text:
        parsed_alert = _parse_alert_body(body_text)
        if parsed_alert:
            return _dedupe_records([parsed_alert])

    if errors and not alerts_only:
        raise SpendSenseParseError("; ".join(errors))

    raise SpendSenseParseError(
        "No recognizable alert content found in the email body."
        if alerts_only
        else "No supported attachments or recognizable alert content found in the email."
    )


def _extract_body_text(raw_email: bytes) -> str:
    msg: Message = message_from_bytes(raw_email)
    if msg.is_multipart():
        for part in msg.walk():
            content_type = part.get_content_type()
            if content_type == "text/plain":
                payload = part.get_payload(decode=True)
                if payload:
                    return payload.decode(part.get_content_charset() or "utf-8", errors="ignore")
    else:
        payload = msg.get_payload(decode=True)
        if payload:
            return payload.decode(msg.get_content_charset() or "utf-8", errors="ignore")
    return ""


def _parse_alert_body(body: str) -> dict[str, Any] | None:
    text, upper = _clean_text(body)
    best_result: AlertParseResult | None = None

    for parser in ALERT_PARSERS:
        try:
            result = parser.parse(text, upper)
        except Exception:  # pragma: no cover - defensive guard
            logger.exception("Alert parser %s failed", parser.__class__.__name__)
            continue

        if not result:
            continue

        result.merchant_raw = extract_merchant_from_description(
            text, result.merchant_raw
        )

        if best_result is None or result.confidence > best_result.confidence:
            best_result = result

    if not best_result or best_result.confidence < 0.5:
        logger.debug(
            "Email alert parser confidence too low (%.2f) for body: %s",
            best_result.confidence if best_result else -1,
            text[:280],
        )
        return None

    return {
        "txn_date": best_result.txn_date,
        "description_raw": best_result.description_raw,
        "amount": best_result.amount,
        "direction": best_result.direction,
        "currency": best_result.currency,
        "merchant_raw": best_result.merchant_raw,
        "account_ref": best_result.account_ref,
        "raw_txn_id": best_result.raw_txn_id,
        "bank_code": best_result.bank_code,
        "channel": best_result.channel,
    }


def _dedupe_records(records: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Remove duplicate transactions within a single email payload."""
    unique: dict[str, dict[str, Any]] = {}
    for rec in records:
        signature = _record_signature(rec)
        if signature not in unique:
            unique[signature] = rec
    return list(unique.values())


def _record_signature(rec: dict[str, Any]) -> str:
    """Create a stable signature for a transaction dict."""
    txn_date = rec.get("txn_date")
    if isinstance(txn_date, datetime):
        date_str = txn_date.date().isoformat()
    else:
        date_str = str(txn_date) if txn_date else ""

    amount = rec.get("amount")
    try:
        amount_str = f"{float(amount):.2f}"
    except (TypeError, ValueError):
        amount_str = ""

    parts = [
        date_str,
        amount_str,
        (rec.get("direction") or "").lower(),
        (rec.get("merchant_raw") or "").strip().lower(),
        (rec.get("raw_txn_id") or "").strip().lower(),
        (rec.get("bank_code") or "").strip().lower(),
        (rec.get("description_raw") or "").strip().lower(),
    ]
    return "|".join(parts)

