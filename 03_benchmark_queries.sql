-- ============================================================================
-- PostgreSQL Declarative Range Partitioning Demo
-- Step 3: Benchmark Queries
-- ============================================================================
-- Run these queries with EXPLAIN ANALYZE to compare:
--   1. Range scan performance on unpartitioned vs partitioned tables
--   2. Partition pruning effectiveness
--   3. Data lifecycle management (DELETE vs DROP TABLE)
-- ============================================================================

-- ============================================================================
-- SECTION 1: Partition Pruning Benchmark
-- Query targeting a specific year (2025) - should hit only sales_2025 partition
-- ============================================================================

-- --- UNPARTITIONED: Full table scan with index filter ---
-- Expected: Seq Scan on sales_unpartitioned (millions of rows)
-- Time complexity: O(n) - must scan entire table

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT
    COUNT(*) AS total_orders,
    SUM(amount) AS total_revenue,
    AVG(amount) AS avg_order_value
FROM sales_unpartitioned
WHERE order_date >= '2025-01-01' AND order_date < '2026-01-01';

-- --- PARTITIONED: Pruned to single partition ---
-- Expected: Index Scan on sales_2025 only (pruning sales_2024 and sales_2026)
-- Time complexity: O(1M) - scans only relevant partition

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT
    COUNT(*) AS total_orders,
    SUM(amount) AS total_revenue,
    AVG(amount) AS avg_order_value
FROM sales_partitioned
WHERE order_date >= '2025-01-01' AND order_date < '2026-01-01';

-- ============================================================================
-- SECTION 2: Date Range Performance Comparison
-- Query spanning multiple partitions vs unpartitioned table
-- ============================================================================

-- --- UNPARTITIONED: Must scan all rows ---
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT
    EXTRACT(YEAR FROM order_date) AS year,
    COUNT(*) AS orders,
    SUM(amount) AS revenue
FROM sales_unpartitioned
WHERE order_date >= '2024-01-01' AND order_date < '2026-07-01'
GROUP BY EXTRACT(YEAR FROM order_date)
ORDER BY year;

-- --- PARTITIONED: Automatically prunes irrelevant partitions ---
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT
    EXTRACT(YEAR FROM order_date) AS year,
    COUNT(*) AS orders,
    SUM(amount) AS revenue
FROM sales_partitioned
WHERE order_date >= '2024-01-01' AND order_date < '2026-07-01'
GROUP BY EXTRACT(YEAR FROM order_date)
ORDER BY year;

-- ============================================================================
-- SECTION 3: Point Lookup Performance
-- Query for specific date range (single month)
-- ============================================================================

-- --- UNPARTITIONED ---
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT *
FROM sales_unpartitioned
WHERE order_date = '2025-06-15'
ORDER BY id;

-- --- PARTITIONED (should use partition pruning + index on partition) ---
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT *
FROM sales_partitioned
WHERE order_date = '2025-06-15'
ORDER BY id;

-- ============================================================================
-- SECTION 4: Data Lifecycle Management
-- ============================================================================
-- Demonstrates the key operational advantage of partitioning:
-- Instant data removal via DROP TABLE vs slow DELETE operation
-- ============================================================================

-- --- STEP 1: Record starting sizes ---
SELECT
    'sales_unpartitioned' AS table_name,
    pg_size_pretty(pg_total_relation_size('sales_unpartitioned')) AS total_size,
    COUNT(*) AS row_count
FROM sales_unpartitioned
WHERE order_date < '2024-01-01';

SELECT
    'sales_partitioned' AS table_name,
    pg_size_pretty(pg_total_relation_size('sales_partitioned')) AS total_size,
    COUNT(*) AS row_count
FROM sales_partitioned
WHERE order_date < '2024-01-01';

-- --- STEP 2: UNPARTITIONED - Slow DELETE (archived data removal) ---
-- This scans the entire table, marks rows as dead tuples, and vacuums
-- For 1M rows, this can take 30-60+ seconds depending on hardware

EXPLAIN (ANALYZE, BUFFERS)
DELETE FROM sales_unpartitioned
WHERE order_date >= '2024-01-01' AND order_date < '2025-01-01';

-- --- STEP 3: PARTITIONED - Instant archival (DROP PARTITION) ---
-- This instantly removes the entire partition file from disk
-- No table scan, no VACUUM needed, no transaction log bloat
-- Execution time: < 100ms regardless of partition size

-- First, detach the partition (allows for backup/recovery window)
-- ALTER TABLE sales_partitioned DETACH PARTITION sales_2024;

-- Then drop it entirely (instant operation)
-- DROP TABLE sales_2024;

-- Or combine in one statement (PostgreSQL 11+):
-- DROP TABLE IF EXISTS sales_2024;

-- --- STEP 4: Verify sizes after archival ---

-- For unpartitioned (after DELETE completes):
-- SELECT
--     'sales_unpartitioned' AS table_name,
--     pg_size_pretty(pg_total_relation_size('sales_unpartitioned')) AS total_size,
--     COUNT(*) AS row_count
-- FROM sales_unpartitioned;

-- For partitioned (after DROP):
-- SELECT
--     'sales_partitioned' AS table_name,
--     pg_size_pretty(pg_total_relation_size('sales_partitioned')) AS total_size,
--     COUNT(*) AS row_count
-- FROM sales_partitioned;

-- ============================================================================
-- SECTION 5: Aggregate Performance Test
-- Heavy aggregation query to stress both architectures
-- ============================================================================

-- --- UNPARTITIONED: Full table aggregation ---
EXPLAIN (ANALYZE, TIMING, BUFFERS)
SELECT
    customer_id,
    COUNT(*) AS order_count,
    SUM(amount) AS lifetime_value,
    MIN(order_date) AS first_purchase,
    MAX(order_date) AS last_purchase
FROM sales_unpartitioned
GROUP BY customer_id
HAVING COUNT(*) > 50
ORDER BY lifetime_value DESC
LIMIT 20;

-- --- PARTITIONED: Same query, should prune during scan ---
EXPLAIN (ANALYZE, TIMING, BUFFERS)
SELECT
    customer_id,
    COUNT(*) AS order_count,
    SUM(amount) AS lifetime_value,
    MIN(order_date) AS first_purchase,
    MAX(order_date) AS last_purchase
FROM sales_partitioned
GROUP BY customer_id
HAVING COUNT(*) > 50
ORDER BY lifetime_value DESC
LIMIT 20;

-- ============================================================================
-- RESULTS LOG (for your article)
-- Copy the "Execution Time" values from EXPLAIN ANALYZE output below:
-- ============================================================================

/*
| Query Type                    | Unpartitioned (ms) | Partitioned (ms) | Speedup |
|-------------------------------|--------------------|--------------------|--------|
| Single Year Range (2025)      |                    |                    |        |
| Multi-Year Range (2 years)    |                    |                    |        |
| Single Day Point Lookup       |                    |                    |        |
| 2024 Data Deletion            |                    |                    |        |
| 2024 Partition Drop           | N/A                |                    |        |
| Customer Aggregation (TOP 20)  |                    |                    |        |
*/
