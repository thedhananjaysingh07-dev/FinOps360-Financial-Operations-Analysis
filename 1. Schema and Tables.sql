create database if not exists finOps360
  CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;
    use finOps360;
    
    #SAFETY: Drop tables in FK-safe order
    DROP TABLE IF EXISTS fact_transactions;
DROP TABLE IF EXISTS fact_churn;
DROP TABLE IF EXISTS fact_budget_vs_actual;
DROP TABLE IF EXISTS dim_customers;
DROP TABLE IF EXISTS dim_date;
DROP TABLE IF EXISTS dim_product;



#DIMENSION TABLES

--  dim_date  |  Calendar / Fiscal Date Dimension

CREATE TABLE dim_date (
    date_key            INT             NOT NULL,   
    full_date           DATE            NOT NULL,
    day_of_week         TINYINT         NOT NULL,   
    day_name            VARCHAR(10)     NOT NULL,
    day_of_month        TINYINT         NOT NULL,
    day_of_year         SMALLINT        NOT NULL,
    week_of_year        TINYINT         NOT NULL,
    month_num           TINYINT         NOT NULL,
    month_name          VARCHAR(10)     NOT NULL,
    month_short         CHAR(3)         NOT NULL,   
    fiscal_month_label  VARCHAR(10)     NOT NULL,   
    quarter_num         TINYINT         NOT NULL,
    quarter_label       CHAR(2)         NOT NULL,   
    fiscal_year         SMALLINT        NOT NULL,
    fiscal_year_quarter VARCHAR(7)      NOT NULL,   
    is_weekend          TINYINT(1)      NOT NULL DEFAULT 0,
    is_month_end        TINYINT(1)      NOT NULL DEFAULT 0,
    is_quarter_end      TINYINT(1)      NOT NULL DEFAULT 0,
    is_year_end         TINYINT(1)      NOT NULL DEFAULT 0,

    PRIMARY KEY (date_key),
    INDEX idx_full_date     (full_date),
    INDEX idx_fiscal_year   (fiscal_year),
    INDEX idx_year_quarter  (fiscal_year_quarter)
) COMMENT = 'Calendar dimension — covers FY2022 to FY2024';


# dim_customers  |  Customer Master Dimension

CREATE TABLE dim_customers (
    customer_key            INT             NOT NULL AUTO_INCREMENT,
    customer_id             VARCHAR(12)     NOT NULL,   -- CUST-0001 … CUST-1200
    company_name            VARCHAR(150)    NOT NULL,
    plan                    ENUM('Starter','Growth','Business','Enterprise') NOT NULL,
    segment                 ENUM('SMB','Mid-Market','Enterprise')            NOT NULL,
    industry                VARCHAR(50)     NOT NULL,
    region                  ENUM('North','South','East','West','Central')    NOT NULL,
    acquisition_date        DATE            NOT NULL,
    acquisition_channel     VARCHAR(30)     NOT NULL,
    mrr_inr                 DECIMAL(12,2)   NOT NULL,
    arr_inr                 DECIMAL(14,2)   NOT NULL,   -- Derived: MRR × 12
    contract_length_months  TINYINT         NOT NULL,
    health_score            DECIMAL(5,1)    NOT NULL,
    health_status           ENUM('Healthy','At Risk','Critical') NOT NULL,
    csm_owner               VARCHAR(100)    NOT NULL,
    nps_score               SMALLINT        NOT NULL,
    last_login_days_ago     SMALLINT        NOT NULL,
    avg_monthly_logins      DECIMAL(6,1)    NOT NULL,
    support_tickets_90d     TINYINT         NOT NULL,
    expected_cltv_months    TINYINT         NOT NULL,
    is_active               TINYINT(1)      NOT NULL DEFAULT 1,
    -- Audit columns
    created_at              TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at              TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (customer_key),
    UNIQUE KEY uq_customer_id   (customer_id),
    INDEX idx_plan              (plan),
    INDEX idx_segment           (segment),
    INDEX idx_region            (region),
    INDEX idx_industry          (industry),
    INDEX idx_health_status     (health_status),
    INDEX idx_acquisition_date  (acquisition_date),
    INDEX idx_is_active         (is_active)
) COMMENT = 'Customer master — 1,200 NexaCloud SaaS accounts';


#dim_product  |  Product / Category Dimension

CREATE TABLE dim_product (
    product_key     INT             NOT NULL AUTO_INCREMENT,
    product_line    VARCHAR(30)     NOT NULL,
    category        VARCHAR(30)     NOT NULL,
    is_recurring    TINYINT(1)      NOT NULL DEFAULT 0,  -- 1 = subscription revenue
    cogs_pct_std    DECIMAL(5,2)    NOT NULL,            -- Standard COGS %
    product_group   VARCHAR(30)     NOT NULL,            -- Revenue / Services

    PRIMARY KEY (product_key),
    UNIQUE KEY uq_product_cat (product_line, category),
    INDEX idx_category  (category),
    INDEX idx_recurring (is_recurring)
) COMMENT = 'Product and revenue category dimension';

