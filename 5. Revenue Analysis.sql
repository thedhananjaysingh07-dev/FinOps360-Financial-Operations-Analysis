#Purpose: MRR,ARR,Growth Trends, Segmentation Analysis

USE finops360;
-- ============================================================
--  SECTION 1 — TOTAL REVENUE SUMMARY
-- ============================================================

-- ── 1.1 Overall Revenue KPIs ─────────────────────────────────
SELECT
    ROUND(SUM(revenue_inr), 0)                              AS total_revenue_inr,
    ROUND(SUM(cogs_inr), 0)                                 AS total_cogs_inr,
    ROUND(SUM(gross_profit_inr), 0)                         AS total_gross_profit_inr,
    ROUND(AVG(gross_margin_pct), 2)                         AS avg_gross_margin_pct,
    COUNT(DISTINCT transaction_id)                          AS total_transactions,
    COUNT(DISTINCT customer_key)                            AS unique_customers_billed,
    ROUND(SUM(revenue_inr) / COUNT(DISTINCT customer_key), 0) AS avg_revenue_per_customer
FROM fact_transactions;


-- ── 1.2 Annual Revenue Summary (YoY) ─────────────────────────
SELECT
    fiscal_year,
    ROUND(SUM(revenue_inr), 0)              AS total_revenue_inr,
    ROUND(SUM(gross_profit_inr), 0)         AS total_gross_profit_inr,
    ROUND(AVG(gross_margin_pct), 2)         AS avg_gross_margin_pct,
    COUNT(DISTINCT transaction_id)          AS total_transactions,
    COUNT(DISTINCT customer_key)            AS unique_customers,
    -- YoY Growth (window function)
    ROUND(
        (SUM(revenue_inr) - LAG(SUM(revenue_inr)) OVER (ORDER BY fiscal_year))
        / LAG(SUM(revenue_inr)) OVER (ORDER BY fiscal_year) * 100
    , 2)                                    AS yoy_revenue_growth_pct
FROM fact_transactions
GROUP BY fiscal_year
ORDER BY fiscal_year;


-- ── 1.3 Quarterly Revenue Trend ──────────────────────────────
SELECT
    fiscal_year,
    fiscal_quarter,
    CONCAT(fiscal_year, '-', fiscal_quarter)    AS year_quarter,
    ROUND(SUM(revenue_inr), 0)                  AS quarterly_revenue,
    ROUND(SUM(gross_profit_inr), 0)             AS quarterly_gross_profit,
    ROUND(AVG(gross_margin_pct), 2)             AS avg_gross_margin_pct,
    COUNT(DISTINCT customer_key)                AS unique_customers,
    -- QoQ Growth
    ROUND(
        (SUM(revenue_inr) - LAG(SUM(revenue_inr)) OVER (ORDER BY fiscal_year, fiscal_quarter))
        / LAG(SUM(revenue_inr)) OVER (ORDER BY fiscal_year, fiscal_quarter) * 100
    , 2)                                        AS qoq_growth_pct
FROM fact_transactions
GROUP BY fiscal_year, fiscal_quarter
ORDER BY fiscal_year, fiscal_quarter;


-- ── 1.4 Monthly Revenue Trend with Running Total ─────────────
SELECT
    t.fiscal_year,                             -- Explicitly defined source
    t.fiscal_month,                            -- Explicitly defined source
    d.month_num,
    ROUND(SUM(t.revenue_inr), 0)                AS monthly_revenue,
    ROUND(SUM(t.gross_profit_inr), 0)           AS monthly_gross_profit,
    -- Running total within year
    ROUND(SUM(SUM(t.revenue_inr)) OVER (
        PARTITION BY t.fiscal_year
        ORDER BY d.month_num
        ROWS UNBOUNDED PRECEDING
    ), 0)                                       AS ytd_revenue,
    -- MoM Growth
    ROUND(
        (SUM(t.revenue_inr) - LAG(SUM(t.revenue_inr)) OVER (ORDER BY t.fiscal_year, d.month_num))
        / LAG(SUM(t.revenue_inr)) OVER (ORDER BY t.fiscal_year, d.month_num) * 100
    , 2)                                        AS mom_growth_pct
FROM fact_transactions t
JOIN dim_date d ON t.date_key = d.date_key
GROUP BY t.fiscal_year, t.fiscal_month, d.month_num
ORDER BY t.fiscal_year, d.month_num;


