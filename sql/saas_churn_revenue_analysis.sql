/* ============================================================================
   Project : SaaS Revenue, Churn & Customer Risk Analysis
   File    : sql/saas_churn_revenue_analysis.sql
   Grain   : subscriptions   = 1 row per customer (600 customers)
             monthly_revenue = 1 row per calendar month (48 months)
   Purpose : Quantify churn concentration, churn drivers, revenue at risk and
             retention priorities for Product, Customer Success, Finance and Growth.
   Dialect : ANSI SQL. Written and validated against PostgreSQL; SQL Server
             equivalents are noted inline where date functions differ.
   Note    : All rates are rounded to 2 decimals so SQL output ties exactly to
             the Excel workbook and the Power BI model (see docs/methodology.md).
   ============================================================================ */


/* ============================================================================
   SECTION 0 - DATA QUALITY CONTROLS
   Run before any analysis is published. Every check must PASS or be explained.
   ============================================================================ */

-- 0.1 Row count and primary-key uniqueness
SELECT
    COUNT(*)                                         AS row_count,
    COUNT(DISTINCT customer_id)                      AS distinct_customers,
    CASE WHEN COUNT(*) = COUNT(DISTINCT customer_id)
         THEN 'PASS' ELSE 'FAIL' END                 AS pk_uniqueness_check
FROM subscriptions;

-- 0.2 Null audit on required fields (all must be zero)
SELECT
    SUM(CASE WHEN customer_id         IS NULL THEN 1 ELSE 0 END) AS null_customer_id,
    SUM(CASE WHEN plan                IS NULL THEN 1 ELSE 0 END) AS null_plan,
    SUM(CASE WHEN billing_cycle       IS NULL THEN 1 ELSE 0 END) AS null_billing_cycle,
    SUM(CASE WHEN company_size        IS NULL THEN 1 ELSE 0 END) AS null_company_size,
    SUM(CASE WHEN acquisition_channel IS NULL THEN 1 ELSE 0 END) AS null_channel,
    SUM(CASE WHEN monthly_revenue     IS NULL THEN 1 ELSE 0 END) AS null_mrr,
    SUM(CASE WHEN signup_date         IS NULL THEN 1 ELSE 0 END) AS null_signup_date
FROM subscriptions;

-- 0.3 Expected nulls: churn_date and churn_reason are populated ONLY for churned
--     customers. Any row in the 'unexpected' buckets is a data-integrity defect.
SELECT
    CASE
        WHEN is_churned = 1 AND churn_date IS NOT NULL AND churn_reason IS NOT NULL
            THEN 'Churned - complete (expected)'
        WHEN is_churned = 1 AND (churn_date IS NULL OR churn_reason IS NULL)
            THEN 'Churned - missing churn detail (unexpected)'
        WHEN is_churned = 0 AND churn_date IS NULL AND churn_reason IS NULL
            THEN 'Active - blank churn fields (expected)'
        ELSE 'Active - churn fields populated (unexpected)'
    END                     AS integrity_bucket,
    COUNT(*)                AS customers
FROM subscriptions
GROUP BY 1
ORDER BY customers DESC;

-- 0.4 Date logic: churn cannot precede signup, dates must fall inside the window
SELECT
    MIN(signup_date)                                                   AS first_signup,
    MAX(signup_date)                                                   AS last_signup,
    MIN(churn_date)                                                    AS first_churn,
    MAX(churn_date)                                                    AS last_churn,
    SUM(CASE WHEN churn_date < signup_date THEN 1 ELSE 0 END)          AS invalid_date_order
FROM subscriptions;

-- 0.5 Categorical domain check (catches typos, casing drift and stray values)
SELECT 'plan'          AS dimension, plan                AS value, COUNT(*) AS customers FROM subscriptions GROUP BY plan
UNION ALL
SELECT 'billing_cycle' AS dimension, billing_cycle       AS value, COUNT(*) AS customers FROM subscriptions GROUP BY billing_cycle
UNION ALL
SELECT 'company_size'  AS dimension, company_size        AS value, COUNT(*) AS customers FROM subscriptions GROUP BY company_size
UNION ALL
SELECT 'channel'       AS dimension, acquisition_channel AS value, COUNT(*) AS customers FROM subscriptions GROUP BY acquisition_channel
ORDER BY dimension, customers DESC;

-- 0.6 Numeric range check: values outside these bounds indicate load errors
SELECT
    MIN(monthly_revenue)   AS min_mrr,
    MAX(monthly_revenue)   AS max_mrr,
    MIN(nps_score)         AS min_nps,          -- expected 0-10
    MAX(nps_score)         AS max_nps,
    MIN(feature_usage_pct) AS min_usage_pct,    -- expected 0-100
    MAX(feature_usage_pct) AS max_usage_pct,
    MIN(support_tickets)   AS min_tickets,      -- expected >= 0
    MAX(support_tickets)   AS max_tickets
