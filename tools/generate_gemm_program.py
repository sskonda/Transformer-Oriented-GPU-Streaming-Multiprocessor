#!/usr/bin/env python3
import argparse
import json
import random
from pathlib import Path

from assembler import assemble_text, render_hex


MATRIX_SIZE = 4
ELEMENTS_PER_WORD = 4
ELEMENT_WIDTH = 8
DEFAULT_SEED = 7
DEFAULT_MIN_VALUE = -8
DEFAULT_MAX_VALUE = 7


def matrix_multiply(
    matrix_a: list[list[int]],
    matrix_b: list[list[int]],
) -> list[list[int]]:
    return [
        [
            sum(
                matrix_a[row][inner] * matrix_b[inner][column]
                for inner in range(MATRIX_SIZE)
            )
            for column in range(MATRIX_SIZE)
        ]
        for row in range(MATRIX_SIZE)
    ]


def flatten(matrix: list[list[int]]) -> list[int]:
    return [value for row in matrix for value in row]


def pack_int8_words(values: list[int]) -> list[int]:
    words = []
    for offset in range(0, len(values), ELEMENTS_PER_WORD):
        word = 0
        for lane, value in enumerate(
            values[offset:offset + ELEMENTS_PER_WORD]
        ):
            word |= (value & ((1 << ELEMENT_WIDTH) - 1)) << (
                ELEMENT_WIDTH * lane
            )
        words.append(word)
    return words


def generate(seed: int) -> dict:
    generator = random.Random(seed)
    matrix_a = [
        [
            generator.randint(DEFAULT_MIN_VALUE, DEFAULT_MAX_VALUE)
            for _ in range(MATRIX_SIZE)
        ]
        for _ in range(MATRIX_SIZE)
    ]
    matrix_b = [
        [
            generator.randint(DEFAULT_MIN_VALUE, DEFAULT_MAX_VALUE)
            for _ in range(MATRIX_SIZE)
        ]
        for _ in range(MATRIX_SIZE)
    ]
    result = matrix_multiply(matrix_a, matrix_b)
    words = pack_int8_words(flatten(matrix_a) + flatten(matrix_b))
    return {
        "seed": seed,
        "matrix_a": matrix_a,
        "matrix_b": matrix_b,
        "expected_c": result,
        "memory_words": words,
    }


def write_outputs(output_dir: Path, seed: int) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    data = generate(seed)
    assembly = (
        "prefetch_tile t0, 0x0000\n"
        "wait_tile t0\n"
        "mma r0, t0\n"
        "end\n"
    )
    instructions = assemble_text(assembly)
    (output_dir / "program.asm").write_text(assembly, encoding="ascii")
    (output_dir / "program.hex").write_text(
        render_hex(instructions),
        encoding="ascii",
    )
    (output_dir / "memory.hex").write_text(
        "".join(f"{word:08x}\n" for word in data["memory_words"]),
        encoding="ascii",
    )
    (output_dir / "golden.json").write_text(
        json.dumps(data, indent=2) + "\n",
        encoding="ascii",
    )


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Generate a deterministic WarpForge 4x4 INT8 GEMM"
    )
    parser.add_argument("output_dir", type=Path)
    parser.add_argument("--seed", type=int, default=DEFAULT_SEED)
    args = parser.parse_args()
    write_outputs(args.output_dir, args.seed)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
