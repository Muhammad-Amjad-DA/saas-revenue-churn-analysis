# powerbi/

Executive reporting layer.

**Report file:** `saas_churn_dashboard.pbix`

## Model

```
        Date (marked date table)
              |  1
              |  *
      monthly_revenue[month]

      subscriptions  (customer grain, 1 row per customer)
```

The `Date` table is generated in the model, marked as the official date table and related one-to-many to `monthly_revenue[month]` with single-direction filtering. Helper fields such as month sort order are hidden from report users.

## Measures (13)

Total Customers, Active Customers, Churned Customers, Churn Rate, At-Risk Customers, Lost MRR, Latest MRR, Average CAC, Average Monthly Churn Rate, Latest Active Customers, MRR Growth, Estimated CLV, CLV:CAC.

The measure list is deliberately restrained. Each one answers a stakeholder question; formulas and assumptions are documented in [../docs/methodology.md](../docs/methodology.md).

## Pages

| Page | Stakeholder question | Contents |
|---|---|---|
| 1. Executive Overview | What is happening? | KPI row, monthly MRR trend, monthly churn trend, churn by plan, churn by billing cycle, plan / billing cycle / region slicers |
| 2. Churn Diagnostics | Where and why are we losing customers? | Churn by company size, churn by acquisition channel, top churn reasons, plan x channel matrix, Lost MRR by segment |
| 3. Customer Risk & Unit Economics | Where should we act? | Feature usage against churn, NPS against churn, support behavior, active high-risk customer table, estimated CLV by plan, CLV:CAC |

Before the report is shared, the KPI cards are reconciled against the SQL control totals.
