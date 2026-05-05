"""Integration tests: full dqlens-dbt flow against a real Postgres database.

Requires:
    - PostgreSQL with demo seed data loaded
    - Environment variables: PG_HOST, PG_USER, PG_PASS, PG_DATABASE
      (or a DQLENS_TEST_DB connection URL)

Run:
    # Load env vars from dqlens/.internal/.env first
    source ../dqlens/.internal/.env
    pytest tests/test_integration.py -v

Skip if no database:
    Tests are skipped if PG_HOST is not set and localhost:5432 is not reachable.
"""

from __future__ import annotations

import os
import shutil
from pathlib import Path

import pytest
import yaml


def _pg_available() -> bool:
    """Check if Postgres is reachable."""
    import socket
    host = os.environ.get("PG_HOST", "localhost")
    port = int(os.environ.get("PG_PORT", "5432"))
    try:
        sock = socket.create_connection((host, port), timeout=5)
        sock.close()
        return True
    except (OSError, ConnectionRefusedError):
        return False


requires_postgres = pytest.mark.skipif(
    not os.environ.get("PG_HOST") and not _pg_available(),
    reason="No PostgreSQL available (set PG_HOST or run Postgres locally)",
)


def _generate_profiles_yml(dest: Path) -> None:
    """Generate profiles.yml from environment variables."""
    profiles = {
        "dqlens_test": {
            "target": "dev",
            "outputs": {
                "dev": {
                    "type": "postgres",
                    "host": os.environ.get("PG_HOST", "localhost"),
                    "port": int(os.environ.get("PG_PORT", "5432")),
                    "user": os.environ.get("PG_USER", "dqlens"),
                    "password": os.environ.get("PG_PASS", "dqlens"),
                    "dbname": os.environ.get("PG_DATABASE", "dqlens_test"),
                    "schema": "public",
                    "threads": 1,
                }
            }
        }
    }
    with open(dest / "profiles.yml", "w") as f:
        yaml.dump(profiles, f, default_flow_style=False)


@requires_postgres
class TestFullFlow:
    """End-to-end: profile via dbt config, generate tests, verify output."""

    @pytest.fixture
    def work_dir(self, tmp_path):
        """Copy the test project to a temp dir and generate profiles.yml."""
        test_project = Path(__file__).parent / "test_project"
        dest = tmp_path / "project"
        shutil.copytree(test_project, dest)
        # Generate real profiles.yml from env vars
        _generate_profiles_yml(dest)
        return dest

    def test_profile_reads_dbt_config(self, work_dir, monkeypatch):
        """dqlens-dbt profile should read profiles.yml and connect."""
        monkeypatch.chdir(work_dir)
        monkeypatch.setenv("DBT_PROFILES_DIR", str(work_dir))

        from click.testing import CliRunner

        from dqlens_dbt.cli import main

        runner = CliRunner()
        result = runner.invoke(main, ["profile"])

        assert result.exit_code == 0, f"Failed: {result.output}"
        assert "Profiled" in result.output
        assert (work_dir / ".dqlens" / "baselines" / "latest.yaml").exists()

    def test_generate_tests_creates_yaml(self, work_dir, monkeypatch):
        """After profiling, generate-tests should create valid YAML."""
        monkeypatch.chdir(work_dir)
        monkeypatch.setenv("DBT_PROFILES_DIR", str(work_dir))

        from click.testing import CliRunner

        from dqlens_dbt.cli import main

        runner = CliRunner()

        # First profile
        result = runner.invoke(main, ["profile"])
        assert result.exit_code == 0, f"Profile failed: {result.output}"

        # Then generate tests
        output_path = str(work_dir / "models" / "_dqlens_tests.yml")
        result = runner.invoke(main, ["generate-tests", "--output", output_path])
        assert result.exit_code == 0, f"Generate failed: {result.output}"

        # Verify output
        output_file = Path(output_path)
        assert output_file.exists()

        with open(output_file) as f:
            content = f.read()

        yaml_lines = [l for l in content.split("\n") if not l.startswith("#")]
        data = yaml.safe_load("\n".join(yaml_lines))

        assert data["version"] == 2
        assert len(data["models"]) > 0

        for model in data["models"]:
            assert "dqlens" in model["tags"]
            assert len(model["columns"]) > 0

    def test_run_does_both(self, work_dir, monkeypatch):
        """The 'run' command should profile + generate in one step."""
        monkeypatch.chdir(work_dir)
        monkeypatch.setenv("DBT_PROFILES_DIR", str(work_dir))

        from click.testing import CliRunner

        from dqlens_dbt.cli import main

        runner = CliRunner()
        output_path = str(work_dir / "models" / "_dqlens_tests.yml")
        result = runner.invoke(main, ["run", "--output", output_path])

        assert result.exit_code == 0, f"Run failed: {result.output}"
        assert Path(output_path).exists()
