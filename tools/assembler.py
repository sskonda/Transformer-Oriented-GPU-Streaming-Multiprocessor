#!/usr/bin/env python3
import argparse
import re
from pathlib import Path
from typing import Iterable

from warpforge_isa import (
    IMMEDIATE_WIDTH,
    INSTRUCTION_WIDTH,
    NUM_REGS,
    NUM_TILES,
    OPCODES,
    Instruction,
)


TOKEN_SPLIT = re.compile(r"[\s,]+")


class AssemblyError(ValueError):
    pass


def parse_index(token: str, prefix: str, limit: int, line_number: int) -> int:
    normalized = token.lower()
    if not normalized.startswith(prefix):
        raise AssemblyError(
            f"line {line_number}: expected {prefix} index, got {token}"
        )
    try:
        value = int(normalized[len(prefix):], 10)
    except ValueError as error:
        raise AssemblyError(
            f"line {line_number}: invalid {prefix} index {token}"
        ) from error
    if value < 0 or value >= limit:
        raise AssemblyError(
            f"line {line_number}: {token} is outside 0..{limit - 1}"
        )
    return value


def parse_immediate(token: str, line_number: int) -> int:
    try:
        value = int(token, 0)
    except ValueError as error:
        raise AssemblyError(
            f"line {line_number}: invalid immediate {token}"
        ) from error
    limit = 1 << IMMEDIATE_WIDTH
    if value < 0 or value >= limit:
        raise AssemblyError(
            f"line {line_number}: immediate is outside 0..{limit - 1}"
        )
    return value


def strip_comment(line: str) -> str:
    for marker in ("//", "#", ";"):
        line = line.split(marker, maxsplit=1)[0]
    return line.strip()


def parse_instruction(line: str, line_number: int) -> Instruction:
    tokens = [token for token in TOKEN_SPLIT.split(line) if token]
    mnemonic = tokens[0].lower()
    operands = tokens[1:]

    if mnemonic not in OPCODES:
        raise AssemblyError(
            f"line {line_number}: unknown instruction {mnemonic}"
        )

    if mnemonic in {"nop", "barrier", "end", "illegal"}:
        if operands:
            raise AssemblyError(
                f"line {line_number}: {mnemonic} takes no operands"
            )
        return Instruction(OPCODES[mnemonic])

    if mnemonic in {"add", "mul"}:
        if len(operands) != 3:
            raise AssemblyError(
                f"line {line_number}: {mnemonic} requires dst, src0, src1"
            )
        return Instruction(
            opcode=OPCODES[mnemonic],
            dst=parse_index(operands[0], "r", NUM_REGS, line_number),
            src0=parse_index(operands[1], "r", NUM_REGS, line_number),
            src1=parse_index(operands[2], "r", NUM_REGS, line_number),
        )

    if mnemonic == "mad":
        if len(operands) != 4:
            raise AssemblyError(
                f"line {line_number}: mad requires dst, src0, src1, src2"
            )
        return Instruction(
            opcode=OPCODES[mnemonic],
            dst=parse_index(operands[0], "r", NUM_REGS, line_number),
            src0=parse_index(operands[1], "r", NUM_REGS, line_number),
            src1=parse_index(operands[2], "r", NUM_REGS, line_number),
            src2=parse_index(operands[3], "r", NUM_REGS, line_number),
        )

    if mnemonic == "prefetch_tile":
        if len(operands) != 2:
            raise AssemblyError(
                f"line {line_number}: prefetch_tile requires tile, address"
            )
        return Instruction(
            opcode=OPCODES[mnemonic],
            tile_id=parse_index(
                operands[0],
                "t",
                NUM_TILES,
                line_number,
            ),
            immediate=parse_immediate(operands[1], line_number),
        )

    if mnemonic == "wait_tile":
        if len(operands) != 1:
            raise AssemblyError(
                f"line {line_number}: wait_tile requires one tile"
            )
        return Instruction(
            opcode=OPCODES[mnemonic],
            tile_id=parse_index(
                operands[0],
                "t",
                NUM_TILES,
                line_number,
            ),
        )

    if mnemonic == "mma":
        if len(operands) not in {2, 3}:
            raise AssemblyError(
                f"line {line_number}: mma requires dst, tile"
            )
        tile_id = parse_index(
            operands[1],
            "t",
            NUM_TILES,
            line_number,
        )
        immediate = 0
        if len(operands) == 3:
            immediate = parse_index(
                operands[2],
                "t",
                NUM_TILES,
                line_number,
            )
        return Instruction(
            opcode=OPCODES[mnemonic],
            dst=parse_index(operands[0], "r", NUM_REGS, line_number),
            tile_id=tile_id,
            immediate=immediate,
        )

    raise AssemblyError(f"line {line_number}: unsupported instruction")


def assemble_lines(lines: Iterable[str]) -> list[Instruction]:
    instructions = []
    for line_number, source_line in enumerate(lines, start=1):
        line = strip_comment(source_line)
        if line:
            instructions.append(parse_instruction(line, line_number))
    return instructions


def assemble_text(source: str) -> list[Instruction]:
    return assemble_lines(source.splitlines())


def render_hex(instructions: list[Instruction]) -> str:
    return "".join(f"{instruction.to_hex()}\n" for instruction in instructions)


def render_systemverilog(
    instructions: list[Instruction],
    package_name: str,
) -> str:
    entries = ",\n".join(
        (
            "    instruction_t'("
            f"{INSTRUCTION_WIDTH}'h{instruction.to_hex()})"
        )
        for instruction in instructions
    )
    return (
        f"package {package_name};\n"
        "  import warpforge_pkg::*;\n\n"
        f"  localparam int unsigned PROGRAM_LENGTH = {len(instructions)};\n"
        "  localparam instruction_t PROGRAM [0:PROGRAM_LENGTH-1] = '{\n"
        f"{entries}\n"
        "  };\n"
        "endpackage\n"
    )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Assemble WarpForge instructions"
    )
    parser.add_argument("input", type=Path, help="assembly source")
    parser.add_argument("-o", "--output", type=Path, required=True)
    parser.add_argument(
        "--format",
        choices=("hex", "sv"),
        default="hex",
    )
    parser.add_argument(
        "--package-name",
        default="warpforge_program_pkg",
    )
    return parser


def main() -> int:
    args = build_parser().parse_args()
    try:
        instructions = assemble_lines(
            args.input.read_text(encoding="utf-8").splitlines()
        )
    except AssemblyError as error:
        raise SystemExit(str(error)) from error

    if not instructions:
        raise SystemExit("assembly source contains no instructions")

    output = (
        render_hex(instructions)
        if args.format == "hex"
        else render_systemverilog(instructions, args.package_name)
    )
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(output, encoding="ascii")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
