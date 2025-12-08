# SpendSense Module

This directory contains all SpendSense-related code, organized for easy maintenance.

## Directory Structure

```
spendsense/
├── docs/              # Documentation for bank parsers, transaction parsing, etc.
├── etl/               # ETL pipeline and parsers
│   └── parsers/       # Bank statement parsers (Excel, PDF, Email)
├── ml/                # Machine learning models for categorization
├── scripts/           # Utility scripts for debugging, re-parsing, etc.
├── services/          # Core services (transaction parsing, bank parser)
├── tests/             # Unit and integration tests
├── training/          # ML model training code
├── sample_bank/       # Sample bank statement files for testing
├── models.py          # Pydantic models
├── routes.py          # FastAPI routes
└── service.py         # Main service class
```

## Key Files

### Services
- **`services/txn_parsed_populator.py`**: Parses transaction descriptions to extract structured metadata (UPI RRN, counterparty info, MCC, etc.)
- **`services/bank_parser.py`**: Unified bank statement parser (works with any bank via configuration)
- **`services/bank_parser_config.py`**: Bank-specific configurations
- **`services/bank_parser_integration.py`**: Integration layer between parser and SpendSense

### ETL
- **`etl/tasks.py`**: Celery tasks for file ingestion and processing
- **`etl/pipeline.py`**: Transaction enrichment pipeline
- **`etl/parsers/`**: Bank-specific parsers (Excel, PDF, Email)

### Scripts
- **`scripts/backfill_txn_parsed.py`**: Backfill txn_parsed table
- **`scripts/backfill_parse_and_enrich.py`**: Backfill parsing and enrichment for existing transactions
- **`scripts/fix_sbi_merchants.py`**: Fix merchant names for SBI transactions
- **`scripts/re_enrich_user.py`**: Re-enrich transactions for a specific user
- **`scripts/train_category_model.py`**: Train ML model for category prediction

## Import Paths

All imports should use the new paths:

```python
# Services
from app.spendsense.services.txn_parsed_populator import parse_transaction_metadata
from app.spendsense.services.bank_parser import parse_bank_statement

# ETL
from app.spendsense.etl.tasks import ingest_statement_file_task
from app.spendsense.etl.parsers import parse_transactions_file
```

## Running Scripts

Scripts are located in `app/spendsense/scripts/`. They automatically add the backend directory to the Python path, so you can run them from anywhere:

```bash
cd backend
python3 -m app.spendsense.scripts.backfill_parse_and_enrich
```

