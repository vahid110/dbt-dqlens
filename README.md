# dbt-dqlens

[![CI](https://github.com/vahid110/dbt-dqlens/actions/workflows/ci.yml/badge.svg)](https://github.com/vahid110/dbt-dqlens/actions/workflows/ci.yml)
[![PyPI](https://img.shields.io/pypi/v/dbt-dqlens)](https://pypi.org/project/dbt-dqlens/)

> Data quality for dbt, without writing tests.

dbt-dqlens brings auto-generated data quality checks into your dbt project. It profiles your models, detects problems (null spikes, schema drift, empty strings, row count anomalies), and runs checks as native dbt tests.

You don't write tests. DQLens writes them for you.

## Quick Start

### 1. Install

Add to your `packages.yml`:

```yaml
packages:
  - package: vahid110/dbt_dqlens
    version: 0.2.0
```

Then:

```bash
dbt deps
```

### 2. Profile your models

```bash
dbt run --select dqlens_profile_results
```

This profiles every table in your schema (null rates, distinct counts, empty strings, value ranges) and stores the results in your warehouse.

### 3. Run checks

```bash
dbt test --select tag:dqlens
```

The catch-all test compares the current profile against the previous one and flags what changed. No configuration needed.

### That's it.

Two dbt commands. No CLI. No Python. No YAML to write. Everything stays inside dbt.

## Alternative: CLI approach

If you prefer a CLI workflow (e.g., for CI pipelines outside dbt):

```bash
pip install dbt-dqlens
dqlens-dbt profile        # profiles models using your profiles.yml
dqlens-dbt generate-tests # outputs _dqlens_tests.yml
dbt test --select tag:dqlens
```

### 2. Profile your models

After `dbt run`, profile your warehouse:

```bash
dqlens-dbt profile
```

This reads your `profiles.yml`, connects to the same warehouse dbt uses, profiles every model, and stores baselines.

### 3. Generate tests

```bash
dqlens-dbt generate-tests
```

This creates a `_dqlens_tests.yml` file with auto-generated tests for every model. Review it, commit it, done.

### 4. Run tests

```bash
dbt test --select tag:dqlens
```

Your auto-generated tests run as native dbt tests. Failures show up in dbt docs, dbt Cloud, and your CI pipeline.

## What it detects

| Check | What it catches |
|---|---|
| Null drift | Null rate increased significantly from baseline |
| Schema drift | Columns added, removed, or type changed |
| Orphaned records | FK references to non-existent rows |
| Empty strings | Columns full of '' that look non-null but aren't |
| Outliers | Values beyond 1.5x IQR bounds |
| Row count anomalies | Unusual growth or shrinkage |
| Freshness | Data that hasn't been updated recently |
| Pattern violations | Values that don't match detected patterns (email, UUID, etc.) |

## How it works

```
dbt run --select dqlens_profile_results   (profiles all tables, stores in warehouse)
    |
dbt test --select tag:dqlens              (compares current vs baseline, flags changes)
```

On the first run, it profiles and stores a baseline. On subsequent runs, it compares against the previous profile and flags drift: null spikes, schema changes, row count anomalies, empty strings.

No external tools. No file writing. Everything lives in your warehouse.

## The `dqlens_findings` model

Every profiling run materializes a `dqlens_findings` table in your warehouse:

| column | type | description |
|---|---|---|
| finding_id | text | Unique identifier |
| table_name | text | Which model |
| column_name | text | Which column (null for table-level) |
| severity | text | HIGH / MEDIUM / LOW |
| category | text | null_anomaly, schema_change, fk_mismatch, etc. |
| message | text | Human-readable description |
| detail | text | Why it was flagged |
| current_value | text | Current metric value |
| baseline_value | text | Previous metric value |
| detected_at | timestamp | When the finding was detected |

Query it in your BI tool, build alerts on it, or just `SELECT * FROM dqlens.dqlens_findings WHERE severity = 'HIGH'`.

## Configuration

In your `dbt_project.yml`:

```yaml
vars:
  dqlens:
    dqlens_schema: "dqlens"        # where findings table lives
    min_severity: "MEDIUM"          # only store MEDIUM+ findings
    exclude_tables: ["staging_*"]   # skip these models
```

## vs other dbt quality packages

| | dbt_expectations | elementary | dbt-dqlens |
|---|---|---|---|
| Auto-generates tests | No | Partial | Yes |
| Requires writing config | Yes (per column) | Yes (YAML) | No |
| Drift detection | No | Yes (paid) | Yes (free) |
| Baseline comparison | No | Yes (paid) | Yes (free) |
| Outlier detection | No | Yes (paid) | Yes (free) |
| Pricing | Free | Free + paid cloud | Free |

## Requirements

- dbt-core >= 1.0.0
- Python with `dqlens` installed (`pip install dqlens[duckdb]` for DuckDB)
- Supported databases: PostgreSQL, DuckDB, SQLite, MySQL (Snowflake, BigQuery coming soon)

## License

MIT
