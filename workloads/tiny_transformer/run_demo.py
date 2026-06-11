#!/usr/bin/env python3
import json
from pathlib import Path


def matrix_multiply(
    matrix_a: list[list[int]],
    matrix_b: list[list[int]],
) -> list[list[int]]:
    rows = len(matrix_a)
    inner = len(matrix_b)
    columns = len(matrix_b[0])
    return [
        [
            sum(
                matrix_a[row][index] * matrix_b[index][column]
                for index in range(inner)
            )
            for column in range(columns)
        ]
        for row in range(rows)
    ]


def transpose(matrix: list[list[int]]) -> list[list[int]]:
    return [list(column) for column in zip(*matrix)]


def main() -> int:
    workload_dir = Path(__file__).resolve().parent
    vectors = json.loads(
        (workload_dir / "vectors.json").read_text(encoding="ascii")
    )
    scores = matrix_multiply(
        vectors["query"],
        transpose(vectors["key"]),
    )
    output = matrix_multiply(scores, vectors["value"])
    if scores != vectors["scores"]:
        raise SystemExit("attention score mismatch")
    if output != vectors["attention_output"]:
        raise SystemExit("attention output mismatch")
    print("Tiny transformer attention PASS")
    print("scores=")
    for row in scores:
        print(" ".join(f"{value:4d}" for value in row))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
