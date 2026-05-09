USE finops360;

-- ============================================================
--  SECTION 1 — NULL & MISSING VALUE CHECKS
-- ============================================================

-- ── 1.1 Check NULLs in dim_customers ─────────────────────────
SELECT
    SUM(CASE WHEN customer_id           IS NULL THEN 1 ELSE 0 END) AS null_customer_id,
    SUM(CASE WHEN company_name          IS NULL THEN 1 ELSE 0 END) AS null_company_name,
    SUM(CASE WHEN plan                  IS NULL THEN 1 ELSE 0 END) AS null_plan,
    SUM(CASE WHEN segment               IS NULL THEN 1 ELSE 0 END) AS null_segment,
    SUM(CASE WHEN acquisition_date      IS NULL THEN 1 ELSE 0 END) AS null_acquisition_date,
    SUM(CASE WHEN mrr_inr               IS NULL THEN 1 ELSE 0 END) AS null_mrr,
    SUM(CASE WHEN health_score          IS NULL THEN 1 ELSE 0 END) AS null_health_score,
    SUM(CASE WHEN csm_owner             IS NULL THEN 1 ELSE 0 END) AS null_csm_owner
FROM dim_customers;
-- Expected: All zeros


-- ── 1.2 Check NULLs in fact_transactions ─────────────────────
SELECT
    SUM(CASE WHEN transaction_id    IS NULL THEN 1 ELSE 0 END) AS null_txn_id,
    SUM(CASE WHEN customer_key      IS NULL THEN 1 ELSE 0 END) AS null_customer_key,
    SUM(CASE WHEN date_key          IS NULL THEN 1 ELSE 0 END) AS null_date_key,
    SUM(CASE WHEN revenue_inr       IS NULL THEN 1 ELSE 0 END) AS null_revenue,
    SUM(CASE WHEN cogs_inr          IS NULL THEN 1 ELSE 0 END) AS null_cogs,
    SUM(CASE WHEN gross_profit_inr  IS NULL THEN 1 ELSE 0 END) AS null_gross_profit,
    SUM(CASE WHEN payment_status    IS NULL THEN 1 ELSE 0 END) AS null_payment_status
FROM fact_transactions;
-- Expected: All zeros


-- ── 1.3 Check NULLs in fact_churn ────────────────────────────
SELECT
    SUM(CASE WHEN customer_key          IS NULL THEN 1 ELSE 0 END) AS null_customer_key,
    SUM(CASE WHEN churn_date_key        IS NULL THEN 1 ELSE 0 END) AS null_churn_date,
    SUM(CASE WHEN mrr_at_churn_inr      IS NULL THEN 1 ELSE 0 END) AS null_mrr_at_churn,
    SUM(CASE WHEN churn_reason          IS NULL THEN 1 ELSE 0 END) AS null_churn_reason,
    SUM(CASE WHEN days_to_churn         IS NULL THEN 1 ELSE 0 END) AS null_days_to_churn
FROM fact_churn;
-- Expected: All zeros


-- ============================================================
--  SECTION 2 — DUPLICATE CHECKS
-- ============================================================

-- ── 2.1 Duplicate CustomerIDs ────────────────────────────────
SELECT
    customer_id,
    COUNT(*) AS occurrences
FROM dim_customers
GROUP BY customer_id
HAVING COUNT(*) > 1;
-- Expected: 0 rows


-- ── 2.2 Duplicate TransactionIDs ─────────────────────────────
SELECT
    transaction_id,
    COUNT(*) AS occurrences
FROM fact_transactions
GROUP BY transaction_id
HAVING COUNT(*) > 1;
-- Expected: 0 rows


-- ── 2.3 Duplicate Churn entries per customer ─────────────────
SELECT
    customer_key,
    COUNT(*) AS occurrences
FROM fact_churn
GROUP BY customer_key
HAVING COUNT(*) > 1;
-- Expected: 0 rows (each customer can only churn once)


-- ── 2.4 Duplicate Budget rows (same period + department) ─────
SELECT
    date_key,
    department,
    COUNT(*) AS occurrences
