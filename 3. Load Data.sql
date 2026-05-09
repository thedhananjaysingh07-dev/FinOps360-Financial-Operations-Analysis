USE finops360;

DROP TABLE IF EXISTS stg_customers;
DROP TABLE IF EXISTS stg_transactions;
DROP TABLE IF EXISTS stg_churn;
DROP TABLE IF EXISTS stg_budget;

CREATE TABLE stg_customers (
    CustomerID              VARCHAR(20),
    CompanyName             VARCHAR(200),
    Plan                    VARCHAR(20),
    Segment                 VARCHAR(20),
    Industry                VARCHAR(50),
    Region                  VARCHAR(20),
    AcquisitionDate         VARCHAR(20),
    AcquisitionChannel      VARCHAR(50),
    MRR_INR                 VARCHAR(20),
    ARR_INR                 VARCHAR(20),
    ContractLength_Months   VARCHAR(10),
    HealthScore             VARCHAR(10),
    HealthStatus            VARCHAR(15),
    CSM_Owner               VARCHAR(100),
    NPS_Score               VARCHAR(10),
    LastLoginDaysAgo        VARCHAR(10),
    AvgMonthlyLogins        VARCHAR(10),
    SupportTickets_Last90D  VARCHAR(10),
    ExpectedCLTV_Months     VARCHAR(10),
    IsActive                VARCHAR(5)
) CHARACTER SET utf8mb4;

CREATE TABLE stg_transactions (
    TransactionID   VARCHAR(15),
    CustomerID      VARCHAR(15),
    TransactionDate VARCHAR(20),
    FiscalYear      VARCHAR(6),
    FiscalQuarter   VARCHAR(4),
    FiscalMonth     VARCHAR(12),
    Category        VARCHAR(30),
    ProductLine     VARCHAR(30),
    Region          VARCHAR(15),
    Segment         VARCHAR(20),
    Plan            VARCHAR(15),
    Revenue_INR     VARCHAR(20),
    COGS_INR        VARCHAR(20),
    GrossProfit_INR VARCHAR(20),
    GrossMargin_Pct VARCHAR(15),
    PaymentStatus   VARCHAR(15),
    InvoiceID       VARCHAR(15)
) CHARACTER SET utf8mb4;

CREATE TABLE stg_churn (
    CustomerID              VARCHAR(15),
    CompanyName             VARCHAR(200),
    Plan                    VARCHAR(15),
    Segment                 VARCHAR(20),
    Region                  VARCHAR(15),
    AcquisitionDate         VARCHAR(20),
    ChurnDate               VARCHAR(20),
    DaysToChurn             VARCHAR(10),
    MRR_AtChurn_INR         VARCHAR(20),
    ARR_AtChurn_INR         VARCHAR(20),
    RevenueRecognized_INR   VARCHAR(20),
    ChurnReason             VARCHAR(30),
    ChurnType               VARCHAR(15),
    WasEscalated            VARCHAR(5),
    ExitSurveyCompleted     VARCHAR(5),
    WinBackEligible         VARCHAR(5),
    LastHealthScore         VARCHAR(10),
    SupportTickets_Last90D  VARCHAR(10)
) CHARACTER SET utf8mb4;

CREATE TABLE stg_budget (
    Period                  VARCHAR(20),
    FiscalYear              VARCHAR(6),
    FiscalQuarter           VARCHAR(4),
    Month                   VARCHAR(12),
    Department              VARCHAR(30),
    BudgetedRevenue_INR     VARCHAR(20),
    ActualRevenue_INR       VARCHAR(20),
    RevenueVariance_INR     VARCHAR(20),
    RevenueVariance_Pct     VARCHAR(15),
    BudgetedOpEx_INR        VARCHAR(20),
    ActualOpEx_INR          VARCHAR(20),
    OpExVariance_INR        VARCHAR(20),
    OpExVariance_Pct        VARCHAR(15),
    BudgetedEBITDA_INR      VARCHAR(20),
    ActualEBITDA_INR        VARCHAR(20),
    HeadCount_Budget        VARCHAR(10),
    HeadCount_Actual        VARCHAR(10)
) CHARACTER SET utf8mb4;


