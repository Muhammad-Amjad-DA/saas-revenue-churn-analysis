# Data reconciliation log

Two inconsistencies were found in a final audit of this project. Both were traced to a cause and are documented here. This is a synthetic dataset.

## 1. Stray "30" in `churn_reason` (Excel only)

| | |
|---|---|
| Symptom | In `excel/saas_revenue_churn_analysis.xlsx`, the 287 active customers had the text value `30` in `churn_reason`. `data/subscriptions.csv`, the data dictionary and the methodology all leave it blank (blank is correct for active customers). |
| How it was found | Compared the Subscriptions sheet with the CSV column by column. Only `churn_reason` differed, and only in those 287 rows (all `churned = "No"`). |
| Effect on results | None. No published metric uses `churn_reason` for active customers. Churn rate, Lost MRR, at-risk flag and the control totals do not read the column. The only exposure was a "churn reasons" summary that counts reasons, where `30` would have appeared as a fake category. |
| Cause | The value is stored as a text cell in the workbook. The files do not show how it was written, so the exact origin is not recorded. I am not guessing at it. |
| Fix | The 287 cells were cleared. After the fix, the Excel `churn_reason` column matches the CSV in all 600 rows (0 differences) and 287 cells are blank. |
| Guard | `python/revenue_at_risk.py` now asserts that no active customer has a `churn_reason`. |

## 2. "281 active" vs "287 active"

Both numbers are correct. They answer different questions.

| Number | Where | Definition |
|---|---|---|
| **287** | `subscriptions.csv`, README, Excel `Analysis` | Customers with `churned = "No"`: still active at the end of the data (31 Dec 2025). |
| **281** | `monthly_revenue.csv`, December 2025 row | Customers active on the **first day** of December: signed up on or before 1 Dec and not churned on or before 1 Dec. |

The bridge: 281 opening + 11 December sign-ups - 4 December churns - 1 = **287**. The 1 is customer CUST-0440, who signed up on 1 December. The monthly table counts that customer in the opening count (signed up on or before the first day) and the sign-up count also includes them, so they are counted once in the bridge.

Verification: recalculating "active on the first day of the month" from `subscriptions.csv` reproduces `total_active_customers` **and** `total_mrr` in all 48 months of `monthly_revenue.csv` with 0 mismatches. So the monthly table is an opening-of-month snapshot, not an end-of-month one.

The same definition explains the MRR figures:

| Figure | Value | Definition |
|---|---|---|
| Latest MRR in the monthly table | $292,628.61 | Opening MRR for December 2025 |
| Active MRR at the end of the data | $295,420.03 | Sum of `monthly_revenue` for the 287 active customers |

The README's "9.6% of active MRR" uses $295,420. Earlier wording called $292.6K "latest MRR". It is now labelled as December opening MRR.
