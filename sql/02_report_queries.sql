/*
보고서용 결과 SQL

01_build_analysis_tables.sql 실행 후 사용합니다.
DB 정책에 따라 CREATE TABLE 대신 CREATE VIEW로 바꿔도 됩니다.
*/

CREATE TABLE report_cross_group_summary AS
WITH group_month AS (
    SELECT
        sms_received_yn,
        base_month,
        COUNT(DISTINCT customer_id) AS customer_count,
        COUNT(DISTINCT CASE WHEN satisfied_item_count >= 1 THEN customer_id END) AS satisfied_customer_count,
        SUM(product_total_count) AS product_total_count,
        CAST(SUM(product_total_count) AS DECIMAL(18, 6))
            / NULLIF(COUNT(DISTINCT CASE WHEN satisfied_item_count >= 1 THEN customer_id END), 0) AS group_cross_index
    FROM mart_cross_customer_month
    GROUP BY sms_received_yn, base_month
),
pivoted AS (
    SELECT
        sms_received_yn,
        MAX(CASE WHEN base_month = '2025-12' THEN customer_count END) AS customer_count_2512,
        MAX(CASE WHEN base_month = '2025-12' THEN satisfied_customer_count END) AS satisfied_customer_count_2512,
        MAX(CASE WHEN base_month = '2025-12' THEN product_total_count END) AS product_total_count_2512,
        MAX(CASE WHEN base_month = '2025-12' THEN group_cross_index END) AS group_cross_index_2512,
        MAX(CASE WHEN base_month = '2026-06' THEN customer_count END) AS customer_count_2606,
        MAX(CASE WHEN base_month = '2026-06' THEN satisfied_customer_count END) AS satisfied_customer_count_2606,
        MAX(CASE WHEN base_month = '2026-06' THEN product_total_count END) AS product_total_count_2606,
        MAX(CASE WHEN base_month = '2026-06' THEN group_cross_index END) AS group_cross_index_2606
    FROM group_month
    GROUP BY sms_received_yn
)
SELECT
    CASE WHEN sms_received_yn = 1 THEN '문자수신' ELSE '문자미수신' END AS sms_group,
    sms_received_yn,
    customer_count_2512,
    satisfied_customer_count_2512,
    product_total_count_2512,
    group_cross_index_2512,
    customer_count_2606,
    satisfied_customer_count_2606,
    product_total_count_2606,
    group_cross_index_2606,
    group_cross_index_2606 - group_cross_index_2512 AS group_cross_index_diff,
    (group_cross_index_2606 / NULLIF(group_cross_index_2512, 0)) - 1 AS group_cross_index_growth_rate
FROM pivoted;


CREATE TABLE report_cross_sms_effect AS
SELECT
    MAX(CASE WHEN sms_received_yn = 1 THEN group_cross_index_diff END) AS sms_received_cross_index_diff,
    MAX(CASE WHEN sms_received_yn = 0 THEN group_cross_index_diff END) AS sms_not_received_cross_index_diff,
    MAX(CASE WHEN sms_received_yn = 1 THEN group_cross_index_diff END)
        - MAX(CASE WHEN sms_received_yn = 0 THEN group_cross_index_diff END) AS estimated_sms_effect,
    CASE
        WHEN MAX(CASE WHEN sms_received_yn = 1 THEN group_cross_index_diff END)
           - MAX(CASE WHEN sms_received_yn = 0 THEN group_cross_index_diff END) > 0
            THEN '문자수신군 개선폭이 더 큼'
        WHEN MAX(CASE WHEN sms_received_yn = 1 THEN group_cross_index_diff END)
           - MAX(CASE WHEN sms_received_yn = 0 THEN group_cross_index_diff END) = 0
            THEN '차이 없음'
        ELSE '문자미수신군 개선폭이 더 큼'
    END AS interpretation
FROM report_cross_group_summary;


