# Instruction Storage And Issue

`instruction_queue` stores one program per warp and maintains an independent program counter for each warp.

Instructions are loaded through a valid/ready interface before execution. Reset clears instruction-valid state. Clear restarts loaded programs by resetting PCs, halt state, and PC errors without erasing the loaded program.

The current instruction and validity are presented for every warp. A program counter advances only when the scheduler selects that warp and the issue transaction is accepted. `END` and illegal opcodes halt the selected warp without advancing. A non-terminating instruction at the final address sets `pc_error` and halts the warp, preventing an out-of-range access.

Instruction loading and execution are intended to occur in separate phases. The integrated top level does not issue while programs are being loaded.
