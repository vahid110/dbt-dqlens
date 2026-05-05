"""Write DQLens findings to a format the dbt model can read.

After profiling, we run the DQLens engine and write findings as a seed CSV
that the dqlens_findings model can reference. This avoids needing DQLens
to INSERT directly into the warehouse.
"""

from __future__ import annotations

import csv
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from dqlens.models import DatabaseProfile, Finding, Severity


def run_checks_and_write_findings(
    profile: DatabaseProfile,
    baseline: DatabaseProfile | None,
    output_dir: str | Path = "seeds",
    conn: Any = None,
) -> Path:
    """Run DQLens rule engine and write findings as a seed CSV.

    Args:
        profile: Current database profile
        baseline: Previous profile for drift comparison
        output_dir: Directory to write the CSV seed file
        conn: Optional database connection for FK checks

    Returns:
        Path to the generated CSV file
    """
    from dqlens.engine import run_checks

    results = run_checks(profile, baseline, conn=conn)

    output_path = Path(output_dir)
    output_path.mkdir(parents=True, exist_ok=True)
    csv_path = output_path / "dqlens_raw_findings.csv"

    with open(csv_path, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=[
            "finding_id",
            "table_name",
            "column_name",
            "severity",
            "category",
            "message",
            "detail",
            "current_value",
            "baseline_value",
            "detected_at",
        ])
        writer.writeheader()

        now = datetime.now(timezone.utc).isoformat()

        for finding in results.all_findings:
            writer.writerow({
                "finding_id": str(uuid.uuid4()),
                "table_name": finding.table,
                "column_name": finding.column or "",
                "severity": finding.severity.value,
                "category": finding.category.value,
                "message": finding.message,
                "detail": finding.detail,
                "current_value": str(finding.current_value) if finding.current_value is not None else "",
                "baseline_value": str(finding.baseline_value) if finding.baseline_value is not None else "",
                "detected_at": now,
            })

    return csv_path
