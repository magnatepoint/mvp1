# Monytix – Augment Project Structure

This document describes the recommended repository layout for implementing the Monytix MVP with Augment assistance.

```
monytix/
├── backend/
│   ├── app/
│   │   ├── main.py
│   │   ├── api/
│   │   │   ├── v1/
│   │   │   │   ├── transactions.py
│   │   │   │   ├── goals.py
│   │   │   │   ├── budget.py
│   │   │   │   ├── goalcompass.py
│   │   │   │   ├── moneymoments.py
│   │   │   │   ├── realtime_ingestion.py
│   │   │   │   └── sse.py
│   │   ├── models/
│   │   ├── schemas/
│   │   ├── services/
│   │   ├── workers/
│   │   │   ├── celery_app.py
│   │   │   └── tasks/
│   │   ├── db/
│   │   │   ├── postgres.py
│   │   │   └── mongo.py
│   │   └── core/
│   ├── tests/
│   │   ├── unit/
│   │   └── integration/
│   └── pyproject.toml
│
├── frontend/
│   ├── src/
│   │   ├── components/
│   │   ├── pages/
│   │   │   ├── Dashboard/
│   │   │   ├── SpendSense/
│   │   │   ├── Goals/
│   │   │   ├── BudgetPilot/
│   │   │   ├── GoalCompass/
│   │   │   └── MoneyMoments/
│   │   ├── hooks/
│   │   ├── api/
│   │   └── store/
│   ├── public/
│   ├── package.json
│   └── vite.config.ts (or CRA config)
│
├── infra/
│   ├── docker/
│   ├── k8s/ (future)
│   ├── scripts/
│   └── env/
│
├── docs/
│   ├── frs/
│   │   ├── 01_introduction_architecture.md
│   │   ├── 02_spendsense.md
│   │   ├── 03_goals.md
│   │   ├── 04_budgetpilot.md
│   │   ├── 05_goalcompass.md
│   │   ├── 06_moneymoments.md
│   │   ├── 07_realtime_ingestion.md
│   │   ├── 08_data_dictionary.md
│   │   ├── 09_api_reference.md
│   │   └── 10_acceptance_criteria.md
│   ├── augment_rules.md
│   └── augment_config.json
│
├── .env.example
├── README.md
└── Makefile
```

Use this as a baseline structure. Augment tasks should reference these paths explicitly when generating or updating code.
