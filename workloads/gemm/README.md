# GEMM Workload

This workload executes one signed INT8 4x4 matrix multiplication on the
integrated WarpForge RTL. The tile contains matrix A followed by matrix B in
row-major order. Four INT8 elements are packed into each 32-bit memory word,
least-significant byte first.

Regenerate the files:

```bash
python tools/generate_gemm_program.py workloads/gemm --seed 17
```

Check the Python golden model:

```bash
python workloads/gemm/run_reference.py
```

Run the RTL workload with the checked ModelSim flow:

```powershell
.\sim\scripts\run_modelsim.ps1 -Test workload_gemm_test -Seed 17
```

`workload_gemm_tb` loads `program.hex` and `memory.hex`, executes
`PREFETCH_TILE`, `WAIT_TILE`, `TENSOR_MMA`, and `END`, then compares all
sixteen tensor outputs against `result.hex`.
