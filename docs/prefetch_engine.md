# Async Tile Prefetch Engine

## Purpose

`async_tile_prefetch` decouples issued `PREFETCH_TILE` instructions from global-memory response latency. Requests are queued, processed in order, and written into shared memory one word at a time.

## Request Format

Each accepted request stores:

- Warp ID
- Tile ID
- Global-memory base word address
- Shared-memory base word address
- Transfer length in words

The transfer length must be between one and `MAX_TRANSFER_WORDS`, inclusive.

## Queue And Backpressure

The request queue uses a valid/ready interface. `req_ready` is low when:

- The queue cannot accept another request
- The requested tile is already pending
- The requested tile is valid and overwrite is disabled
- The encoded warp or tile ID is outside the implemented parameter range
- The request length is invalid
- Reset or clear is asserted

The FIFO can accept and dequeue on the same cycle. A full FIFO therefore accepts a new request only when the active engine simultaneously removes the oldest queued request.

## Global-Memory Interface

Addresses are word-addressed. The engine issues one read request, waits for one response, writes that word to shared memory, then advances to the next word.

The memory model must not return a response in the same cycle that a read request is accepted. The earliest supported response is the following cycle. `global_rsp_ready` remains asserted while the engine waits for that response.

## Shared-Memory Interface

`shared_wr_valid`, `shared_wr_addr`, and `shared_wr_data` remain active until `shared_wr_ready` accepts the write. A tile becomes valid only after the final word is accepted by shared memory.

## Tile Validity

Tile status is tracked independently for each warp and tile ID. A pending or valid tile cannot be requested again when `ALLOW_TILE_OVERWRITE` is disabled. `invalidate_valid` explicitly clears a valid tile. If invalidation and completion target the same tile in one cycle, invalidation wins.

The integrated instruction path distinguishes these cases. A duplicate
pending prefetch waits for the original transfer, while a `PREFETCH_TILE`
instruction targeting an already-valid tile retires as an idempotent no-op
without incrementing the engine request count.

Warp and tile IDs are validated before any state-array access. This prevents
out-of-range indexing when non-power-of-two parameter values leave unused
binary encodings.

## Reset Behavior

Reset and clear remove queued requests, cancel the active transfer, clear pending state, clear all tile-valid bits, and clear the completion pulse. Datapath storage is not reset because it is ignored unless the associated valid state is asserted.

## Debug Outputs

- `queue_level`
- `queue_full`
- `active_request_valid`
- `current_warp_id`
- `current_tile_id`
- `current_word_index`
- `prefetch_busy`
- `prefetch_stall`
- `tile_valid`
- `tile_completed`
