from dataclasses import dataclass


NUM_REGS = 32
NUM_TILES = 4
REGISTER_WIDTH = 5
TILE_WIDTH = 2
IMMEDIATE_WIDTH = 16
OPCODE_WIDTH = 4
INSTRUCTION_WIDTH = (
    OPCODE_WIDTH
    + (4 * REGISTER_WIDTH)
    + TILE_WIDTH
    + IMMEDIATE_WIDTH
)
INSTRUCTION_HEX_DIGITS = (INSTRUCTION_WIDTH + 3) // 4

OPCODES = {
    "nop": 0x0,
    "add": 0x1,
    "mul": 0x2,
    "mad": 0x3,
    "mma": 0x4,
    "prefetch_tile": 0x5,
    "wait_tile": 0x6,
    "barrier": 0x7,
    "end": 0x8,
    "illegal": 0xF,
}

FIELD_WIDTHS = (
    OPCODE_WIDTH,
    REGISTER_WIDTH,
    REGISTER_WIDTH,
    REGISTER_WIDTH,
    REGISTER_WIDTH,
    TILE_WIDTH,
    IMMEDIATE_WIDTH,
)


@dataclass(frozen=True)
class Instruction:
    opcode: int
    dst: int = 0
    src0: int = 0
    src1: int = 0
    src2: int = 0
    tile_id: int = 0
    immediate: int = 0

    def encode(self) -> int:
        values = (
            self.opcode,
            self.dst,
            self.src0,
            self.src1,
            self.src2,
            self.tile_id,
            self.immediate,
        )
        encoded = 0
        for value, width in zip(values, FIELD_WIDTHS):
            if value < 0 or value >= (1 << width):
                raise ValueError(
                    f"Field value {value} does not fit in {width} bits"
                )
            encoded = (encoded << width) | value
        return encoded

    def to_hex(self) -> str:
        return f"{self.encode():0{INSTRUCTION_HEX_DIGITS}x}"
