# dbt-dqlens: Native dbt Approach (No CLI)

## The Problem

Users expect `dbt run-operation dqlens_profile` to work inside dbt without dropping
to a separate CLI. Our current approach requires a Python CLI step (`dqlens-dbt profile`)
which breaks the dbt-native workflow. First user feedback (Ian Andriot) confirmed this
is confusing.

## The Challenge

dbt macros (Jinja + SQL) cannot:
- Import Python packages
- Write files to disk
- Run subprocess commands

So we can't call the DQLens Python profiler from inside a dbt macro. We need a
pure-SQL approach that works entirely within dbt's execution model.

## The Proposal: Pure SQL Profiling + Dynamic Test Macros

### Architecture

```
dbt run                                    (user's models build as usual)
    |
dbt run --select dqlens_profile            (profiles all tables, stores in warehouse)
    |
dbt test --select tag:dqlens               (test macros read profiles, compare, flag)
```

No CLI. No YAML generation. No file writing. Everything stays in dbt.

### How it works

**Step 1: Profile model (`dqlens_profile`)**

A dbt model (materialized as table) that profiles every column in the target schema
using SQL aggregates:

```sql
-- For each table and column, compute:
SELECT
    'orders' as table_name,
    'email' as column_name,
    COUNT(*) as row_count,
    SUM(CASE WHEN email IS NULL THEN 1 ELSE 0 END) as null_count,
    ROUND(null_count::numeric / NULLIF(row_count, 0) * 100, 2) as null_pct,
    COUNT(DISTINCT email) as distinct_count,
    -- ... more stats
    CURRENT_TIMESTAMP as profiled_at
FROM orders
```

This produces a `dqlens_profile_results` table in the warehouse with one row per
column per table.

**Step 2: Baseline storage**

A second model (`dqlens_baseline`) that stores the previous profile for comparison:

```sql
-- On each run, the current profile becomes the new baseline
-- The previous baseline is kept for drift comparison
SELECT * FROM {{ ref('dqlens_profile_results') }}
WHERE profiled_at < (SELECT MAX(profiled_at) FROM {{ ref('dqlens_profile_results') }})
```

Or simpler: use an incremental model that appends each profile run, and the test
macros compare the latest two.

**Step 3: Dynamic test macros**

Custom dbt tests that read from the profile table and compare against baseline:

```sql
-- test: dqlens_null_drift
-- Fails if any column's null rate increased more than 3x from baseline

SELECT
    current.table_name,
    current.column_name,
    current.null_pct as current_null_pct,
    baseline.null_pct as baseline_null_pct
FROM {{ ref('dqlens_profile_results') }} current
JOIN {{ ref('dqlens_baseline') }} baseline
    ON current.table_name = baseline.table_name
    AND current.column_name = baseline.column_name
WHERE current.null_pct > baseline.null_pct * 3
    AND current.null_pct > 1  -- ignore trivial changes
```

If this query returns rows, the test fails. Each row is a finding.

### What gets profiled (per column)

| Metric | SQL | Use |
|---|---|---|
| row_count | `COUNT(*)` | Row count anomalies |
| null_count | `SUM(CASE WHEN col IS NULL THEN 1 ELSE 0 END)` | Null drift |
| null_pct | `null_count / row_count * 100` | Null drift |
| distinct_count | `COUNT(DISTINCT col)` | Uniqueness checks |
| min_value | `MIN(col)` | Range drift |
| max_value | `MAX(col)` | Range drift |
| empty_string_count | `SUM(CASE WHEN col = '' THEN 1 ELSE 0 END)` | Empty string detection |
| data_type | From information_schema | Schema drift |

### Test macros included

| Test | What it catches | Fails when |
|---|---|---|
| `dqlens_null_drift` | Null rate spike | null_pct increased > 3x from baseline |
| `dqlens_schema_drift` | Columns added/removed/type changed | Column set differs from baseline |
| `dqlens_row_count_anomaly` | Unusual growth/shrinkage | Row count changed > 30% |
| `dqlens_empty_strings` | Columns full of '' | Empty string rate > 30% |
| `dqlens_freshness` | Stale data | Max timestamp older than threshold |

## How Elementary Does It (Competitor Analysis)

Elementary's approach:

1. **Monitoring models**: dbt models that query `information_schema` and compute stats.
   Materialized as tables. Run as part of `dbt run`.

2. **Anomaly detection tests**: Custom generic tests (`elementary.volume_anomalies`,
   `elementary.freshness_anomalies`, etc.) that users add to their schema.yml manually.

3. **Historical storage**: An incremental model that stores all past profiles.
   Anomaly detection compares current values against a time-series of historical values.

4. **Configuration required**: Users must add Elementary tests to each model in schema.yml:
   ```yaml
   models:
     - name: orders
       tests:
         - elementary.volume_anomalies
         - elementary.freshness_anomalies
   ```

5. **CLI for reporting only**: `edr` CLI generates a dashboard from the stored results.
   Core profiling and testing is dbt-native.

### Where Elementary falls short (user feedback from dbt Slack)