CREATE TABLE report_cross_item_contribution AS
WITH item_long AS (
    SELECT sms_received_yn, base_month, '적립식' AS item_name, customer_id, installment_savings_satisfied AS satisfied_yn FROM mart_cross_customer_month
    UNION ALL SELECT sms_received_yn, base_month, '거치식', customer_id, lump_savings_satisfied FROM mart_cross_customer_month
    UNION ALL SELECT sms_received_yn, base_month, '신탁', customer_id, trust_satisfied FROM mart_cross_customer_month
    UNION ALL SELECT sms_received_yn, base_month, '집합투자', customer_id, fund_satisfied FROM mart_cross_customer_month
    UNION ALL SELECT sms_received_yn, base_month, '방카', customer_id, bancassurance_satisfied FROM mart_cross_customer_month
    UNION ALL SELECT sms_received_yn, base_month, '청약', customer_id, subscription_savings_satisfied FROM mart_cross_customer_month
    UNION ALL SELECT sms_received_yn, base_month, '개인연금', customer_id, personal_pension_satisfied FROM mart_cross_customer_month
    UNION ALL SELECT sms_received_yn, base_month, '퇴직연금', customer_id, retirement_pension_satisfied FROM mart_cross_customer_month
    UNION ALL SELECT sms_received_yn, base_month, '담보대출', customer_id, mortgage_loan_satisfied FROM mart_cross_customer_month
    UNION ALL SELECT sms_received_yn, base_month, '기타대출', customer_id, other_loan_satisfied FROM mart_cross_customer_month
    UNION ALL SELECT sms_received_yn, base_month, '요구불', customer_id, salary_transfer_satisfied FROM mart_cross_customer_month
    UNION ALL SELECT sms_received_yn, base_month, '입금이체', customer_id, auto_transfer_satisfied FROM mart_cross_customer_month
    UNION ALL SELECT sms_received_yn, base_month, '출금이체', customer_id, withdrawal_transfer_satisfied FROM mart_cross_customer_month
    UNION ALL SELECT sms_received_yn, base_month, '디지털', customer_id, digital_satisfied FROM mart_cross_customer_month
    UNION ALL SELECT sms_received_yn, base_month, '환전송금', customer_id, fx_remittance_satisfied FROM mart_cross_customer_month
    UNION ALL SELECT sms_received_yn, base_month, '하나머니', customer_id, hana_money_satisfied FROM mart_cross_customer_month
),
item_summary AS (
    SELECT
        item_name,
        sms_received_yn,
        COUNT(DISTINCT CASE WHEN base_month = '2025-12' AND satisfied_yn = 1 THEN customer_id END) AS satisfied_customer_count_2512,
        COUNT(DISTINCT CASE WHEN base_month = '2026-06' AND satisfied_yn = 1 THEN customer_id END) AS satisfied_customer_count_2606
    FROM item_long
    GROUP BY item_name, sms_received_yn
),
pivoted AS (
    SELECT
        item_name,
        MAX(CASE WHEN sms_received_yn = 1 THEN satisfied_customer_count_2512 END) AS sms_received_satisfied_count_2512,
        MAX(CASE WHEN sms_received_yn = 1 THEN satisfied_customer_count_2606 END) AS sms_received_satisfied_count_2606,
        MAX(CASE WHEN sms_received_yn = 0 THEN satisfied_customer_count_2512 END) AS sms_not_received_satisfied_count_2512,
        MAX(CASE WHEN sms_received_yn = 0 THEN satisfied_customer_count_2606 END) AS sms_not_received_satisfied_count_2606
    FROM item_summary
    GROUP BY item_name
)
SELECT
    item_name,
    sms_received_satisfied_count_2512,
    sms_received_satisfied_count_2606,
    sms_received_satisfied_count_2606 - sms_received_satisfied_count_2512 AS sms_received_diff,
    sms_not_received_satisfied_count_2512,
    sms_not_received_satisfied_count_2606,
    sms_not_received_satisfied_count_2606 - sms_not_received_satisfied_count_2512 AS sms_not_received_diff,
    (sms_received_satisfied_count_2606 - sms_received_satisfied_count_2512)
        - (sms_not_received_satisfied_count_2606 - sms_not_received_satisfied_count_2512) AS diff_gap
FROM pivoted;