FROM fact_budget_vs_actual
GROUP BY date_key, department
HAVING COUNT(*) > 1;
-- Expected: 0 rows


-- ============================================================
--  SECTION 3 — REFERENTIAL INTEGRITY CHECKS
-- ============================================================

-- ── 3.1 Transactions with invalid date_key ───────────────────
SELECT COUNT(*) AS orphan_txn_dates
FROM fact_transactions t
LEFT JOIN dim_date d ON t.date_key = d.date_key
WHERE d.date_key IS NULL;
-- Expected: 0


-- ── 3.2 Churn records with invalid date_keys ─────────────────
SELECT COUNT(*) AS orphan_churn_dates
FROM fact_churn c
LEFT JOIN dim_date d ON c.churn_date_key = d.date_key
WHERE d.date_key IS NULL;
-- Expected: 0


-- ── 3.3 Budget rows with invalid date_key ────────────────────
SELECT COUNT(*) AS orphan_budget_dates
FROM fact_budget_vs_actual b
LEFT JOIN dim_date d ON b.date_key = d.date_key
WHERE d.date_key IS NULL;
-- Expected: 0


-- ============================================================
--  SECTION 4 — BUSINESS LOGIC VALIDATION
-- ============================================================

-- ── 4.1 Revenue must be positive ─────────────────────────────
SELECT COUNT(*) AS negative_revenue_rows
FROM fact_transactions
WHERE revenue_inr <= 0;
-- Expected: 0


-- ── 4.2 COGS must not exceed Revenue ─────────────────────────
SELECT COUNT(*) AS cogs_exceeds_revenue
FROM fact_transactions
WHERE cogs_inr > revenue_inr;
-- Flag any rows where COGS > Revenue (loss-making transactions)


-- ── 4.3 Gross Profit = Revenue - COGS validation ─────────────
SELECT COUNT(*) AS gross_profit_mismatch
FROM fact_transactions
WHERE ABS(gross_profit_inr - (revenue_inr - cogs_inr)) > 1;
-- Tolerance of ₹1 for rounding. Expected: 0


-- ── 4.4 ARR must equal MRR × 12 ──────────────────────────────
SELECT COUNT(*) AS arr_mrr_mismatch
FROM dim_customers
WHERE ABS(arr_inr - (mrr_inr * 12)) > 1;
-- Expected: 0


-- ── 4.5 Health Score must be between 0 and 100 ───────────────
SELECT COUNT(*) AS invalid_health_scores
FROM dim_customers
WHERE health_score < 0 OR health_score > 100;
-- Expected: 0


-- ── 4.6 Churn date must be after Acquisition date ────────────
SELECT COUNT(*) AS churn_before_acquisition
FROM fact_churn ch
JOIN dim_customers c ON ch.customer_key = c.customer_key
JOIN dim_date acq    ON ch.acquisition_date_key = acq.date_key
JOIN dim_date chd    ON ch.churn_date_key       = chd.date_key
WHERE chd.full_date <= acq.full_date;
-- Expected: 0


-- ── 4.7 Days to churn must be positive ───────────────────────
SELECT COUNT(*) AS invalid_days_to_churn
FROM fact_churn
WHERE days_to_churn <= 0;
-- Expected: 0


-- ── 4.8 NPS Score range check (-100 to +100) ─────────────────
SELECT COUNT(*) AS invalid_nps
FROM dim_customers
WHERE nps_score < -100 OR nps_score > 100;
-- Expected: 0


-- ── 4.9 Budget variance recalculation check ──────────────────
SELECT COUNT(*) AS variance_mismatch
FROM fact_budget_vs_actual
WHERE ABS(revenue_variance_inr - (actual_revenue_inr - budgeted_revenue_inr)) > 1;
-- Expected: 0


-- ============================================================
--  SECTION 5 — DISTRIBUTION & OUTLIER CHECKS
-- ============================================================