FROM subscriptions;


/* ============================================================================
   BUSINESS QUESTION 1
   What is the overall retention position of the customer base?
   ============================================================================ */

SELECT
    COUNT(*)                                                              AS total_customers,
    SUM(CASE WHEN is_churned = 1 THEN 1 ELSE 0 END)                       AS churned_customers,
    SUM(CASE WHEN is_churned = 0 THEN 1 ELSE 0 END)                       AS active_customers,
    ROUND(100.0 * SUM(CASE WHEN is_churned = 1 THEN 1 ELSE 0 END)
          / NULLIF(COUNT(*), 0), 2)                                       AS churn_rate_pct,
    ROUND(SUM(CASE WHEN is_churned = 0 THEN monthly_revenue ELSE 0 END), 2) AS active_mrr,
    ROUND(SUM(CASE WHEN is_churned = 1 THEN monthly_revenue ELSE 0 END), 2) AS lost_mrr
FROM subscriptions;


/* ============================================================================
   BUSINESS QUESTION 2
   Which plan tiers are losing customers fastest, and what revenue sits behind them?
   ============================================================================ */

SELECT
    plan,
    COUNT(*)                                                              AS customers,
    SUM(CASE WHEN is_churned = 1 THEN 1 ELSE 0 END)                       AS churned_customers,
    ROUND(100.0 * SUM(CASE WHEN is_churned = 1 THEN 1 ELSE 0 END)
          / NULLIF(COUNT(*), 0), 2)                                       AS churn_rate_pct,
    ROUND(AVG(monthly_revenue), 2)                                        AS avg_mrr_per_customer,
    ROUND(SUM(CASE WHEN is_churned = 1 THEN monthly_revenue ELSE 0 END), 2) AS lost_mrr
FROM subscriptions
GROUP BY plan
ORDER BY churn_rate_pct DESC;


/* ============================================================================
   BUSINESS QUESTION 3
   Does billing cadence relate to retention (monthly vs annual commitment)?
   ============================================================================ */

SELECT
    billing_cycle,
    COUNT(*)                                                              AS customers,
    SUM(CASE WHEN is_churned = 1 THEN 1 ELSE 0 END)                       AS churned_customers,
    ROUND(100.0 * SUM(CASE WHEN is_churned = 1 THEN 1 ELSE 0 END)
          / NULLIF(COUNT(*), 0), 2)                                       AS churn_rate_pct
FROM subscriptions
GROUP BY billing_cycle
ORDER BY churn_rate_pct DESC;


/* ============================================================================
   BUSINESS QUESTION 4
   Is churn concentrated in particular company sizes or regions?
   ============================================================================ */

SELECT
    company_size,
    region,
    COUNT(*)                                                              AS customers,
    ROUND(100.0 * SUM(CASE WHEN is_churned = 1 THEN 1 ELSE 0 END)
          / NULLIF(COUNT(*), 0), 2)                                       AS churn_rate_pct,
    ROUND(SUM(CASE WHEN is_churned = 1 THEN monthly_revenue ELSE 0 END), 2) AS lost_mrr
FROM subscriptions
GROUP BY company_size, region
HAVING COUNT(*) >= 20            -- minimum sample size: suppress unstable segments
ORDER BY churn_rate_pct DESC;


/* ============================================================================
   BUSINESS QUESTION 5
   Which acquisition channels deliver customers who retain, not just customers who sign?
   ============================================================================ */

WITH channel_performance AS (
    SELECT
        acquisition_channel,
        COUNT(*)                                                          AS customers,
        SUM(CASE WHEN is_churned = 1 THEN 1 ELSE 0 END)                   AS churned_customers,
        ROUND(100.0 * SUM(CASE WHEN is_churned = 1 THEN 1 ELSE 0 END)
              / NULLIF(COUNT(*), 0), 2)                                   AS churn_rate_pct,
        ROUND(AVG(cac), 2)                                                AS avg_cac,
        ROUND(SUM(CASE WHEN is_churned = 1 THEN monthly_revenue ELSE 0 END), 2) AS lost_mrr
    FROM subscriptions
    GROUP BY acquisition_channel
    HAVING COUNT(*) >= 30        -- minimum sample size for channel-level decisions
)
SELECT
    acquisition_channel,
    customers,
    churned_customers,
    churn_rate_pct,
    avg_cac,
    lost_mrr,
    RANK() OVER (ORDER BY churn_rate_pct DESC) AS churn_rank,
    RANK() OVER (ORDER BY lost_mrr      DESC) AS revenue_loss_rank
