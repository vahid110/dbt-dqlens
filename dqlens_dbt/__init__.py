"""dbt-dqlens: Bridge between DQLens and dbt.

This package provides:
- CLI commands to profile dbt models and generate test YAML
- A Python API for programmatic use

Usage:
    dqlens-dbt profile          # profile all models in target schema
    dqlens-dbt generate-tests   # generate _dqlens_tests.yml
"""

__version__ = "0.1.0"
