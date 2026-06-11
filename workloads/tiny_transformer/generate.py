#!/usr/bin/env python3
import json
import random
from pathlib import Path


SEQUENCE_LENGTH = 4
EMBEDDING_DIMENSION = 16
DEFAULT_SEED = 23
VALUE_MIN = -3
VALUE_MAX = 3


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


def generate(seed: int) -> dict:
    generator = random.Random(seed)

    def matrix() -> list[list[int]]:
        return [
            [
                generator.randint(VALUE_MIN, VALUE_MAX)
                for _ in range(EMBEDDING_DIMENSION)
            ]
            for _ in range(SEQUENCE_LENGTH)
        ]

    query = matrix()
    key = matrix()
    value = matrix()
    scores = matrix_multiply(query, transpose(key))
    output = matrix_multiply(scores, value)
    return {
        "seed": seed,
        "sequence_length": SEQUENCE_LENGTH,
        "embedding_dimension": EMBEDDING_DIMENSION,
        "query": query,
        "key": key,
        "value": value,
        "scores": scores,
        "attention_output": output,
    }


def main() -> int:
    output = Path(__file__).resolve().parent / "vectors.json"
    output.write_text(
        json.dumps(generate(DEFAULT_SEED), indent=2) + "\n",
        encoding="ascii",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
