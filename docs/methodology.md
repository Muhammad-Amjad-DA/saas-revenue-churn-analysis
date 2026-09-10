# Methodology and Metric Definitions

**Project:** SaaS Revenue, Churn & Customer Risk Analysis
**Scope:** 600 subscription customers, 48 months of monthly revenue history
**Purpose of this document:** define every published metric once, so the SQL layer, the Excel workbook and the Power BI report cannot disagree.

---

## 1. Data sources and grain

| Source | Grain | Rows | Role in the analysis |
|---|---|---|---|
| `data/subscriptions.csv` | One row per customer | 600 | Customer attributes, MRR, churn status and reason, NPS, feature usage, support activity, acquisition channel, company size, billing cycle, CAC |
| `data/monthly_revenue.csv` | One row per calendar month | 48 | Monthly recurring revenue and customer movement used for trend analysis |
| `Date` (Power BI calculated table) | One row per calendar date | Generated | Marked as the model date table; joined to `monthly_revenue[month]` for time intelligence |

Raw extracts are treated as immutable. All cleaning, typing and derivation happens downstream in Power Query, SQL or DAX so that the analysis is reproducible from the source files.

---

## 2. Metric definitions

| Metric | Definition | Published value |
|---|---|---|
| Total Customers | Distinct count of `customer_id` in `subscriptions` | 600 |
| Churned Customers | Customers where `is_churned = 1` | 313 |
| Active Customers | Customers where `is_churned = 0` | 287 |
| Churn Rate | Churned Customers / Total Customers. Lifetime (cumulative) rate across the observed window, not a monthly rate | 52.17% |
| Monthly Churn Rate | Customers churning in month M / customers billable at the start of month M | Trended over 48 months |
| Average Monthly Churn Rate | Mean of the 48 monthly churn rates | Reported on Page 1 |
| MRR | Sum of `monthly_revenue` for active customers | Snapshot measure |
| Latest MRR | `total_mrr` for the most recent month in `monthly_revenue` | approx. \$292.6K |
| MRR Growth | (Latest MRR - prior month MRR) / prior month MRR | Month-over-month |
| Lost MRR | Sum of `monthly_revenue` for churned customers. Represents recurring revenue no longer being billed, measured at the customer's last known MRR | Segment-level driver metric |
| Average CAC | Average of `cac` across customers in scope | Blended, see assumptions |
| Estimated CLV | Average MRR x average observed customer lifespan in months | Directional estimate |
| CLV:CAC | Estimated CLV / Average CAC | Efficiency indicator by plan |
| At-Risk Customers | Active customers with `feature_usage_pct < 40` AND `nps_score <= 4` | 31 |

---

## 3. At-risk rule

**Definition:** a customer is flagged At Risk when all three conditions hold: the customer is currently active, feature usage is below 40%, and NPS is 4 or lower.

**Why these thresholds:** in the observed data, churned customers show materially lower adoption and lower satisfaction than retained customers. The 40% usage and NPS <= 4 cut-offs isolate a small, operationally actionable population (31 accounts) rather than a list too large for a Customer Success team to work.

**What this rule is not:** it is a transparent business heuristic, not a machine-learning prediction. It carries no probability, no confidence interval and no claim that low usage or low NPS *causes* churn. It is intended as an outreach prioritisation filter that any stakeholder can audit and adjust.

A secondary **Watch** tier (active customers meeting one of the two conditions) is used in the SQL layer to size the population just outside the primary flag.

---

## 4. CLV assumptions

Estimated CLV = average monthly revenue x average observed lifespan (months).

1. Lifespan is measured only for customers who have already churned (`churn_date` - `signup_date` in whole months). Active customers are still in-flight, so their true tenure is unknown and would bias the average upward if partially counted.
2. No discount rate is applied. This is a simple contribution-style estimate, not a discounted-cash-flow valuation.
3. Gross margin is not available in the dataset, so CLV is stated on a revenue basis rather than a gross-profit basis. A margin-adjusted CLV would be lower.
4. No expansion or contraction revenue is modelled, so upsell-driven value is excluded.
5. CLV is compared against CAC on a like-for-like plan basis only; cross-plan comparisons are directional.

