# 2048-Tile Elaboration Plan

**Target:** Full ultra-low-power 6G baseband fabric  
**Envelope:** ≤ 4 W  
**Intensity cap:** ≤ 700 ops / transistor  
**Energy:** ~0.10 pJ / op  
**Control:** Continuous TBU (regional TBCU + pruning)

---

## 1. Current Baseline (what we have)

| Component | Status | Notes |
|-----------|--------|-------|
| TBU mathematics | Complete | `python/tbu/` |
| Calibrated energy model | Complete | `python/power/energy_model.py` |
| Approximate ALU | Complete | `rtl/tile/approx_alu.sv` |
| Intensity limiter | Complete | hard + soft throttle |
| Pruning controller | Complete | light / aggressive / skip |
| FFT butterfly + OFDM stage | Complete | real baseband kernels |
| Regional TBCU | Complete | hierarchical thermal containment |
| Top-level (small) | Complete | 8-tile skeleton |
| Testbenches | Complete | tile, regional, FFT+prune |

---

## 2. Scaling Strategy

### Phase A – Functional correctness (already underway)
- Keep `NUM_TILES` small (8–64) for fast simulation
- Prove TBU + pruning + FFT path under rising load
- Lock energy numbers to the calibrated model

### Phase B – Structural hierarchy
