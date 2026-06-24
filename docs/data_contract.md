# 데이터 계약

이 분석은 아래 3개 원천 영역이 있다고 가정합니다. 실제 DB의 테이블명과 컬럼명이 다르면 `sql/01_build_analysis_tables.sql` 상단의 `src_*` CTE만 수정하면 됩니다.

## 1. 고객 기준월 상품/활동 테이블

권장 테이블명: `source.customer_monthly_features`

| 컬럼 | 설명 |
|---|---|
| `customer_id` | 고객 식별자 |
| `base_month` | 기준월, 예: `2025-12` |
| `installment_savings_amt` | 적립식 잔액 또는 인정금액 |
| `lump_savings_amt` | 거치식 잔액 또는 인정금액 |
| `trust_amt` | 신탁 잔액 또는 인정금액 |
| `fund_amt` | 집합투자 잔액 또는 인정금액 |
| `bancassurance_amt` | 방카 잔액 또는 인정금액 |
| `subscription_savings_amt` | 청약 잔액 또는 인정금액 |
| `personal_pension_amt` | 개인연금 잔액 또는 인정금액 |
| `retirement_pension_amt` | 퇴직연금 잔액 또는 인정금액 |
| `mortgage_loan_balance` | 담보대출 잔액 |
| `other_loan_balance` | 기타대출 잔액 |
| `salary_transfer_cnt_3m` | 최근 3개월 급여성 입금 횟수 |
| `auto_transfer_cnt_3m` | 최근 3개월 자동이체 또는 입출금이체 횟수 |
| `withdrawal_transfer_cnt_3m` | 최근 3개월 출금이체 횟수 |
| `digital_login_cnt_3m` | 최근 3개월 디지털 로그인 횟수 |
| `fx_remittance_usd_amt` | 환전/송금 USD 환산금액 |
| `hana_money_login_cnt_3m` | 최근 3개월 하나머니 로그인 횟수 |
| `customer_grade` | 고객등급 |
| `age_band` | 연령대 |
| `tenure_months` | 거래기간, 개월 |
| `channel_active_yn` | 채널활성 여부 |
| `is_test_customer` | 테스트 고객 여부 |
| `is_closed_customer` | 해지/탈회 고객 여부 |

## 2. 문자마케팅 발송 테이블

권장 테이블명: `source.sms_campaign_send`

| 컬럼 | 설명 |
|---|---|
| `customer_id` | 고객 식별자 |
| `send_date` | 문자 발송일 |
| `campaign_id` | 캠페인 식별자 |
| `send_status` | 발송 상태, 성공 기준값 예: `SENT` |

분석 기준은 2026년 1월 1일부터 2026년 6월 30일까지 문자 발송 성공 이력이 있는 고객을 `문자수신`으로 봅니다.

## 3. 16개 항목 만족 기준

기본 임계값은 `sql/01_build_analysis_tables.sql`의 `params` CTE에 정의되어 있습니다. 내부 기준이 다르면 이 CTE의 값만 수정합니다.