-- ============================================================
--  SECTION 2 — MRR & ARR ANALYSIS
-- ============================================================

-- ── 2.1 Total MRR & ARR from Customer Master ─────────────────
SELECT
    plan,
    COUNT(*)                                AS customer_count,
    ROUND(SUM(mrr_inr), 0)                  AS total_mrr_inr,
    ROUND(SUM(arr_inr), 0)                  AS total_arr_inr,
    ROUND(AVG(mrr_inr), 0)                  AS avg_mrr_per_customer,
    ROUND(SUM(mrr_inr) / SUM(SUM(mrr_inr)) OVER () * 100, 2) AS mrr_contribution_pct
FROM dim_customers
WHERE is_active = 1
GROUP BY plan
ORDER BY total_mrr_inr DESC;


-- ── 2.2 MRR by Segment and Region ────────────────────────────
SELECT
    segment,
    region,
    COUNT(*)                    AS customer_count,
    ROUND(SUM(mrr_inr), 0)      AS total_mrr,
    ROUND(AVG(mrr_inr), 0)      AS avg_mrr,
    ROUND(SUM(arr_inr), 0)      AS total_arr
FROM dim_customers
WHERE is_active = 1
GROUP BY segment, region
ORDER BY segment, total_mrr DESC;


-- ── 2.3 MRR Concentration — Top 20% Customers (Pareto) ───────
WITH ranked_customers AS (
    SELECT
        customer_id,
        company_name,
        plan,
        segment,
        mrr_inr,
        ROUND(mrr_inr / SUM(mrr_inr) OVER () * 100, 4)     AS mrr_share_pct,
        ROUND(SUM(mrr_inr) OVER (ORDER BY mrr_inr DESC
              ROWS UNBOUNDED PRECEDING)
              / SUM(mrr_inr) OVER () * 100, 2)              AS cumulative_mrr_pct,
        NTILE(5) OVER (ORDER BY mrr_inr DESC)               AS quintile
    FROM dim_customers
    WHERE is_active = 1
)
SELECT
    quintile,
    COUNT(*)                        AS customers_in_quintile,
    ROUND(SUM(mrr_inr), 0)          AS total_mrr,
    ROUND(AVG(mrr_share_pct), 4)    AS avg_mrr_share_pct,
    ROUND(SUM(mrr_inr) / SUM(SUM(mrr_inr)) OVER () * 100, 2) AS quintile_mrr_pct
FROM ranked_customers
GROUP BY quintile
ORDER BY quintile;
-- Quintile 1 = top 20% customers. Expect ~60-70% of MRR (Pareto principle)


-- ============================================================
--  SECTION 3 — REVENUE BY SEGMENT & INDUSTRY
-- ============================================================

-- ── 3.1 Revenue by Customer Segment ──────────────────────────
SELECT
    t.segment,
    COUNT(DISTINCT t.customer_key)              AS unique_customers,
    COUNT(t.transaction_id)                     AS total_transactions,
    ROUND(SUM(t.revenue_inr), 0)                AS total_revenue,
    ROUND(SUM(t.gross_profit_inr), 0)           AS total_gross_profit,
    ROUND(AVG(t.gross_margin_pct), 2)           AS avg_gross_margin_pct,
    ROUND(SUM(t.revenue_inr)
          / SUM(SUM(t.revenue_inr)) OVER () * 100, 2) AS revenue_share_pct
FROM fact_transactions t
GROUP BY t.segment
ORDER BY total_revenue DESC;


-- ── 3.2 Revenue by Industry ───────────────────────────────────
SELECT
    c.industry,
    COUNT(DISTINCT t.customer_key)              AS unique_customers,
    ROUND(SUM(t.revenue_inr), 0)                AS total_revenue,
    ROUND(AVG(t.gross_margin_pct), 2)           AS avg_gross_margin_pct,
    ROUND(SUM(t.revenue_inr)
          / SUM(SUM(t.revenue_inr)) OVER () * 100, 2) AS revenue_share_pct
FROM fact_transactions t
JOIN dim_customers c ON t.customer_key = c.customer_key
GROUP BY c.industry
ORDER BY total_revenue DESC;


