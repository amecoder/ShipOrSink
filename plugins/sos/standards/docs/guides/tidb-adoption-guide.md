# TiDB 도입 가이드

> **작성일**: 2026-05-01
> **기반 표준**: TiDB Stable Docs, TiKV Docs, TiFlash Docs, TiDB MySQL Compatibility Docs
> **적용 수준**: TiDB/TiDB Cloud 도입 검토 및 운영 표준

---

## 1. TiDB의 위치

TiDB는 MySQL 프로토콜과 일반적인 MySQL 문법을 제공하는 분산 SQL/NewSQL 데이터베이스다. 핵심 가치는 다음이다.

- SQL 기반 OLTP를 수평 확장
- TiKV 기반 분산 트랜잭션과 고가용성
- TiFlash를 통한 HTAP/near-real-time analytics
- MySQL 생태계와의 높은 수준의 호환성

단, TiDB는 MySQL과 완전히 동일한 데이터베이스가 아니다. MySQL 호환성은 PoC와 통합 테스트로 검증해야 한다.

---

## 2. 아키텍처 요약

| 컴포넌트 | 역할 | 운영 포인트 |
|----------|------|-------------|
| TiDB Server | stateless SQL layer, MySQL protocol endpoint | 수평 확장, connection/load balancing |
| PD | placement driver, metadata, scheduling, transaction ID allocation | quorum, scheduling health, dashboard |
| TiKV | row-oriented distributed transactional KV storage | region, raft, leader distribution, storage |
| TiFlash | columnar analytical replica | HTAP, table replica, workload isolation |

TiDB Server는 데이터를 직접 저장하지 않는다. SQL parsing, optimization, distributed execution plan을 담당하고 실제 데이터 요청은 TiKV 또는 TiFlash로 전달한다.

---

## 3. 도입이 맞는 경우

- MySQL 호환성이 중요한 대규모 OLTP 시스템이다.
- 단일 MySQL/PostgreSQL primary에서 write scale이 한계에 도달했다.
- sharding을 직접 구현/운영하는 비용이 높다.
- 운영 데이터에 가까운 분석 쿼리를 warehouse ETL 없이 처리해야 한다.
- managed TiDB Cloud를 사용할 수 있고 운영 책임 범위가 명확하다.

## 4. 도입이 맞지 않는 경우

- MVP 또는 초기 제품이다.
- 단일 RDBMS, read replica, cache, index 최적화를 아직 소진하지 않았다.
- 복잡한 분산 DB 운영을 감당할 팀/관측 체계가 없다.
- MySQL compatibility를 100% drop-in replacement로 기대한다.
- 데이터가 작고 트랜잭션/쿼리 패턴이 단순하다.

---

## 5. MySQL 호환성 검증

TiDB 공식 문서는 MySQL과의 차이를 명확히 설명한다. 다음 항목은 반드시 테스트한다.

- `EXPLAIN`과 query plan 해석 차이
- built-in function 지원 범위
- online DDL과 `ALTER TABLE` 제한
- unsupported partition syntax
- non-updatable view
- character set, collation, SQL mode 기본값
- generated ID와 auto-increment 동작
- pessimistic transaction lock 차이
- ORM migration이 생성하는 SQL

검증 기준:

- 실제 migration을 TiDB에 적용한다.
- 주요 repository integration test를 TiDB에서 실행한다.
- slow query와 query plan을 staging 데이터 크기로 확인한다.
- MySQL에서 되던 SQL이 TiDB에서 warning으로 무시되는지 확인한다.

---

## 6. TiFlash 사용 기준

TiFlash는 모든 테이블에 기본 적용하지 않는다.

적합한 경우:

- 최신 OLTP 데이터에 가까운 analytical query가 필요하다.
- warehouse ETL 지연을 줄여야 한다.
- row-store OLTP 부하와 analytical scan 부하를 분리해야 한다.

주의:

- TiFlash는 TiKV 데이터를 columnar replica로 복제한다.
- 테이블 단위 replica를 명시적으로 구성한다.
- TiFlash node는 가능하면 TiKV와 분리해 workload isolation을 확보한다.
- pushdown 지원 여부에 따라 쿼리 성능이 달라진다.

---

## 7. 운영 관측

필수 dashboard:

- TiDB Server query latency p50/p95/p99
- QPS, connection count, connection pool saturation
- slow query count
- transaction conflict/retry
- PD health, scheduling, store status
- TiKV region count, leader distribution, raftstore CPU
- TiKV storage, compaction, IO, write stall
- TiFlash replica sync progress and query latency
- backup status and restore rehearsal result

필수 runbook:

- slow query and bad plan
- transaction conflict spike
- PD leader issue
- TiKV node failure
- TiFlash replica lag
- DDL or migration failure
- backup restore
- version upgrade

---

## 8. 마이그레이션 접근

1. Database Decision Record 작성
2. 현재 MySQL/PostgreSQL에서 한계가 되는 쿼리와 지표 수집
3. TiDB Cloud 또는 self-managed PoC 구성
4. schema migration 적용
5. integration test와 load test 실행
6. backup/restore 리허설
7. read-only shadow traffic 검증
8. 제한된 tenant 또는 기능부터 cutover
9. rollback 또는 forward-fix 경로 검증

---

## 9. Barim 같은 MVP에서의 권장

초기 제품은 PostgreSQL 중심으로 시작한다. TiDB는 다음 조건이 생긴 뒤 검토한다.

- 문서/회의록/이벤트 데이터 규모가 단일 DB 운영 한계를 넘는다.
- multi-tenant write throughput이 병목이다.
- 운영 데이터 분석을 거의 실시간으로 제공해야 한다.
- TiDB Cloud 비용과 운영 책임을 감당할 수 있다.

MVP에서는 TiDB를 직접 도입하기보다 `DATABASE_DECISION_RECORD.md`와 `DISTRIBUTED_SQL_READINESS_CHECKLIST.md`를 통해 미래 도입 기준만 준비하는 것이 적절하다.

---

## 10. 공식 문서

- TiDB Architecture: https://docs.pingcap.com/tidb/stable/tidb-architecture/
- TiKV Overview: https://docs.pingcap.com/tidb/stable/tikv-overview/
- TiFlash Overview: https://docs.pingcap.com/tidbcloud/tiflash-overview/
- MySQL Compatibility: https://docs.pingcap.com/tidb/stable/mysql-compatibility/
