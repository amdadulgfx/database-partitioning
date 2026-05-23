-- ============================================================================
-- PostgreSQL Declarative Range Partitioning Demo
-- Step 1: Schema Setup
-- ============================================================================
-- This script creates two identical table architectures:
--   1. sales_unpartitioned  - A monolithic table (baseline)
--   2. sales_partitioned   - A partitioned table with 3 yearly partitions
-- ============================================================================

-- Drop existing objects if they exist (clean slate)
DROP TABLE IF EXISTS sales_unpartitioned CASCADE;
DROP TABLE IF EXISTS sales_partitioned CASCADE;

-- ============================================================================
-- UNPARTITIONED TABLE (Baseline)
-- Standard B-tree index on order_date for fair comparison
-- ============================================================================
CREATE TABLE sales_unpartitioned (
    id          SERIAL,
    order_date  DATE        NOT NULL,
    customer_id INT,
    amount      NUMERIC(10, 2),
    PRIMARY KEY (id, order_date)
);

-- Index on order_date for range queries (simulates typical production workload)
CREATE INDEX idx_unpartitioned_order_date ON sales_unpartitioned (order_date);

COMMENT ON TABLE sales_unpartitioned IS 'Baseline: monolithic sales table without partitioning';

-- ============================================================================
-- PARTITIONED TABLE (Target Architecture)
-- Declarative RANGE partitioning on order_date column
-- ============================================================================
CREATE TABLE sales_partitioned (
    id          INT,
    order_date  DATE        NOT NULL,
    customer_id INT,
    amount      NUMERIC(10, 2)
) PARTITION BY RANGE (order_date);

COMMENT ON TABLE sales_partitioned IS 'Target: partitioned sales table using RANGE partitioning on order_date';

-- ============================================================================
-- EXPLICIT PARTITION DEFINITIONS
-- Three yearly partitions covering 2024, 2025, and 2026
-- ============================================================================

-- Partition for year 2024 (inclusive start, exclusive end)
CREATE TABLE sales_2024 PARTITION OF sales_partitioned
    FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');

-- Partition for year 2025 (inclusive start, exclusive end)
CREATE TABLE sales_2025 PARTITION OF sales_partitioned
    FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');

-- Partition for year 2026 (inclusive start, exclusive end)
CREATE TABLE sales_2026 PARTITION OF sales_partitioned
    FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');

COMMENT ON TABLE sales_2024 IS 'Partition for 2024 sales data';
COMMENT ON TABLE sales_2025 IS 'Partition for 2025 sales data';
COMMENT ON TABLE sales_2026 IS 'Partition for 2026 sales data';

-- ============================================================================
-- VERIFICATION QUERIES (Optional - run after 02_seed_data.sql)
-- ============================================================================
-- SELECT
--     'Unpartitioned' AS table_type,
--     COUNT(*) AS total_rows
-- FROM sales_unpartitioned
-- UNION ALL
-- SELECT
--     'Partitioned',
--     COUNT(*)
-- FROM sales_partitioned;

-- SELECT
--     child.relname      AS partition_name,
--     pg_size_pretty(pg_relation_size(child.oid)) AS partition_size
-- FROM pg_inherits
-- JOIN pg_class parent ON pg_inherits.inhparent = parent.oid
-- JOIN pg_class child  ON pg_inherits.inhrelid   = child.oid
-- WHERE parent.relname = 'sales_partitioned'
-- ORDER BY child.relname;
