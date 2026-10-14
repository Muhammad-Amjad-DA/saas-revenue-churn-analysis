"""Revenue-at-risk and Lost MRR by plan, plus the hero chart.
Reads data/subscriptions.csv. Reproduces the control totals in docs/methodology.md (600 / 313 / 287 / 31).
Usage (from repo root):  python python/revenue_at_risk.py
"""
import pathlib, pandas as pd, matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

root = pathlib.Path(__file__).resolve().parents[1]
s = pd.read_csv(root / "data" / "subscriptions.csv")
churned, active = s[s.churned == "Yes"], s[s.churned == "No"]

# Control totals (must match docs/methodology.md)
at_risk = active[(active.feature_usage_pct < 40) & (active.nps_score <= 4)]
assert (len(s), len(churned), len(active), len(at_risk)) == (600, 313, 287, 31), "control totals changed"

lost_total = churned.monthly_revenue.sum()
by_plan = (churned.groupby("plan").agg(churned_customers=("customer_id", "count"), lost_mrr=("monthly_revenue", "sum"))
           .assign(pct_churned_customers=lambda d: 100 * d.churned_customers / d.churned_customers.sum(),
                   pct_lost_mrr=lambda d: 100 * d.lost_mrr / lost_total))
print(by_plan.round(1))
print(f"\nLost MRR total: ${lost_total:,.0f}")
print(f"At-risk accounts: {len(at_risk)}  MRR ${at_risk.monthly_revenue.sum():,.0f}  ARR ${12*at_risk.monthly_revenue.sum():,.0f}  "
      f"= {100*at_risk.monthly_revenue.sum()/active.monthly_revenue.sum():.1f}% of active MRR (${active.monthly_revenue.sum():,.0f})")
print("At-risk MRR by plan:\n", at_risk.groupby("plan").monthly_revenue.agg(["count", "sum"]).round(0))
print(f"Top 10 at-risk accounts = {100*at_risk.nlargest(10, 'monthly_revenue').monthly_revenue.sum()/at_risk.monthly_revenue.sum():.1f}% of at-risk MRR")
bm = churned[(churned.plan == "Business") & (churned.billing_cycle == "Monthly")].monthly_revenue.sum()
print(f"Business x Monthly lost MRR: ${bm:,.0f} = {100*bm/lost_total:.1f}% of all Lost MRR")

# Hero chart
NAVY, ORANGE, GREY = "#1F3A5F", "#E07A1F", "#8A94A3"
plt.rcParams.update({"font.family": "DejaVu Sans", "axes.spines.top": False, "axes.spines.right": False, "axes.edgecolor": GREY})
order = ["Starter", "Professional", "Business", "Enterprise"]
d = by_plan.loc[order]
fig, ax = plt.subplots(figsize=(12, 6.3), dpi=100)
x = range(len(d)); w = 0.38
b1 = ax.bar([i - w/2 for i in x], d.pct_churned_customers, w, color=GREY, label="% of churned customers")
b2 = ax.bar([i + w/2 for i in x], d.pct_lost_mrr, w, color=[NAVY, NAVY, ORANGE, NAVY], label="% of Lost MRR")
for b in list(b1) + list(b2):
    ax.text(b.get_x() + b.get_width()/2, b.get_height() + 1, f"{b.get_height():.0f}%", ha="center", fontsize=12, fontweight="bold")
ax.set_xticks(list(x)); ax.set_xticklabels(order, fontsize=13); ax.set_yticks([]); ax.spines["left"].set_visible(False); ax.set_ylim(0, 62)
ax.legend(frameon=False, fontsize=11, loc="upper right")
fig.suptitle("Starter loses the customers. Business loses the money.", x=0.05, ha="left", fontsize=19, fontweight="bold", color=NAVY)
fig.text(0.05, 0.885, "Share of churned customers vs share of Lost MRR, by plan (synthetic dataset, 600 customers)", fontsize=11, color=GREY)
fig.tight_layout(rect=[0, 0, 1, 0.87]); fig.savefig(root / "screenshots" / "hero_lost_mrr.png"); plt.close(fig)
