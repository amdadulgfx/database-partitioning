# PostgreSQL Declarative Range Partitioning Demo

A hands-on demonstration comparing unpartitioned vs. declaratively partitioned tables in PostgreSQL, highlighting performance differences and operational benefits.

## Overview

This project benchmarks **3 million rows** across two identical table schemas:
- `sales_unpartitioned` — Baseline monolithic table
- `sales_partitioned` — Declarative RANGE partition by year (2024, 2025, 2026)

## Table Schema

| Column | Type | Notes |
|---|---|---|
| `id` | INT | Primary key component |
| `order_date` | DATE | Partition key for `sales_partitioned` |
| `customer_id` | INT | Indexed for joins |
| `amount` | NUMERIC(10, 2) | Transaction value |

## Scripts

| Order | Script | Description |
|---|---|---|
| 1 | `01_setup_tables.sql` | Creates both tables + 3 yearly partitions (2024–2026) |
| 2 | `02_seed_data.sql` | Seeds 1M rows per year (3M total) |
| 3 | `03_benchmark_queries.sql` | Side-by-side `EXPLAIN ANALYZE` comparisons |

## Setup

### 1. Start PostgreSQL

Using Docker:

```bash
docker run -d \
  --name postgres-partition-demo \
  -e POSTGRES_DB=postgres \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=secret \
  -p 5432:5432 \
  postgres:16-alpine
```

### 2. Run the Scripts

```bash
docker exec -i postgres-partition-demo psql -U postgres < 01_setup_tables.sql
docker exec -i postgres-partition-demo psql -U postgres < 02_seed_data.sql
```

Or interactively:

```bash
docker exec -it postgres-partition-demo psql -U postgres
```

Then run each file with `\i /path/to/script.sql`.

## Running Benchmarks

Open `03_benchmark_queries.sql` in your SQL client. Each section compares the same query on both tables with `EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)`.

Key results to capture:

| Query Type | Unpartitioned (ms) | Partitioned (ms) |
|---|---|---|
| Single Year Range (2025) | | |
| Multi-Year Range (2 years) | | |
| 2024 Data Deletion | | |
| 2024 Partition Drop | N/A | |

## What to Expect

### Partition Pruning

Queries like:

```sql
SELECT ... FROM sales_partitioned
WHERE order_date >= '2025-01-01' AND order_date < '2026-01-01';
```

Should show in the explain plan:

```
->  Index Scan on sales_2025
   ->  Index Cond: ((order_date >= '2025-01-01') AND (order_date < '2026-01-01'))
```

While `sales_unpartitioned` does a full table scan.

### Data Lifecycle

- **Unpartitioned DELETE**: Scans table, marks rows as dead, requires `VACUUM`
- **Partitioned DROP**: Instant file removal, no transaction log bloat

## Cleanup

```bash
docker stop postgres-partition-demo
docker rm postgres-partition-demo
```

## Requirements

- PostgreSQL 11+ (declarative partitioning introduced in PG10, but PG11+ has full support)
- Docker (optional, for containerized testing)
- ~500MB disk space for 3M rows