/*
문자마케팅 교차지수 분석 테이블 생성 SQL

수정 위치:
1. src_customer_monthly_features CTE를 실제 고객 기준월 상품/활동 테이블로 교체
2. src_sms_campaign_send CTE를 실제 문자 발송 테이블로 교체
3. params CTE의 만족 기준을 내부 기준에 맞게 조정
*/

CREATE TABLE mart_cross_population AS
WITH
params AS (
    SELECT
        '2025-12' AS pre_month,
        '2026-06' AS post_month,
        DATE '2026-01-01' AS campaign_start_date,
        DATE '2026-06-30' AS campaign_end_date,
        100000 AS min_deposit_amt,
        50000 AS min_banca_amt,
        300000 AS min_salary_transfer_amt,
        1000 AS min_fx_remittance_usd_amt
),
src_customer_monthly_features AS (
    SELECT
        customer_id,
        base_month,
        installment_savings_amt,
        lump_savings_amt,
        trust_amt,
        fund_amt,
        bancassurance_amt,
        subscription_savings_amt,
        personal_pension_amt,
        retirement_pension_amt,
        mortgage_loan_balance,
        other_loan_balance,
        salary_transfer_cnt_3m,
        auto_transfer_cnt_3m,
        withdrawal_transfer_cnt_3m,
        digital_login_cnt_3m,
        fx_remittance_usd_amt,
        hana_money_login_cnt_3m,
        customer_grade,
        age_band,
        tenure_months,
        channel_active_yn,
        is_test_customer,
        is_closed_customer
    FROM source.customer_monthly_features
),
src_sms_campaign_send AS (
    SELECT
        customer_id,
        send_date,
        campaign_id,
        send_status
    FROM source.sms_campaign_send
),
sms_target AS (
    SELECT DISTINCT
        s.customer_id,
        1 AS sms_received_yn
    FROM src_sms_campaign_send s
    CROSS JOIN params p
    WHERE s.send_status = 'SENT'
      AND s.send_date BETWEEN p.campaign_start_date AND p.campaign_end_date
),
eligible_customer AS (
    SELECT
        f.customer_id,
        MAX(CASE WHEN f.base_month = p.pre_month THEN 1 ELSE 0 END) AS has_pre_month,
        MAX(CASE WHEN f.base_month = p.post_month THEN 1 ELSE 0 END) AS has_post_month
    FROM src_customer_monthly_features f
    CROSS JOIN params p
    WHERE f.base_month IN (p.pre_month, p.post_month)
      AND COALESCE(f.is_test_customer, 0) = 0
      AND COALESCE(f.is_closed_customer, 0) = 0
    GROUP BY f.customer_id
    HAVING MAX(CASE WHEN f.base_month = p.pre_month THEN 1 ELSE 0 END) = 1
       AND MAX(CASE WHEN f.base_month = p.post_month THEN 1 ELSE 0 END) = 1
)
SELECT
    e.customer_id,
    COALESCE(t.sms_received_yn, 0) AS sms_received_yn,
    e.has_pre_month,
    e.has_post_month,
    CASE WHEN e.has_pre_month = 1 AND e.has_post_month = 1 THEN 1 ELSE 0 END AS analysis_included_yn
FROM eligible_customer e
LEFT JOIN sms_target t
    ON e.customer_id = t.customer_id;