CREATE TABLE report_cross_customer_movement AS
WITH movement_count AS (
    SELECT
        sms_received_yn,
        movement_type,
        COUNT(*) AS customer_count
    FROM mart_cross_customer_compare
    GROUP BY sms_received_yn, movement_type
),
group_total AS (
    SELECT
        sms_received_yn,
        SUM(customer_count) AS total_customer_count
    FROM movement_count
    GROUP BY sms_received_yn
)
SELECT
    CASE WHEN m.sms_received_yn = 1 THEN '문자수신' ELSE '문자미수신' END AS sms_group,
    m.sms_received_yn,
    m.movement_type,
    m.customer_count,
    CAST(m.customer_count AS DECIMAL(18, 6)) / NULLIF(t.total_customer_count, 0) AS customer_ratio
FROM movement_count m
INNER JOIN group_total t
    ON m.sms_received_yn = t.sms_received_yn;


CREATE TABLE report_cross_adjusted_by_pre_item_band AS
WITH band_summary AS (
    SELECT
        pre_satisfied_item_count_band,
        sms_received_yn,
        COUNT(*) AS customer_count,
        SUM(product_total_count_2512) AS product_total_count_2512,
        COUNT(CASE WHEN satisfied_item_count_2512 >= 1 THEN 1 END) AS satisfied_customer_count_2512,
        CAST(SUM(product_total_count_2512) AS DECIMAL(18, 6))
            / NULLIF(COUNT(CASE WHEN satisfied_item_count_2512 >= 1 THEN 1 END), 0) AS group_cross_index_2512,
        SUM(product_total_count_2606) AS product_total_count_2606,
        COUNT(CASE WHEN satisfied_item_count_2606 >= 1 THEN 1 END) AS satisfied_customer_count_2606,
        CAST(SUM(product_total_count_2606) AS DECIMAL(18, 6))
            / NULLIF(COUNT(CASE WHEN satisfied_item_count_2606 >= 1 THEN 1 END), 0) AS group_cross_index_2606
    FROM mart_cross_customer_compare
    GROUP BY pre_satisfied_item_count_band, sms_received_yn
),
with_diff AS (
    SELECT
        pre_satisfied_item_count_band,
        sms_received_yn,
        customer_count,
        group_cross_index_2512,
        group_cross_index_2606,
        group_cross_index_2606 - group_cross_index_2512 AS group_cross_index_diff
    FROM band_summary
)
SELECT
    pre_satisfied_item_count_band,
    MAX(CASE WHEN sms_received_yn = 1 THEN customer_count END) AS sms_received_customer_count,
    MAX(CASE WHEN sms_received_yn = 1 THEN group_cross_index_diff END) AS sms_received_cross_index_diff,
    MAX(CASE WHEN sms_received_yn = 0 THEN customer_count END) AS sms_not_received_customer_count,
    MAX(CASE WHEN sms_received_yn = 0 THEN group_cross_index_diff END) AS sms_not_received_cross_index_diff,
    MAX(CASE WHEN sms_received_yn = 1 THEN group_cross_index_diff END)
        - MAX(CASE WHEN sms_received_yn = 0 THEN group_cross_index_diff END) AS estimated_sms_effect
FROM with_diff
GROUP BY pre_satisfied_item_count_band;


CREATE TABLE report_cross_adjusted_by_customer_grade AS
WITH grade_summary AS (
    SELECT
        COALESCE(customer_grade, '미상') AS customer_grade,
        sms_received_yn,
        COUNT(*) AS customer_count,
        CAST(SUM(product_total_count_2512) AS DECIMAL(18, 6))
            / NULLIF(COUNT(CASE WHEN satisfied_item_count_2512 >= 1 THEN 1 END), 0) AS group_cross_index_2512,
        CAST(SUM(product_total_count_2606) AS DECIMAL(18, 6))
            / NULLIF(COUNT(CASE WHEN satisfied_item_count_2606 >= 1 THEN 1 END), 0) AS group_cross_index_2606
    FROM mart_cross_customer_compare
    GROUP BY COALESCE(customer_grade, '미상'), sms_received_yn
),
with_diff AS (
    SELECT
        customer_grade,
        sms_received_yn,
        customer_count,
        group_cross_index_2606 - group_cross_index_2512 AS group_cross_index_diff
    FROM grade_summary
)
SELECT
    customer_grade,
    MAX(CASE WHEN sms_received_yn = 1 THEN customer_count END) AS sms_received_customer_count,
    MAX(CASE WHEN sms_received_yn = 1 THEN group_cross_index_diff END) AS sms_received_cross_index_diff,
    MAX(CASE WHEN sms_received_yn = 0 THEN customer_count END) AS sms_not_received_customer_count,
    MAX(CASE WHEN sms_received_yn = 0 THEN group_cross_index_diff END) AS sms_not_received_cross_index_diff,
    MAX(CASE WHEN sms_received_yn = 1 THEN group_cross_index_diff END)
        - MAX(CASE WHEN sms_received_yn = 0 THEN group_cross_index_diff END) AS estimated_sms_effect