-- ─────────────────────────────────────────────────────────────
--  LOAD DATA INTO STAGING
--  ⚠  Update file paths to match your machine
-- ─────────────────────────────────────────────────────────────

-- Option A: LOAD DATA LOCAL INFILE (fastest)
/*
LOAD DATA LOCAL INFILE 'C:/finops360_data/customers.csv'
INTO TABLE stg_customers
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

LOAD DATA LOCAL INFILE 'C:/finops360_data/transactions.csv'
INTO TABLE stg_transactions
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

LOAD DATA LOCAL INFILE 'C:/finops360_data/churn_log.csv'
INTO TABLE stg_churn
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

LOAD DATA LOCAL INFILE 'C:/finops360_data/budget_vs_actual.csv'
INTO TABLE stg_budget
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;
*/

-- Option B: MySQL Workbench Table Data Import Wizard
-- Right-click table name → Table Data Import Wizard → select your CSV

SHOW TABLES FROM finops360;
--  QUICK STAGING ROW COUNTS CHECK
-- ─────────────────────────────────────────────────────────────

SELECT 'stg_customers'    AS staging_table, COUNT(*) AS rows_loaded FROM stg_customers
UNION ALL
SELECT 'stg_transactions', COUNT(*) FROM stg_transactions
UNION ALL
SELECT 'stg_churn',        COUNT(*) FROM stg_churn
UNION ALL
SELECT 'stg_budget',       COUNT(*) FROM stg_budget;
/*
  Expected:
  stg_customers    → 1200
  stg_transactions → 5000
  stg_churn        → 210
  stg_budget       → 216
*/


-- ============================================================
--  LOAD dim_customers  FROM STAGING
-- ============================================================

INSERT INTO dim_customers (
    customer_id, company_name, plan, segment, industry, region,
    acquisition_date, acquisition_channel,
    mrr_inr, arr_inr, contract_length_months,
    health_score, health_status, csm_owner, nps_score,
    last_login_days_ago, avg_monthly_logins, support_tickets_90d,
    expected_cltv_months, is_active
)
SELECT
    TRIM(CustomerID),
    TRIM(CompanyName),
    TRIM(Plan),
    TRIM(Segment),
    TRIM(Industry),
    TRIM(Region),
    -- Handle both DD-Mon-YYYY (Excel) and YYYY-MM-DD formats
    STR_TO_DATE(TRIM(AcquisitionDate), '%d-%b-%Y'),
    TRIM(AcquisitionChannel),
    ROUND(CAST(REPLACE(MRR_INR, ',', '') AS DECIMAL(12,2)), 2),
    ROUND(CAST(REPLACE(ARR_INR, ',', '') AS DECIMAL(14,2)), 2),
    CAST(ContractLength_Months AS UNSIGNED),
    CAST(HealthScore AS DECIMAL(5,1)),
    TRIM(HealthStatus),
    TRIM(CSM_Owner),
    CAST(NPS_Score AS SIGNED),
    CAST(LastLoginDaysAgo AS UNSIGNED),
    CAST(AvgMonthlyLogins AS DECIMAL(6,1)),
    CAST(SupportTickets_Last90D AS UNSIGNED),
    CAST(ExpectedCLTV_Months AS UNSIGNED),
    IF(TRIM(IsActive) = 'Yes', 1, 0)
FROM stg_customers
WHERE TRIM(CustomerID) IS NOT NULL
  AND TRIM(CustomerID) != '';

-- Verify
SELECT COUNT(*) AS dim_customers_loaded FROM dim_customers;
-- Expected: 1200


-- ============================================================
--  LOAD fact_transactions  FROM STAGING
-- ============================================================

ALTER TABLE stg_transactions CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
ALTER TABLE stg_customers CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
ALTER TABLE stg_churn CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
ALTER TABLE stg_budget CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;


