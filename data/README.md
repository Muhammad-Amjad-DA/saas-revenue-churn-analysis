# data/

Immutable source extracts. These files are the single source of truth for every number published in the SQL layer, the Excel workbook and the Power BI report, and they are never edited in place.

| File | Grain | Rows | Contents |
|---|---|---|---|
| `subscriptions.csv` | One row per customer | 600 | Plan, billing cycle, company size, region, acquisition channel, MRR, CAC, NPS, feature usage, support tickets, churn flag, churn date, churn reason |
| `monthly_revenue.csv` | One row per calendar month | 48 | Total MRR, active customers, new customers, churned customers |

Field-level definitions are documented in [../docs/data_dictionary.md](../docs/data_dictionary.md). Cleaning, typing and derived fields are handled downstream in Power Query, SQL and DAX so the workflow reruns end to end from these files.
