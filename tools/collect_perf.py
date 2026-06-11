#!/usr/bin/env python3
import argparse
import csv
import re
from pathlib import Path


PERF_MARKER = "WARPFORGE_PERF"
PAIR_PATTERN = re.compile(r"([A-Za-z_]+)=([^\s]+)")
COUNTER_FIELDS = (
    "cycles",
    "issued",
    "scalar",
    "tensor",
    "prefetch",
    "scheduler_stall",
    "scoreboard_stall",
    "tile_wait",
    "tensor_wait",
    "prefetch_stall",
    "tensor_busy",
    "tensor_accepted",
    "tensor_completed",
    "bank_conflicts",
    "prefetch_requests",
    "prefetch_stalls",
    "completed_warps",
    "illegal",
)
OUTPUT_FIELDS = (
    "workload",
    "policy",
    "seed",
    *COUNTER_FIELDS,
    "tensor_utilization_percent",
)


def parse_perf_line(line: str) -> dict[str, str] | None:
    if PERF_MARKER not in line:
        return None
    payload = line.split(PERF_MARKER, maxsplit=1)[1]
    record = dict(PAIR_PATTERN.findall(payload))
    required = {"workload", "policy", "seed", *COUNTER_FIELDS}
    missing = sorted(required - record.keys())
    if missing:
        raise ValueError(
            "performance record is missing: " + ", ".join(missing)
        )
    cycles = int(record["cycles"])
    tensor_busy = int(record["tensor_busy"])
    utilization = 0.0 if cycles == 0 else (100.0 * tensor_busy / cycles)
    record["tensor_utilization_percent"] = f"{utilization:.3f}"
    return {field: record[field] for field in OUTPUT_FIELDS}


def collect(logs: list[Path]) -> list[dict[str, str]]:
    records = []
    for log in logs:
        for line in log.read_text(
            encoding="utf-8",
            errors="replace",
        ).splitlines():
            record = parse_perf_line(line)
            if record is not None:
                records.append(record)
    return records


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Extract WarpForge performance records from logs"
    )
    parser.add_argument("logs", type=Path, nargs="+")
    parser.add_argument("-o", "--output", type=Path, required=True)
    parser.add_argument("--workload")
    args = parser.parse_args()

    records = collect(args.logs)
    if args.workload is not None:
        records = [
            record
            for record in records
            if record["workload"] == args.workload
        ]
    if not records:
        raise SystemExit("no matching WarpForge performance records found")

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", encoding="ascii", newline="") as output_file:
        writer = csv.DictWriter(output_file, fieldnames=OUTPUT_FIELDS)
        writer.writeheader()
        writer.writerows(records)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