INSERT INTO fact_transactions (
    transaction_id, invoice_id,
    customer_key, product_key, date_key,
    fiscal_year, fiscal_quarter, fiscal_month,
    region, segment, plan, payment_status,
    revenue_inr, cogs_inr, gross_profit_inr, gross_margin_pct
)
SELECT
    TRIM(t.TransactionID),
    TRIM(t.InvoiceID),
    c.customer_key,
    p.product_key,
    CAST(DATE_FORMAT(
        STR_TO_DATE(TRIM(t.TransactionDate), '%d-%b-%Y'),
        '%Y%m%d'
    ) AS UNSIGNED),
    CAST(t.FiscalYear AS UNSIGNED),
    TRIM(t.FiscalQuarter),
    TRIM(t.FiscalMonth),
    TRIM(t.Region),
    TRIM(t.Segment),
    TRIM(t.Plan),
    TRIM(t.PaymentStatus),
    ROUND(CAST(REPLACE(t.Revenue_INR, ',', '') AS DECIMAL(14,2)), 2),
    ROUND(CAST(REPLACE(t.COGS_INR,    ',', '') AS DECIMAL(14,2)), 2),
    ROUND(CAST(REPLACE(t.GrossProfit_INR, ',', '') AS DECIMAL(14,2)), 2),
    ROUND(CAST(t.GrossMargin_Pct AS DECIMAL(6,2)), 2)
FROM stg_transactions t
JOIN dim_customers c ON c.customer_id = TRIM(t.CustomerID)
JOIN dim_product   p ON p.product_line = TRIM(t.ProductLine)
                    AND p.category     = TRIM(t.Category)
WHERE TRIM(t.TransactionID) IS NOT NULL;

-- Verify
SELECT COUNT(*) AS fact_transactions_loaded FROM fact_transactions;
-- Expected: 5000


-- ============================================================
--  LOAD fact_churn  FROM STAGING
-- ============================================================

INSERT INTO fact_churn (
    customer_key,
    acquisition_date_key, churn_date_key,
    plan, segment, region,
    churn_reason, churn_type,
    was_escalated, exit_survey_completed, win_back_eligible,
    days_to_churn, mrr_at_churn_inr, arr_at_churn_inr,
    revenue_recognized_inr, last_health_score, support_tickets_90d
)
SELECT
    c.customer_key,

    -- Acquisition date → dim_date key
    CAST(DATE_FORMAT(
        STR_TO_DATE(TRIM(ch.AcquisitionDate), '%d-%b-%Y'),
        '%Y%m%d'
    ) AS UNSIGNED),

    -- Churn date → dim_date key
    CAST(DATE_FORMAT(
        STR_TO_DATE(TRIM(ch.ChurnDate), '%d-%b-%Y'),
        '%Y%m%d'
    ) AS UNSIGNED),

    TRIM(ch.Plan),
    TRIM(ch.Segment),
    TRIM(ch.Region),
    TRIM(ch.ChurnReason),
    TRIM(ch.ChurnType),
    IF(TRIM(ch.WasEscalated)          = 'Yes', 1, 0),
    IF(TRIM(ch.ExitSurveyCompleted)   = 'Yes', 1, 0),
    IF(TRIM(ch.WinBackEligible)       = 'Yes', 1, 0),
    CAST(ch.DaysToChurn AS UNSIGNED),
    ROUND(CAST(REPLACE(ch.MRR_AtChurn_INR,       ',', '') AS DECIMAL(12,2)), 2),
    ROUND(CAST(REPLACE(ch.ARR_AtChurn_INR,       ',', '') AS DECIMAL(14,2)), 2),
    ROUND(CAST(REPLACE(ch.RevenueRecognized_INR, ',', '') AS DECIMAL(14,2)), 2),
    CAST(ch.LastHealthScore AS DECIMAL(5,1)),
    CAST(ch.SupportTickets_Last90D AS UNSIGNED)

FROM stg_churn ch
JOIN dim_customers c ON c.customer_id = TRIM(ch.CustomerID)
WHERE TRIM(ch.CustomerID) IS NOT NULL;

-- Verify
SELECT COUNT(*) AS fact_churn_loaded FROM fact_churn;
-- Expected: 210


