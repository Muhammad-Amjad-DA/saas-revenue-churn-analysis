# SaaS Revenue, Churn & Customer Risk Analysis

**End-to-end analytics engagement:** SQL for analysis, Excel for exploration and validation, Power BI for the executive reporting layer, with documented metric definitions and QA controls.

![Executive Overview](screenshots/executive_overview.png)

---

## Executive summary

A SaaS business with growing revenue is losing customers faster than it can compound them. Across 600 subscription customers and 48 months of revenue history, **52.17% of all customers acquired have churned (313 of 600)**, leaving **287 active customers carrying roughly \$292.6K in latest MRR**.

The loss is not evenly spread. Churn concentrates at the entry tier (**Starter 70.51%** against **Enterprise 22.00%**) and among customers on monthly billing (**60.51%** against **40.32%** for annual). Behavioural signals separate the two groups clearly: customers who left had materially lower product adoption and lower satisfaction than customers who stayed. Applying a transparent risk heuristic to the current base flags **31 active customers** who look like prior churners and are still saveable today.

The recommendation set is therefore narrow and operational: fix entry-tier onboarding and adoption, test annual conversion for suitable monthly accounts, trigger Customer Success outreach on the 31 flagged accounts, review the acquisition channels producing the highest Lost MRR, and protect the small number of high-value Enterprise accounts that carry a disproportionate share of revenue.

---

## Business problem

Revenue is growing, but retention is not keeping pace. Leadership could see the revenue line and knew churn was high, but could not answer where churn was concentrated, why customers were leaving, how much recurring revenue was being lost, or which accounts to work first. Without that, retention effort was being spread evenly across a customer base where the risk is highly uneven.

**Stakeholders:** Product, Customer Success, Finance, Growth.

## Stakeholder questions

1. What is happening to churn and revenue?
2. Where is churn concentrated?
3. Why are customers leaving?
4. What revenue is being lost?
5. Where should retention effort focus first?

---

## Dataset

| Source | Grain | Rows | Contents |
|---|---|---|---|
| `data/subscriptions.csv` | One row per customer | 600 | Plan, billing cycle, company size, region, acquisition channel, MRR, CAC, NPS, feature usage, support tickets, churn status, churn date, churn reason |
| `data/monthly_revenue.csv` | One row per month | 48 | Monthly recurring revenue, active customers, new customers, churned customers |

Source extracts are treated as immutable; all cleaning and derivation happens downstream so the workflow reruns end to end. Field-level documentation is in [`docs/data_dictionary.md`](docs/data_dictionary.md).

> **Note on the data:** the dataset accompanying this repository is a synthetic sample constructed to mirror realistic SaaS subscription behaviour. It demonstrates the analytical workflow rather than describing a real company.

---

## Tools and skills

| Layer | Tooling | What it demonstrates |
|---|---|---|
| Data quality | SQL, Power Query | Uniqueness, null and expected-null audits, date and type validation, categorical integrity checks |
| Analysis | SQL (CTEs, `CASE WHEN`, `RANK()`, `LAG()`, minimum sample-size filters) | Multi-dimensional segmentation and revenue-impact quantification |
| Exploration and validation | Excel (PivotTables, cross-checks) | Independent recalculation of published totals |
| Reporting | Power BI (star schema, marked date table, DAX) | Executive reporting layer with 13 governed measures |
| Governance | Markdown documentation | Metric definitions, assumptions, QA controls, stated limitations |

---

## Data model

A small star schema, deliberately kept minimal:

```
        Date (marked date table)
              |  1
              |  *
      monthly_revenue[month]

      subscriptions  (customer dimension + facts, 1 row per customer)
```

- `Date` is a generated calendar table, marked as the model date table, related one-to-many to `monthly_revenue[month]` with **single-direction filtering**.
- `subscriptions` is held at customer grain and carries the churn, risk and unit-economics measures.
- Helper fields such as month sort order are hidden from report users.

**Measures (13):** Total Customers, Active Customers, Churned Customers, Churn Rate, At-Risk Customers, Lost MRR, Latest MRR, Average CAC, Average Monthly Churn Rate, Latest Active Customers, MRR Growth, Estimated CLV, CLV:CAC.