FROM channel_performance
ORDER BY revenue_loss_rank;


/* ============================================================================
   BUSINESS QUESTION 6
   Why do customers say they are leaving?
   ============================================================================ */

SELECT
    churn_reason,
    COUNT(*)                                                              AS churned_customers,
    ROUND(100.0 * COUNT(*)
          / NULLIF(SUM(COUNT(*)) OVER (), 0), 2)                          AS pct_of_churn,
    ROUND(SUM(monthly_revenue), 2)                                        AS lost_mrr
FROM subscriptions
WHERE is_churned = 1
  AND churn_reason IS NOT NULL
GROUP BY churn_reason
ORDER BY churned_customers DESC;


/* ============================================================================
   BUSINESS QUESTION 7
   How does behavior differ between customers who stayed and customers who left?
   (Observational comparison only - it does not establish causation.)
   ============================================================================ */

SELECT
    CASE WHEN is_churned = 1 THEN 'Churned' ELSE 'Active' END             AS customer_status,
    COUNT(*)                                                              AS customers,
    ROUND(AVG(feature_usage_pct), 1)                                      AS avg_feature_usage_pct,
    ROUND(AVG(CAST(nps_score AS DECIMAL(10,2))), 1)                       AS avg_nps,
    ROUND(AVG(CAST(support_tickets AS DECIMAL(10,2))), 1)                 AS avg_support_tickets,
    ROUND(AVG(monthly_revenue), 2)                                        AS avg_mrr
FROM subscriptions
GROUP BY CASE WHEN is_churned = 1 THEN 'Churned' ELSE 'Active' END
ORDER BY customer_status;


/* ============================================================================
   BUSINESS QUESTION 8  (primary revenue question)
   Which plan + acquisition-channel segments are creating the greatest
   recurring revenue loss, and how large is each segment's share of total loss?
   ============================================================================ */

WITH segment_loss AS (
    SELECT
        plan,
        acquisition_channel,
        COUNT(*)                                                          AS customers,
        SUM(CASE WHEN is_churned = 1 THEN 1 ELSE 0 END)                   AS churned_customers,
        ROUND(100.0 * SUM(CASE WHEN is_churned = 1 THEN 1 ELSE 0 END)
              / NULLIF(COUNT(*), 0), 2)                                   AS churn_rate_pct,
        SUM(CASE WHEN is_churned = 1 THEN monthly_revenue ELSE 0 END)     AS lost_mrr
    FROM subscriptions
    GROUP BY plan, acquisition_channel
    HAVING COUNT(*) >= 15        -- minimum sample size before a segment is actioned
),
company_total AS (
    SELECT SUM(CASE WHEN is_churned = 1 THEN monthly_revenue ELSE 0 END) AS total_lost_mrr
    FROM subscriptions
)
SELECT
    s.plan,
    s.acquisition_channel,
    s.customers,
    s.churned_customers,
    s.churn_rate_pct,
    ROUND(s.lost_mrr, 2)                                                  AS lost_mrr,
    ROUND(100.0 * s.lost_mrr / NULLIF(t.total_lost_mrr, 0), 2)            AS pct_of_total_lost_mrr,
    RANK() OVER (ORDER BY s.lost_mrr DESC)                                AS loss_rank
FROM segment_loss s
CROSS JOIN company_total t
ORDER BY loss_rank;


/* ============================================================================
   BUSINESS QUESTION 9
   Which ACTIVE customers should Customer Success contact first?
   Business heuristic (not a predictive model): active AND feature usage < 40%
   AND NPS <= 4. See docs/methodology.md for the rationale and limitations.
   ============================================================================ */

-- 9.1 Size of the at-risk population and the MRR it represents
WITH risk_flagged AS (
    SELECT
        s.*,
        CASE
            WHEN is_churned = 0 AND feature_usage_pct < 40 AND nps_score <= 4 THEN 'At Risk'
            WHEN is_churned = 0 AND (feature_usage_pct < 40 OR nps_score <= 4) THEN 'Watch'
            WHEN is_churned = 0                                                THEN 'Healthy'
            ELSE 'Churned'
        END AS risk_segment
    FROM subscriptions s
)
SELECT
    risk_segment,
    COUNT(*)                                                              AS customers,
    ROUND(SUM(monthly_revenue), 2)                                        AS mrr_in_segment,
    ROUND(AVG(feature_usage_pct), 1)                                      AS avg_feature_usage_pct,
    ROUND(AVG(CAST(nps_score AS DECIMAL(10,2))), 1)                       AS avg_nps
