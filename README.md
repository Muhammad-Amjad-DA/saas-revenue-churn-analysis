# SaaS Revenue, Churn & Customer Risk Analysis

**End-to-end analytics case study:** SQL for analysis, Excel for exploration and validation, and Power BI for executive reporting, supported by documented metric definitions, assumptions, and QA controls.

![Executive Overview](screenshots/executive_overview.png)

---

## Executive Summary

A SaaS business is growing revenue while experiencing significant customer churn, creating a clear retention and customer-health challenge. Across 600 subscription customers and 48 months of revenue history, **52.17% of customers have churned (313 of 600)**.

The subscription snapshot contains **287 active customers**, while the latest monthly revenue snapshot reports **281 active customers** and approximately **$292.6K in MRR**.

Churn is concentrated at the entry tier, with **Starter churn at 70.51% compared with 22.00% for Enterprise**. Customers on monthly billing also show materially higher churn at **60.51% compared with 40.32% for annual billing**.

Behavioral indicators provide an additional retention signal. Customers who churned generally show lower feature adoption and lower NPS than retained customers. A defined high-risk heuristic — active customer, feature usage below 40%, and NPS ≤ 4 — identifies **31 currently active accounts** for prioritized Customer Success review.

The recommended response is targeted: improve Starter onboarding and adoption, investigate annual-plan conversion for suitable monthly customers, prioritize outreach to high-risk active accounts, review acquisition channels generating the greatest Lost MRR, and protect high-value Enterprise accounts.

---

## Business Problem

Revenue is growing, but customer retention remains a significant business risk.

Leadership needs to understand:

- where churn is concentrated
- why customers are leaving
- which customer segments create the greatest recurring revenue loss
- which active customers show elevated retention risk
- where retention resources should be prioritized

**Stakeholders:** Product, Customer Success, Finance, Growth.

---

## Stakeholder Questions

1. What is happening to customer churn and recurring revenue?
2. Which customer segments have the highest churn?
3. Why are customers leaving?
4. Which customer segments create the greatest Lost MRR?
5. Which active customers should Customer Success prioritize?

---

## Dataset

| Source | Grain | Rows | Contents |
|---|---|---:|---|
| `data/subscriptions.csv` | One row per customer | 600 | Plan, billing cycle, industry, company size, seats, monthly revenue, acquisition channel, region, signup date, churn status/date/reason, support tickets, NPS, feature usage, upgraded |
| `data/monthly_revenue.csv` | One row per month | 48 | Active customers, new customers, churned customers, monthly churn rate, total MRR, average revenue per customer, customer acquisition cost |

Source extracts are treated as immutable. Cleaning, calculations, segmentation, and reporting are performed downstream.

Field-level documentation is available in [`docs/data_dictionary.md`](docs/data_dictionary.md).

> **Data note:** The dataset is a synthetic sample designed to represent realistic SaaS subscription behavior. The project demonstrates analytical workflow and business reasoning rather than the performance of a real company.

---

## Tools & Skills

| Layer | Tooling | Application |
|---|---|---|
| Data validation | SQL, Power Query, Excel | Null checks, duplicates, dates, types, categorical validation |
| Analysis | MySQL | Aggregation, `CASE WHEN`, CTEs, segmentation, ranking, window functions |
| Exploration | Excel | PivotTables, independent KPI validation, trend analysis |
| Data modeling | Power BI | Date dimension, relationships, reporting model |
| Metrics | DAX | Churn, MRR, CAC, customer risk, CLV and growth measures |
| Reporting | Power BI | Executive overview, churn diagnostics, customer-risk analysis |
| Governance | Markdown | Metric definitions, methodology, assumptions and limitations |

---

## Data Model

A lightweight reporting model with a dedicated Date dimension:

```text
          Date
           |
          1:1
           |
    monthly_revenue


    subscriptions
    customer-level subscription snapshot
    one row per customer
