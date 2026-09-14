# Data Dictionary

Field-level documentation for the two source extracts used in this project. Every field name below matches the header in the source CSV exactly, and data types are stated as they are loaded.

---

## Table: `subscriptions`

**Grain:** one row per customer. **Rows:** 600. **Primary key:** `customer_id`.

| Field | Table | Data type | Definition | Business interpretation |
|---|---|---|---|---|
| `customer_id` | subscriptions | Text | Unique customer identifier | Primary key. Uniqueness is validated before analysis |
| `plan` | subscriptions | Text | Subscription tier: Starter, Professional, Business, Enterprise | Main product-value dimension; drives the plan churn comparison |
| `billing_cycle` | subscriptions | Text | Billing cadence: Monthly, Annual | Proxy for commitment length; monthly customers churn more |
| `industry` | subscriptions | Text | Customer industry (for example Technology, Finance, Retail, Healthcare, Media) | Context dimension for segment review |
| `company_size` | subscriptions | Text | Employee band: 1-10, 11-50, 51-200, 201-500, 500+ | Segments where churn concentrates by customer size |
| `seats` | subscriptions | Integer | Licensed seats on the subscription | Account size indicator alongside MRR |
| `monthly_revenue` | subscriptions | Decimal | Customer monthly recurring revenue. For churned customers this is the last known MRR before churn | Basis for Active MRR and Lost MRR |
| `acquisition_channel` | subscriptions | Text | Channel that acquired the customer (for example Organic Search, Paid Ads, Referral, Partner, Direct Sales) | Links retention quality to go-to-market source |
| `region` | subscriptions | Text | Customer region (for example North America, Europe, Asia Pacific, Latin America) | Slicer dimension for executive reporting |
| `signup_date` | subscriptions | Date | Date the subscription started | Used for tenure and cohort logic |
| `churned` | subscriptions | Text (Yes/No) | Churn flag: Yes = churned, No = active | Drives every churn rate in the project |
| `churn_date` | subscriptions | Date (nullable) | Date the subscription ended | Expected blank for active customers. Blank is valid, not missing |
| `churn_reason` | subscriptions | Text (nullable) | Self-reported reason for cancellation | Expected blank for active customers; self-reported, so subject to reporting bias |
| `support_tickets_12mo` | subscriptions | Integer | Support tickets raised by the customer in the last 12 months | Service-friction indicator, not a satisfaction score |
| `nps_score` | subscriptions | Integer (0-10) | Most recent Net Promoter Score response | Satisfaction signal; one of the two inputs to the at-risk rule |
| `feature_usage_pct` | subscriptions | Decimal (0-100) | Percentage of core product features actively used | Adoption signal; low adoption indicates unrealized product value |
| `upgraded` | subscriptions | Text (Yes/No) | Whether the customer has upgraded plan since signup | Expansion indicator |

---

## Table: `monthly_revenue`

**Grain:** one row per calendar month. **Rows:** 48. **Primary key:** `month`.

| Field | Table | Data type | Definition | Business interpretation |
|---|---|---|---|---|
| `month` | monthly_revenue | Date | Reporting month (YYYY-MM) | Join key to the `Date` table in the Power BI model |
| `total_active_customers` | monthly_revenue | Integer | Customers billable during the month | Denominator context for monthly churn |
| `new_customers` | monthly_revenue | Integer | Customers acquired during the month | Shows whether growth is masking retention weakness |
| `churned_customers` | monthly_revenue | Integer | Customers who canceled during the month | Numerator of the monthly churn rate |
| `monthly_churn_rate_pct` | monthly_revenue | Decimal | Churn rate recorded for the month | Trend line behind the monthly churn chart |
| `total_mrr` | monthly_revenue | Decimal | Total recurring revenue billed in the month | Source of the MRR trend and of Latest MRR |
| `avg_revenue_per_customer` | monthly_revenue | Decimal | Average revenue per active customer in the month | Context for whether MRR movement is volume or price driven |
| `customer_acquisition_cost` | monthly_revenue | Decimal | Blended customer acquisition cost recorded for the month | Monthly aggregate, not a per-customer attribute; pairs with CLV to assess payback |

---

## Table: `Date` (Power BI model table)

**Grain:** one row per calendar date. Generated in the model, marked as the official date table, and related one-to-many to `monthly_revenue[month]` with single-direction filtering.

| Field | Table | Data type | Definition | Business interpretation |
|---|---|---|---|---|
| `Date` | Date | Date | Calendar date | Time-intelligence anchor |
| `Year` | Date | Integer | Calendar year | Report axis and slicer |
| `Month Name` | Date | Text | Month label | Report axis |
| `Month Number` | Date | Integer | Month sort order | Hidden helper field used only for sorting |
| `Year-Month` | Date | Text | Period label (YYYY-MM) | Trend axis label |

---

## Derived fields (created in SQL and DAX, not stored in the source files)

| Field | Created in | Definition |
|---|---|---|
| `tenure_months` | SQL | Whole months between `signup_date` and `churn_date`; used for average observed lifespan and CLV |
| `risk_segment` | SQL | At Risk / Watch / Healthy / Churned classification built from the at-risk rule |
| At-Risk Customers | DAX | Active customers with `feature_usage_pct < 40` and `nps_score <= 4` |
| Lost MRR | DAX / SQL | Sum of `monthly_revenue` for churned customers |
| Estimated CLV | DAX / SQL | Average MRR x average observed lifespan in months |

---

## Conventions

1. Source CSV files are never edited; all typing and derivation happens in Power Query, SQL or DAX so the workflow reruns end to end.
2. Percentages are stored as numeric values and formatted in the presentation layer.
3. Helper fields such as `Month Number` are hidden from report users in the Power BI model.
4. Metric formulas and assumptions live in `docs/methodology.md`; this file documents fields only.
