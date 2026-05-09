USE finOps360;

SET @start = '2022-01-01';
SET @end = '2024-12-31';

INSERT INTO dim_date (
    date_key, full_date, day_of_week, day_name,
    day_of_month, day_of_year, week_of_year,
    month_num, month_name, month_short,
    fiscal_month_label, quarter_num, quarter_label,
    fiscal_year, fiscal_year_quarter,
    is_weekend, is_month_end, is_quarter_end, is_year_end
)
SELECT
    CAST(DATE_FORMAT(d, '%Y%m%d') AS UNSIGNED),
    d,
    IF(DAYOFWEEK(d)=1,7,DAYOFWEEK(d)-1),
    DAYNAME(d),
    DAY(d),
    DAYOFYEAR(d),
    WEEK(d,3),
    MONTH(d),
    MONTHNAME(d),
    DATE_FORMAT(d,'%b'),
    DATE_FORMAT(d,'%b-%Y'),
    QUARTER(d),
    CONCAT('Q',QUARTER(d)),
    YEAR(d),
    CONCAT(YEAR(d),'-Q',QUARTER(d)),
    IF(DAYOFWEEK(d) IN (1,7),1,0),
    IF(MONTH(DATE_ADD(d,INTERVAL 1 DAY))<>MONTH(d),1,0),
    IF(QUARTER(DATE_ADD(d,INTERVAL 1 DAY))<>QUARTER(d),1,0),
    IF(DATE_FORMAT(d,'%m-%d')='12-31',1,0)
FROM (
    SELECT DATE_ADD(@start, INTERVAL seq DAY) AS d
    FROM (
        SELECT a.N + b.N*10 + c.N*100 + d.N*1000 AS seq
        FROM
            (SELECT 0 AS N UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4
             UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) a,
            (SELECT 0 AS N UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4
             UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) b,
            (SELECT 0 AS N UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4
             UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) c,
            (SELECT 0 AS N UNION SELECT 1 UNION SELECT 2 UNION SELECT 3) d
    ) nums
    WHERE DATE_ADD(@start, INTERVAL seq DAY) <= @end
) dates;


#  VERIFY: Should return 1096 rows (3 years incl. 2024 leap year)

SELECT
    fiscal_year,
    COUNT(*)                                AS total_days,
    COUNT(CASE WHEN is_weekend    = 1 THEN 1 END) AS weekend_days,
    COUNT(CASE WHEN is_month_end  = 1 THEN 1 END) AS month_ends,
    COUNT(CASE WHEN is_quarter_end= 1 THEN 1 END) AS quarter_ends
FROM dim_date
GROUP BY fiscal_year
ORDER BY fiscal_year;

#  SAMPLE: Preview first 5 and last 5 rows

(SELECT 'FIRST 5' AS sample_set, d.*
 FROM dim_date d
 ORDER BY date_key ASC
 LIMIT 5)
UNION ALL
(SELECT 'LAST 5', d.*
 FROM dim_date d
 ORDER BY date_key DESC
 LIMIT 5)
ORDER BY date_key;