# Seed product dimension with known combinations
INSERT INTO dim_product (product_line, category, is_recurring, cogs_pct_std, product_group)
VALUES
    ('Core Platform',    'Subscription',           1, 22.00, 'Revenue'),
    ('Analytics Add-on', 'Subscription',           1, 22.00, 'Revenue'),
    ('API Suite',        'Subscription',           1, 22.00, 'Revenue'),
    ('Mobile Module',    'Subscription',           1, 22.00, 'Revenue'),
    ('Compliance Pack',  'Subscription',           1, 22.00, 'Revenue'),
    ('Core Platform',    'Professional Services',  0, 55.00, 'Services'),
    ('Analytics Add-on', 'Professional Services',  0, 55.00, 'Services'),
    ('API Suite',        'Professional Services',  0, 55.00, 'Services'),
    ('Mobile Module',    'Professional Services',  0, 55.00, 'Services'),
    ('Compliance Pack',  'Professional Services',  0, 55.00, 'Services'),
    ('Core Platform',    'Training',               0, 40.00, 'Services'),
    ('Analytics Add-on', 'Training',               0, 40.00, 'Services'),
    ('API Suite',        'Training',               0, 40.00, 'Services'),
    ('Mobile Module',    'Training',               0, 40.00, 'Services'),
    ('Compliance Pack',  'Training',               0, 40.00, 'Services'),
    ('Core Platform',    'Support Premium',        1, 30.00, 'Revenue'),
    ('Analytics Add-on', 'Support Premium',        1, 30.00, 'Revenue'),
    ('API Suite',        'Support Premium',        1, 30.00, 'Revenue'),
    ('Mobile Module',    'Support Premium',        1, 30.00, 'Revenue'),
    ('Compliance Pack',  'Support Premium',        1, 30.00, 'Revenue'),
    ('Core Platform',    'Overage Charges',        0, 10.00, 'Revenue'),
    ('Analytics Add-on', 'Overage Charges',        0, 10.00, 'Revenue'),
    ('API Suite',        'Overage Charges',        0, 10.00, 'Revenue'),
    ('Mobile Module',    'Overage Charges',        0, 10.00, 'Revenue'),
    ('Compliance Pack',  'Overage Charges',        0, 10.00, 'Revenue');
    
    
    
#     FACT TABLES
#  fact_transactions  |  Revenue Transaction Fact

CREATE TABLE fact_transactions (
    transaction_key     BIGINT          NOT NULL AUTO_INCREMENT,
    transaction_id      VARCHAR(12)     NOT NULL,   -- TXN-00001
    invoice_id          VARCHAR(12)     NOT NULL,   -- INV-00001
    -- Foreign Keys
    customer_key        INT             NOT NULL,
    product_key         INT             NOT NULL,
    date_key            INT             NOT NULL,   -- FK → dim_date
    -- Degenerate dimensions (fast filters — no join needed)
    fiscal_year         SMALLINT        NOT NULL,
    fiscal_quarter      CHAR(2)         NOT NULL,
    fiscal_month        VARCHAR(10)     NOT NULL,
    region              VARCHAR(10)     NOT NULL,
    segment             VARCHAR(15)     NOT NULL,
    plan                VARCHAR(12)     NOT NULL,
    payment_status      ENUM('Paid','Pending','Overdue') NOT NULL,
    -- Measures
    revenue_inr         DECIMAL(14,2)   NOT NULL,
    cogs_inr            DECIMAL(14,2)   NOT NULL,
    gross_profit_inr    DECIMAL(14,2)   NOT NULL,
    gross_margin_pct    DECIMAL(6,2)    NOT NULL,
    -- Audit
    created_at          TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (transaction_key),
    UNIQUE KEY uq_transaction_id (transaction_id),
    INDEX idx_customer_key   (customer_key),
    INDEX idx_product_key    (product_key),
    INDEX idx_date_key       (date_key),
    INDEX idx_fiscal_year    (fiscal_year),
    INDEX idx_fiscal_quarter (fiscal_year, fiscal_quarter),
    INDEX idx_region         (region),
    INDEX idx_segment        (segment),
    INDEX idx_plan           (plan),
    INDEX idx_payment_status (payment_status),

    CONSTRAINT fk_txn_customer FOREIGN KEY (customer_key) REFERENCES dim_customers(customer_key),
    CONSTRAINT fk_txn_product  FOREIGN KEY (product_key)  REFERENCES dim_product(product_key),
    CONSTRAINT fk_txn_date     FOREIGN KEY (date_key)     REFERENCES dim_date(date_key)
) COMMENT = 'Revenue fact table — 5,000 transactions FY2022–FY2024';