-- ── 5.1 MRR distribution by Plan ─────────────────────────────
SELECT
    plan,
    COUNT(*)                        AS customer_count,
    ROUND(MIN(mrr_inr), 0)          AS min_mrr,
    ROUND(AVG(mrr_inr), 0)          AS avg_mrr,
    ROUND(MAX(mrr_inr), 0)          AS max_mrr,
    ROUND(SUM(mrr_inr), 0)          AS total_mrr,
    ROUND(SUM(mrr_inr) * 12, 0)     AS total_arr
FROM dim_customers
GROUP BY plan
ORDER BY avg_mrr;


-- ── 5.2 Transaction count and revenue by Category ────────────
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

desc fact_transactions;
-- ── 5.3 Churn distribution by Reason ─────────────────────────
SELECT
    churn_reason,
    COUNT(*)                                AS churned_customers,
    ROUND(SUM(mrr_at_churn_inr), 0)         AS total_mrr_lost,
    ROUND(AVG(days_to_churn), 0)            AS avg_days_to_churn,
    ROUND(AVG(last_health_score), 1)        AS avg_last_health_score
FROM fact_churn
GROUP BY churn_reason
ORDER BY total_mrr_lost DESC;


-- ── 5.4 Revenue outliers (top 10 transactions) ───────────────
SELECT
    t.transaction_id,
    c.company_name,
    p.category,          -- Changed prefix to 'p'
    p.product_line,      -- Changed prefix to 'p'
    t.fiscal_year,
    ROUND(t.revenue_inr, 2)         AS revenue_inr,
    ROUND(t.gross_margin_pct, 2)    AS gross_margin_pct
FROM fact_transactions t
JOIN dim_customers c ON t.customer_key = c.customer_key
JOIN dim_product   p ON t.product_key  = p.product_key -- Added this join
ORDER BY t.revenue_inr DESC
LIMIT 10;


-- ── 5.5 Customers with unusually high support tickets ────────
SELECT
    customer_id,
    company_name,
    plan,
    health_status,
    support_tickets_90d,
    health_score
FROM dim_customers
WHERE support_tickets_90d >= 10
ORDER BY support_tickets_90d DESC;


-- ============================================================
--  SECTION 6 — DATA QUALITY SUMMARY SCORECARD
-- ============================================================

SELECT 'dim_customers'          AS table_name,
       COUNT(*)                 AS total_rows,
       SUM(CASE WHEN acquisition_date IS NULL THEN 1 ELSE 0 END) AS critical_nulls,
       0                        AS duplicates
FROM dim_customers

UNION ALL

SELECT 'fact_transactions',
       COUNT(*),
       SUM(CASE WHEN revenue_inr IS NULL OR revenue_inr <= 0 THEN 1 ELSE 0 END),
       (SELECT COUNT(*) FROM (
           SELECT transaction_id FROM fact_transactions
           GROUP BY transaction_id HAVING COUNT(*) > 1
       ) x)
FROM fact_transactions

UNION ALL

SELECT 'fact_churn',
       COUNT(*),
       SUM(CASE WHEN churn_date_key IS NULL THEN 1 ELSE 0 END),
       (SELECT COUNT(*) FROM (
           SELECT customer_key FROM fact_churn
           GROUP BY customer_key HAVING COUNT(*) > 1
       ) x)
FROM fact_churn

UNION ALL

SELECT 'fact_budget_vs_actual',
       COUNT(*),
       SUM(CASE WHEN actual_revenue_inr IS NULL THEN 1 ELSE 0 END),
       (SELECT COUNT(*) FROM (
           SELECT date_key, department FROM fact_budget_vs_actual
           GROUP BY date_key, department HAVING COUNT(*) > 1
       ) x)
FROM fact_budget_vs_actual;

/*
  A clean dataset should show:
  ┌──────────────────────┬────────────┬────────────────┬────────────┐
  │ table_name           │ total_rows │ critical_nulls │ duplicates │
  ├──────────────────────┼────────────┼────────────────┼────────────┤
  │ dim_customers        │    1200    │       0        │     0      │
  │ fact_transactions    │    5000    │       0        │     0      │
  │ fact_churn           │     210    │       0        │     0      │
  │ fact_budget_vs_actual│     216    │       0        │     0      │
  └──────────────────────┴────────────┴────────────────┴────────────┘
*/

