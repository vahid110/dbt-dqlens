# dbt-dqlens

[![CI](https://github.com/vahid110/dbt-dqlens/actions/workflows/ci.yml/badge.svg)](https://github.com/vahid110/dbt-dqlens/actions/workflows/ci.yml)
[![PyPI](https://img.shields.io/pypi/v/dbt-dqlens)](https://pypi.org/project/dbt-dqlens/)

> Data quality for dbt, without writing tests.

dbt-dqlens brings auto-generated data quality checks into your dbt project. It profiles your models, detects problems (null spikes, orphaned records, schema drift, outliers), and exposes findings as native dbt tests and a queryable model.

You don't write tests. DQLens writes them for you.

## Quick Start

### 1. Install

Add to your `packages.yml`:

```yaml
packages:
  - package: vahid110/dbt_dqlens
    version: 0.1.0
```

Then:

```bash
pip install dqlens
dbt deps
```

### 2. Profile your models

After `dbt run`, profile your warehouse:

```bash
dbt run-operation dqlens_profile
```

This connects to your warehouse (using your dbt profile), profiles every model, and stores baselines in a `_dqlens` schema.

### 3. Generate tests

```bash
dbt run-operation dqlens_generate_tests
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
dbt run                          (your models build as usual)
    |
dbt run-operation dqlens_profile (DQLens profiles the output tables)
    |
dbt run-operation dqlens_generate_tests  (auto-generates schema.yml tests)
    |
dbt test --select tag:dqlens     (runs the generated tests)
```

DQLens reads your dbt `profiles.yml` to connect to the same warehouse. No double configuration.

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
- Python with `dqlens` installed (`pip install dqlens`)
- PostgreSQL, Snowflake, or BigQuery (PostgreSQL for MVP)

## License

MIT
