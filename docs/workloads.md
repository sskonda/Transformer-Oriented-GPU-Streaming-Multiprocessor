# Workloads

## RTL GEMM

`workloads/gemm` contains a seed-17 signed INT8 4x4 GEMM. The generator packs
matrix A and matrix B into eight 32-bit words, emits a four-instruction
program, and writes Python golden results.

`workload_gemm_tb` loads those files into the integrated top, services global
memory requests, and compares all sixteen tensor outputs. The workload runs
against both `TENSOR_ARCH_PIPELINED_TREE` and `TENSOR_ARCH_TREE` in the direct
Verilator regression.

## Reduced MNIST-Style MLP

`workloads/mnist_mlp` uses a deterministic 64x16x10 integer network. It
calculates a clipped ReLU hidden layer, ten logits, and a predicted class.
This is a reduced educational shape, not a trained full MNIST deployment.

The data and arithmetic checks run in Python. Tiling this model into WarpForge
programs is future runtime/compiler work.

## Tiny Transformer Attention

`workloads/tiny_transformer` uses four tokens, embedding dimension sixteen,
and one integer attention head. It computes `QK^T` and then scores-times-V.
Softmax and scale normalization are intentionally omitted.

This reference is aligned with the project theme but is not yet executed by
the RTL instruction stream.

## Supported Claims

WarpForge demonstrates small signed INT8 tiled matrix kernels and toy integer
inference arithmetic. It does not run complete large language models or
production neural-network frameworks.
