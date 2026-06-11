import json
import unittest
from pathlib import Path

from assembler import AssemblyError, assemble_text, render_systemverilog
from generate_gemm_program import MATRIX_SIZE, generate, write_outputs
from quantize_mlp import quantize_tensor
from warpforge_isa import INSTRUCTION_WIDTH, OPCODE_WIDTH, OPCODES


class AssemblerTest(unittest.TestCase):
    def test_all_instruction_forms(self) -> None:
        instructions = assemble_text(
            """
            nop
            add r2, r0, r1
            mul r3, r1, r2
            mad r4, r1, r2, r3
            prefetch_tile t0, 0x20
            wait_tile t0
            mma r5, t0
            barrier
            end
            """
        )
        self.assertEqual(len(instructions), 9)
        self.assertEqual(instructions[1].opcode, OPCODES["add"])
        self.assertEqual(instructions[4].immediate, 0x20)
        self.assertEqual(instructions[6].dst, 5)

    def test_packed_opcode_position(self) -> None:
        instruction = assemble_text("end\n")[0]
        self.assertEqual(
            instruction.encode(),
            OPCODES["end"] << (INSTRUCTION_WIDTH - OPCODE_WIDTH),
        )

    def test_invalid_register_rejected(self) -> None:
        with self.assertRaises(AssemblyError):
            assemble_text("add r32, r0, r1\n")

    def test_systemverilog_render(self) -> None:
        output = render_systemverilog(
            assemble_text("nop\nend\n"),
            "sample_pkg",
        )
        self.assertIn("package sample_pkg;", output)
        self.assertIn("PROGRAM_LENGTH = 2", output)


class GeneratorTest(unittest.TestCase):
    def test_gemm_golden_dimensions(self) -> None:
        generated = generate(7)
        self.assertEqual(len(generated["matrix_a"]), MATRIX_SIZE)
        self.assertEqual(len(generated["expected_c"]), MATRIX_SIZE)
        self.assertEqual(len(generated["memory_words"]), 8)

    def test_gemm_files(self) -> None:
        output = Path.cwd() / "build" / "tool-tests" / "gemm"
        write_outputs(output, 7)
        self.assertEqual(
            len((output / "program.hex").read_text().splitlines()),
            4,
        )
        golden = json.loads(
            (output / "golden.json").read_text(encoding="ascii")
        )
        self.assertEqual(golden["seed"], 7)

    def test_quantization_bounds(self) -> None:
        quantized = quantize_tensor([-2.0, 0.0, 1.0, 2.0])
        self.assertEqual(quantized["values"][0], -127)
        self.assertEqual(quantized["values"][-1], 127)


if __name__ == "__main__":
    unittest.main()
