"""Read dbt profiles.yml and extract connection info."""

from __future__ import annotations

import os
from pathlib import Path
from typing import Any

import yaml


def find_profiles_yml() -> Path:
    """Find dbt profiles.yml in standard locations."""
    # Check DBT_PROFILES_DIR env var first
    env_dir = os.environ.get("DBT_PROFILES_DIR")
    if env_dir:
        path = Path(env_dir) / "profiles.yml"
        if path.exists():
            return path

    # Default: ~/.dbt/profiles.yml
    default = Path.home() / ".dbt" / "profiles.yml"
    if default.exists():
        return default

    raise FileNotFoundError(
        "Could not find profiles.yml. "
        "Set DBT_PROFILES_DIR or ensure ~/.dbt/profiles.yml exists."
    )


def find_dbt_project() -> dict[str, Any]:
    """Find and parse dbt_project.yml in current directory or parents."""
    cwd = Path.cwd()
    for parent in [cwd, *cwd.parents]:
        project_file = parent / "dbt_project.yml"
        if project_file.exists():
            with open(project_file) as f:
                return yaml.safe_load(f)
    raise FileNotFoundError(
        "Could not find dbt_project.yml in current directory or parents."
    )


def get_target_config(
    profile_name: str | None = None,
    target_name: str | None = None,
) -> dict[str, Any]:
    """Extract the active target configuration from profiles.yml.

    Args:
        profile_name: Override profile name (default: from dbt_project.yml)
        target_name: Override target name (default: from profile's 'target' key)

    Returns:
        Dict with connection details (type, host, port, user, password, dbname, schema, etc.)
    """
    profiles_path = find_profiles_yml()
    with open(profiles_path) as f:
        profiles = yaml.safe_load(f)

    # Determine profile name
    if not profile_name:
        project = find_dbt_project()
        profile_name = project.get("profile")
        if not profile_name:
            raise ValueError("No 'profile' key in dbt_project.yml")

    if profile_name not in profiles:
        raise ValueError(
            f"Profile '{profile_name}' not found in {profiles_path}. "
            f"Available: {list(profiles.keys())}"
        )

    profile = profiles[profile_name]

    # Determine target
    if not target_name:
        target_name = os.environ.get("DBT_TARGET") or profile.get("target")
        if not target_name:
            raise ValueError(
                f"No 'target' key in profile '{profile_name}' and DBT_TARGET not set."
            )

    outputs = profile.get("outputs", {})
    if target_name not in outputs:
        raise ValueError(
            f"Target '{target_name}' not found in profile '{profile_name}'. "
            f"Available: {list(outputs.keys())}"
        )

    return outputs[target_name]


def target_to_connection_url(target: dict[str, Any]) -> str:
    """Convert a dbt target config dict to a DQLens connection URL.

    Supports: postgres, snowflake, mysql, sqlite.
    """
    db_type = target.get("type", "")

    if db_type == "postgres":
        host = target.get("host", "localhost")
        port = target.get("port", 5432)
        user = target.get("user", "")
        password = target.get("password", "")
        dbname = target.get("dbname", "")
        return f"postgresql://{user}:{password}@{host}:{port}/{dbname}"

    elif db_type == "mysql":
        host = target.get("host", "localhost")
        port = target.get("port", 3306)
        user = target.get("user", "")
        password = target.get("password", "")
        dbname = target.get("schema", "")
        return f"mysql://{user}:{password}@{host}:{port}/{dbname}"

    elif db_type == "sqlite":
        path = target.get("database", "")
        return f"sqlite:///{path}"

    elif db_type == "snowflake":
        account = target.get("account", "")
        user = target.get("user", "")
        password = target.get("password", "")
        database = target.get("database", "")
        schema = target.get("schema", "")
        return f"snowflake://{user}:{password}@{account}/{database}/{schema}"

    else:
        raise ValueError(
            f"Unsupported dbt target type: '{db_type}'. "
            f"Supported: postgres, mysql, sqlite, snowflake."
        )