-- ============================================================
--  LOAD fact_budget_vs_actual  FROM STAGING
-- ============================================================

INSERT INTO fact_budget_vs_actual (
    date_key, fiscal_year, fiscal_quarter, month_label, department,
    budgeted_revenue_inr, actual_revenue_inr, revenue_variance_inr, revenue_variance_pct,
    budgeted_opex_inr,   actual_opex_inr,   opex_variance_inr,   opex_variance_pct,
    budgeted_ebitda_inr, actual_ebitda_inr,
    headcount_budget, headcount_actual
)
SELECT
    CAST(DATE_FORMAT(
        STR_TO_DATE(TRIM(Period), '%d-%b-%Y'),
        '%Y%m%d'
    ) AS UNSIGNED),
    CAST(FiscalYear AS UNSIGNED),
    TRIM(FiscalQuarter),
    TRIM(Month),
    TRIM(Department),
    ROUND(CAST(REPLACE(BudgetedRevenue_INR, ',', '') AS DECIMAL(14,2)), 2),
    ROUND(CAST(REPLACE(ActualRevenue_INR,   ',', '') AS DECIMAL(14,2)), 2),
    ROUND(CAST(REPLACE(RevenueVariance_INR, ',', '') AS DECIMAL(14,2)), 2),
    ROUND(CAST(RevenueVariance_Pct AS DECIMAL(7,2)), 2),
    ROUND(CAST(REPLACE(BudgetedOpEx_INR, ',', '') AS DECIMAL(14,2)), 2),
    ROUND(CAST(REPLACE(ActualOpEx_INR,   ',', '') AS DECIMAL(14,2)), 2),
    ROUND(CAST(REPLACE(OpExVariance_INR, ',', '') AS DECIMAL(14,2)), 2),
    ROUND(CAST(OpExVariance_Pct AS DECIMAL(7,2)), 2),
    ROUND(CAST(REPLACE(BudgetedEBITDA_INR, ',', '') AS DECIMAL(14,2)), 2),
    ROUND(CAST(REPLACE(ActualEBITDA_INR,   ',', '') AS DECIMAL(14,2)), 2),
    CAST(HeadCount_Budget AS UNSIGNED),
    CAST(HeadCount_Actual AS UNSIGNED)
FROM stg_budget
WHERE TRIM(Period) IS NOT NULL;

-- Verify
SELECT COUNT(*) AS fact_budget_loaded FROM fact_budget_vs_actual;
-- Expected: 216


-- ============================================================
--  FINAL LOAD SUMMARY
-- ============================================================

SELECT
    'dim_date'              AS table_name, COUNT(*) AS rows_loaded FROM dim_date        UNION ALL
SELECT 'dim_customers',                   COUNT(*) FROM dim_customers                  UNION ALL
SELECT 'dim_product',                     COUNT(*) FROM dim_product                    UNION ALL
SELECT 'fact_transactions',               COUNT(*) FROM fact_transactions              UNION ALL
SELECT 'fact_churn',                      COUNT(*) FROM fact_churn                     UNION ALL
SELECT 'fact_budget_vs_actual',           COUNT(*) FROM fact_budget_vs_actual;

/*
  Expected Final Summary:
  ┌──────────────────────┬──────────────┐
  │ table_name           │ rows_loaded  │
  ├──────────────────────┼──────────────┤
  │ dim_date             │    1096      │
  │ dim_customers        │    1200      │
  │ dim_product          │      25      │
  │ fact_transactions    │    5000      │
  │ fact_churn           │     210      │
  │ fact_budget_vs_actual│     216      │
  └──────────────────────┴──────────────┘
*/


-- ─────────────────────────────────────────────────────────────
--  CLEANUP: Drop staging tables once load is verified
-- ─────────────────────────────────────────────────────────────

-- Uncomment after you confirm all row counts above are correct:
 DROP TABLE IF EXISTS stg_customers;
 DROP TABLE IF EXISTS stg_transactions;
 DROP TABLE IF EXISTS stg_churn;
 DROP TABLE IF EXISTS stg_budget;

