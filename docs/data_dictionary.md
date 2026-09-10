# Data Dictionary

Field-level documentation for the two source extracts used in this project. Data types are stated as they are modeled in SQL and Power BI after load, not as raw CSV text.

---

## Table: `subscriptions`

**Grain:** one row per customer. **Rows:** 600. **Primary key:** `customer_id`.

| Field | Table | Data type | Definition | Business interpretation |
|---|---|---|---|---|
| `customer_id` | subscriptions | Text | Unique customer identifier | Primary key. Uniqueness is validated before analysis; duplicates would double-count churn and MRR |
| `signup_date` | subscriptions | Date | Date the subscription started | Used for tenure and cohort logic |
| `plan` | subscriptions | Text | Subscription tier (Starter, Growth, Enterprise) | Main product-value dimension; plan mix drives both churn and MRR concentration |
| `billing_cycle` | subscriptions | Text | Billing cadence (Monthly, Annual) | Proxy for commitment length; monthly customers can leave at every renewal point |
| `company_size` | subscriptions | Text | Customer size band (for example SMB, Mid-Market, Enterprise) | Segments where churn behavior and service expectations differ |
| `region` | subscriptions | Text | Customer region | Slicer dimension for executive reporting |
| `acquisition_channel` | subscriptions | Text | Channel that acquired the customer (for example Organic, Paid Search, Referral, Partner, Outbound) | Links retention quality back to go-to-market spend, not just volume |
| `monthly_revenue` | subscriptions | Decimal | Customer monthly recurring revenue. For churned customers this is the last known MRR before churn | Basis for MRR and Lost MRR; makes revenue impact comparable across segments |
| `cac` | subscriptions | Decimal | Customer acquisition cost attributed to the customer | Blended channel/plan level figure, used only for CLV:CAC context |
| `nps_score` | subscriptions | Integer (0-10) | Most recent Net Promoter Score response | Satisfaction signal; one of the two inputs to the at-risk rule |
| `feature_usage_pct` | subscriptions | Decimal (0-100) | Percentage of core product features actively used | Adoption signal; low adoption indicates unrealized product value |
| `support_tickets` | subscriptions | Integer | Count of support tickets raised by the customer | Service-friction indicator used in behavioral comparison |
| `is_churned` | subscriptions | Integer (0/1) | Churn flag: 1 = churned, 0 = active | Drives every churn rate in the project |
| `churn_date` | subscriptions | Date (nullable) | Date the subscription ended | **Expected blank for active customers.** Blank is valid, not missing |
| `churn_reason` | subscriptions | Text (nullable) | Self-reported reason for cancellation | **Expected blank for active customers.** Self-reported, so subject to reporting bias |

---

## Table: `monthly_revenue`

**Grain:** one row per calendar month. **Rows:** 48. **Primary key:** `month`.

| Field | Table | Data type | Definition | Business interpretation |
|---|---|---|---|---|
| `month` | monthly_revenue | Date | First day of the reporting month | Join key to the `Date` table in the Power BI model |
| `total_mrr` | monthly_revenue | Decimal | Total recurring revenue billed in the month | Source of the MRR trend and of Latest MRR |
| `active_customers` | monthly_revenue | Integer | Customers billable during the month | Denominator context for monthly churn |
| `new_customers` | monthly_revenue | Integer | Customers acquired during the month | Shows whether growth is masking retention weakness |
| `churned_customers` | monthly_revenue | Integer | Customers who canceled during the month | Numerator of the monthly churn rate |

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
2Ba. Percentages are stored as numeric values and formatted in the presentation layer.
3. Helper fields such as `Month Number` are hidden from report users in the Power BI model.
4. Metric formulas and assumptions live in `docs/methodology.md`; this file documents fields only.
# Data Dictionary

Field-level documentation for the two source extracts used in this project. Data types are stated as they are modelled in SQL and Power BI after load, not as raw CSV text.

---

## Table: `subscriptions`

**Grain:** one row per customer. **Rows:** 600. **Primary key:** `customer_id`.

| Field | Table | Data type | Definition | Business interpretation |
|---|---|---|---|---|
| `customer_id` | subscriptions | Text | Unique customer identifier | Primary key. Uniqueness is validated before analysis; duplicates would double-count churn and MRR |
| `signup_date` | subscriptions | Date | Date the subscription started | Used for tenure and cohort logic |
| `plan` | subscriptions | Text | Subscription tier (Starter, Growth, Enterprise) | Main product-value dimension; plan mix drives both churn and MRR concentration |
| `billing_cycle` | subscriptions | Text | Billing cadence (Monthly, Annual) | Proxy for commitment length; monthly customers can leave at every renewal point |
| `company_size` | subscriptions | Text | Customer size band (for example SMB, Mid-Market, Enterprise) | Segments where churn behaviour and service expectations differ |
| `region` | subscriptions | Text | Customer region | Slicer dimension for executive reporting |
| `acquisition_channel` | subscriptions | Text | Channel that acquired the customer (for example Organic, Paid Search, Referral, Partner, Outbound) | Links retention quality back to go-to-market spend, not just volume |
| `monthly_revenue` | subscriptions | Decimal | Customer monthly recurring revenue. For churned customers this is the last known MRR before churn | Basis for MRR and Lost MRR; makes revenue impact comparable across segments |
| `cac` | subscriptions | Decimal | Customer acquisition cost attributed to the customer | Blended channel/plan level figure, used only for CLV:CAC context |
| `nps_score` | subscriptions | Integer (0-10) | Most recent Net Promoter Score response | Satisfaction signal; one of the two inputs to the at-risk rule |
| `feature_usage_pct` | subscriptions | Decimal (0-100) | Percentage of core product features actively used | Adoption signal; low adoption indicates unrealised product value |
| `support_tickets` | subscriptions | Integer | Count of support tickets raised by the customer | Service-friction indicator used in behavioural comparison |
| `is_churned` | subscriptions | Integer (0/1) | Churn flag: 1 = churned, 0 = active | Drives every churn rate in the project |
| `churn_date` | subscriptions | Date (nullable) | Date the subscription ended | **Expected blank for active customers.** Blank is valid, not missing |
| `churn_reason` | subscriptions | Text (nullable) | Self-reported reason for cancellation | **Expected blank for active customers.** Self-reported, so subject to reporting bias |

