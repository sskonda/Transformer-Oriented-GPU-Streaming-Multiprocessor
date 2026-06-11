# Regression

WarpForge uses direct self-checking testbenches for block-level behavior and
UVM tests for integrated execution. `sim/test_manifest.csv` maps every public
test name to its simulation target.

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

## Reproducibility

Random tests accept `SEED` and print the selected value. A watchdog terminates
deadlocked tests. UVM errors and fatals cause the regression to fail, and logs
are written under the ignored `build/logs` directory.
