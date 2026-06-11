#!/usr/bin/env python3
import argparse
import json
import random
from pathlib import Path


DEFAULT_INPUT_SIZE = 64
DEFAULT_HIDDEN_SIZE = 16
DEFAULT_OUTPUT_SIZE = 10
DEFAULT_SEED = 11
INPUT_MIN = 0
INPUT_MAX = 15
WEIGHT_MIN = -4
WEIGHT_MAX = 4
ACTIVATION_MIN = 0
ACTIVATION_MAX = 127


def matrix_vector(
    matrix: list[list[int]],
    vector: list[int],
    bias: list[int],
) -> list[int]:
    return [
        sum(weight * value for weight, value in zip(row, vector)) + offset
        for row, offset in zip(matrix, bias)
    ]


def generate(
    seed: int,
    input_size: int,
    hidden_size: int,
    output_size: int,
) -> dict:
    generator = random.Random(seed)
    sample = [
        generator.randint(INPUT_MIN, INPUT_MAX)
        for _ in range(input_size)
    ]
    hidden_weights = [
        [
            generator.randint(WEIGHT_MIN, WEIGHT_MAX)
            for _ in range(input_size)
        ]
        for _ in range(hidden_size)
    ]
    hidden_bias = [
        generator.randint(WEIGHT_MIN, WEIGHT_MAX)
        for _ in range(hidden_size)
    ]
    output_weights = [
        [
            generator.randint(WEIGHT_MIN, WEIGHT_MAX)
            for _ in range(hidden_size)
        ]
        for _ in range(output_size)
    ]
    output_bias = [
        generator.randint(WEIGHT_MIN, WEIGHT_MAX)
        for _ in range(output_size)
    ]
    hidden_raw = matrix_vector(hidden_weights, sample, hidden_bias)
    hidden = [
        min(ACTIVATION_MAX, max(ACTIVATION_MIN, value))
        for value in hidden_raw
    ]
    logits = matrix_vector(output_weights, hidden, output_bias)
    predicted_class = max(range(output_size), key=logits.__getitem__)
    return {
        "seed": seed,
        "shape": {
            "input": input_size,
            "hidden": hidden_size,
            "output": output_size,
        },
        "sample": sample,
        "hidden_weights": hidden_weights,
        "hidden_bias": hidden_bias,
        "output_weights": output_weights,
        "output_bias": output_bias,
        "hidden_activation": hidden,
        "expected_logits": logits,
        "expected_class": predicted_class,
    }


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Generate a deterministic reduced INT8 MLP data set"
    )
    parser.add_argument("output", type=Path)
    parser.add_argument("--seed", type=int, default=DEFAULT_SEED)
    parser.add_argument("--input-size", type=int, default=DEFAULT_INPUT_SIZE)
    parser.add_argument("--hidden-size", type=int, default=DEFAULT_HIDDEN_SIZE)
    parser.add_argument("--output-size", type=int, default=DEFAULT_OUTPUT_SIZE)
    args = parser.parse_args()

    if min(args.input_size, args.hidden_size, args.output_size) <= 0:
        raise SystemExit("all layer dimensions must be positive")

    data = generate(
        args.seed,
        args.input_size,
        args.hidden_size,
        args.output_size,
    )
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(data, indent=2) + "\n",
        encoding="ascii",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
