# SaaS Revenue, Churn & Customer Risk Analysis

End-to-end SaaS analytics case study using **MySQL, Excel, Power BI, and DAX** to identify churn drivers, quantify recurring revenue risk, and prioritize customer-retention actions.

![Executive Overview](screenshots/executive_overview.png)

## Business Problem

A SaaS company is growing revenue while experiencing significant customer churn. The analysis focuses on:

- Where is churn concentrated?
- Why are customers leaving?
- Which segments create the greatest revenue loss?
- Which active customers should Customer Success prioritize?

## Dataset

- **600** subscription customers
- **48 months** of revenue history
- Customer plans, billing cycles, company size, acquisition channels, NPS, feature usage, support activity, churn status, and revenue

> Synthetic dataset used to demonstrate analytical workflow and business decision-making.

## Tech Stack

**MySQL · Excel · Power BI · DAX · Power Query · GitHub**

Key techniques: CTEs, `CASE WHEN`, `RANK()`, segmentation, revenue-loss analysis, data validation, KPI reconciliation, and customer-risk analysis.

## Key Findings

- **52.17% overall historical churn** — 313 of 600 customers.
- **Starter churn: 70.51%** vs. **Enterprise: 22.00%**.
- **Monthly billing churn: 60.51%** vs. **Annual: 40.32%**.
- Churned customers show materially lower **feature usage and NPS**.
- **31 active customers** meet the defined high-risk heuristic.
- Latest monthly revenue reached approximately **$292.6K MRR**.
- Lost MRR is concentrated in specific **plan × acquisition-channel** segments.

## Dashboard

### Executive Overview
Revenue, churn, customer risk, and high-level retention performance.

![Executive Overview](screenshots/executive_overview.png)

### Churn Diagnostics
Segment-level churn, churn reasons, acquisition-channel performance, and Lost MRR.

![Churn Diagnostics](screenshots/churn_diagnostics.png)

### Customer Risk & Unit Economics
Behavioral risk indicators, active high-risk accounts, Estimated CLV, and CLV:CAC.

![Customer Risk & Unit Economics](screenshots/customer_risk_unit_economics.png)

## Recommendations

1. Improve **Starter onboarding and product adoption**.
2. Test **monthly-to-annual conversion** for suitable customers.
3. Prioritize Customer Success outreach to the **31 high-risk active accounts**.
4. Review acquisition channels using **Lost MRR and retention**, not customer volume alone.
5. Protect high-value **Enterprise accounts** through proactive retention monitoring.

## Analytical Controls

Key results were independently reconciled across **SQL, Excel, and Power BI**.

| KPI | Result |
|---|---:|
| Total Customers | 600 |
| Churned Customers | 313 |
| Active Customers | 287 |
| Churn Rate | 52.17% |
| At-Risk Active Customers | 31 |
| Latest Active Customers | 281 |
| Latest MRR | $292,628.61 |

## Limitations

- Analysis is observational and does not establish causation.
- Customer-risk classification is a business heuristic, not a predictive model.
- CAC is available only at monthly aggregate level.
- Estimated CLV is directional.
- Standard NRR cannot be calculated from the available revenue components.

## Project Files

- [`SQL Analysis`](sql/saas_churn_revenue_analysis.sql)
- [`Methodology`](docs/methodology.md)
- [`Data Dictionary`](docs/data_dictionary.md)
- `excel/saas_revenue_churn_analysis.xlsx`
- `powerbi/saas_churn_dashboard.pbix`

---

**Goal:** translate customer and revenue data into clear retention priorities and measurable business actions.