-- ── 3.3 Revenue by Region ─────────────────────────────────────
SELECT
    t.region,
    fiscal_year,
    ROUND(SUM(t.revenue_inr), 0)                AS total_revenue,
    ROUND(SUM(t.gross_profit_inr), 0)           AS gross_profit,
    ROUND(AVG(t.gross_margin_pct), 2)           AS avg_margin_pct,
    COUNT(DISTINCT t.customer_key)              AS unique_customers
FROM fact_transactions t
GROUP BY t.region, fiscal_year
ORDER BY t.region, fiscal_year;


-- ============================================================
--  SECTION 4 — REVENUE BY PRODUCT LINE & CATEGORY
-- ============================================================
describe fact_transactions;
-- ── 4.1 Revenue by Product Line ───────────────────────────────
SELECT
    p.product_line,                              -- Changed alias to 'p'
    COUNT(t.transaction_id)                     AS total_transactions,
    ROUND(SUM(t.revenue_inr), 0)                AS total_revenue,
    ROUND(SUM(t.cogs_inr), 0)                   AS total_cogs,
    ROUND(SUM(t.gross_profit_inr), 0)           AS total_gross_profit,
    ROUND(AVG(t.gross_margin_pct), 2)           AS avg_gross_margin_pct,
    ROUND(SUM(t.revenue_inr)
          / SUM(SUM(t.revenue_inr)) OVER () * 100, 2) AS revenue_share_pct
FROM fact_transactions t
JOIN dim_product p ON t.product_key = p.product_key -- Joining the dimension table
GROUP BY p.product_line
ORDER BY total_revenue DESC;


-- ── 4.2 Revenue Mix: Recurring vs Non-Recurring ───────────────
SELECT
    p.product_group,
    CASE WHEN p.is_recurring = 1 THEN 'Recurring' ELSE 'Non-Recurring' END AS revenue_type,
    COUNT(t.transaction_id)                 AS total_transactions,
    ROUND(SUM(t.revenue_inr), 0)            AS total_revenue,
    ROUND(SUM(t.revenue_inr)
          / SUM(SUM(t.revenue_inr)) OVER () * 100, 2) AS revenue_share_pct
FROM fact_transactions t
JOIN dim_product p ON t.product_key = p.product_key
GROUP BY p.product_group, p.is_recurring
ORDER BY total_revenue DESC;


-- ── 4.3 Category Revenue Heatmap by Year ─────────────────────
SELECT
    p.product_line,
    COUNT(t.transaction_id)                     AS total_transactions,
    ROUND(SUM(t.revenue_inr), 0)                AS total_revenue,
    ROUND(SUM(t.cogs_inr), 0)                   AS total_cogs,
    ROUND(SUM(t.gross_profit_inr), 0)           AS total_gross_profit,
    -- Double check if gross_margin_pct is in 't'. 
    -- If not, it might be a calculation: (gross_profit/revenue)
    ROUND(AVG(t.gross_margin_pct), 2)           AS avg_gross_margin_pct,
    ROUND(SUM(t.revenue_inr)
          / SUM(SUM(t.revenue_inr)) OVER () * 100, 2) AS revenue_share_pct
FROM fact_transactions t
JOIN dim_product p ON t.product_key = p.product_key
GROUP BY p.product_line
ORDER BY total_revenue DESC;


-- ============================================================
--  SECTION 5 — REVENUE FORECASTING BASE
-- ============================================================

-- ── 5.1 3-Month Rolling Average Revenue ──────────────────────
WITH monthly_revenue AS (
    SELECT
        t.fiscal_year,
        d.month_num,
        t.fiscal_month,
        ROUND(SUM(t.revenue_inr), 0) AS monthly_revenue
    FROM fact_transactions t
    JOIN dim_date d ON t.date_key = d.date_key
    GROUP BY t.fiscal_year, d.month_num, t.fiscal_month
)
SELECT
    fiscal_year,
    month_num,
    fiscal_month,
    monthly_revenue,
    ROUND(AVG(monthly_revenue) OVER (
        ORDER BY fiscal_year, month_num
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ), 0)                           AS rolling_3m_avg,
    ROUND(AVG(monthly_revenue) OVER (
        ORDER BY fiscal_year, month_num
        ROWS BETWEEN 5 PRECEDING AND CURRENT ROW
    ), 0)                           AS rolling_6m_avg
FROM monthly_revenue
ORDER BY fiscal_year, month_num;


