# SQL 기반 문자마케팅 교차지수 분석

문자마케팅 수신 고객의 교차지수 증가폭이 미수신 고객보다 큰지 검증하기 위한 SQL 분석 템플릿입니다.

## 사용 순서

1. [docs/data_contract.md](docs/data_contract.md)의 원천 테이블 계약에 맞춰 실제 테이블/컬럼명을 매핑합니다.
2. [sql/01_build_analysis_tables.sql](sql/01_build_analysis_tables.sql)의 `src_*` CTE를 실제 원천 테이블로 교체합니다.
3. `mart_cross_population`, `mart_cross_customer_month`, `mart_cross_customer_compare`를 생성합니다.
4. [sql/02_report_queries.sql](sql/02_report_queries.sql)를 실행해 보고서용 결과를 생성합니다.
5. [tests/quality_checks.sql](tests/quality_checks.sql)를 실행해 중복, 누락, 산식 오류를 검증합니다.

## 생성되는 주요 테이블

| 테이블 | 용도 |
|---|---|
| `mart_cross_population` | 문자 수신 여부와 분석 포함 모집단 고정 |
| `mart_cross_customer_month` | 고객별/월별 16개 항목 만족 여부 |
| `mart_cross_customer_compare` | 고객별 25.12 vs 26.06 전후 비교 |
| `report_cross_group_summary` | 문자 수신/미수신 그룹별 교차지수 요약 |
| `report_cross_sms_effect` | 문자효과 추정값 |
| `report_cross_item_contribution` | 16개 항목별 증가 기여도 |
| `report_cross_customer_movement` | 신규만족/개선/유지/악화/이탈 이동 분석 |
| `report_cross_adjusted_*` | 기준월 상태, 등급, 연령, 거래기간, 채널활성 기준 보정 분석 |

## 핵심 지표

```text
그룹 교차지수 = 상품합계수 / 만족손님수
고객 교차지수 = 고객별 상품합계수 / 고객별 만족손님수, 단 고객별 만족손님수는 만족항목수 >= 1이면 1
문자효과 추정 = 문자수신군 교차지수 증가폭 - 문자미수신군 교차지수 증가폭
```

## 기본 가정

- 기준월은 `2025-12`, `2026-06`입니다.
- 분석 모집단은 두 기준월 모두 관측 가능한 고객입니다.
- 만족손님수는 16개 항목 중 1개 이상 만족한 고객 수입니다.
- 문자 수신 여부는 고객 단위로 부여합니다.
- SQL은 ANSI SQL에 가깝게 작성했으며, 날짜/문자열 함수는 사용하는 DB에 맞게 조정할 수 있습니다.
