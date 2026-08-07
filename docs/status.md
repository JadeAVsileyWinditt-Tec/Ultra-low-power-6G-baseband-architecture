# Build Status – Ultra-Low-Power 6G Baseband

## Working
- Continuous TBU thermal boundary (global + regional)
- Algorithmic intensity reduction (approx + pruning)
- Full RX chain: FFT → EQ → soft demap
- Full TX chain: map → IFFT
- PHY tile (TX/RX under TBU)
- Hierarchical fabric path to 2048 tiles
- Co-sim harness + envelope stress tests
- End-to-end observable throttle / prune

## Next
1. Capture co-sim envelope proof numbers
2. MIMO detection kernel
3. Channel coding stub (LDPC/polar)
4. Larger NUM_TILES elaboration

## Core claim
High-throughput 6G baseband processing inside a ≤ 4 W mobile thermal envelope
via continuous boundary control + intensity reduction.