- "Anomaly was not that accurate, so we stopped" (Karthik)
- "Noisy, get warnings for both drops and increases" (johannes.muller)
- "Tables with too little fresh data will be ignored" (johannes.muller)
- Requires manual configuration per model (not auto-generated)

### How DQLens would differ

| Aspect | Elementary | dbt-dqlens |
|---|---|---|
| Configuration | Manual (add tests per model) | Auto (profile discovers what to check) |
| Detection method | Statistical time-series anomaly | Baseline comparison (deterministic) |
| Noise level | High (statistical models guess) | Low (compares against last known state) |
| Setup | Add tests to schema.yml per model | Run one command, checks all models |
| First run | Needs history to detect anomalies | Works on first run (profile = baseline) |

## Implementation Plan

### Phase 1: Profile model (pure SQL)

- Macro that generates a UNION ALL query profiling every table/column in the schema
- Uses `information_schema` to discover tables and columns
- Computes null_count, distinct_count, min, max, empty_string_count per column
- Materializes as an incremental table (appends each run)

### Phase 2: Baseline comparison

- View or model that identifies the "previous" profile for each table/column
- Simple: second-most-recent `profiled_at` timestamp per table

### Phase 3: Test macros

- Generic tests that query the profile table
- Compare current vs baseline
- Return rows where thresholds are exceeded (dbt test convention: rows = failures)

### Phase 4: Auto-application

- A macro that generates schema.yml entries automatically (or applies tests via dbt_project.yml)
- Or: a single "catch-all" test that checks ALL columns in one query

## Tests for Resilience

| Test case | What could go wrong | How to handle |
|---|---|---|
| Empty database (0 tables) | Profile query returns nothing | Return empty result, no failures |
| Table with 0 rows | Division by zero in null_pct | NULLIF in denominators |
| Column with all NULLs | distinct_count = 0, no baseline | Skip comparison, flag as finding |
| First run (no baseline) | No previous profile to compare | Profile only, no test failures |
| Schema change between runs | Column in baseline doesn't exist in current | Detect as schema drift finding |
| Very large tables | Profile query takes too long | Use sampling (TABLESAMPLE where supported) |
| Views in schema | Some aggregates may fail on complex views | Try/catch or exclude views |
| Reserved words as column names | SQL syntax errors | Quote all identifiers |
| Concurrent runs | Two profiles stored at same timestamp | Use unique run_id, not just timestamp |
| Cross-database compatibility | PERCENTILE_CONT not available everywhere | Only use basic aggregates (COUNT, MIN, MAX, AVG) |

## Corner Cases

1. **Incremental models**: Profile should run AFTER the incremental model updates,
   not before. Order matters in the DAG.

2. **Ephemeral models**: Can't be profiled (they don't exist as tables). Skip them.

3. **dbt Cloud**: No persistent filesystem. This approach works because everything
   is in the warehouse. No local files needed.

4. **Multi-schema projects**: Need to handle profiling across multiple schemas.
   Use `target.schema` as default, allow override.

5. **Large number of columns**: A table with 200 columns generates a very wide
   UNION ALL query. May hit SQL length limits on some warehouses. Batch if needed.

6. **Permissions**: User may not have access to `information_schema` or certain tables.
   Graceful skip with warning.

## Risks

| Risk | Severity | Mitigation |
|---|---|---|
| SQL dialect differences across warehouses | HIGH | Start with PostgreSQL + DuckDB only. Use dbt's cross-db macros where possible. |
| Profile query too slow on large tables | MEDIUM | Default to sampling. Let users configure full scan per table. |
| dbt version compatibility | MEDIUM | Test against dbt 1.0+. Use stable APIs only. |
| Competing with Elementary (established) | MEDIUM | Differentiate on "zero config" and "deterministic, not statistical." |
| Complexity of pure-SQL profiling | MEDIUM | Keep it simple. Basic aggregates only. No percentiles in v1. |

## Decision: Build or Not?

**Arguments for:**
- Eliminates the CLI step (the #1 user complaint)
- Works in dbt Cloud (no filesystem needed)
- Truly dbt-native (shows up in DAG, docs, lineage)
- Proven pattern (Elementary does it successfully)

**Arguments against:**
- Significant rewrite of dbt-dqlens (current approach is Python-based)
- Pure SQL is less powerful than Python profiling (no regex patterns, no IQR)
- Maintaining SQL across multiple warehouses is harder than Python
- The CLI approach works fine for local/CI usage

**Recommendation:** Build it. The CLI version stays as a power-user option. The
pure-SQL version becomes the default for dbt users. Two paths to the same result.

## Effort Estimate

| Task | Effort |
|---|---|
| Profile macro (generates SQL for all tables/columns) | 6h |
| Incremental profile storage model | 2h |
| Baseline comparison view | 2h |
| 5 test macros (null_drift, schema_drift, row_count, empty_strings, freshness) | 6h |
| Cross-database testing (PostgreSQL + DuckDB) | 4h |
| Documentation | 2h |
| Integration tests | 4h |

**Total: ~26h (~1.5 weeks)**
