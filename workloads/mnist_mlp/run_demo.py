#!/usr/bin/env python3
import json
from pathlib import Path


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


def main() -> int:
    workload_dir = Path(__file__).resolve().parent
    model = json.loads(
        (workload_dir / "model.json").read_text(encoding="ascii")
    )
    hidden_raw = matrix_vector(
        model["hidden_weights"],
        model["sample"],
        model["hidden_bias"],
    )
    hidden = [
        min(ACTIVATION_MAX, max(ACTIVATION_MIN, value))
        for value in hidden_raw
    ]
    logits = matrix_vector(
        model["output_weights"],
        hidden,
        model["output_bias"],
    )
    predicted_class = max(range(len(logits)), key=logits.__getitem__)

    if hidden != model["hidden_activation"]:
        raise SystemExit("MLP hidden activation mismatch")
    if logits != model["expected_logits"]:
        raise SystemExit("MLP logit mismatch")
    if predicted_class != model["expected_class"]:
        raise SystemExit("MLP class mismatch")

    print(f"MNIST-style MLP PASS predicted_class={predicted_class}")
    print("logits=" + ",".join(str(value) for value in logits))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
