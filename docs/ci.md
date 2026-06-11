# Continuous Integration

WarpForge defines two GitHub Actions workflows.

`lint.yml` installs Verilator and lints the synthesizable RTL rooted at
`warpforge_top`. It also attempts Verible lint when the Ubuntu runner package
index provides Verible; absence of that optional package is reported as a
skip.

`smoke.yml` runs the Python unit tests, all three software reference
workloads, and a non-UVM Verilator build of `workload_gemm_tb`. The RTL smoke
loads the checked GEMM instruction and memory hex files and compares all
sixteen tensor outputs.

Run the Verilator smoke locally:

```bash
./sim/scripts/run_verilator_smoke.sh
```

Commercial-simulator UVM regressions remain separate because GitHub-hosted
runners do not provide Questa, VCS, or Xcelium licenses. The checked local
ModelSim flow is documented in `docs/regression.md`.

The workflows were added without a local Verilator or container runtime in
the development environment. Their status should therefore be taken from the
GitHub Actions run, while ModelSim and Python results are reported separately.
