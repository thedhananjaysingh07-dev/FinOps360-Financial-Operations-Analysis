--  STEP 7 — Profitability Analysis

--  Purpose : CLV, CAC, margins, EBITDA, budget vs actual

USE finops360;

--  SECTION 1 — GROSS MARGIN ANALYSIS

-- ── 1.1 Gross Margin by Product Line & Year ──────────
SELECT
    product_line,
    fiscal_year,
    total_revenue,
    total_cogs,
    gross_profit,
    avg_gross_margin_pct,
    RANK() OVER (
        PARTITION BY fiscal_year
        ORDER BY avg_gross_margin_pct DESC
    ) AS margin_rank
FROM (
    SELECT
        p.product_line,
        t.fiscal_year,
        ROUND(SUM(t.revenue_inr), 0)        AS total_revenue,
        ROUND(SUM(t.cogs_inr), 0)           AS total_cogs,
        ROUND(SUM(t.gross_profit_inr), 0)   AS gross_profit,
        ROUND(AVG(t.gross_margin_pct), 2)   AS avg_gross_margin_pct
    FROM fact_transactions t
    JOIN dim_product p ON t.product_key = p.product_key
    GROUP BY p.product_line, t.fiscal_year
) ranked
ORDER BY fiscal_year, margin_rank;


-- ── 1.2 Gross Margin by Category ─────────────────────
SELECT
    category,
    is_recurring,
    total_revenue,
    total_cogs,
    gross_profit,
    avg_gross_margin_pct,
    ROUND(avg_gross_margin_pct - (100 - cogs_pct_std), 2) AS margin_vs_standard_pct
FROM (
    SELECT
        p.category,
        p.is_recurring,
        p.cogs_pct_std,
        ROUND(SUM(t.revenue_inr), 0)        AS total_revenue,
        ROUND(SUM(t.cogs_inr), 0)           AS total_cogs,
        ROUND(SUM(t.gross_profit_inr), 0)   AS gross_profit,
        ROUND(AVG(t.gross_margin_pct), 2)   AS avg_gross_margin_pct
    FROM fact_transactions t
    JOIN dim_product p ON t.product_key = p.product_key
    GROUP BY p.category, p.is_recurring, p.cogs_pct_std
) base
ORDER BY avg_gross_margin_pct DESC;

-- ── 1.3 Margin Trend: Quarterly ───────────────────────────────
SELECT
    fiscal_year,
    fiscal_quarter,
    ROUND(SUM(revenue_inr), 0)              AS revenue,
    ROUND(SUM(gross_profit_inr), 0)         AS gross_profit,
    ROUND(AVG(gross_margin_pct), 2)         AS avg_gross_margin_pct,
    -- QoQ margin change
    ROUND(
        AVG(gross_margin_pct)
        - LAG(AVG(gross_margin_pct)) OVER (ORDER BY fiscal_year, fiscal_quarter)
    , 2)                                    AS qoq_margin_change_pp
    -- pp = percentage points
FROM fact_transactions
GROUP BY fiscal_year, fiscal_quarter
ORDER BY fiscal_year, fiscal_quarter;


-- ============================================================
--  SECTION 2 — CUSTOMER LIFETIME VALUE (CLV)
-- ============================================================

-- ── 2.1 CLV by Plan ───────────────────────────────────────────
-- CLV = Avg MRR × Avg Gross Margin % × Avg Customer Lifetime (months)
SELECT
    c.plan,
    COUNT(DISTINCT c.customer_key)              AS customer_count,
    ROUND(AVG(c.mrr_inr), 0)                    AS avg_mrr,
    ROUND(AVG(t.gross_margin_pct), 2)           AS avg_gross_margin_pct,
    ROUND(AVG(c.expected_cltv_months), 0)       AS avg_lifetime_months,
    -- CLV Formula
    ROUND(
        AVG(c.mrr_inr)
        * (AVG(t.gross_margin_pct) / 100)
        * AVG(c.expected_cltv_months)
    , 0)                                        AS avg_clv_inr,
    -- Total CLV potential
    ROUND(
        SUM(c.mrr_inr)
        * (AVG(t.gross_margin_pct) / 100)
        * AVG(c.expected_cltv_months)
    , 0)                                        AS total_clv_potential_inr
FROM dim_customers c
JOIN fact_transactions t ON c.customer_key = t.customer_key
WHERE c.is_active = 1
GROUP BY c.plan
ORDER BY avg_clv_inr DESC;


-- ── 2.2 CLV by Segment ────────────────────────────────────────
SELECT
    c.segment,
    c.region,
    COUNT(DISTINCT c.customer_key)              AS customer_count,
    ROUND(AVG(c.mrr_inr), 0)                    AS avg_mrr,
    ROUND(AVG(t.gross_margin_pct), 2)           AS avg_gross_margin_pct,
    ROUND(AVG(c.expected_cltv_months), 0)       AS avg_lifetime_months,
    ROUND(
        AVG(c.mrr_inr)
        * (AVG(t.gross_margin_pct) / 100)
        * AVG(c.expected_cltv_months)
    , 0)                                        AS avg_clv_inr