-- ── 5.2 Seasonality Index by Month ───────────────────────────
-- Identifies which months over/underperform vs annual average
WITH monthly_avg AS (
    SELECT
        d.month_num,
        d.month_short,
        ROUND(AVG(monthly_rev), 0)  AS avg_monthly_revenue
    FROM (
        SELECT
            t.date_key,
            ROUND(SUM(t.revenue_inr), 0) AS monthly_rev
        FROM fact_transactions t
        JOIN dim_date d ON t.date_key = d.date_key
        GROUP BY t.fiscal_year, d.month_num, t.date_key
    ) sub
    JOIN dim_date d ON sub.date_key = d.date_key
    GROUP BY d.month_num, d.month_short
),
overall_avg AS (
    SELECT ROUND(AVG(avg_monthly_revenue), 0) AS grand_avg
    FROM monthly_avg
)
SELECT
    m.month_num,
    m.month_short,
    m.avg_monthly_revenue,
    ROUND(m.avg_monthly_revenue / o.grand_avg, 4) AS seasonality_index
    -- > 1.0 = above average month, < 1.0 = below average month
FROM monthly_avg m
CROSS JOIN overall_avg o
ORDER BY m.month_num;


-- ── 5.3 Year-over-Year Revenue Bridge ────────────────────────
-- Shows how much revenue changed from 2022→2023 and 2023→2024
WITH yearly AS (
    SELECT
        fiscal_year,
        ROUND(SUM(revenue_inr), 0) AS total_revenue
    FROM fact_transactions
    GROUP BY fiscal_year
)
SELECT
    y1.fiscal_year                              AS from_year,
    y2.fiscal_year                              AS to_year,
    y1.total_revenue                            AS from_revenue,
    y2.total_revenue                            AS to_revenue,
    ROUND(y2.total_revenue - y1.total_revenue, 0) AS absolute_change,
    ROUND((y2.total_revenue - y1.total_revenue)
          / y1.total_revenue * 100, 2)          AS growth_pct
FROM yearly y1
JOIN yearly y2 ON y2.fiscal_year = y1.fiscal_year + 1
ORDER BY from_year;


-- ── 5.4 Simple Trend Forecast: FY2025 Projection ─────────────
-- Uses average YoY growth rate to project next year
WITH yearly AS (
    SELECT
        fiscal_year,
        SUM(revenue_inr) AS total_revenue
    FROM fact_transactions
    GROUP BY fiscal_year
),
growth_rates AS (
    SELECT
        fiscal_year,
        total_revenue,
        (total_revenue - LAG(total_revenue) OVER (ORDER BY fiscal_year))
        / LAG(total_revenue) OVER (ORDER BY fiscal_year) AS yoy_growth
    FROM yearly
)
SELECT
    'FY2025 Forecast (Avg Growth)'          AS scenario,
    ROUND(MAX(total_revenue)
          * (1 + AVG(yoy_growth)), 0)       AS projected_revenue_inr,
    ROUND(AVG(yoy_growth) * 100, 2)         AS avg_growth_rate_used_pct
FROM growth_rates
WHERE yoy_growth IS NOT NULL;


-- ============================================================
--  SECTION 6 — PAYMENT STATUS & COLLECTIONS ANALYSIS
-- ============================================================

-- ── 6.1 Revenue by Payment Status ────────────────────────────
SELECT
    payment_status,
    COUNT(*)                            AS transaction_count,
    ROUND(SUM(revenue_inr), 0)          AS total_revenue,
    ROUND(AVG(revenue_inr), 0)          AS avg_transaction_value,
    ROUND(SUM(revenue_inr)
          / SUM(SUM(revenue_inr)) OVER () * 100, 2) AS revenue_share_pct
FROM fact_transactions
GROUP BY payment_status
ORDER BY total_revenue DESC;


-- ── 6.2 Overdue Revenue by Region ────────────────────────────
SELECT
    region,
    COUNT(*)                        AS overdue_transactions,
    ROUND(SUM(revenue_inr), 0)      AS overdue_revenue_at_risk,
    ROUND(AVG(revenue_inr), 0)      AS avg_overdue_amount
FROM fact_transactions
WHERE payment_status = 'Overdue'
GROUP BY region
ORDER BY overdue_revenue_at_risk DESC;


