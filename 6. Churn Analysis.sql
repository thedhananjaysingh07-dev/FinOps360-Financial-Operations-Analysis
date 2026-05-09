--  STEP 6 — Churn & Retention Analysis

--  Purpose : Churn rate, cohort retention, risk segmentation

USE finops360;


-- ============================================================
--  SECTION 1 — OVERALL CHURN KPIs
-- ============================================================

-- ── 1.1 High-Level Churn Summary ─────────────────────────────
SELECT
    (SELECT COUNT(*) FROM dim_customers)            AS total_customers,
    (SELECT COUNT(*) FROM fact_churn)               AS total_churned,
    (SELECT COUNT(*) FROM dim_customers
     WHERE is_active = 1)                           AS active_customers,
    ROUND(
        (SELECT COUNT(*) FROM fact_churn)
        / (SELECT COUNT(*) FROM dim_customers) * 100
    , 2)                                            AS overall_churn_rate_pct,
    ROUND(
        (SELECT SUM(mrr_at_churn_inr) FROM fact_churn)
        / (SELECT SUM(mrr_inr) FROM dim_customers) * 100
    , 2)                                            AS mrr_churn_rate_pct,
    ROUND(
        (SELECT SUM(mrr_at_churn_inr) FROM fact_churn)
    , 0)                                            AS total_mrr_lost_inr,
    ROUND(
        (SELECT AVG(days_to_churn) FROM fact_churn)
    , 0)                                            AS avg_days_to_churn;


-- ── 1.2 Annual Churn Rate ─────────────────────────────────────
SELECT
    d.fiscal_year,
    COUNT(ch.churn_key)                             AS churned_customers,
    ROUND(SUM(ch.mrr_at_churn_inr), 0)              AS mrr_lost_inr,
    ROUND(AVG(ch.days_to_churn), 0)                 AS avg_days_to_churn,
    ROUND(AVG(ch.last_health_score), 1)             AS avg_health_score_at_churn,
    -- Churn rate = churned / total customers that year
    ROUND(COUNT(ch.churn_key)
          / (SELECT COUNT(*) FROM dim_customers) * 100
    , 2)                                            AS churn_rate_pct
FROM fact_churn ch
JOIN dim_date d ON ch.churn_date_key = d.date_key
GROUP BY d.fiscal_year
ORDER BY d.fiscal_year;


-- ── 1.3 Monthly Churn Trend ───────────────────────────────────
SELECT
    d.fiscal_year,
    d.month_num,
    d.fiscal_month_label                            AS churn_month,
    COUNT(ch.churn_key)                             AS churned_customers,
    ROUND(SUM(ch.mrr_at_churn_inr), 0)              AS mrr_lost_inr,
    -- Rolling 3-month average churn
    ROUND(AVG(COUNT(ch.churn_key)) OVER (
        ORDER BY d.fiscal_year, d.month_num
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ), 1)                                           AS rolling_3m_avg_churn
FROM fact_churn ch
JOIN dim_date d ON ch.churn_date_key = d.date_key
GROUP BY d.fiscal_year, d.month_num, d.fiscal_month_label
ORDER BY d.fiscal_year, d.month_num;


-- ============================================================
--  SECTION 2 — CHURN BY DIMENSION
-- ============================================================

-- ── 2.1 Churn by Plan ─────────────────────────────────────────
SELECT
    ch.plan,
    COUNT(ch.churn_key)                             AS churned_customers,
    ROUND(SUM(ch.mrr_at_churn_inr), 0)              AS total_mrr_lost,
    ROUND(AVG(ch.mrr_at_churn_inr), 0)              AS avg_mrr_at_churn,
    ROUND(AVG(ch.days_to_churn), 0)                 AS avg_days_to_churn,
    ROUND(AVG(ch.last_health_score), 1)             AS avg_health_score,
    -- Churn rate within plan
    ROUND(COUNT(ch.churn_key)
          / (SELECT COUNT(*) FROM dim_customers c2
             WHERE c2.plan = ch.plan) * 100
    , 2)                                            AS plan_churn_rate_pct
FROM fact_churn ch
GROUP BY ch.plan
ORDER BY total_mrr_lost DESC;


-- ── 2.2 Churn by Segment ──────────────────────────────────────
SELECT
    ch.segment,
    COUNT(ch.churn_key)                             AS churned_customers,
    ROUND(SUM(ch.mrr_at_churn_inr), 0)              AS total_mrr_lost,
    ROUND(AVG(ch.days_to_churn), 0)                 AS avg_days_to_churn,
    ROUND(AVG(ch.last_health_score), 1)             AS avg_last_health_score,
    ROUND(COUNT(ch.churn_key)
          / (SELECT COUNT(*) FROM dim_customers c2
             WHERE c2.segment = ch.segment) * 100
    , 2)                                            AS segment_churn_rate_pct
FROM fact_churn ch
GROUP BY ch.segment
ORDER BY total_mrr_lost DESC;