FROM dim_customers c
JOIN fact_transactions t ON c.customer_key = t.customer_key
WHERE c.is_active = 1
GROUP BY c.segment, c.region
ORDER BY avg_clv_inr DESC;


-- ── 2.3 Top 20 Customers by CLV ───────────────────────────────
SELECT
    c.customer_id,
    c.company_name,
    c.plan,
    c.segment,
    c.industry,
    c.region,
    ROUND(c.mrr_inr, 0)                         AS mrr_inr,
    ROUND(c.arr_inr, 0)                         AS arr_inr,
    c.expected_cltv_months,
    ROUND(AVG(t.gross_margin_pct), 2)           AS avg_gross_margin_pct,
    ROUND(
        c.mrr_inr
        * (AVG(t.gross_margin_pct) / 100)
        * c.expected_cltv_months
    , 0)                                        AS estimated_clv_inr,
    c.health_status
FROM dim_customers c
JOIN fact_transactions t ON c.customer_key = t.customer_key
WHERE c.is_active = 1
GROUP BY
    c.customer_key, c.customer_id, c.company_name,
    c.plan, c.segment, c.industry, c.region,
    c.mrr_inr, c.arr_inr, c.expected_cltv_months, c.health_status
ORDER BY estimated_clv_inr DESC
LIMIT 20;


-- ============================================================
--  SECTION 3 — BUDGET vs ACTUAL (P&L ANALYSIS)
-- ============================================================

-- ── 3.1 Annual P&L Summary ────────────────────────────────────
SELECT
    fiscal_year,
    ROUND(SUM(budgeted_revenue_inr), 0)         AS total_budgeted_revenue,
    ROUND(SUM(actual_revenue_inr), 0)           AS total_actual_revenue,
    ROUND(SUM(revenue_variance_inr), 0)         AS total_revenue_variance,
    ROUND(AVG(revenue_variance_pct), 2)         AS avg_revenue_variance_pct,
    ROUND(SUM(budgeted_opex_inr), 0)            AS total_budgeted_opex,
    ROUND(SUM(actual_opex_inr), 0)              AS total_actual_opex,
    ROUND(SUM(opex_variance_inr), 0)            AS total_opex_variance,
    ROUND(SUM(budgeted_ebitda_inr), 0)          AS total_budgeted_ebitda,
    ROUND(SUM(actual_ebitda_inr), 0)            AS total_actual_ebitda,
    ROUND(
        (SUM(actual_ebitda_inr) - SUM(budgeted_ebitda_inr))
        / ABS(SUM(budgeted_ebitda_inr)) * 100
    , 2)                                        AS ebitda_variance_pct
FROM fact_budget_vs_actual
GROUP BY fiscal_year
ORDER BY fiscal_year;


-- ── 3.2 Department-Level P&L Performance ─────────────────────
SELECT
    department,
    ROUND(SUM(budgeted_revenue_inr), 0)         AS total_budgeted_revenue,
    ROUND(SUM(actual_revenue_inr), 0)           AS total_actual_revenue,
    ROUND(SUM(revenue_variance_inr), 0)         AS total_revenue_variance,
    ROUND(AVG(revenue_variance_pct), 2)         AS avg_revenue_variance_pct,
    ROUND(SUM(actual_opex_inr), 0)              AS total_actual_opex,
    ROUND(SUM(actual_ebitda_inr), 0)            AS total_actual_ebitda,
    -- Actual EBITDA Margin
    ROUND(SUM(actual_ebitda_inr)
          / NULLIF(SUM(actual_revenue_inr), 0) * 100
    , 2)                                        AS ebitda_margin_pct,
    -- Budget Attainment
    ROUND(SUM(actual_revenue_inr)
          / NULLIF(SUM(budgeted_revenue_inr), 0) * 100
    , 2)                                        AS budget_attainment_pct
FROM fact_budget_vs_actual
GROUP BY department
ORDER BY total_actual_revenue DESC;


-- ── 3.3 Monthly Budget vs Actual Variance Trend ───────────────
SELECT
    fiscal_year,
    fiscal_quarter,
    month_label,
    ROUND(SUM(budgeted_revenue_inr), 0)         AS budgeted_revenue,
    ROUND(SUM(actual_revenue_inr), 0)           AS actual_revenue,
    ROUND(SUM(revenue_variance_inr), 0)         AS revenue_variance,
    ROUND(AVG(revenue_variance_pct), 2)         AS variance_pct,
    ROUND(SUM(actual_ebitda_inr), 0)            AS actual_ebitda,
    -- Flag months that missed budget by more than 5%
    CASE
        WHEN AVG(revenue_variance_pct) < -5  THEN 'MISSED TARGET'
        WHEN AVG(revenue_variance_pct) < 0   THEN 'SLIGHTLY BELOW'
        WHEN AVG(revenue_variance_pct) < 5   THEN 'ON TARGET'
        ELSE                                      'EXCEEDED TARGET'
    END                                         AS performance_flag
