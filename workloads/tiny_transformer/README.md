# Tiny Transformer Attention

This toy one-head attention datapath uses four tokens and an embedding
dimension of sixteen. It calculates signed integer `QK^T` scores and then
multiplies those scores by V.

```bash
python workloads/tiny_transformer/generate.py
python workloads/tiny_transformer/run_demo.py
```

Softmax and scaling are intentionally omitted, so this is a partial attention
datapath rather than a complete transformer layer. The workload is a reference
for future tiled lowering onto the WarpForge tensor instruction path.
