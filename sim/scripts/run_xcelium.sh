#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FILELIST_DIR="$ROOT_DIR/sim/filelists"
BUILD_DIR="$ROOT_DIR/build/xcelium"
LOG_DIR="$ROOT_DIR/build/logs"
TEST="${TEST:-sanity_smoke_test}"
SEED="${SEED:-1}"

mkdir -p "$BUILD_DIR" "$LOG_DIR"
pushd "$FILELIST_DIR" >/dev/null
xrun -64bit -uvm -sv \
  +define+SYNTHESIS \
  +define+WARPFORGE_ENABLE_CONSTRAINED_RANDOM \
  -f uvm.f \
  -top tb_top \
  "+UVM_TESTNAME=$TEST" \
  "+ntb_random_seed=$SEED" \
  "+SEED=$SEED" \
  -xmlibdirname "$BUILD_DIR/xcelium.d" \
  -l "$LOG_DIR/${TEST}_${SEED}_xcelium.log"
popd >/dev/null
