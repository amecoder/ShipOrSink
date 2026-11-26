# Distributed SQL / NewSQL 가이드

> **작성일**: 2026-05-01
> **기반 표준**: TiDB Docs, CockroachDB Docs, YugabyteDB Docs, Google Spanner 논문/운영 모델
> **적용 수준**: 분산 SQL 도입을 검토하는 팀의 운영 표준

---

## 1. 목적

Distributed SQL/NewSQL은 기존 RDBMS의 SQL과 트랜잭션 모델을 유지하면서 수평 확장, 고가용성, 지역 배치, 일부 HTAP 요구를 해결하려는 데이터베이스 계열이다.

대표 후보:

| 계열 | 예시 | 호환성 방향 | 주 사용처 |
|------|------|-------------|-----------|
| MySQL-compatible distributed SQL | TiDB | MySQL protocol/syntax 중심 | 대규모 OLTP, HTAP |
| PostgreSQL-compatible distributed SQL | CockroachDB, YugabyteDB | PostgreSQL wire/query 호환 중심 | 글로벌 OLTP, multi-region |
| Globally distributed SQL | Spanner | 독자 SQL/TrueTime 기반 | 글로벌 강한 일관성 |

이 계열은 "기존 DB보다 좋은 기본값"이 아니다. 운영 복잡도, 장애 표면, 비용, 지연 시간, 호환성 차이를 감수할 명확한 이유가 있을 때만 선택한다.

---

## 2. 도입 판단

### 2.1 적합한 경우

- 단일 Primary DB로 write scale을 감당하기 어렵다.
- 고가용성과 자동 failover가 제품 요구사항이다.
- 지역별 데이터 배치나 multi-region latency 요구가 있다.
- OLTP 데이터에 가까운 실시간 분석이 필요하다.
- 샤딩을 직접 운영하는 비용이 분산 SQL 운영 비용보다 크다.

### 2.2 부적합한 경우

- MVP 또는 초기 제품이다.
- 쿼리 최적화, 인덱스, 캐싱, read replica를 아직 시도하지 않았다.
- 데이터 모델 경계가 불명확하다.
- 팀에 DB 운영/관측/장애 대응 역량이 없다.
- "MySQL/PostgreSQL과 호환된다"는 이유만으로 drop-in replacement를 기대한다.

---

## 3. 선택 매트릭스

| 질문 | PostgreSQL/MySQL 유지 | Distributed SQL 검토 |
|------|----------------------|----------------------|
| write scale | 단일 primary로 충분 | 수평 write scale 필요 |
| availability | managed RDBMS Multi-AZ로 충분 | DB 계층 자체의 강한 HA 요구 |
| multi-region | read replica 또는 app-level 전략 가능 | 지역 배치/글로벌 트랜잭션 요구 |
| analytics | ETL/warehouse 허용 | 최신 OLTP 데이터 분석 필요 |
| 운영 역량 | 일반 RDBMS 운영 중심 | 분산 consensus/replication 관측 가능 |
| 비용 | 단순 비용 최적화 | 복잡도 증가를 감수할 명확한 ROI |

---

## 4. 모델링 원칙

### 4.1 Hotspot 회피

분산 SQL은 데이터 분산이 핵심이다. 단조 증가 키, 특정 tenant로 몰리는 write, 순차 timestamp 인덱스는 병목을 만들 수 있다.

권장:

- UUID v7, ULID, snowflake-style ID 등 분산 친화 ID를 검토한다.
- tenant_id가 있는 경우 shard/partition/region 배치 전략을 명확히 한다.
- 고쓰기 테이블의 primary key와 secondary index를 부하 테스트한다.

### 4.2 트랜잭션 범위

- 트랜잭션은 짧고 명확한 비즈니스 유스케이스에 묶는다.
- aggregate 경계를 넘어서는 쓰기는 도메인 이벤트, outbox, saga를 우선 검토한다.
- distributed SQL이 ACID를 제공하더라도 큰 트랜잭션은 충돌, 지연 시간, 재시도 비용을 키운다.

### 4.3 호환성 검증

호환성은 반드시 실제 애플리케이션 기준으로 검증한다.

- ORM migration 생성 SQL
- lock, unique constraint, generated ID
- DDL
- collation/timezone/date function
- query planner hint
- bulk insert/update
- backup/restore
- CDC/replication

---

## 5. 운영 기준

### 5.1 필수 관측 항목

- query latency p50/p95/p99
- transaction conflict/retry
- slow query
- node health
- replica/region distribution
- replication lag
- storage growth
- backup status
- failover event
- connection pool saturation

### 5.2 필수 Runbook

- connection storm
- slow query and bad plan
- node failure
- storage pressure
- replication lag
- failed migration
- backup restore
- version upgrade
- managed service incident

---

## 6. 도입 프로세스

1. `DATABASE_DECISION_RECORD.md` 작성
2. 현재 DB로 해결 가능한지 검토
3. 실제 쿼리/마이그레이션/ORM으로 PoC
4. 장애/백업/복구/업그레이드 리허설
5. 읽기 전용 shadow traffic 또는 dual-read 검증
6. 제한된 scope에서 cutover
7. runbook, dashboard, on-call handoff 완료

---

## 7. 체크리스트

- [ ] 도입 이유가 수치로 증명됨
- [ ] source of truth가 명확함
- [ ] 기존 DB 유지 대안을 검토함
- [ ] 호환성 차이를 문서화함
- [ ] 실제 마이그레이션을 staging에서 실행함
- [ ] backup/restore를 테스트함
- [ ] p95/p99 latency와 conflict를 측정함
- [ ] 운영 dashboard와 alert가 있음
- [ ] 장애 대응 runbook이 있음
- [ ] 비용과 scaling limit을 승인받음

---

## 8. 관련 문서

- `common/rules/database-governance.md`
- `common/rules/distributed-sql.md`
- `common/templates/DATABASE_DECISION_RECORD.md`
- `common/templates/DISTRIBUTED_SQL_READINESS_CHECKLIST.md`
- `docs/guides/tidb-adoption-guide.md`
