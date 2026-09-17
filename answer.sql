-- Step 1: Generate a Big Table (2 Million Rows)
CREATE TABLE orders (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  customer_id INT,
  amount NUMERIC(10,2),
  status TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

INSERT INTO orders (customer_id, amount, status, created_at)
SELECT
  (random()*50000)::int,
  (random()*500)::numeric(10,2),
  (ARRAY['pending','shipped','delivered'])[ceil(random()*3)],
  now() - (random()*365)::int * interval '1 day'
FROM generate_series(1, 2000000);

ANALYZE orders;

-- Step 2: Measure the Slow Query (Before Index)
EXPLAIN (ANALYZE, BUFFERS)
SELECT customer_id, SUM(amount)
FROM orders
WHERE status = 'pending'
  AND created_at > now() - interval '30 days'
GROUP BY customer_id
ORDER BY SUM(amount) DESC
LIMIT 10;

/* 
-- OBSERVATION BEFORE INDEX:
-- The execution plan uses a Sequential Scan across the entire 2-million-row table.
-- Execution Time is high because it has to check every single row and filter them in memory/disk.
*/

-- Step 3: Add a Targeted Index and Re-Measure
CREATE INDEX idx_pending_recent
ON orders (created_at DESC, customer_id)
WHERE status = 'pending';

-- Re-run EXPLAIN ANALYZE to compare results
EXPLAIN (ANALYZE, BUFFERS)
SELECT customer_id, SUM(amount)
FROM orders
WHERE status = 'pending'
  AND created_at > now() - interval '30 days'
GROUP BY customer_id
ORDER BY SUM(amount) DESC
LIMIT 10;

/* 
-- OBSERVATION AFTER INDEX:
-- The execution plan shifts to a Bitmap Index Scan (or Index Scan) utilizing 'idx_pending_recent'.
-- Execution Time drops significantly because the partial index pre-filters only 'pending' orders and sorts them by date, 
-- avoiding unnecessary disk I/O.
*/

-- Step 4: Observe Isolation Levels Notes
/*
-- TRANSACTION ISOLATION BEHAVIOR OBSERVATIONS:
1. Read Committed (Default):
   - In Session 1, if we run SELECT amount WHERE id = 1, and Session 2 updates and commits a new amount (e.g., 9999), 
     running the SELECT query again in Session 1 *will* reflect the updated value (Non-Repeatable Read behavior).
2. Repeatable Read:
   - If Session 1 starts with 'BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;', it takes a snapshot of the data. 
     Even if Session 2 updates and commits the value for id = 1, Session 1 will *still* see the original old value until Session 1 commits or rolls back.
*/

-- Step 5: PgBouncer Configuration Reference (/etc/pgbouncer/pgbouncer.ini)
/*
[databases]
bootcamp = host=127.0.0.1 port=5432 dbname=bootcamp

[pgbouncer]
pool_mode = transaction
max_client_conn = 1000
default_pool_size = 20
listen_port = 6432
*/