FROM with_diff
GROUP BY customer_grade;


CREATE TABLE report_cross_adjusted_by_pre_cross_index_band AS
WITH band_summary AS (
    SELECT
        pre_cross_index_band,
        sms_received_yn,
        COUNT(*) AS customer_count,
        CAST(SUM(product_total_count_2512) AS DECIMAL(18, 6))
            / NULLIF(COUNT(CASE WHEN satisfied_item_count_2512 >= 1 THEN 1 END), 0) AS group_cross_index_2512,
        CAST(SUM(product_total_count_2606) AS DECIMAL(18, 6))
            / NULLIF(COUNT(CASE WHEN satisfied_item_count_2606 >= 1 THEN 1 END), 0) AS group_cross_index_2606
    FROM mart_cross_customer_compare
    GROUP BY pre_cross_index_band, sms_received_yn
),
with_diff AS (
    SELECT
        pre_cross_index_band,
        sms_received_yn,
        customer_count,
        group_cross_index_2606 - group_cross_index_2512 AS group_cross_index_diff
    FROM band_summary
)
SELECT
    pre_cross_index_band,
    MAX(CASE WHEN sms_received_yn = 1 THEN customer_count END) AS sms_received_customer_count,
    MAX(CASE WHEN sms_received_yn = 1 THEN group_cross_index_diff END) AS sms_received_cross_index_diff,
    MAX(CASE WHEN sms_received_yn = 0 THEN customer_count END) AS sms_not_received_customer_count,
    MAX(CASE WHEN sms_received_yn = 0 THEN group_cross_index_diff END) AS sms_not_received_cross_index_diff,
    MAX(CASE WHEN sms_received_yn = 1 THEN group_cross_index_diff END)
        - MAX(CASE WHEN sms_received_yn = 0 THEN group_cross_index_diff END) AS estimated_sms_effect
FROM with_diff
GROUP BY pre_cross_index_band;


CREATE TABLE report_cross_adjusted_by_age_band AS
WITH age_summary AS (
    SELECT
        COALESCE(age_band, '미상') AS age_band,
        sms_received_yn,
        COUNT(*) AS customer_count,
        CAST(SUM(product_total_count_2512) AS DECIMAL(18, 6))
            / NULLIF(COUNT(CASE WHEN satisfied_item_count_2512 >= 1 THEN 1 END), 0) AS group_cross_index_2512,
        CAST(SUM(product_total_count_2606) AS DECIMAL(18, 6))
            / NULLIF(COUNT(CASE WHEN satisfied_item_count_2606 >= 1 THEN 1 END), 0) AS group_cross_index_2606
    FROM mart_cross_customer_compare
    GROUP BY COALESCE(age_band, '미상'), sms_received_yn
),
with_diff AS (
    SELECT
        age_band,
        sms_received_yn,
        customer_count,
        group_cross_index_2606 - group_cross_index_2512 AS group_cross_index_diff
    FROM age_summary
)
SELECT
    age_band,
    MAX(CASE WHEN sms_received_yn = 1 THEN customer_count END) AS sms_received_customer_count,
    MAX(CASE WHEN sms_received_yn = 1 THEN group_cross_index_diff END) AS sms_received_cross_index_diff,
    MAX(CASE WHEN sms_received_yn = 0 THEN customer_count END) AS sms_not_received_customer_count,
    MAX(CASE WHEN sms_received_yn = 0 THEN group_cross_index_diff END) AS sms_not_received_cross_index_diff,
    MAX(CASE WHEN sms_received_yn = 1 THEN group_cross_index_diff END)
        - MAX(CASE WHEN sms_received_yn = 0 THEN group_cross_index_diff END) AS estimated_sms_effect