-- ── 2.3 Churn by Region ───────────────────────────────────────
SELECT
    ch.region,
    COUNT(ch.churn_key)                             AS churned_customers,
    ROUND(SUM(ch.mrr_at_churn_inr), 0)              AS total_mrr_lost,
    ROUND(AVG(ch.days_to_churn), 0)                 AS avg_days_to_churn,
    ROUND(COUNT(ch.churn_key)
          / (SELECT COUNT(*) FROM dim_customers c2
             WHERE c2.region = ch.region) * 100
    , 2)                                            AS region_churn_rate_pct
FROM fact_churn ch
GROUP BY ch.region
ORDER BY total_mrr_lost DESC;


-- ── 2.4 Churn by Reason ───────────────────────────────────────
SELECT
    ch.churn_reason,
    ch.churn_type,
    COUNT(ch.churn_key)                             AS churned_customers,
    ROUND(SUM(ch.mrr_at_churn_inr), 0)              AS total_mrr_lost,
    ROUND(AVG(ch.mrr_at_churn_inr), 0)              AS avg_mrr_at_churn,
    ROUND(AVG(ch.days_to_churn), 0)                 AS avg_days_to_churn,
    ROUND(AVG(ch.last_health_score), 1)             AS avg_last_health_score,
    SUM(ch.win_back_eligible)                       AS win_back_eligible_count
FROM fact_churn ch
GROUP BY ch.churn_reason, ch.churn_type
ORDER BY total_mrr_lost DESC;


-- ── 2.5 Voluntary vs Involuntary Churn ───────────────────────
SELECT
    churn_type,
    COUNT(*)                                        AS churned_customers,
    ROUND(SUM(mrr_at_churn_inr), 0)                 AS total_mrr_lost,
    ROUND(AVG(days_to_churn), 0)                    AS avg_days_to_churn,
    ROUND(COUNT(*) / SUM(COUNT(*)) OVER () * 100, 2) AS share_pct
FROM fact_churn
GROUP BY churn_type;


-- ============================================================
--  SECTION 3 — COHORT RETENTION ANALYSIS
-- ============================================================

-- ── 3.1 Acquisition Cohort Size by Quarter ───────────────────
SELECT
    CONCAT(YEAR(acquisition_date), '-', 
           CONCAT('Q', QUARTER(acquisition_date)))  AS acquisition_cohort,
    COUNT(*)                                        AS cohort_size,
    ROUND(SUM(mrr_inr), 0)                          AS cohort_mrr,
    ROUND(AVG(mrr_inr), 0)                          AS avg_mrr
FROM dim_customers
GROUP BY acquisition_cohort
ORDER BY acquisition_cohort;


-- ── 3.2 Cohort Churn Analysis ─────────────────────────────────
-- For each acquisition cohort, how many churned and when
WITH cohort_base AS (
    SELECT
        customer_key,
        CONCAT(YEAR(acquisition_date), '-Q',
               QUARTER(acquisition_date))           AS acq_cohort,
        acquisition_date,
        mrr_inr
    FROM dim_customers
),
cohort_churn AS (
    SELECT
        cb.acq_cohort,
        COUNT(cb.customer_key)                      AS cohort_size,
        ROUND(SUM(cb.mrr_inr), 0)                   AS cohort_starting_mrr,
        COUNT(ch.churn_key)                         AS churned_count,
        ROUND(SUM(ch.mrr_at_churn_inr), 0)          AS mrr_churned,
        ROUND(AVG(ch.days_to_churn), 0)             AS avg_days_to_churn
    FROM cohort_base cb
    LEFT JOIN fact_churn ch ON cb.customer_key = ch.customer_key
    GROUP BY cb.acq_cohort
)
SELECT
    acq_cohort,
    cohort_size,
    cohort_starting_mrr,
    churned_count,
    cohort_size - churned_count                     AS retained_count,
    mrr_churned,
    cohort_starting_mrr - mrr_churned               AS retained_mrr,
    ROUND(churned_count / cohort_size * 100, 2)     AS cohort_churn_rate_pct,
    ROUND((cohort_size - churned_count)
          / cohort_size * 100, 2)                   AS cohort_retention_rate_pct,
    avg_days_to_churn
FROM cohort_churn
ORDER BY acq_cohort;


-- ── 3.3 Days-to-Churn Distribution (Buckets) ─────────────────
SELECT
    CASE
        WHEN days_to_churn <= 90  THEN '0-90 days (Early Churn)'
        WHEN days_to_churn <= 180 THEN '91-180 days'
        WHEN days_to_churn <= 365 THEN '181-365 days (Year 1)'
        WHEN days_to_churn <= 540 THEN '366-540 days (Year 1-2)'
        ELSE                           '540+ days (Long-term)'
    END                                             AS churn_bucket,
    COUNT(*)                                        AS customers,
    ROUND(SUM(mrr_at_churn_inr), 0)                 AS mrr_lost,
    ROUND(AVG(mrr_at_churn_inr), 0)                 AS avg_mrr_at_churn,
    ROUND(AVG(last_health_score), 1)                AS avg_health_score
