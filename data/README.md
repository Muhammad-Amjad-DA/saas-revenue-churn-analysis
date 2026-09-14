# data/

Immutable source extracts. These files are the single source of truth for every number published in the SQL layer, the Excel workbook and the Power BI report, and they are never edited in place.

| File | Grain | Rows | Contents |
|---|---|---|---|
| `subscriptions.csv` | One row per customer | 600 | customer_id, plan, billing_cycle, industry, company_size, seats, monthly_revenue, acquisition_channel, region, signup_date, churned, churn_date, churn_reason, support_tickets_12mo, nps_score, feature_usage_pct, upgraded |
| `monthly_revenue.csv` | One row per calendar month | 48 | month, total_active_customers, new_customers, churned_customers, monthly_churn_rate_pct, total_mrr, avg_revenue_per_customer, customer_acquisition_cost |

Customer acquisition cost is recorded only in `monthly_revenue.csv` as a blended monthly figure. It is not available at customer level in `subscriptions.csv`.

Field-level definitions are documented in [../docs/data_dictionary.md](../docs/data_dictionary.md). Cleaning, typing and derived fields are handled downstream in Power Query, SQL and DAX so the workflow reruns end to end from these files.