FROM with_diff
GROUP BY age_band;


CREATE TABLE report_cross_adjusted_by_tenure_band AS
WITH tenure_summary AS (
    SELECT
        tenure_band,
        sms_received_yn,
        COUNT(*) AS customer_count,
        CAST(SUM(product_total_count_2512) AS DECIMAL(18, 6))
            / NULLIF(COUNT(CASE WHEN satisfied_item_count_2512 >= 1 THEN 1 END), 0) AS group_cross_index_2512,
        CAST(SUM(product_total_count_2606) AS DECIMAL(18, 6))
            / NULLIF(COUNT(CASE WHEN satisfied_item_count_2606 >= 1 THEN 1 END), 0) AS group_cross_index_2606
    FROM mart_cross_customer_compare
    GROUP BY tenure_band, sms_received_yn
),
with_diff AS (
    SELECT
        tenure_band,
        sms_received_yn,
        customer_count,
        group_cross_index_2606 - group_cross_index_2512 AS group_cross_index_diff
    FROM tenure_summary
)
SELECT
    tenure_band,
    MAX(CASE WHEN sms_received_yn = 1 THEN customer_count END) AS sms_received_customer_count,
    MAX(CASE WHEN sms_received_yn = 1 THEN group_cross_index_diff END) AS sms_received_cross_index_diff,
    MAX(CASE WHEN sms_received_yn = 0 THEN customer_count END) AS sms_not_received_customer_count,
    MAX(CASE WHEN sms_received_yn = 0 THEN group_cross_index_diff END) AS sms_not_received_cross_index_diff,
    MAX(CASE WHEN sms_received_yn = 1 THEN group_cross_index_diff END)
        - MAX(CASE WHEN sms_received_yn = 0 THEN group_cross_index_diff END) AS estimated_sms_effect
FROM with_diff
GROUP BY tenure_band;


CREATE TABLE report_cross_adjusted_by_channel_active AS
WITH channel_summary AS (
    SELECT
        COALESCE(channel_active_yn, 'N') AS channel_active_yn,
        sms_received_yn,
        COUNT(*) AS customer_count,
        CAST(SUM(product_total_count_2512) AS DECIMAL(18, 6))
            / NULLIF(COUNT(CASE WHEN satisfied_item_count_2512 >= 1 THEN 1 END), 0) AS group_cross_index_2512,
        CAST(SUM(product_total_count_2606) AS DECIMAL(18, 6))
            / NULLIF(COUNT(CASE WHEN satisfied_item_count_2606 >= 1 THEN 1 END), 0) AS group_cross_index_2606
    FROM mart_cross_customer_compare
    GROUP BY COALESCE(channel_active_yn, 'N'), sms_received_yn
),
with_diff AS (
    SELECT
        channel_active_yn,
        sms_received_yn,
        customer_count,
        group_cross_index_2606 - group_cross_index_2512 AS group_cross_index_diff
    FROM channel_summary
)
SELECT
    channel_active_yn,
    MAX(CASE WHEN sms_received_yn = 1 THEN customer_count END) AS sms_received_customer_count,
    MAX(CASE WHEN sms_received_yn = 1 THEN group_cross_index_diff END) AS sms_received_cross_index_diff,
    MAX(CASE WHEN sms_received_yn = 0 THEN customer_count END) AS sms_not_received_customer_count,
    MAX(CASE WHEN sms_received_yn = 0 THEN group_cross_index_diff END) AS sms_not_received_cross_index_diff,
    MAX(CASE WHEN sms_received_yn = 1 THEN group_cross_index_diff END)
        - MAX(CASE WHEN sms_received_yn = 0 THEN group_cross_index_diff END) AS estimated_sms_effect
FROM with_diff
GROUP BY channel_active_yn;