---

## 5. Analytical assumptions

1. Churn is defined at the **customer** level (the subscription ended), not at the seat or licence level.
2. The dataset is a point-in-time snapshot. Churn status reflects the latest month in `monthly_revenue`.
3. `monthly_revenue` for a churned customer is the last known MRR before churn, which is what makes Lost MRR interpretable.
4. CAC is not available per individual customer contract; it is applied at the acquisition-channel and plan level, so Average CAC and CLV:CAC are blended figures.
5. All currency values are USD.
6. Segments with small samples are suppressed before they are actioned: minimum 15 customers for plan x channel, 20 for company size x region, and 30 for channel-level decisions. Rates on tiny segments are unstable and were deliberately excluded from the recommendations.
7. Net Revenue Retention is intentionally **not** published because expansion and contraction MRR components are not present in the source data; publishing an incomplete NRR would misstate performance.

---

## 6. Quality assurance process

Checks run before any figure is shared:

1. **Uniqueness** - `customer_id` is unique; row count equals distinct customer count.
2. **Completeness** - no nulls in required fields (identifier, plan, billing cycle, company size, channel, MRR, signup date).
3. **Expected nulls** - `churn_date` and `churn_reason` are populated only for churned customers and blank for active customers. Blanks here are correct, not missing data.
4. **Date validity** - all dates parse, no churn date precedes its signup date, all dates fall inside the 48-month window.
5. **Type validity** - MRR, NPS, feature usage, support tickets and CAC load as numeric; NPS within 0-10 and feature usage within 0-100.
6. **Categorical integrity** - plan, billing cycle, company size, region and channel contain only expected values with no casing or spelling drift.
7. **Cross-tool reconciliation** - SQL, Excel and Power BI must return identical control totals.

### Control totals

| Metric | Published value |
|---|---|
| Total Customers | 600 |
| Churned Customers | 313 |
| Active Customers | 287 |
| Overall Churn Rate | 52.17% |
| Starter Churn Rate | 70.51% |
| Enterprise Churn Rate | 22.00% |
| Monthly Billing Churn Rate | 60.51% |
| Annual Billing Churn Rate | 40.32% |
| At-Risk Active Customers | 31 |
| Latest MRR | approx. \$292.6K |

Any tool returning a materially different value is investigated and resolved before publication; the report is not released on unreconciled numbers.

---

## 7. Limitations

1. This is **observational** analysis. Differences between segments describe where churn is concentrated; they do not establish cause.
2. The at-risk flag is a heuristic, not a validated predictive model, and has not been backtested against a holdout period.
3. Estimated CLV relies on observed historical lifespan and excludes discounting, margin, expansion and contraction.
4. CAC is not customer-level, so unit economics are blended and should be read directionally.
5. Standard Net Revenue Retention cannot be computed from the available fields.
6. Churn reasons are self-reported categories and are subject to reporting bias.
7. The dataset accompanying this repository is a synthetic sample built to mirror realistic SaaS subscription behaviour; it is used to demonstrate the analytical workflow rather than to describe a real company.

---

## 8. Reproducibility

1. Load `data/subscriptions.csv` and `data/monthly_revenue.csv` without modifying the source files.
2. Run `sql/saas_churn_revenue_analysis.sql` top to bottom. Section 0 must pass before the business questions are trusted; Section 12 returns the control totals.
3. Open `excel/saas_revenue_churn_analysis.xlsx` for the exploratory cut and independent validation of the same totals.
4. Open `powerbi/saas_churn_dashboard.pbix`, refresh, and confirm the KPI cards match the control totals in section 6 before sharing.
