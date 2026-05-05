"""Unit tests for dbt config parsing."""

import tempfile
from pathlib import Path

import pytest
import yaml

from dqlens_dbt.dbt_config import (
    get_target_config,
    target_to_connection_url,
)


class TestTargetToConnectionUrl:
    def test_postgres(self):
        target = {
            "type": "postgres",
            "host": "localhost",
            "port": 5432,
            "user": "myuser",
            "password": "mypass",
            "dbname": "mydb",
            "schema": "public",
        }
        url = target_to_connection_url(target)
        assert url == "postgresql://myuser:mypass@localhost:5432/mydb"

    def test_postgres_default_port(self):
        target = {
            "type": "postgres",
            "host": "db.example.com",
            "user": "admin",
            "password": "secret",
            "dbname": "analytics",
        }
        url = target_to_connection_url(target)
        assert url == "postgresql://admin:secret@db.example.com:5432/analytics"

    def test_mysql(self):
        target = {
            "type": "mysql",
            "host": "mysql.example.com",
            "port": 3306,
            "user": "root",
            "password": "pass",
            "schema": "warehouse",
        }
        url = target_to_connection_url(target)
        assert url == "mysql://root:pass@mysql.example.com:3306/warehouse"

    def test_sqlite(self):
        target = {
            "type": "sqlite",
            "database": "/tmp/test.db",
        }
        url = target_to_connection_url(target)
        assert url == "sqlite:////tmp/test.db"

    def test_unsupported_type_raises(self):
        target = {"type": "bigquery"}
        with pytest.raises(ValueError, match="Unsupported"):
            target_to_connection_url(target)


class TestGetTargetConfig:
    def test_reads_profiles_yml(self, tmp_path, monkeypatch):
        # Create a profiles.yml
        profiles = {
            "my_project": {
                "target": "dev",
                "outputs": {
                    "dev": {
                        "type": "postgres",
                        "host": "localhost",
                        "port": 5432,
                        "user": "dqlens",
                        "password": "dqlens",
                        "dbname": "dqlens_test",
                        "schema": "public",
                    }
                }
            }
        }
        profiles_path = tmp_path / "profiles.yml"
        with open(profiles_path, "w") as f:
            yaml.dump(profiles, f)

        # Create a dbt_project.yml
        project = {"name": "test", "profile": "my_project", "version": "1.0.0"}
        project_path = tmp_path / "dbt_project.yml"
        with open(project_path, "w") as f:
            yaml.dump(project, f)

        # Point to the right dirs
        monkeypatch.setenv("DBT_PROFILES_DIR", str(tmp_path))
        monkeypatch.chdir(tmp_path)

        config = get_target_config()
        assert config["type"] == "postgres"
        assert config["host"] == "localhost"
        assert config["dbname"] == "dqlens_test"

    def test_missing_profile_raises(self, tmp_path, monkeypatch):
        profiles = {"other_project": {"target": "dev", "outputs": {"dev": {"type": "postgres"}}}}
        profiles_path = tmp_path / "profiles.yml"
        with open(profiles_path, "w") as f:
            yaml.dump(profiles, f)

        project = {"name": "test", "profile": "nonexistent", "version": "1.0.0"}
        project_path = tmp_path / "dbt_project.yml"
        with open(project_path, "w") as f:
            yaml.dump(project, f)

        monkeypatch.setenv("DBT_PROFILES_DIR", str(tmp_path))
        monkeypatch.chdir(tmp_path)

        with pytest.raises(ValueError, match="not found"):
            get_target_config()