#fact_churn  |  Customer Churn Event Fact

CREATE TABLE fact_churn (
    churn_key                   BIGINT          NOT NULL AUTO_INCREMENT,
    -- Foreign Keys
    customer_key                INT             NOT NULL,
    acquisition_date_key        INT             NOT NULL,
    churn_date_key              INT             NOT NULL,
    -- Degenerate dimensions
    plan                        VARCHAR(12)     NOT NULL,
    segment                     VARCHAR(15)     NOT NULL,
    region                      VARCHAR(10)     NOT NULL,
    churn_reason                VARCHAR(30)     NOT NULL,
    churn_type                  ENUM('Voluntary','Involuntary') NOT NULL,
    was_escalated               TINYINT(1)      NOT NULL DEFAULT 0,
    exit_survey_completed       TINYINT(1)      NOT NULL DEFAULT 0,
    win_back_eligible           TINYINT(1)      NOT NULL DEFAULT 0,
    -- Measures
    days_to_churn               SMALLINT        NOT NULL,
    mrr_at_churn_inr            DECIMAL(12,2)   NOT NULL,
    arr_at_churn_inr            DECIMAL(14,2)   NOT NULL,
    revenue_recognized_inr      DECIMAL(14,2)   NOT NULL,
    last_health_score           DECIMAL(5,1)    NOT NULL,
    support_tickets_90d         TINYINT         NOT NULL,
    -- Audit
    created_at                  TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (churn_key),
    UNIQUE KEY uq_churn_customer (customer_key),
    INDEX idx_churn_customer     (customer_key),
    INDEX idx_churn_date         (churn_date_key),
    INDEX idx_churn_reason       (churn_reason),
    INDEX idx_churn_plan         (plan),
    INDEX idx_churn_segment      (segment),

    CONSTRAINT fk_churn_customer  FOREIGN KEY (customer_key)         REFERENCES dim_customers(customer_key),
    CONSTRAINT fk_churn_acq_date  FOREIGN KEY (acquisition_date_key) REFERENCES dim_date(date_key),
    CONSTRAINT fk_churn_date      FOREIGN KEY (churn_date_key)       REFERENCES dim_date(date_key)
) COMMENT = 'Churn event fact — 210 churned customers FY2022–FY2024';


# fact_budget_vs_actual  |  Financial Planning Fact

CREATE TABLE fact_budget_vs_actual (
    bva_key                 BIGINT          NOT NULL AUTO_INCREMENT,
    -- Foreign Keys
    date_key                INT             NOT NULL,
    -- Degenerate dimensions
    fiscal_year             SMALLINT        NOT NULL,
    fiscal_quarter          CHAR(2)         NOT NULL,
    month_label             VARCHAR(10)     NOT NULL,
    department              VARCHAR(30)     NOT NULL,
    -- Revenue Measures
    budgeted_revenue_inr    DECIMAL(14,2)   NOT NULL,
    actual_revenue_inr      DECIMAL(14,2)   NOT NULL,
    revenue_variance_inr    DECIMAL(14,2)   NOT NULL,
    revenue_variance_pct    DECIMAL(7,2)    NOT NULL,
    -- OpEx Measures
    budgeted_opex_inr       DECIMAL(14,2)   NOT NULL,
    actual_opex_inr         DECIMAL(14,2)   NOT NULL,
    opex_variance_inr       DECIMAL(14,2)   NOT NULL,
    opex_variance_pct       DECIMAL(7,2)    NOT NULL,
    -- EBITDA Measures
    budgeted_ebitda_inr     DECIMAL(14,2)   NOT NULL,
    actual_ebitda_inr       DECIMAL(14,2)   NOT NULL,
    -- Headcount
    headcount_budget        SMALLINT        NOT NULL,
    headcount_actual        SMALLINT        NOT NULL,
    -- Audit
    created_at              TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (bva_key),
    UNIQUE KEY uq_bva_period_dept (date_key, department),
    INDEX idx_bva_date       (date_key),
    INDEX idx_bva_year       (fiscal_year),
    INDEX idx_bva_dept       (department),
    INDEX idx_bva_yq         (fiscal_year, fiscal_quarter),

    CONSTRAINT fk_bva_date FOREIGN KEY (date_key) REFERENCES dim_date(date_key)
) COMMENT = 'Budget vs Actual fact — monthly dept-level FY2022–FY2024';


 # VERIFY SCHEMA

SELECT
    TABLE_NAME                              AS `Table`,
    TABLE_COMMENT                           AS `Description`,
    TABLE_ROWS                              AS `Approx Rows`,
    ROUND(DATA_LENGTH / 1024, 1)            AS `Data KB`,
    ROUND(INDEX_LENGTH / 1024, 1)           AS `Index KB`
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'finOps360'
ORDER BY TABLE_NAME;