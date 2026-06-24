/*
품질 검증 SQL

각 쿼리는 이상 건수를 반환합니다.
issue_count가 0이면 통과로 봅니다.
*/

-- 1. 모집단 고객 중복
SELECT
    'mart_cross_population duplicate customer' AS check_name,
    COUNT(*) AS issue_count
FROM (
    SELECT customer_id
    FROM mart_cross_population
    GROUP BY customer_id
    HAVING COUNT(*) > 1
) d;

-- 2. 모집단 분석 포함 여부 검증
SELECT
    'population must have both months and be included' AS check_name,
    COUNT(*) AS issue_count
FROM mart_cross_population
WHERE has_pre_month <> 1
   OR has_post_month <> 1
   OR analysis_included_yn <> 1;

-- 3. 고객ID + 기준월 중복
SELECT
    'mart_cross_customer_month duplicate customer/month' AS check_name,
    COUNT(*) AS issue_count
FROM (
    SELECT customer_id, base_month
    FROM mart_cross_customer_month
    GROUP BY customer_id, base_month
    HAVING COUNT(*) > 1
) d;

-- 4. 분석 고객이 두 기준월을 모두 갖는지 확인
SELECT
    'customer must have both 2025-12 and 2026-06' AS check_name,
    COUNT(*) AS issue_count
FROM (
    SELECT customer_id
    FROM mart_cross_customer_month
    GROUP BY customer_id
    HAVING COUNT(DISTINCT base_month) <> 2
) d;

-- 5. 문자 수신 여부 값 검증
SELECT
    'sms_received_yn must be 0 or 1' AS check_name,
    COUNT(*) AS issue_count
FROM mart_cross_customer_month
WHERE sms_received_yn NOT IN (0, 1)
   OR sms_received_yn IS NULL;

-- 6. 16개 항목 flag 값 검증
SELECT
    'item flags must be 0 or 1' AS check_name,
    COUNT(*) AS issue_count
FROM mart_cross_customer_month
WHERE installment_savings_satisfied NOT IN (0, 1)
   OR lump_savings_satisfied NOT IN (0, 1)
   OR trust_satisfied NOT IN (0, 1)
   OR fund_satisfied NOT IN (0, 1)
   OR bancassurance_satisfied NOT IN (0, 1)
   OR subscription_savings_satisfied NOT IN (0, 1)
   OR personal_pension_satisfied NOT IN (0, 1)
   OR retirement_pension_satisfied NOT IN (0, 1)
   OR mortgage_loan_satisfied NOT IN (0, 1)
   OR other_loan_satisfied NOT IN (0, 1)
   OR salary_transfer_satisfied NOT IN (0, 1)
   OR auto_transfer_satisfied NOT IN (0, 1)
   OR withdrawal_transfer_satisfied NOT IN (0, 1)
   OR digital_satisfied NOT IN (0, 1)
   OR fx_remittance_satisfied NOT IN (0, 1)
   OR hana_money_satisfied NOT IN (0, 1);

-- 7. 만족항목수가 0~16 범위인지 확인
SELECT
    'satisfied_item_count must be between 0 and 16' AS check_name,
    COUNT(*) AS issue_count
FROM mart_cross_customer_month
WHERE satisfied_item_count < 0
   OR satisfied_item_count > 16;

-- 8. 만족항목수 재계산 검증
SELECT
    'satisfied_item_count recalculation mismatch' AS check_name,
    COUNT(*) AS issue_count
FROM mart_cross_customer_month
WHERE satisfied_item_count <> (
    installment_savings_satisfied
    + lump_savings_satisfied
    + trust_satisfied
    + fund_satisfied
    + bancassurance_satisfied
    + subscription_savings_satisfied
    + personal_pension_satisfied
    + retirement_pension_satisfied
    + mortgage_loan_satisfied
    + other_loan_satisfied
    + salary_transfer_satisfied
    + auto_transfer_satisfied
    + withdrawal_transfer_satisfied
    + digital_satisfied
    + fx_remittance_satisfied
    + hana_money_satisfied
);

-- 9. 비교 테이블 고객 중복 검증
SELECT
    'customer cross index recalculation mismatch' AS check_name,
    COUNT(*) AS issue_count
FROM mart_cross_customer_month
WHERE (
        satisfied_item_count >= 1
        AND ABS(customer_cross_index - product_total_count) > 0.000001
    )
   OR (
        satisfied_item_count = 0
        AND customer_cross_index IS NOT NULL
    );

-- 10. 비교 테이블 고객 중복 검증
SELECT
    'mart_cross_customer_compare duplicate customer' AS check_name,
    COUNT(*) AS issue_count
FROM (
    SELECT customer_id
    FROM mart_cross_customer_compare
    GROUP BY customer_id
    HAVING COUNT(*) > 1
) d;

-- 11. 문자 수신군 + 미수신군 = 전체 고객수
SELECT
    'sms group count must equal total customer count' AS check_name,
    CASE
        WHEN SUM(customer_count_2606) = (SELECT COUNT(*) FROM mart_cross_customer_compare)
        THEN 0 ELSE 1
    END AS issue_count
FROM report_cross_group_summary;

-- 12. 그룹 교차지수 재계산 검증
WITH recalculated AS (
    SELECT
        sms_received_yn,
        CAST(SUM(CASE WHEN base_month = '2025-12' THEN product_total_count ELSE 0 END) AS DECIMAL(18, 6))
            / NULLIF(COUNT(DISTINCT CASE WHEN base_month = '2025-12' AND satisfied_item_count >= 1 THEN customer_id END), 0) AS group_cross_index_2512,
        CAST(SUM(CASE WHEN base_month = '2026-06' THEN product_total_count ELSE 0 END) AS DECIMAL(18, 6))
            / NULLIF(COUNT(DISTINCT CASE WHEN base_month = '2026-06' AND satisfied_item_count >= 1 THEN customer_id END), 0) AS group_cross_index_2606
    FROM mart_cross_customer_month
    GROUP BY sms_received_yn
)
SELECT
    'group cross index recalculation mismatch' AS check_name,
    COUNT(*) AS issue_count
FROM report_cross_group_summary r
INNER JOIN recalculated c
    ON r.sms_received_yn = c.sms_received_yn
WHERE ABS(r.group_cross_index_2512 - c.group_cross_index_2512) > 0.000001
   OR ABS(r.group_cross_index_2606 - c.group_cross_index_2606) > 0.000001;