FROM fact_churn
GROUP BY churn_bucket
ORDER BY MIN(days_to_churn);


-- ============================================================
--  SECTION 4 — CHURN RISK SEGMENTATION (Active Customers)
-- ============================================================

-- ── 4.1 At-Risk Customer List ─────────────────────────────────
SELECT
    c.customer_id,
    c.company_name,
    c.plan,
    c.segment,
    c.region,
    c.health_status,
    c.health_score,
    c.mrr_inr,
    c.last_login_days_ago,
    c.support_tickets_90d,
    c.nps_score,
    -- Risk Score: composite of multiple signals (lower = higher risk)
    ROUND(
        (c.health_score * 0.40)
        + (GREATEST(0, 100 - c.last_login_days_ago) * 0.25)
        + (GREATEST(0, 100 - (c.support_tickets_90d * 8)) * 0.20)
        + (GREATEST(0, (c.nps_score + 100) / 2) * 0.15)
    , 1)                                            AS composite_risk_score,
    CASE
        WHEN c.health_status = 'Critical'                       THEN 'HIGH RISK'
        WHEN c.health_status = 'At Risk'
             AND c.last_login_days_ago > 30                     THEN 'HIGH RISK'
        WHEN c.health_status = 'At Risk'                        THEN 'MEDIUM RISK'
        WHEN c.health_score < 50                                THEN 'MEDIUM RISK'
        ELSE                                                         'LOW RISK'
    END                                             AS risk_category
FROM dim_customers c
WHERE c.is_active = 1
ORDER BY composite_risk_score ASC
LIMIT 50;
-- Top 50 most at-risk active customers


-- ── 4.2 Risk Summary by Plan ──────────────────────────────────
SELECT
    plan,
    COUNT(CASE WHEN health_status = 'Critical'  THEN 1 END)    AS critical_count,
    COUNT(CASE WHEN health_status = 'At Risk'   THEN 1 END)    AS at_risk_count,
    COUNT(CASE WHEN health_status = 'Healthy'   THEN 1 END)    AS healthy_count,
    COUNT(*)                                                    AS total_customers,
    ROUND(SUM(CASE WHEN health_status IN ('Critical','At Risk')
              THEN mrr_inr ELSE 0 END), 0)                     AS mrr_at_risk_inr,
    ROUND(COUNT(CASE WHEN health_status IN ('Critical','At Risk') THEN 1 END)
          / COUNT(*) * 100, 2)                                 AS pct_at_risk
FROM dim_customers
WHERE is_active = 1
GROUP BY plan
ORDER BY mrr_at_risk_inr DESC;


-- ── 4.3 Win-Back Opportunity Analysis ────────────────────────
SELECT
    ch.plan,
    ch.segment,
    ch.churn_reason,
    COUNT(*)                                        AS win_back_candidates,
    ROUND(SUM(ch.mrr_at_churn_inr), 0)              AS recoverable_mrr,
    ROUND(AVG(ch.days_to_churn), 0)                 AS avg_days_to_churn
FROM fact_churn ch
WHERE ch.win_back_eligible = 1
GROUP BY ch.plan, ch.segment, ch.churn_reason
ORDER BY recoverable_mrr DESC;


-- ============================================================
--  SECTION 5 — NET REVENUE RETENTION (NRR)
-- ============================================================

-- ── 5.1 NRR Calculation ───────────────────────────────────────
-- NRR = (Beginning MRR + Expansion MRR - Churned MRR) / Beginning MRR
-- We approximate using available data
WITH mrr_components AS (
    SELECT
        ROUND(SUM(mrr_inr), 0)                      AS current_total_mrr,
        ROUND(SUM(mrr_inr) * 1200 / 1410, 0)        AS beginning_mrr_approx,
        -- Expansion: customers who upgraded (top 25% MRR growth assumed)
        ROUND(SUM(mrr_inr) * 0.08, 0)               AS expansion_mrr_approx
    FROM dim_customers
    WHERE is_active = 1
),
churn_mrr AS (
    SELECT ROUND(SUM(mrr_at_churn_inr), 0)          AS churned_mrr
    FROM fact_churn
)
SELECT
    m.beginning_mrr_approx                          AS beginning_mrr,
    m.expansion_mrr_approx                          AS expansion_mrr,
    c.churned_mrr                                   AS churned_mrr,
    m.beginning_mrr_approx
        + m.expansion_mrr_approx
        - c.churned_mrr                             AS ending_mrr,
    ROUND(
        (m.beginning_mrr_approx + m.expansion_mrr_approx - c.churned_mrr)
        / m.beginning_mrr_approx * 100
    , 2)                                            AS nrr_pct
    -- NRR > 100% = expansion revenue covers churn (best-in-class SaaS)
    -- NRR 90-100% = healthy
    -- NRR < 90% = concerning
FROM mrr_components m
CROSS JOIN churn_mrr c;