FROM risk_flagged
WHERE risk_segment <> 'Churned'
GROUP BY risk_segment
ORDER BY mrr_in_segment DESC;

-- 9.2 Outreach worklist, highest revenue exposure first
SELECT
    customer_id,
    plan,
    billing_cycle,
    company_size,
    acquisition_channel,
    region,
    monthly_revenue,
    feature_usage_pct,
    nps_score,
    support_tickets
FROM subscriptions
WHERE is_churned = 0
  AND feature_usage_pct < 40
  AND nps_score <= 4
ORDER BY monthly_revenue DESC;


/* ============================================================================
   BUSINESS QUESTION 10
   Are the plans we are acquiring into economically worth defending?
   Estimated CLV = average MRR x average observed lifespan (months).
   Lifespan is observed only for churned customers, so CLV is a directional
   estimate, not a contractual value. PostgreSQL month difference shown;
   for SQL Server use DATEDIFF(MONTH, signup_date, churn_date).
   ============================================================================ */

WITH lifespan AS (
    SELECT
        plan,
        (EXTRACT(YEAR  FROM churn_date) - EXTRACT(YEAR  FROM signup_date)) * 12
      + (EXTRACT(MONTH FROM churn_date) - EXTRACT(MONTH FROM signup_date)) AS tenure_months
    FROM subscriptions
    WHERE is_churned = 1
      AND churn_date IS NOT NULL
),
plan_lifespan AS (
    SELECT plan, AVG(tenure_months) AS avg_lifespan_months
    FROM lifespan
    GROUP BY plan
),
plan_economics AS (
    SELECT plan, AVG(monthly_revenue) AS avg_mrr, AVG(cac) AS avg_cac
    FROM subscriptions
    GROUP BY plan
)
SELECT
    e.plan,
    ROUND(e.avg_mrr, 2)                                                   AS avg_mrr,
    ROUND(l.avg_lifespan_months, 1)                                       AS avg_lifespan_months,
    ROUND(e.avg_mrr * l.avg_lifespan_months, 2)                           AS estimated_clv,
    ROUND(e.avg_cac, 2)                                                   AS avg_cac,
    ROUND(e.avg_mrr * l.avg_lifespan_months / NULLIF(e.avg_cac, 0), 2)    AS clv_to_cac_ratio
FROM plan_economics e
JOIN plan_lifespan  l ON l.plan = e.plan
ORDER BY clv_to_cac_ratio;


/* ============================================================================
   BUSINESS QUESTION 11
   What is the monthly revenue and churn trajectory over the 48-month window?
   ============================================================================ */

SELECT
    month,
    total_mrr,
    active_customers,
    new_customers,
    churned_customers,
    ROUND(100.0 * churned_customers
          / NULLIF(active_customers + churned_customers, 0), 2)           AS monthly_churn_rate_pct,
    LAG(total_mrr) OVER (ORDER BY month)                                  AS prior_month_mrr,
    ROUND(100.0 * (total_mrr - LAG(total_mrr) OVER (ORDER BY month))
          / NULLIF(LAG(total_mrr) OVER (ORDER BY month), 0), 2)           AS mrr_growth_pct
FROM monthly_revenue
ORDER BY month;


/* ============================================================================
   SECTION 12 - RECONCILIATION HARNESS
   These figures are the published control totals. Excel and Power BI must
   return the same values before anything is shared with stakeholders.
   ============================================================================ */

