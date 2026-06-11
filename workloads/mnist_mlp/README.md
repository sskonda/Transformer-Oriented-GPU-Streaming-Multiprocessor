# Reduced MNIST-Style MLP

This deterministic integer reference workload uses a 64-element input, a
16-element hidden layer with clipped ReLU, and 10 output logits. It is a
simulation-friendly stand-in for a 784-element MNIST input.

```bash
python tools/generate_mnist_mlp.py workloads/mnist_mlp/model.json --seed 17
python workloads/mnist_mlp/run_demo.py
```

The checked data demonstrates quantized model preparation and golden-model
checking. It is not currently lowered into a sequence of WarpForge 4x4 tiles;
that compiler/runtime mapping remains future work.
