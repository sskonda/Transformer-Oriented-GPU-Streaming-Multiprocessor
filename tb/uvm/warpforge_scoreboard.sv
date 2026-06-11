`uvm_analysis_imp_decl(_actual)
`uvm_analysis_imp_decl(_expected)

class warpforge_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(warpforge_scoreboard)

  uvm_analysis_imp_actual #(warpforge_observation, warpforge_scoreboard)
      actual_export;
  uvm_analysis_imp_expected #(warpforge_observation, warpforge_scoreboard)
      expected_export;

  warpforge_observation actual_scalar[$];
  warpforge_observation expected_scalar[$];
  warpforge_observation actual_tensor[$];
  warpforge_observation expected_tensor[$];
  warpforge_observation actual_terminal[$];
  warpforge_observation expected_terminal[$];
  int unsigned comparisons;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    actual_export = new("actual_export", this);
    expected_export = new("expected_export", this);
  endfunction

  function void compare_scalar();
    warpforge_observation actual;
    warpforge_observation expected;
    while (actual_scalar.size() != 0 && expected_scalar.size() != 0) begin
      actual = actual_scalar.pop_front();
      expected = expected_scalar.pop_front();
      if (
        actual.warp_id != expected.warp_id ||
        actual.register_index != expected.register_index ||
        actual.scalar_data !== expected.scalar_data
      ) begin
        `uvm_error(
          "SCALAR_MISMATCH",
          $sformatf(
            "expected %s actual %s",
            expected.convert2string(),
            actual.convert2string()
          )
        )
      end
      comparisons++;
    end
  endfunction

  function void compare_tensor();
    warpforge_observation actual;
    warpforge_observation expected;
    while (actual_tensor.size() != 0 && expected_tensor.size() != 0) begin
      actual = actual_tensor.pop_front();
      expected = expected_tensor.pop_front();
      if (
        actual.warp_id != expected.warp_id ||
        actual.register_index != expected.register_index ||
        actual.tensor_data !== expected.tensor_data
      ) begin
        `uvm_error("TENSOR_MISMATCH", "Tensor result mismatch")
      end
      comparisons++;
    end
  endfunction

  function void compare_terminal();
    warpforge_observation actual;
    warpforge_observation expected;
    while (actual_terminal.size() != 0 && expected_terminal.size() != 0) begin
      actual = actual_terminal.pop_front();
      expected = expected_terminal.pop_front();
      if (
        actual.kind != expected.kind ||
        actual.warp_id != expected.warp_id
      ) begin
        `uvm_error(
          "TERMINAL_MISMATCH",
          $sformatf(
            "expected %s warp=%0d actual %s warp=%0d",
            expected.kind.name(),
            expected.warp_id,
            actual.kind.name(),
            actual.warp_id
          )
        )
      end
      comparisons++;
    end
  endfunction

  function void write_actual(warpforge_observation observation);
    unique case (observation.kind)
      OBS_SCALAR_RESULT: actual_scalar.push_back(observation);
      OBS_TENSOR_RESULT: actual_tensor.push_back(observation);
      OBS_WARP_DONE, OBS_WARP_ERROR:
          actual_terminal.push_back(observation);
      default: return;
    endcase
    compare_scalar();
    compare_tensor();
    compare_terminal();
  endfunction

  function void write_expected(warpforge_observation observation);
    unique case (observation.kind)
      OBS_SCALAR_RESULT: expected_scalar.push_back(observation);
      OBS_TENSOR_RESULT: expected_tensor.push_back(observation);
      OBS_WARP_DONE, OBS_WARP_ERROR:
          expected_terminal.push_back(observation);
      default: return;
    endcase
    compare_scalar();
    compare_tensor();
    compare_terminal();
  endfunction

  function void check_phase(uvm_phase phase);
    super.check_phase(phase);
    if (
      actual_scalar.size() != 0 ||
      expected_scalar.size() != 0 ||
      actual_tensor.size() != 0 ||
      expected_tensor.size() != 0 ||
      actual_terminal.size() != 0 ||
      expected_terminal.size() != 0
    ) begin
      `uvm_error("PENDING", "Unmatched expected or actual observations")
    end
    if (comparisons == 0) begin
      `uvm_error("NO_CHECKS", "Scoreboard performed no comparisons")
    end
  endfunction
endclass