CREATE TABLE mart_cross_customer_month AS
WITH
params AS (
    SELECT
        '2025-12' AS pre_month,
        '2026-06' AS post_month,
        DATE '2026-01-01' AS campaign_start_date,
        DATE '2026-06-30' AS campaign_end_date,
        100000 AS min_deposit_amt,
        50000 AS min_banca_amt,
        300000 AS min_salary_transfer_amt,
        1000 AS min_fx_remittance_usd_amt
),
src_customer_monthly_features AS (
    SELECT
        customer_id,
        base_month,
        installment_savings_amt,
        lump_savings_amt,
        trust_amt,
        fund_amt,
        bancassurance_amt,
        subscription_savings_amt,
        personal_pension_amt,
        retirement_pension_amt,
        mortgage_loan_balance,
        other_loan_balance,
        salary_transfer_cnt_3m,
        auto_transfer_cnt_3m,
        withdrawal_transfer_cnt_3m,
        digital_login_cnt_3m,
        fx_remittance_usd_amt,
        hana_money_login_cnt_3m,
        customer_grade,
        age_band,
        tenure_months,
        channel_active_yn,
        is_test_customer,
        is_closed_customer
    FROM source.customer_monthly_features
),
item_flags AS (
    SELECT
        f.customer_id,
        f.base_month,
        p2.sms_received_yn,
        f.customer_grade,
        f.age_band,
        f.tenure_months,
        f.channel_active_yn,

        CASE WHEN COALESCE(f.installment_savings_amt, 0) >= p.min_deposit_amt THEN 1 ELSE 0 END AS installment_savings_satisfied,
        CASE WHEN COALESCE(f.lump_savings_amt, 0) >= p.min_deposit_amt THEN 1 ELSE 0 END AS lump_savings_satisfied,
        CASE WHEN COALESCE(f.trust_amt, 0) >= p.min_deposit_amt THEN 1 ELSE 0 END AS trust_satisfied,
        CASE WHEN COALESCE(f.fund_amt, 0) >= p.min_deposit_amt THEN 1 ELSE 0 END AS fund_satisfied,
        CASE WHEN COALESCE(f.bancassurance_amt, 0) >= p.min_banca_amt THEN 1 ELSE 0 END AS bancassurance_satisfied,
        CASE WHEN COALESCE(f.subscription_savings_amt, 0) >= p.min_deposit_amt THEN 1 ELSE 0 END AS subscription_savings_satisfied,
        CASE WHEN COALESCE(f.personal_pension_amt, 0) >= p.min_deposit_amt THEN 1 ELSE 0 END AS personal_pension_satisfied,
        CASE WHEN COALESCE(f.retirement_pension_amt, 0) >= p.min_deposit_amt THEN 1 ELSE 0 END AS retirement_pension_satisfied,
        CASE WHEN COALESCE(f.mortgage_loan_balance, 0) > 0 THEN 1 ELSE 0 END AS mortgage_loan_satisfied,
        CASE WHEN COALESCE(f.other_loan_balance, 0) > 0 THEN 1 ELSE 0 END AS other_loan_satisfied,
        CASE WHEN COALESCE(f.salary_transfer_cnt_3m, 0) >= 2 THEN 1 ELSE 0 END AS salary_transfer_satisfied,
        CASE WHEN COALESCE(f.auto_transfer_cnt_3m, 0) >= 2 THEN 1 ELSE 0 END AS auto_transfer_satisfied,
        CASE WHEN COALESCE(f.withdrawal_transfer_cnt_3m, 0) >= 1 THEN 1 ELSE 0 END AS withdrawal_transfer_satisfied,
        CASE WHEN COALESCE(f.digital_login_cnt_3m, 0) >= 1 THEN 1 ELSE 0 END AS digital_satisfied,
        CASE WHEN COALESCE(f.fx_remittance_usd_amt, 0) >= p.min_fx_remittance_usd_amt THEN 1 ELSE 0 END AS fx_remittance_satisfied,
        CASE WHEN COALESCE(f.hana_money_login_cnt_3m, 0) >= 1 THEN 1 ELSE 0 END AS hana_money_satisfied
    FROM src_customer_monthly_features f
    INNER JOIN mart_cross_population p2
        ON f.customer_id = p2.customer_id
       AND p2.analysis_included_yn = 1
    CROSS JOIN params p
    WHERE f.base_month IN (p.pre_month, p.post_month)
      AND COALESCE(f.is_test_customer, 0) = 0
      AND COALESCE(f.is_closed_customer, 0) = 0
)
SELECT
    customer_id,
    base_month,
    sms_received_yn,
    customer_grade,
    age_band,
    tenure_months,
    channel_active_yn,
    installment_savings_satisfied,
    lump_savings_satisfied,
    trust_satisfied,
    fund_satisfied,
    bancassurance_satisfied,
    subscription_savings_satisfied,
    personal_pension_satisfied,
    retirement_pension_satisfied,
    mortgage_loan_satisfied,
    other_loan_satisfied,
    salary_transfer_satisfied,
    auto_transfer_satisfied,
    withdrawal_transfer_satisfied,
    digital_satisfied,
    fx_remittance_satisfied,
    hana_money_satisfied,
    (
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
    ) AS satisfied_item_count,
    (
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
    ) AS product_total_count,
    CAST((
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
    ) AS DECIMAL(18, 6)) / NULLIF(CASE WHEN (
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
    ) >= 1 THEN 1 ELSE 0 END, 0) AS customer_cross_index