FROM fact_budget_vs_actual
GROUP BY fiscal_year, fiscal_quarter, month_label, date_key
ORDER BY date_key;


-- ── 3.4 Departments that Consistently Miss Budget ─────────────
SELECT
    department,
    COUNT(*)                                            AS total_months,
    SUM(CASE WHEN revenue_variance_pct < 0 THEN 1 ELSE 0 END)  AS months_below_budget,
    SUM(CASE WHEN revenue_variance_pct >= 0 THEN 1 ELSE 0 END) AS months_above_budget,
    ROUND(
        SUM(CASE WHEN revenue_variance_pct < 0 THEN 1 ELSE 0 END)
        / COUNT(*) * 100
    , 1)                                                AS pct_months_missed,
    ROUND(AVG(revenue_variance_pct), 2)                 AS avg_variance_pct,
    ROUND(MIN(revenue_variance_pct), 2)                 AS worst_month_pct,
    ROUND(MAX(revenue_variance_pct), 2)                 AS best_month_pct
FROM fact_budget_vs_actual
GROUP BY department
ORDER BY pct_months_missed DESC;


-- ── 3.5 Headcount Efficiency ──────────────────────────────────
SELECT
    department,
    fiscal_year,
    ROUND(AVG(headcount_budget), 0)             AS avg_budgeted_headcount,
    ROUND(AVG(headcount_actual), 0)             AS avg_actual_headcount,
    ROUND(AVG(headcount_actual)
          - AVG(headcount_budget), 1)           AS headcount_variance,
    ROUND(SUM(actual_revenue_inr), 0)           AS total_revenue,
    -- Revenue per head
    ROUND(SUM(actual_revenue_inr)
          / NULLIF(AVG(headcount_actual), 0)
    , 0)                                        AS revenue_per_head_inr
FROM fact_budget_vs_actual
GROUP BY department, fiscal_year
ORDER BY department, fiscal_year;


-- ============================================================
--  SECTION 4 — EXECUTIVE PROFITABILITY SCORECARD
-- ============================================================

-- ── 4.1 Full KPI Dashboard (Single Query Summary) ────────────
SELECT
    -- Revenue KPIs
    ROUND((SELECT SUM(revenue_inr) FROM fact_transactions), 0)
                                                AS total_revenue_inr,
    ROUND((SELECT SUM(gross_profit_inr) FROM fact_transactions), 0)
                                                AS total_gross_profit_inr,
    ROUND((SELECT AVG(gross_margin_pct) FROM fact_transactions), 2)
                                                AS avg_gross_margin_pct,

    -- MRR / ARR
    ROUND((SELECT SUM(mrr_inr) FROM dim_customers WHERE is_active=1), 0)
                                                AS current_total_mrr,
    ROUND((SELECT SUM(arr_inr) FROM dim_customers WHERE is_active=1), 0)
                                                AS current_total_arr,

    -- Customer KPIs
    (SELECT COUNT(*) FROM dim_customers WHERE is_active=1)
                                                AS active_customers,
    ROUND((SELECT AVG(mrr_inr) FROM dim_customers WHERE is_active=1), 0)
                                                AS avg_mrr_per_customer,

    -- Churn KPIs
    ROUND((SELECT COUNT(*) FROM fact_churn)
          / (SELECT COUNT(*) FROM dim_customers) * 100, 2)
                                                AS overall_churn_rate_pct,
    ROUND((SELECT SUM(mrr_at_churn_inr) FROM fact_churn), 0)
                                                AS total_mrr_lost_to_churn,
    ROUND((SELECT AVG(days_to_churn) FROM fact_churn), 0)
                                                AS avg_days_to_churn,

    -- Health KPIs
    (SELECT COUNT(*) FROM dim_customers WHERE health_status='Critical' AND is_active=1)
                                                AS critical_health_customers,
    (SELECT COUNT(*) FROM dim_customers WHERE health_status='At Risk' AND is_active=1)
                                                AS at_risk_customers,

    -- Budget Performance
    ROUND((SELECT AVG(revenue_variance_pct) FROM fact_budget_vs_actual), 2)
                                                AS avg_budget_variance_pct;


 

select count(*) from dim_customers;
SELECT COUNT(*) FROM fact_transactions;
SELECT COUNT(*) FROM fact_churn;
SELECT COUNT(*) FROM fact_budget_vs_actual;
SELECT COUNT(*) FROM dim_date;
select count(*) from dim_product;

show tables from finops360; 

SELECT COUNT(*) FROM stg_customers;
SELECT COUNT(*) FROM stg_transactions;
SELECT COUNT(*) FROM stg_churn;
SELECT COUNT(*) FROM stg_budget;

select * from dim_customers;
SELECT * FROM fact_transactions;
SELECT * FROM fact_churn;
SELECT * FROM fact_budget_vs_actual;
SELECT * FROM dim_date;
select * from dim_product;