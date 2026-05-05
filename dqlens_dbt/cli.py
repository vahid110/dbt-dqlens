"""CLI for dbt-dqlens: bridge between DQLens and dbt.

Commands:
    dqlens-dbt profile          Profile all models using dbt connection
    dqlens-dbt generate-tests   Generate _dqlens_tests.yml from profile
    dqlens-dbt run              Profile + generate in one step
"""

from __future__ import annotations

import sys

import click

from dqlens_dbt.dbt_config import get_target_config, target_to_connection_url


@click.group()
@click.version_option()
def main():
    """dbt-dqlens: Data quality for dbt, without writing tests."""
    pass


@main.command()
@click.option("--profile", default=None, help="dbt profile name (default: from dbt_project.yml)")
@click.option("--target", default=None, help="dbt target name (default: from profile)")
@click.option("--schema", default=None, help="Schema to profile (default: from target)")
@click.option("--exclude", default=None, help="Comma-separated table patterns to exclude")
@click.option("--quick", is_flag=True, help="Sample data for faster profiling")
def profile(profile, target, schema, exclude, quick):
    """Profile all models in the dbt target schema."""
    try:
        target_config = get_target_config(profile_name=profile, target_name=target)
    except (FileNotFoundError, ValueError) as e:
        click.echo(f"Error: {e}", err=True)
        sys.exit(1)

    conn_url = target_to_connection_url(target_config)
    target_schema = schema or target_config.get("schema", "public")

    click.echo(f"Connecting to {target_config['type']} schema '{target_schema}'...")

    # Import DQLens and run profiling
    try:
        from dqlens.config import init_dqlens_dir
        from dqlens.connectors.factory import get_connector
        from dqlens.profiler_v2 import profile_database
        from dqlens.baseline import save_profile
    except ImportError:
        click.echo(
            "Error: dqlens is not installed. Run: pip install dqlens",
            err=True,
        )
        sys.exit(1)

    # Initialize .dqlens/ directory
    exclude_list = [e.strip() for e in exclude.split(",")] if exclude else None
    init_dqlens_dir(conn_url, target_schema, exclude_tables=exclude_list)

    # Profile
    connector = get_connector(conn_url)
    with connector.connect() as conn:
        db_profile = profile_database(
            db=connector,
            conn=conn,
            schema=target_schema,
            exclude_tables=exclude_list,
            quick=quick,
        )

    # Save baseline
    save_profile(db_profile)

    table_count = len(db_profile.tables)
    col_count = sum(len(t.columns) for t in db_profile.tables)
    click.echo(f"Profiled {table_count} tables, {col_count} columns.")
    click.echo("Run 'dqlens-dbt generate-tests' to create test YAML.")


@main.command("generate-tests")
@click.option("--output", default="models/_dqlens_tests.yml", help="Output YAML path")
@click.option("--min-severity", default="LOW", help="Minimum severity (LOW/MEDIUM/HIGH)")
def generate_tests(output, min_severity):
    """Generate dbt test YAML from the latest DQLens profile."""
    try:
        from dqlens.baseline import load_latest_profile, load_previous_profile
    except ImportError:
        click.echo(
            "Error: dqlens is not installed. Run: pip install dqlens",
            err=True,
        )
        sys.exit(1)

    from dqlens_dbt.test_generator import generate_dbt_tests

    current = load_latest_profile()
    if current is None:
        click.echo(
            "Error: No profile found. Run 'dqlens-dbt profile' first.",
            err=True,
        )
        sys.exit(1)

    previous = load_previous_profile()

    path = generate_dbt_tests(
        profile=current,
        baseline=previous,
        output_path=output,
        min_severity=min_severity,
    )

    if path:
        click.echo(f"Generated: {path}")
        click.echo("Review the file, then commit it to your repo.")
        click.echo("Run 'dbt test --select tag:dqlens' to execute the tests.")
    else:
        click.echo("No tests generated (no findings above threshold).")


@main.command()
@click.option("--profile", default=None, help="dbt profile name")
@click.option("--target", default=None, help="dbt target name")
@click.option("--schema", default=None, help="Schema to profile")
@click.option("--output", default="models/_dqlens_tests.yml", help="Output YAML path")
@click.option("--quick", is_flag=True, help="Sample data for faster profiling")
def run(profile, target, schema, output, quick):
    """Profile and generate tests in one step."""
    from click.testing import CliRunner

    runner = CliRunner()

    # Run profile
    args = []
    if profile:
        args.extend(["--profile", profile])
    if target:
        args.extend(["--target", target])
    if schema:
        args.extend(["--schema", schema])
    if quick:
        args.append("--quick")

    result = runner.invoke(globals()["profile"], args, standalone_mode=False)
    if result and isinstance(result, int) and result != 0:
        sys.exit(result)

    # Run generate-tests
    result = runner.invoke(generate_tests, ["--output", output], standalone_mode=False)
    if result and isinstance(result, int) and result != 0:
        sys.exit(result)


if __name__ == "__main__":
    main()
