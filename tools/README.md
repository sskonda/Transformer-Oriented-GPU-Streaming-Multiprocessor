# WarpForge Tools

The tools use only the Python standard library.

## Assembler

```bash
python tools/assembler.py program.asm -o program.hex
python tools/assembler.py program.asm -o program_pkg.sv \
  --format sv --package-name program_pkg
```

Supported syntax:

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

The current RTL stores the A and B matrices together in one prefetched tile.
`mma r0, t0` therefore reads both operands from `t0`. The assembler also
accepts a third tile operand and places it in reserved immediate metadata for
future split-tile architectures; current RTL does not consume that metadata.

The output word is the packed 42-bit `instruction_t` from
`rtl/packages/warpforge_pkg.sv`. Hex output uses eleven digits per instruction.

## Data Generators

```bash
python tools/generate_gemm_program.py build/gemm --seed 7
python tools/generate_mnist_mlp.py build/mnist_mlp.json --seed 11
python tools/quantize_mlp.py float_model.json int8_model.json
python tools/collect_perf.py build/logs/workload_gemm_test_17.log \
  -o build/gemm_results.csv
```

The GEMM generator creates assembly, instruction hex, packed memory words, and
a JSON golden result for a 4x4 signed INT8 matrix multiplication. The reduced
MLP generator creates deterministic 64x16x10 integer test data and expected
logits. `quantize_mlp.py` symmetrically quantizes numeric JSON tensors.
`collect_perf.py` extracts machine-readable counter snapshots from simulator
logs and calculates tensor busy-cycle utilization.

## Tests

```bash
python -m unittest discover -s tools -p "test_*.py"
```