Measure count is intentionally restrained. Every measure answers a stakeholder question rather than demonstrating DAX for its own sake.

---

## Methodology

1. **Define the question before touching the data** - five stakeholder questions set the scope.
2. **Validate the source** - primary-key uniqueness, null audit, expected-null logic on churn fields, date-order validity, numeric range checks, categorical domain checks.
3. **Define metrics up front** - every published metric has one formula, documented in [`docs/methodology.md`](docs/methodology.md) before analysis begins.
4. **Explore in Excel** - overall churn, monthly trend, plan, billing cycle, company size, channel, churn reasons and behavioural comparison, used as an independent check on the SQL layer.
5. **Analyse in SQL** - segmentation, ranking and revenue-loss quantification with minimum sample-size guards.
6. **Model and report in Power BI** - three pages, each answering one stakeholder question.
7. **Reconcile before publishing** - SQL, Excel and Power BI must return identical control totals.

**At-risk rule (business heuristic, not a model):** active customer **and** feature usage below 40% **and** NPS of 4 or lower. This flags 31 accounts, a population small enough for a Customer Success team to actually work. It carries no probability and makes no causal claim.

---

## SQL analysis

[`sql/saas_churn_revenue_analysis.sql`](sql/saas_churn_revenue_analysis.sql) is organised as numbered business questions rather than a syntax showcase:

| # | Business question | Technique |
|---|---|---|
| 0 | Is the data fit to publish? | Uniqueness, null and expected-null audits, date and range checks |
| 1 | What is the overall retention position? | Aggregation with `CASE WHEN` |
| 2 | Which plans lose customers fastest? | `GROUP BY` with rate and revenue side by side |
| 3 | Does billing cadence relate to retention? | Segment comparison |
| 4 | Is churn concentrated by company size or region? | Multi-dimension `GROUP BY` with `HAVING` sample-size floor |
| 5 | Which channels deliver customers who retain? | CTE plus `RANK()` on churn and revenue loss |
| 6 | Why do customers say they leave? | Share-of-total window aggregation |
| 7 | How do churned and retained customers behave differently? | Conditional aggregation |
| 8 | **Which plan + channel segments create the greatest recurring revenue loss?** | Layered CTEs, share of total Lost MRR, `RANK()` |
| 9 | Which active customers should Customer Success contact first? | Risk segmentation and prioritised worklist |
| 10 | Are the plans we acquire into worth defending? | CLV and CLV:CAC by plan |
| 11 | What is the 48-month revenue and churn trajectory? | `LAG()` for month-over-month growth |
| 12 | Do all three tools agree? | Reconciliation harness returning the control totals |

Question 8 is the core revenue question: it moves the analysis from "churn is high" to "this is where recurring revenue is leaving and this is how much."

---

## Dashboard

**Page 1 - Executive Overview:** *What is happening?*
KPI row (Total Customers, Churned Customers, Churn Rate, Latest MRR, Average CAC, At-Risk Customers), monthly MRR trend, monthly churn trend, churn by plan, churn by billing cycle, with plan / billing cycle / region slicers.

![Churn Diagnostics](screenshots/churn_diagnostics.png)

**Page 2 - Churn Diagnostics:** *Where and why are we losing customers?*
Churn by company size, churn by acquisition channel, top churn reasons, plan x acquisition-channel matrix, and Lost MRR by segment.

![Customer Risk and Unit Economics](screenshots/customer_risk_unit_economics.png)

**Page 3 - Customer Risk & Unit Economics:** *Where should the company act?*
Feature usage against churn, NPS against churn, support behaviour comparison, the active high-risk customer table, estimated CLV by plan and CLV:CAC.

---

## Key findings

