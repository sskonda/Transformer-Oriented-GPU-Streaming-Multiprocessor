#!/usr/bin/env python3
import argparse
import json
from pathlib import Path
from typing import Any


INT8_MAX = 127


def flatten_numbers(value: Any) -> list[float]:
    if isinstance(value, list):
        flattened = []
        for element in value:
            flattened.extend(flatten_numbers(element))
        return flattened
    if isinstance(value, (int, float)):
        return [float(value)]
    raise ValueError("model values must be numeric lists")


def quantize_value(value: Any, scale: float) -> Any:
    if isinstance(value, list):
        return [quantize_value(element, scale) for element in value]
    quantized = round(float(value) / scale)
    return max(-INT8_MAX, min(INT8_MAX, quantized))


def quantize_tensor(value: Any) -> dict:
    numbers = flatten_numbers(value)
    maximum = max((abs(number) for number in numbers), default=0.0)
    scale = maximum / INT8_MAX if maximum != 0.0 else 1.0
    return {
        "scale": scale,
        "values": quantize_value(value, scale),
    }


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Symmetrically quantize JSON MLP tensors to signed INT8"
    )
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()

    source = json.loads(args.input.read_text(encoding="utf-8"))
    if not isinstance(source, dict):
        raise SystemExit("input JSON must contain a tensor-name object")

    quantized = {}
    for name, value in source.items():
        try:
            quantized[name] = quantize_tensor(value)
        except ValueError as error:
            raise SystemExit(f"{name}: {error}") from error

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(quantized, indent=2) + "\n",
        encoding="ascii",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
