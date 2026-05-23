-- ============================================================================
-- PostgreSQL Declarative Range Partitioning Demo
-- Step 2: Data Seeding
-- ============================================================================
\timing on

TRUNCATE TABLE sales_unpartitioned RESTART IDENTITY;
TRUNCATE TABLE sales_partitioned;

-- 2024 (1M rows)
INSERT INTO sales_unpartitioned (id, order_date, customer_id, amount)
SELECT gs, DATE '2024-01-01' + (gs % 365), (gs * 17 % 100000) + 1, (gs * 31 % 100000)::NUMERIC / 100 + 0.01
FROM generate_series(1, 1000000) gs;

-- 2025 (1M rows)
INSERT INTO sales_unpartitioned (id, order_date, customer_id, amount)
SELECT gs + 1000000, DATE '2025-01-01' + (gs % 365), (gs * 17 % 100000) + 1, (gs * 31 % 100000)::NUMERIC / 100 + 0.01
FROM generate_series(1, 1000000) gs;

-- 2026 (1M rows)
INSERT INTO sales_unpartitioned (id, order_date, customer_id, amount)
SELECT gs + 2000000, DATE '2026-01-01' + (gs % 365), (gs * 17 % 100000) + 1, (gs * 31 % 100000)::NUMERIC / 100 + 0.01
FROM generate_series(1, 1000000) gs;

-- Copy to partitioned
INSERT INTO sales_partitioned (id, order_date, customer_id, amount)
SELECT id, order_date, customer_id, amount FROM sales_unpartitioned;

-- Verify
SELECT 'Unpartitioned' AS table_name, COUNT(*) AS rows FROM sales_unpartitioned
UNION ALL SELECT 'Partitioned', COUNT(*) FROM sales_partitioned;