SELECT 'Total Customers'   AS metric, CAST(COUNT(*) AS DECIMAL(18,2)) AS value FROM subscriptions
UNION ALL
SELECT 'Churned Customers', CAST(SUM(CASE WHEN is_churned = 1 THEN 1 ELSE 0 END) AS DECIMAL(18,2)) FROM subscriptions
UNION ALL
SELECT 'Active Customers',  CAST(SUM(CASE WHEN is_churned = 0 THEN 1 ELSE 0 END) AS DECIMAL(18,2)) FROM subscriptions
UNION ALL
SELECT 'Churn Rate %',      ROUND(100.0 * SUM(CASE WHEN is_churned = 1 THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 2) FROM subscriptions
UNION ALL
SELECT 'At-Risk Active',    CAST(SUM(CASE WHEN is_churned = 0 AND feature_usage_pct < 40 AND nps_score <= 4 THEN 1 ELSE 0 END) AS DECIMAL(18,2)) FROM subscriptions
UNION ALL
SELECT 'Lost MRR',          ROUND(SUM(CASE WHEN is_churned = 1 THEN monthly_revenue ELSE 0 END), 2) FROM subscriptions
UNION ALL
SELECT 'Active MRR',        ROUND(SUM(CASE WHEN is_churned = 0 THEN monthly_revenue ELSE 0 END), 2) FROM subscriptions;

-- End of file
/* ============================================================================
   Project : SaaS Revenue, Churn & Customer Risk Analysis
   File    : sql/saas_churn_revenue_analysis.sql
   Grain   : subscriptions   = 1 row per customer (600 customers)
             monthly_revenue = 1 row per calendar month (48 months)
   Purpose : Quantify churn concentration, churn drivers, revenue at risk and
             retention priorities for Product, Customer Success, Finance and Growth.
   Dialect : ANSI SQL. Written and validated against PostgreSQL; SQL Server
             equivalents are noted inline where date functions differ.
   Note    : All rates are rounded to 2 decimals so SQL output ties exactly to
             the Excel workbook and the Power BI model (see docs/methodology.md).
   ============================================================================ */


/* ============================================================================
   SECTION 0 - DATA QUALITY CONTROLS
   Run before any analysis is published. Every check must PASS or be explained.
   ============================================================================ */

-- 0.1 Row count and primary-key uniqueness
SELECT
    COUNT(*)                                         AS row_count,
    COUNT(DISTINCT customer_id)                      AS distinct_customers,
    CASE WHEN COUNT(*) = COUNT(DISTINCT customer_id)
         THEN 'PASS' ELSE 'FAIL' END                 AS pk_uniqueness_check
FROM subscriptions;

-- 0.2 Null audit on required fields (all must be zero)
SELECT
    SUM(CASE WHEN customer_id         IS NULL THEN 1 ELSE 0 END) AS null_customer_id,
    SUM(CASE WHEN plan                IS NULL THEN 1 ELSE 0 END) AS null_plan,
    SUM(CASE WHEN billing_cycle       IS NULL THEN 1 ELSE 0 END) AS null_billing_cycle,
    SUM(CASE WHEN company_size        IS NULL THEN 1 ELSE 0 END) AS null_company_size,
    SUM(CASE WHEN acquisition_channel IS NULL THEN 1 ELSE 0 END) AS null_channel,
    SUM(CASE WHEN monthly_revenue     IS NULL THEN 1 ELSE 0 END) AS null_mrr,
    SUM(CASE WHEN signup_date         IS NULL THEN 1 ELSE 0 END) AS null_signup_date
FROM subscriptions;

-- 0.3 Expected nulls: churn_date and churn_reason are populated ONLY for churned
--     customers. Any row in the 'unexpected' buckets is a data-integrity defect.
SELECT
    CASE
        WHEN is_churned = 1 AND churn_date IS NOT NULL AND churn_reason IS NOT NULL
            THEN 'Churned - complete (expected)'
        WHEN is_churned = 1 AND (churn_date IS NULL OR churn_reason IS NULL)
            THEN 'Churned - missing churn detail (unexpected)'
        WHEN is_churned = 0 AND churn_date IS NULL AND churn_reason IS NULL
            THEN 'Active - blank churn fields (expected)'
        ELSE 'Active - churn fields populated (unexpected)'
    END                     AS integrity_bucket,
    COUNT(*)                AS customers
FROM subscriptions
GROUP BY 1
ORDER BY customers DESC;

-- 0.4 Date logic: churn cannot precede signup, dates must fall inside the window
SELECT
    MIN(signup_date)                                                   AS first_signup,
    MAX(signup_date)                                                   AS last_signup,
    MIN(churn_date)                                                    AS first_churn,
    MAX(churn_date)                                                    AS last_churn,
    SUM(CASE WHEN churn_date < signup_date THEN 1 ELSE 0 END)          AS invalid_date_order
FROM subscriptions;

-- 0.5 Categorical domain check (catches typos, casing drift and stray values)
SELECT 'plan'          AS dimension, plan                AS value, COUNT(*) AS customers FROM subscriptions GROUP BY plan
UNION ALL
SELECT 'billing_cycle' AS dimension, billing_cycle       AS value, COUNT(*) AS customers FROM subscriptions GROUP BY billing_cycle
UNION ALL
SELECT 'company_size'  AS dimension, company_size        AS value, COUNT(*) AS customers FROM subscriptions GROUP BY company_size
UNION ALL
SELECT 'channel'       AS dimension, acquisition_channel AS value, COUNT(*) AS customers FROM subscriptions GROUP BY acquisition_channel
ORDER BY dimension, customers DESC;

-- 0.6 Numeric range check: values outside these bounds indicate load errors
SELECT
    MIN(monthly_revenue)   AS min_mrr,
    MAX(monthly_revenue)   AS max_mrr,
    MIN(nps_score)         AS min_nps,          -- expected 0-10
    MAX(nps_score)         AS max_nps,
    MIN(feature_usage_pct) AS min_usage_pct,    -- expected 0-100
    MAX(feature_usage_pct) AS max_usage_pct,
    MIN(support_tickets)   AS min_tickets,      -- expected >= 0
    MAX(support_tickets)   AS max_tickets
FROM subscriptions;


/* ============================================================================
   BUSINESS QUESTION 1
   What is the overall retention position of the customer base?
   ============================================================================ */

SELECT
    COUNT(*)                                                              AS total_customers,
    SUM(CASE WHEN is_churned = 1 THEN 1 ELSE 0 END)                       AS churned_customers,
    SUM(CASE WHEN is_churned = 0 THEN 1 ELSE 0 END)                       AS active_customers,
    ROUND(100.0 * SUM(CASE WHEN is_churned = 1 THEN 1 ELSE 0 END)
          / NULLIF(COUNT(*), 0), 2)                                       AS churn_rate_pct,
    ROUND(SUM(CASE WHEN is_churned = 0 THEN monthly_revenue ELSE 0 END), 2) AS active_mrr,
    ROUND(SUM(CASE WHEN is_churned = 1 THEN monthly_revenue ELSE 0 END), 2) AS lost_mrr
FROM subscriptions;


/* ============================================================================
   BUSINESS QUESTION 2
   Which plan tiers are losing customers fastest, and what revenue sits behind them?
   ============================================================================ */

SELECT
    plan,
    COUNT(*)                                                              AS customers,
    SUM(CASE WHEN is_churned = 1 THEN 1 ELSE 0 END)                       AS churned_customers,
    ROUND(100.0 * SUM(CASE WHEN is_churned = 1 THEN 1 ELSE 0 END)
          / NULLIF(COUNT(*), 0), 2)                                       AS churn_rate_pct,
    ROUND(AVG(monthly_revenue), 2)                                        AS avg_mrr_per_customer,
    ROUND(SUM(CASE WHEN is_churned = 1 THEN monthly_revenue ELSE 0 END), 2) AS lost_mrr
FROM subscriptions
GROUP BY plan
ORDER BY churn_rate_pct DESC;


/* ============================================================================
   BUSINESS QUESTION 3
   Does billing cadence relate to retention (monthly vs annual commitment)?
   ============================================================================ */

SELECT
    billing_cycle,
    COUNT(*)                                                              AS customers,
    SUM(CASE WHEN is_churned = 1 THEN 1 ELSE 0 END)                       AS churned_customers,
    ROUND(100.0 * SUM(CASE WHEN is_churned = 1 THEN 1 ELSE 0 END)
          / NULLIF(COUNT(*), 0), 2)                                       AS churn_rate_pct
FROM subscriptions
GROUP BY billing_cycle
ORDER BY churn_rate_pct DESC;


/* ============================================================================
   BUSINESS QUESTION 4
   Is churn concentrated in particular company sizes or regions?
   ============================================================================ */

SELECT
    company_size,
    region,
    COUNT(*)                                                              AS customers,
    ROUND(100.0 * SUM(CASE WHEN is_churned = 1 THEN 1 ELSE 0 END)
          / NULLIF(COUNT(*), 0), 2)                                       AS churn_rate_pct,
    ROUND(SUM(CASE WHEN is_churned = 1 THEN monthly_revenue ELSE 0 END), 2) AS lost_mrr
FROM subscriptions
GROUP BY company_size, region
HAVING COUNT(*) >= 20            -- minimum sample size: suppress unstable segments
ORDER BY churn_rate_pct DESC;


/* ============================================================================
   BUSINESS QUESTION 5
   Which acquisition channels deliver customers who retain, not just customers who sign?
   ============================================================================ */

WITH channel_performance AS (
    SELECT
        acquisition_channel,
        COUNT(*)                                                          AS customers,
        SUM(CASE WHEN is_churned = 1 THEN 1 ELSE 0 END)                   AS churned_customers,
        ROUND(100.0 * SUM(CASE WHEN is_churned = 1 THEN 1 ELSE 0 END)
              / NULLIF(COUNT(*), 0), 2)                                   AS churn_rate_pct,
        ROUND(AVG(cac), 2)                                                AS avg_cac,
        ROUND(SUM(CASE WHEN is_churned = 1 THEN monthly_revenue ELSE 0 END), 2) AS lost_mrr
    FROM subscriptions
    GROUP BY acquisition_channel
    HAVING COUNT(*) >= 30        -- minimum sample size for channel-level decisions
)
SELECT
    acquisition_channel,
    customers,
    churned_customers,
    churn_rate_pct,
    avg_cac,
    lost_mrr,
    RANK() OVER (ORDER BY churn_rate_pct DESC) AS churn_rank,
    RANK() OVER (ORDER BY lost_mrr      DESC) AS revenue_loss_rank
FROM channel_performance
ORDER BY revenue_loss_rank;


/* ============================================================================
   BUSINESS QUESTION 6
   Why do customers say they are leaving?
   ============================================================================ */

SELECT
    churn_reason,
    COUNT(*)                                                              AS churned_customers,
    ROUND(100.0 * COUNT(*)
          / NULLIF(SUM(COUNT(*)) OVER (), 0), 2)                          AS pct_of_churn,
    ROUND(SUM(monthly_revenue), 2)                                        AS lost_mrr
FROM subscriptions
WHERE is_churned = 1
  AND churn_reason IS NOT NULL
GROUP BY churn_reason
ORDER BY churned_customers DESC;


/* ============================================================================
   BUSINESS QUESTION 7
   How does behaviour differ between customers who stayed and customers who left?
   (Observational comparison only - it does not establish causation.)
   ============================================================================ */

SELECT
    CASE WHEN is_churned = 1 THEN 'Churned' ELSE 'Active' END             AS customer_status,
    COUNT(*)                                                              AS customers,
    ROUND(AVG(feature_usage_pct), 1)                                      AS avg_feature_usage_pct,
    ROUND(AVG(CAST(nps_score AS DECIMAL(10,2))), 1)                       AS avg_nps,
    ROUND(AVG(CAST(support_tickets AS DECIMAL(10,2))), 1)                 AS avg_support_tickets,
    ROUND(AVG(monthly_revenue), 2)                                        AS avg_mrr
FROM subscriptions
GROUP BY CASE WHEN is_churned = 1 THEN 'Churned' ELSE 'Active' END
ORDER BY customer_status;


/* ============================================================================
   BUSINESS QUESTION 8  (primary revenue question)
   Which plan + acquisition-channel segments are creating the greatest
   recurring revenue loss, and how large is each segment's share of total loss?
   ============================================================================ */

WITH segment_loss AS (
    SELECT
        plan,
        acquisition_channel,
        COUNT(*)                                                          AS customers,
        SUM(CASE WHEN is_churned = 1 THEN 1 ELSE 0 END)                   AS churned_customers,
        ROUND(100.0 * SUM(CASE WHEN is_churned = 1 THEN 1 ELSE 0 END)
              / NULLIF(COUNT(*), 0), 2)                                   AS churn_rate_pct,
        SUM(CASE WHEN is_churned = 1 THEN monthly_revenue ELSE 0 END)     AS lost_mrr
    FROM subscriptions
    GROUP BY plan, acquisition_channel
    HAVING COUNT(*) >= 15        -- minimum sample size before a segment is actioned
),
company_total AS (
    SELECT SUM(CASE WHEN is_churned = 1 THEN monthly_revenue ELSE 0 END) AS total_lost_mrr
    FROM subscriptions
)
SELECT
    s.plan,
    s.acquisition_channel,
    s.customers,
    s.churned_customers,
    s.churn_rate_pct,
    ROUND(s.lost_mrr, 2)                                                  AS lost_mrr,
    ROUND(100.0 * s.lost_mrr / NULLIF(t.total_lost_mrr, 0), 2)            AS pct_of_total_lost_mrr,
    RANK() OVER (ORDER BY s.lost_mrr DESC)                                AS loss_rank
FROM segment_loss s
CROSS JOIN company_total t
ORDER BY loss_rank;


/* ============================================================================
   BUSINESS QUESTION 9
   Which ACTIVE customers should Customer Success contact first?
   Business heuristic (not a predictive model): active AND feature usage < 40%
   AND NPS <= 4. See docs/methodology.md for the rationale and limitations.
   ============================================================================ */

-- 9.1 Size of the at-risk population and the MRR it represents
WITH risk_flagged AS (
    SELECT
        s.*,
        CASE
            WHEN is_churned = 0 AND feature_usage_pct < 40 AND nps_score <= 4 THEN 'At Risk'
            WHEN is_churned = 0 AND (feature_usage_pct < 40 OR nps_score <= 4) THEN 'Watch'
            WHEN is_churned = 0                                                THEN 'Healthy'
            ELSE 'Churned'
        END AS risk_segment
    FROM subscriptions s
)
SELECT
    risk_segment,
    COUNT(*)                                                              AS customers,
    ROUND(SUM(monthly_revenue), 2)                                        AS mrr_in_segment,
    ROUND(AVG(feature_usage_pct), 1)                                      AS avg_feature_usage_pct,
    ROUND(AVG(CAST(nps_score AS DECIMAL(10,2))), 1)                       AS avg_nps
FROM risk_flagged
WHERE risk_segment <> 'Churned'
GROUP BY risk_segment
ORDER BY mrr_in_segment DESC;

-- 9.2 Outreach worklist, highest revenue exposure first
SELECT
    customer_id,
    plan,
    billing_cycle,
    company_size,
    acquisition_channel,
    region,
    monthly_revenue,
    feature_usage_pct,
    nps_score,
    support_tickets
FROM subscriptions
WHERE is_churned = 0
  AND feature_usage_pct < 40
  AND nps_score <= 4
ORDER BY monthly_revenue DESC;


/* ============================================================================
   BUSINESS QUESTION 10
   Are the plans we are acquiring into economically worth defending?
   Estimated CLV = average MRR x average observed lifespan (months).
   Lifespan is observed only for churned customers, so CLV is a directional
   estimate, not a contractual value. PostgreSQL month difference shown;
   for SQL Server use DATEDIFF(MONTH, signup_date, churn_date).
   ============================================================================ */

WITH lifespan AS (
    SELECT
        plan,
        (EXTRACT(YEAR  FROM churn_date) - EXTRACT(YEAR  FROM signup_date)) * 12
      + (EXTRACT(MONTH FROM churn_date) - EXTRACT(MONTH FROM signup_date)) AS tenure_months
    FROM subscriptions
    WHERE is_churned = 1
      AND churn_date IS NOT NULL
),
plan_lifespan AS (
    SELECT plan, AVG(tenure_months) AS avg_lifespan_months
    FROM lifespan
    GROUP BY plan
),
plan_economics AS (
    SELECT plan, AVG(monthly_revenue) AS avg_mrr, AVG(cac) AS avg_cac
    FROM subscriptions
    GROUP BY plan
)
SELECT
    e.plan,
    ROUND(e.avg_mrr, 2)                                                   AS avg_mrr,
    ROUND(l.avg_lifespan_months, 1)                                       AS avg_lifespan_months,
    ROUND(e.avg_mrr * l.avg_lifespan_months, 2)                           AS estimated_clv,
    ROUND(e.avg_cac, 2)                                                   AS avg_cac,
    ROUND(e.avg_mrr * l.avg_lifespan_months / NULLIF(e.avg_cac, 0), 2)    AS clv_to_cac_ratio
FROM plan_economics e
JOIN plan_lifespan  l ON l.plan = e.plan
ORDER BY clv_to_cac_ratio;


/* ============================================================================
   BUSINESS QUESTION 11
   What is the monthly revenue and churn trajectory over the 48-month window?
   ============================================================================ */

SELECT
    month,
    total_mrr,
    active_customers,
    new_customers,
    churned_customers,
    ROUND(100.0 * churned_customers
          / NULLIF(active_customers + churned_customers, 0), 2)           AS monthly_churn_rate_pct,
    LAG(total_mrr) OVER (ORDER BY month)                                  AS prior_month_mrr,
    ROUND(100.0 * (total_mrr - LAG(total_mrr) OVER (ORDER BY month))
          / NULLIF(LAG(total_mrr) OVER (ORDER BY month), 0), 2)           AS mrr_growth_pct
FROM monthly_revenue
ORDER BY month;


/* ============================================================================
   SECTION 12 - RECONCILIATION HARNESS
   These figures are the published control totals. Excel and Power BI must
   return the same values before anything is shared with stakeholders.
   ============================================================================ */

SELECT 'Total Customers'   AS metric, CAST(COUNT(*) AS DECIMAL(18,2)) AS value FROM subscriptions
UNION ALL
SELECT 'Churned Customers', CAST(SUM(CASE WHEN is_churned = 1 THEN 1 ELSE 0 END) AS DECIMAL(18,2)) FROM subscriptions
UNION ALL
SELECT 'Active Customers',  CAST(SUM(CASE WHEN is_churned = 0 THEN 1 ELSE 0 END) AS DECIMAL(18,2)) FROM subscriptions
UNION ALL
SELECT 'Churn Rate %',      ROUND(100.0 * SUM(CASE WHEN is_churned = 1 THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 2) FROM subscriptions
UNION ALL
SELECT 'At-Risk Active',    CAST(SUM(CASE WHEN is_churned = 0 AND feature_usage_pct < 40 AND nps_score <= 4 THEN 1 ELSE 0 END) AS DECIMAL(18,2)) FROM subscriptions
UNION ALL
SELECT 'Lost MRR',          ROUND(SUM(CASE WHEN is_churned = 1 THEN monthly_revenue ELSE 0 END), 2) FROM subscriptions
UNION ALL
SELECT 'Active MRR',        ROUND(SUM(CASE WHEN is_churned = 0 THEN monthly_revenue ELSE 0 END), 2) FROM subscriptions;

-- End of file
