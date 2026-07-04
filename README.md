# TD Netcode Framework

Custom ECS-based simulation and binary netcode layer for a tower defense game built around bandwidth-efficient replication, extrapolation, and object pooling.

## Overview

This framework separates authoritative game simulation (server) from rendering/prediction (client), communicating only the minimum data needed over the network. It was built to handle large numbers of moving enemies without the bandwidth or GC overhead that naive roblox networking typically produces.

**Key features:**
- Custom fixed-tick ECS simulation (60Hz sim / 20Hz network flush, decoupled)
- Binary-packed netcode using luau `buffer` instead of table serialization
- Float16 encoding for `progress` / `speed` fields to halve payload size
- Dirty-flag delta replication only entities that changed get sent
- Client-side extrapolation for smooth movement between network ticks
- Reliable vs. unreliable channel separation per message type
- Object pooling for entity IDs and rendered models to avoid GC churn and `Instance` overhead
- Deterministic Catmull-Rom spline pathing, computed independently and identically on server and client


**Core principle:** the server owns the authoritative simulation and never sends 3D positions — only scalar `progress` values along a path. Both server and client reconstruct world-space position locally from the same deterministic spline, so the network only ever carries the minimum state needed to keep both sides in sync.

![demo](.tdShowcase.gif)

## Data flow

1. **Wave start** — client fires a `RemoteEvent`, servers `WaveSpawner` transitions its state machine and begins scheduling spawns.
2. **Simulation tick (60Hz)** — server spawns entities into the ECS `World`, advances each enemy's `progress` along its path, applies damage, and marks entities `dirty` when their state changes meaningfully.
3. **Network tick (20Hz)** — `NetworkSync` drains dirty entities into batches, packs them into binary buffers (`Buffers.lua`), and fires them over the appropriate reliable/unreliable remote.
4. **Client receive** — `StateReceiver` unpacks each batch and updates `ClientWorld` (spawn, correct progress, change speed, apply damage, remove on death).
5. **Client render (every frame)** — `Interpolation` extrapolates each enemy's visual position via extrapolation, `AnimationSystem` converts that into a world-space transform via the shared spline sampler and moves the pooled model, `VFXSystem` layers on cosmetic elements.

## Optimizations

### Position is never replicated
World-space position is 12+ bytes per entity per update. Instead, only a scalar `progress` (0–1) and `pathId` are synced. Both sides independently sample the same precomputed spline to get identical positions — this is the single biggest bandwidth saving in the system.

### Extrapolation
The client doesnt wait for network updates to move enemies. Every frame it extrapolates:
```lua
renderProgress = syncProgress + speed * (now - syncTime) / pathLength
```
The server only sends a correction when real simulated progress drifts from what the client would predict by more than a small epsilon. Most frames require zero network traffic for movement.

### Decoupled simulation and network rates
Simulation runs at a fixed 60Hz for deterministic gameplay logic; network flushes happen at 20Hz via a separate accumulator in the same loop. Combined with dead reckoning, this reduces network traffic well below a naive "sync every tick" approach.

### Dirty-flag delta replication
Each enemy record tracks independent `dirty`, `speedDirty`, and `hpDirty` flags. Every network tick, only entities whose flags are set get drained, packed, and sent — bandwidth scales with the number of *changes*, not the number of *entities*.

### Binary packing over `buffer`
Instead of sending Lua tables (which carry per-key serialization overhead), all replication data is packed into fixed-width binary layouts by hand — e.g. a spawn entry is `u16 id, u8 pathId, u8 typeId, f16 speed, u16 maxHp` (8 bytes total).

### Float16 encoding
`progress` and `speed` are encoded as IEEE-754 half-precision floats (hand-implemented codec) rather than full 32-bit floats, halving their size. Precision loss is negligible relative to the system's correction threshold.

### Batching with caps and chunking
Changed entities are packed into a single buffer per remote call, up to a configurable batch cap; oversized batches are automatically chunked. This avoids both per-entity call overhead and unbounded packet sizes.

### Reliable vs. unreliable channels
Position corrections are sent over an `UnreliableRemoteEvent` since a dropped packet is quickly superseded by the next one. Spawn, death, damage, and speed-change events — which are critical and can't be "caught up" the same way — use reliable ordered `RemoteEvent`s.

### Entity ID recycling
Freed entity IDs are returned to a pool and reused rather than growing an ever-increasing counter, keeping IDs small enough to fit in a `u16` even during long sessions with thousands of spawns.

### Zero-allocation hot path
Scratch buffers for outgoing batches are allocated once and reused every tick (`table.clear`), avoiding garbage collector pressure in the 60Hz/20Hz loops.

### Client-side model pooling
Enemy `Model` instances are expensive to create/destroy. A pool per enemy type recycles models instead of calling `Instance.new`/`Destroy` on every spawn and death.

### Precomputed spline sampling
The expensive part of spline evaluation — building an arc-length lookup table for uniform-speed traversal — happens once when a path loads. Runtime position queries are an O(log n) binary search over that table rather than re-integrating the curve each time.

## License

See [LICENSE](./LICENSE).
