# Shared Memory

WarpForge shared memory is divided into independently inferred RAM banks.
Arbitration and storage are separate: request arbitration selects at most one
port for each bank, then one `ram_sdp` instance per bank performs the accepted
access.

## Address mapping

`NUM_BANKS` must be a power of two. The low `log2(NUM_BANKS)` address bits
select the bank. The remaining high bits select the row inside that bank.
Consecutive words therefore map across consecutive banks.

## Arbitration and conflicts

Requests to different banks are accepted together. When multiple ports target
the same bank in one cycle, the lowest numbered port wins. Losing ports see
`req_ready` deasserted and must retry without changing their request.

`conflict_event` is combinational and indicates at least one denied request.
`conflict_count` adds the number of denied requests and saturates at its
maximum value. Reset or clear returns the counter to zero.

## Read and write behavior

Accepted writes update memory on the rising clock edge and do not produce a
response. Accepted reads produce `rsp_valid` and `rsp_rdata` one cycle later.
A response tag routes each bank result back to the requesting port.

Only one request is accepted per bank per cycle, so a same-bank read and write
cannot occur together. A write followed by a read on the next cycle returns
the newly written value. Requests to separate banks execute independently.

## Reset behavior

Reset and clear flush read-response validity and reset the conflict counter.
The RAM arrays are not reset, which preserves inference quality and avoids a
large reset network. Tests must initialize any location before relying on its
contents. Clear does not modify stored data.