---

## Table: `monthly_revenue`

**Grain:** one row per calendar month. **Rows:** 48. **Primary key:** `month`.

| Field | Table | Data type | Definition | Business interpretation |
|---|---|---|---|---|
| `month` | monthly_revenue | Date | First day of the reporting month | Join key to the `Date` table in the Power BI model |
| `total_mrr` | monthly_revenue | Decimal | Total recurring revenue billed in the month | Source of the MRR trend and of Latest MRR |
| `active_customers` | monthly_revenue | Integer | Customers billable during the month | Denominator context for monthly churn |
| `new_customers` | monthly_revenue | Integer | Customers acquired during the month | Shows whether growth is masking retention weakness |
| `churned_customers` | monthly_revenue | Integer | Customers who cancelled during the month | Numerator of the monthly churn rate |

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
# Data Dictionary

Field-level documentation for the two source extracts used in this project. Data types are stated as they are modelled in SQL and Power BI after load, not as raw CSV text.

---

## Table: `subscriptions`

**Grain:** one row per customer. **Rows:** 600. **Primary key:** `customer_id`.

| Field | Table | Data type | Definition | Business interpretation |
|---|---|---|---|---|
| `customer_id` | subscriptions | Text | Unique customer identifier | Primary key. Uniqueness is validated before analysis; duplicates would double-count churn and MRR |
| `signup_date` | subscriptions | Date | Date the subscription started | Used for tenure and cohort logic |
| `plan` | subscriptions | Text | Subscription tier (Starter, Growth, Enterprise) | Main product-value dimension; plan mix drives both churn and MRR concentration |
| `billing_cycle` | subscriptions | Text | Billing cadence (Monthly, Annual) | Proxy for commitment length; monthly customers can leave at every renewal point |
| `company_size` | subscriptions | Text | Customer size band (for example SMB, Mid-Market, Enterprise) | Segments where churn behaviour and service expectations differ |
| `region` | subscriptions | Text | Customer region | Slicer dimension for executive reporting |
| `acquisition_channel` | subscriptions | Text | Channel that acquired the customer (for example Organic, Paid Search, Referral, Partner, Outbound) | Links retention quality back to go-to-market spend, not just volume |
| `monthly_revenue` | subscriptions | Decimal | Customer monthly recurring revenue. For churned customers this is the last known MRR before churn | Basis for MRR and Lost MRR; makes revenue impact comparable across segments |
| `cac` | subscriptions | Decimal | Customer acquisition cost attributed to the customer | Blended channel/plan level figure, used only for CLV:CAC context |
| `nps_score` | subscriptions | Integer (0-10) | Most recent Net Promoter Score response | Satisfaction signal; one of the two inputs to the at-risk rule |
| `feature_usage_pct` | subscriptions | Decimal (0-100) | Percentage of core product features actively used | Adoption signal; low adoption indicates unrealised product value |
| `support_tickets` | subscriptions | Integer | Count of support tickets raised by the customer | Service-friction indicator used in behavioural comparison |
| `is_churned` | subscriptions | Integer (0/1) | Churn flag: 1 = churned, 0 = active | Drives every churn rate in the project |
| `churn_date` | subscriptions | Date (nullable) | Date the subscription ended | **Expected blank for active customers.** Blank is valid, not missing |
| `churn_reason` | subscriptions | Text (nullable) | Self-reported reason for cancellation | **Expected blank for active customers.** Self-reported, so subject to reporting bias |

---

## Table: `monthly_revenue`

**Grain:** one row per calendar month. **Rows:** 48. **Primary key:** `month`.

| Field | Table | Data type | Definition | Business interpretation |
|---|---|---|---|---|
| `month` | monthly_revenue | Date | First day of the reporting month | Join key to the `Date` table in the Power BI model |
| `total_mrr` | monthly_revenue | Decimal | Total recurring revenue billed in the month | Source of the MRR trend and of Latest MRR |
| `active_customers` | monthly_revenue | Integer | Customers billable during the month | Denominator context for monthly churn |
| `new_customers` | monthly_revenue | Integer | Customers acquired during the month | Shows whether growth is masking retention weakness |
| `churned_customers` | monthly_revenue | Integer | Customers who cancelled during the month | Numerator of the monthly churn rate |

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
2Ba. Percentages are stored as numeric values and formatted in the presentation layer.
3. Helper fields such as `Month Number` are hidden from report users in the Power BI model.
4. Metric formulas and assumptions live in `docs/methodology.md`; this file documents fields only.
