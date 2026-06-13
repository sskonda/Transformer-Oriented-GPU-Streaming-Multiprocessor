`timescale 1ns/1ps

module workload_gemm_tree_tb;
  import warpforge_pkg::*;

  workload_gemm_tb #(
    .TENSOR_ARCH(TENSOR_ARCH_TREE)
  ) test();
endmodule
