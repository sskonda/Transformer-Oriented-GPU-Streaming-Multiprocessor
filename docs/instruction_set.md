# Instruction Set

WarpForge uses one packed instruction type defined in `warpforge_pkg.sv`.
With the default register and tile counts, the instruction is 42 bits.

| Bits | Field | Purpose |
| --- | --- | --- |
| `[41:38]` | `opcode` | Operation encoding |
| `[37:33]` | `dst` | Destination scalar register |
| `[32:28]` | `src0` | First scalar source |
| `[27:23]` | `src1` | Second scalar source |
| `[22:18]` | `src2` | Third scalar source |
| `[17:16]` | `tile_id` | Warp-local tensor tile |
| `[15:0]` | `immediate` | Prefetch base word address or metadata |

## Opcodes

| Encoding | Name | Operands | Architectural effect |
| --- | --- | --- | --- |
| `0x0` | `NOP` | none | Advance PC |
| `0x1` | `ALU_ADD` | `dst, src0, src1` | Scalar addition |
| `0x2` | `ALU_MUL` | `dst, src0, src1` | Low-width signed product |
| `0x3` | `ALU_MAD` | `dst, src0, src1, src2` | Low-width multiply-add |
| `0x4` | `TENSOR_MMA` | `dst, tile_id` | Signed tiled matrix product |
| `0x5` | `PREFETCH_TILE` | `tile_id, immediate` | Queue tile transfer |
| `0x6` | `WAIT_TILE` | `tile_id` | Wait for tile validity |
| `0x7` | `BARRIER` | none | All-launched-warp barrier |
| `0x8` | `END` | none | Mark warp complete |
| `0xf` | `ILLEGAL` | none | Mark warp error |

Other opcode encodings are illegal.

## PC Rules

The PC advances only when issue is accepted. `END` and illegal instructions
halt the warp without repeatedly advancing. A nonterminal instruction at the
last instruction address raises a PC error and halts the warp.

## Assembler Syntax

```text
nop
add r2, r0, r1
mul r3, r1, r2
mad r4, r1, r2, r3
prefetch_tile t0, 0x0000
wait_tile t0
mma r0, t0
barrier
end
```

`tools/assembler.py` emits eleven-digit instruction hex or a SystemVerilog
package. The optional third `mma` tile operand is reserved metadata; current
RTL reads packed A and B matrices from the single selected tile.