FROM item_flags;


CREATE TABLE mart_cross_customer_compare AS
WITH
pre AS (
    SELECT *
    FROM mart_cross_customer_month
    WHERE base_month = '2025-12'
),
post AS (
    SELECT *
    FROM mart_cross_customer_month
    WHERE base_month = '2026-06'
)
SELECT
    pre.customer_id,
    pre.sms_received_yn,
    pre.customer_grade,
    pre.age_band,
    pre.tenure_months,
    pre.channel_active_yn,

    pre.satisfied_item_count AS satisfied_item_count_2512,
    pre.product_total_count AS product_total_count_2512,
    pre.customer_cross_index AS customer_cross_index_2512,

    post.satisfied_item_count AS satisfied_item_count_2606,
    post.product_total_count AS product_total_count_2606,
    post.customer_cross_index AS customer_cross_index_2606,

    post.satisfied_item_count - pre.satisfied_item_count AS satisfied_item_count_diff,
    post.product_total_count - pre.product_total_count AS product_total_count_diff,
    post.customer_cross_index - pre.customer_cross_index AS customer_cross_index_diff,

    CASE
        WHEN pre.satisfied_item_count = 0 AND post.satisfied_item_count >= 1 THEN '신규만족'
        WHEN pre.satisfied_item_count >= 1 AND post.satisfied_item_count = 0 THEN '이탈'
        WHEN pre.satisfied_item_count >= 1 AND post.satisfied_item_count > pre.satisfied_item_count THEN '유지개선'
        WHEN post.satisfied_item_count = pre.satisfied_item_count THEN '유지동일'
        WHEN post.satisfied_item_count < pre.satisfied_item_count THEN '악화'
        ELSE '기타'
    END AS movement_type,

    CASE
        WHEN pre.satisfied_item_count = 0 THEN '0개'
        WHEN pre.satisfied_item_count = 1 THEN '1개'
        WHEN pre.satisfied_item_count = 2 THEN '2개'
        WHEN pre.satisfied_item_count BETWEEN 3 AND 4 THEN '3~4개'
        ELSE '5개 이상'
    END AS pre_satisfied_item_count_band,

    CASE
        WHEN pre.customer_cross_index IS NULL THEN '미산출'
        WHEN pre.customer_cross_index < 1 THEN '1 미만'
        WHEN pre.customer_cross_index < 2 THEN '1~2 미만'
        WHEN pre.customer_cross_index < 3 THEN '2~3 미만'
        ELSE '3 이상'
    END AS pre_cross_index_band,

    CASE
        WHEN pre.tenure_months IS NULL THEN '미상'
        WHEN pre.tenure_months < 12 THEN '1년 미만'
        WHEN pre.tenure_months < 36 THEN '1~3년 미만'
        WHEN pre.tenure_months < 60 THEN '3~5년 미만'
        ELSE '5년 이상'
    END AS tenure_band
FROM pre
INNER JOIN post
    ON pre.customer_id = post.customer_id;
