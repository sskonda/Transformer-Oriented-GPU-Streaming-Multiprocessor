# Regression

WarpForge uses direct self-checking testbenches for block-level behavior and
UVM tests for integrated execution. `sim/test_manifest.csv` maps every public
test name to its simulation target.

The June 13, 2026 local audit, fixes, test matrix, and remaining limitations
are recorded in [audit_report_2026-06-13.md](audit_report_2026-06-13.md).

## ModelSim Intel FPGA Starter

The checked local flow uses the deterministic random-program fallback because
Starter Edition cannot execute user constrained-random or functional coverage
constructs:

```powershell
.\sim\scripts\run_modelsim.ps1 -Test sanity_smoke_test -Seed 17
.\sim\scripts\run_modelsim.ps1 -Test all -Seed 17
```

Set `UVM_HOME` when the UVM 1.2 source is installed somewhere other than the
default Intel FPGA Lite location in the script.

## Questa

```bash
UVM_HOME=/path/to/uvm-1.2/src \
TEST=constrained_random_instruction_test \
SEED=17 \
./sim/scripts/run_questa.sh

UVM_HOME=/path/to/uvm-1.2/src \
SEED=17 \
./sim/scripts/run_regression.sh
```

The Questa flow enables native constrained randomization. VCS and Xcelium
entry points are also provided, but they require their commercial simulator
and have not been executed in the current environment.

## Verilator

Run the complete direct-test suite, including both tensor architectures and
the integrated control-boundary test:

```bash
./sim/scripts/run_verilator_regression.sh
```

The smaller CI smoke remains available through
`./sim/scripts/run_verilator_smoke.sh`.

The June 13, 2026 run passed 13/13 direct targets. Each generated binary was
also executed 100 times, for 1,300/1,300 repeated passes. This deterministic
stress run checks stability but is not a substitute for seeded UVM random
testing or formal liveness proof.

Icarus Verilog 12.0 can execute the scheduler, shared-memory, and
performance-counter benches. Its elaborator does not support the packed
multidimensional dynamic indexing used by the tensor, prefetch, and integrated
interfaces.

## Reproducibility

Random tests accept `SEED` and print the selected value. A watchdog terminates
deadlocked tests. UVM errors and fatals cause the regression to fail, and logs
are written under the ignored `build/logs` directory.
