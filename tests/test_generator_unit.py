"""Unit tests for the dbt test YAML generator."""

import tempfile
from pathlib import Path

import yaml

from dqlens.models import ColumnProfile, DatabaseProfile, TableProfile
from dqlens_dbt.test_generator import generate_dbt_tests


def _col(**kwargs):
    defaults = {
        "name": "id",
        "data_type": "integer",
        "nullable": False,
        "row_count": 1000,
        "null_count": 0,
        "null_pct": 0.0,
        "distinct_count": 1000,
        "distinct_pct": 100.0,
        "is_unique": True,
        "is_primary_key": True,
    }
    defaults.update(kwargs)
    return ColumnProfile(**defaults)


def _profile(tables):
    from datetime import datetime, timezone
    return DatabaseProfile(
        connection_url="",
        schema_name="public",
        tables=tables,
        profiled_at=datetime.now(timezone.utc),
    )


class TestGenerateDbtTests:
    def test_generates_unique_not_null_for_pk(self, tmp_path):
        table = TableProfile(
            schema_name="public",
            table_name="orders",
            row_count=1000,
            columns=[_col(name="id")],
        )
        profile = _profile([table])

        output = tmp_path / "tests.yml"
        path = generate_dbt_tests(profile, output_path=str(output))

        assert path == str(output)
        assert output.exists()

        with open(output) as f:
            content = f.read()

        # Skip the comment header
        yaml_content = "\n".join(
            line for line in content.split("\n")
            if not line.startswith("#")
        )
        data = yaml.safe_load(yaml_content)

        assert data["version"] == 2
        assert len(data["models"]) == 1
        model = data["models"][0]
        assert model["name"] == "orders"
        assert "dqlens" in model["tags"]

        col = model["columns"][0]
        assert col["name"] == "id"
        assert "unique" in col["tests"]
        assert "not_null" in col["tests"]

    def test_generates_null_drift_test(self, tmp_path):
        table = TableProfile(
            schema_name="public",
            table_name="orders",
            row_count=1000,
            columns=[
                _col(
                    name="email", is_primary_key=False, is_unique=False,
                    null_count=32, null_pct=3.2, distinct_count=900,
                ),
            ],
        )
        baseline_table = TableProfile(
            schema_name="public",
            table_name="orders",
            row_count=1000,
            columns=[
                _col(
                    name="email", is_primary_key=False, is_unique=False,
                    null_count=1, null_pct=0.1, distinct_count=900,
                ),
            ],
        )
        profile = _profile([table])
        baseline = _profile([baseline_table])

        output = tmp_path / "tests.yml"
        generate_dbt_tests(profile, baseline=baseline, output_path=str(output))

        with open(output) as f:
            content = f.read()

        yaml_content = "\n".join(
            line for line in content.split("\n") if not line.startswith("#")
        )
        data = yaml.safe_load(yaml_content)

        col = data["models"][0]["columns"][0]
        test_names = []
        for t in col["tests"]:
            if isinstance(t, dict):
                test_names.extend(t.keys())
            else:
                test_names.append(t)

        assert "dqlens_no_null_drift" in test_names

    def test_generates_empty_string_test(self, tmp_path):
        table = TableProfile(
            schema_name="public",
            table_name="users",
            row_count=1000,
            columns=[
                _col(
                    name="bio", data_type="text",
                    is_primary_key=False, is_unique=False,
                    null_count=0, null_pct=0.0,
                    distinct_count=800,
                    empty_string_count=150, empty_string_pct=15.0,
                ),
            ],
        )
        profile = _profile([table])

        output = tmp_path / "tests.yml"
        generate_dbt_tests(profile, output_path=str(output))

        with open(output) as f:
            content = f.read()

        yaml_content = "\n".join(
            line for line in content.split("\n") if not line.startswith("#")
        )
        data = yaml.safe_load(yaml_content)

        col = data["models"][0]["columns"][0]
        test_names = []
        for t in col["tests"]:
            if isinstance(t, dict):
                test_names.extend(t.keys())
            else:
                test_names.append(t)

        assert "dqlens_no_empty_strings" in test_names

    def test_generates_outlier_test(self, tmp_path):
        table = TableProfile(
            schema_name="public",
            table_name="orders",
            row_count=1000,
            columns=[
                _col(
                    name="amount", is_primary_key=False, is_unique=False,
                    null_count=0, null_pct=0.0,
                    distinct_count=500,
                    min_value=1.0, max_value=500.0,
                    p25=20.0, p50=50.0, p75=100.0, p95=200.0,
                ),
            ],
        )
        profile = _profile([table])

        output = tmp_path / "tests.yml"
        generate_dbt_tests(profile, output_path=str(output))

        with open(output) as f:
            content = f.read()

        yaml_content = "\n".join(
            line for line in content.split("\n") if not line.startswith("#")
        )
        data = yaml.safe_load(yaml_content)

        col = data["models"][0]["columns"][0]
        test_names = []
        for t in col["tests"]:
            if isinstance(t, dict):
                test_names.extend(t.keys())
            else:
                test_names.append(t)

        assert "dqlens_no_outliers" in test_names

    def test_generates_fk_test(self, tmp_path):
        table = TableProfile(
            schema_name="public",
            table_name="orders",
            row_count=1000,
            columns=[
                _col(
                    name="customer_id", is_primary_key=False, is_unique=False,
                    null_count=0, null_pct=0.0,
                    distinct_count=200,
                    is_foreign_key=True,
                    fk_target_table="customers",
                    fk_target_column="id",
                ),
            ],
        )
        profile = _profile([table])

        output = tmp_path / "tests.yml"
        generate_dbt_tests(profile, output_path=str(output))

        with open(output) as f:
            content = f.read()

        yaml_content = "\n".join(
            line for line in content.split("\n") if not line.startswith("#")
        )
        data = yaml.safe_load(yaml_content)

        col = data["models"][0]["columns"][0]
        test_names = []
        for t in col["tests"]:
            if isinstance(t, dict):
                test_names.extend(t.keys())
            else:
                test_names.append(t)

        assert "dqlens_no_orphans" in test_names

    def test_empty_profile_returns_empty(self, tmp_path):
        profile = _profile([])
        output = tmp_path / "tests.yml"
        path = generate_dbt_tests(profile, output_path=str(output))
        assert path == ""
