param(
  [string]$Test = "sanity_smoke_test",
  [int]$Seed = 1,
  [switch]$Quiet
)

$ErrorActionPreference = "Stop"
$rootDir = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$filelistDir = Join-Path $rootDir "sim\filelists"
$buildDir = Join-Path $rootDir "build\modelsim"
$logDir = Join-Path $rootDir "build\logs"
$runId = "${PID}_$([DateTime]::UtcNow.Ticks)"
$uvmHome = if ($env:UVM_HOME) {
  $env:UVM_HOME
} else {
  "C:\intelFPGA_lite\20.1\modelsim_ase\verilog_src\uvm-1.2\src"
}

$unitTests = @{
  scoreboard_dependency_test = "scoreboard_tb"
  scoreboard_simultaneous_set_clear_test = "scoreboard_tb"
  tensor_core_basic_test = "tensor_core_tb"
  tensor_core_signed_test = "tensor_core_tb"
  tensor_core_zero_test = "tensor_core_tb"
  tensor_core_extreme_test = "tensor_core_tb"
  tensor_core_back_to_back_test = "tensor_core_tb"
  tensor_core_reset_mid_operation_test = "tensor_core_tb"
  tensor_core_parameter_limits_test = "tensor_core_parameter_tb"
  shared_memory_basic_test = "shared_memory_tb"
  shared_memory_bank_conflict_test = "shared_memory_tb"
  shared_memory_read_after_write_test = "shared_memory_tb"
  prefetch_basic_test = "async_tile_prefetch_tb"
  prefetch_queue_full_test = "async_tile_prefetch_tb"
  prefetch_reset_mid_request_test = "async_tile_prefetch_tb"
  instruction_queue_load_issue_test = "instruction_queue_tb"
  scalar_alu_basic_test = "scalar_alu_tb"
  perf_counter_basic_test = "perf_counters_tb"
  workload_gemm_test = "workload_gemm_tb"
  workload_gemm_tree_test = "workload_gemm_tree_tb"
  control_boundary_test = "warpforge_control_tb"
}

$uvmTests = @(
  "sanity_smoke_test",
  "scheduler_round_robin_test",
  "scheduler_greedy_test",
  "scheduler_memory_aware_test",
  "top_single_warp_gemm_test",
  "top_multi_warp_contention_test",
  "barrier_synchronization_test",
  "reset_mid_operation_test",
  "illegal_instruction_test",
  "constrained_random_instruction_test",
  "random_multi_warp_test",
  "random_memory_latency_test",
  "random_backpressure_test",
  "long_regression_test"
)

function Invoke-Tool {
  param(
    [string]$Command,
    [string[]]$Arguments
  )

  if ($Quiet) {
    $toolOutput = & $Command @Arguments 2>&1
  } else {
    & $Command @Arguments
  }
  if ($LASTEXITCODE -ne 0) {
    if ($Quiet) {
      foreach ($line in $toolOutput) {
        Write-Host $line
      }
    }
    throw "$Command failed with exit code $LASTEXITCODE"
  }
}

function Invoke-WarpForgeTest {
  param([string]$TestName)

  $safeTestName = $TestName -replace "[^A-Za-z0-9_]", "_"
  $workLib = Join-Path $buildDir "work_${runId}_$safeTestName"

  New-Item -ItemType Directory -Force -Path $buildDir, $logDir |
      Out-Null
  Invoke-Tool "vlib" @($workLib)
  Push-Location $filelistDir
  try {
    if ($unitTests.ContainsKey($TestName)) {
      Invoke-Tool "vlog" @(
        "-sv",
        "-work", $workLib,
        "+define+SYNTHESIS",
        "-f", "all.f"
      )
      $top = $unitTests[$TestName]
      $logFile = Join-Path $logDir "${TestName}_${Seed}.log"
      Invoke-Tool "vsim" @(
        "-c",
        "-lib", $workLib,
        $top,
        "-l", $logFile,
        "-do", "run -all; quit -f"
      )
    } elseif ($uvmTests -contains $TestName) {
      $uvmPackage = Join-Path $uvmHome "uvm_pkg.sv"
      if (-not (Test-Path $uvmPackage)) {
        throw "UVM source was not found at $uvmHome"
      }
      Invoke-Tool "vlog" @(
        "-sv",
        "-work", $workLib,
        "+define+UVM_NO_DPI",
        "+define+WARPFORGE_DISABLE_COVERAGE",
        "+incdir+$uvmHome",
        $uvmPackage,
        "-f", "uvm.f"
      )
      $logFile = Join-Path $logDir "${TestName}_${Seed}.log"
      Invoke-Tool "vsim" @(
        "-c",
        "-lib", $workLib,
        "tb_top",
        "+UVM_TESTNAME=$TestName",
        "+UVM_VERBOSITY=UVM_LOW",
        "+SEED=$Seed",
        "-l", $logFile,
        "-do", "run -all; quit -f"
      )
      $failure = Select-String -LiteralPath $logFile -Pattern (
        "UVM_(ERROR|FATAL)\s*:\s*[1-9]"
      )
      if ($failure) {
        throw "UVM reported an error for $TestName"
      }
    } else {
      throw "Unknown test: $TestName"
    }
  } finally {
    Pop-Location
  }
  Write-Host "PASS: $TestName seed=$Seed"
}

if ($Test -eq "all") {
  $unitRepresentatives = @(
    "scoreboard_dependency_test",
    "tensor_core_basic_test",
    "tensor_core_parameter_limits_test",
    "shared_memory_basic_test",
    "prefetch_basic_test",
    "instruction_queue_load_issue_test",
    "scalar_alu_basic_test",
    "perf_counter_basic_test",
    "workload_gemm_test",
    "workload_gemm_tree_test",
    "control_boundary_test"
  )
  foreach ($testName in $unitRepresentatives + $uvmTests) {
    Invoke-WarpForgeTest $testName
  }
} else {
  Invoke-WarpForgeTest $Test
}
