#!/usr/bin/env python3
import json
from pathlib import Path


def matrix_multiply(
    matrix_a: list[list[int]],
    matrix_b: list[list[int]],
) -> list[list[int]]:
    row_count = len(matrix_a)
    inner_count = len(matrix_b)
    column_count = len(matrix_b[0])
    return [
        [
            sum(
                matrix_a[row][inner] * matrix_b[inner][column]
                for inner in range(inner_count)
            )
            for column in range(column_count)
        ]
        for row in range(row_count)
    ]


def main() -> int:
    workload_dir = Path(__file__).resolve().parent
    golden = json.loads(
        (workload_dir / "golden.json").read_text(encoding="ascii")
    )
    calculated = matrix_multiply(
        golden["matrix_a"],
        golden["matrix_b"],
    )
    if calculated != golden["expected_c"]:
        raise SystemExit("GEMM reference mismatch")
    print("GEMM reference PASS")
    for row in calculated:
        print(" ".join(f"{value:5d}" for value in row))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