1. **Retention, not acquisition, is the constraint.** 313 of 600 customers acquired have cancelled, a lifetime churn rate of 52.17%. Revenue growth is being funded by replacing customers rather than compounding them.
2. **Churn is concentrated at the entry tier.** Starter churn is 70.51% against 22.00% for Enterprise - roughly 3.2 times higher. Plan tier, not overall product quality, is where the retention problem lives.
3. **Billing cadence separates retention sharply.** Monthly-billed customers churn at 60.51% against 40.32% for annual, a gap of 20.2 percentage points. Annual commitment coincides with materially better retention.
4. **Adoption and satisfaction differ measurably between churned and retained customers.** Customers who left show lower feature usage and lower NPS than customers who stayed. This is an observational difference, not proof of cause, but it is strong enough to prioritise outreach on.
5. **31 active customers currently look like prior churners.** That is 10.8% of the 287 active accounts, flagged by low adoption and low NPS while still billable - the saveable population.
6. **Recurring revenue loss is concentrated in a small number of plan and channel combinations.** Ranking segments by Lost MRR shows a minority of plan x channel pairs driving a disproportionate share of total loss, which makes channel quality a revenue issue rather than a marketing metric.
7. **Revenue concentration raises the stakes on Enterprise retention.** 287 active customers carry roughly \$292.6K MRR, about \$1.0K per account on average, and Enterprise accounts sit well above that average - so a small number of Enterprise losses would outweigh many Starter losses.

---

## Recommendations

1. **Prioritise Starter onboarding and adoption.** Starter carries the highest churn rate and the largest customer counts. Test a structured first-30-day onboarding path and measure whether feature adoption at day 30 moves Starter retention.
2. **Investigate monthly-to-annual conversion for suitable accounts.** Given the 20-point retention gap, test incentives for monthly customers who already show healthy adoption, and monitor whether converted accounts retain at annual-cohort levels.
3. **Trigger Customer Success outreach on the 31 flagged accounts.** Work the list in descending MRR order, log the intervention and the outcome so the heuristic can be evaluated against a real baseline rather than assumed to work.
4. **Review acquisition channels by Lost MRR, not by volume.** Where channels produce customers with high churn and high revenue loss, test reallocating spend toward channels producing customers who retain, and monitor CLV:CAC by channel over the following quarters.
5. **Protect high-value Enterprise accounts explicitly.** Maintain service levels and executive relationships in the segment carrying the largest revenue per account, and monitor Enterprise adoption and NPS as leading indicators.

Language here is deliberate: **test, investigate, monitor, review.** The data supports prioritisation, not causal claims.

---

## Limitations

1. This is observational analysis. Segment differences show where churn is concentrated; they do not establish cause.
2. The at-risk flag is a documented heuristic, not a validated predictive model, and has not been backtested on a holdout period.
3. Estimated CLV is directional: it uses observed historical lifespan and excludes discounting, gross margin, expansion and contraction.
4. CAC is not available at individual-customer level, so unit economics are blended at channel and plan level.
5. Standard Net Revenue Retention is not published, because expansion and contraction MRR components are absent from the source data and an incomplete NRR would misstate performance.
6. Churn reasons are self-reported and subject to reporting bias.
7. The accompanying dataset is a synthetic sample; findings illustrate analytical reasoning rather than a real company's performance.

---

## Repository structure

```
saas-revenue-churn-analysis/
|-- README.md
|-- data/
|   |-- subscriptions.csv                  # 600 customers, immutable source
|   |-- monthly_revenue.csv                # 48 months of revenue history
|-- sql/
|   |-- saas_churn_revenue_analysis.sql    # numbered business questions + QA harness
|-- excel/
|   |-- saas_revenue_churn_analysis.xlsx   # exploratory analysis and validation
|-- powerbi/
|   |-- saas_churn_dashboard.pbix          # 3-page executive report
|-- screenshots/
|   |-- executive_overview.png
|   |-- churn_diagnostics.png
|   |-- customer_risk_unit_economics.png
|-- docs/
    |-- data_dictionary.md                 # field, table, type, definition
    |-- methodology.md                     # metric formulas, assumptions, QA
```

---

## How to reproduce

1. Load `data/subscriptions.csv` and `data/monthly_revenue.csv` into your SQL engine as `subscriptions` and `monthly_revenue`. Do not edit the source files.
2. Run `sql/saas_churn_revenue_analysis.sql` top to bottom. Section 0 must pass before any result is trusted; Section 12 returns the control totals.
3. Open `excel/saas_revenue_churn_analysis.xlsx` to review the exploratory cut and independently confirm the same totals.
4. Open `powerbi/saas_churn_dashboard.pbix`, refresh, and confirm the KPI cards match the control totals below before sharing anything.

### Control totals

| Metric | Value |
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

Full definitions and assumptions: [`docs/methodology.md`](docs/methodology.md).
