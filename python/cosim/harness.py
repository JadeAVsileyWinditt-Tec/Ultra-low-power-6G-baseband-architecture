#!/usr/bin/env python3
"""
Co-simulation harness – fabric-wide ≤4 W envelope proof.

Mirrors RTL policy:
  - inverted logistic throttle (TBCU)
  - pruning levels (pruning_controller)
  - intensity hard-cap + approx factor (energy_model)

Power is computed over the full tile fabric (n_tiles × ops/tile × energy).
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import numpy as np
from power.energy_model import EnergyParams, DEFAULT_ENERGY
from tbu.core import TBUParams, boundary_measure, classify_region, Region


def rtl_throttle(power_W: float, tbu: TBUParams) -> float:
    """1 - B_δ(P) → high power produces strong containment."""
    return float(1.0 - boundary_measure(power_W, tbu))


def rtl_prune(region: Region, throttle: float) -> tuple[bool, int]:
    if region == Region.BOUND:
        return True, 2
    if region == Region.BOUNDARY:
        return True, 1
    if throttle < 0.75:
        return True, 1
    return False, 0


def run_harness(
    load_factors: list[float] | None = None,
    energy: EnergyParams = DEFAULT_ENERGY,
    tbu: TBUParams = TBUParams(S_crit=4.0, delta=0.30, K=12.0),
) -> list[dict]:
    if load_factors is None:
        # Design point → over-subscribe past envelope → cool-down
        load_factors = list(np.concatenate([
            np.linspace(0.2, 1.0, 5),
            np.linspace(1.2, 3.0, 10),
            np.linspace(1.0, 0.3, 4),
        ]))

    n = energy.n_tiles
    e_op = energy.energy_per_op_J
    cap_tile = energy.max_ops_per_tile

    print("=" * 74)
    print("TBU Co-simulation – Fabric Envelope Proof (2048 tiles)")
    print("=" * 74)
    print(energy.summary())
    print(f"TBU  S_crit={tbu.S_crit} W   δ={tbu.delta} W")
    print()
    print(f"{'Load':>6} {'Unconst W':>10} {'Ctrl W':>8} {'Thr':>6} "
          f"{'Region':<10} {'Prune':>5} {'OK':>4}")
    print("-" * 74)

    rows: list[dict] = []
    peak_ctrl = 0.0
    peak_unconst = 0.0

    for load in load_factors:
        req_tile = load * cap_tile
        # Unconstrained fabric power if the request were served raw
        unconst = float(n * req_tile * e_op)
        peak_unconst = max(peak_unconst, unconst)

        thr = rtl_throttle(unconst, tbu)
        region = classify_region(unconst, tbu)
        approx_en, prune_level = rtl_prune(region, thr)

        # Controlled: intensity hard-cap + prune + approx + throttle
        eff_tile = energy.effective_ops(
            req_tile, approx_en=approx_en, prune_level=prune_level
        )
        ctrl = float(n * eff_tile * e_op * thr)
        peak_ctrl = max(peak_ctrl, ctrl)
        ok = ctrl <= energy.thermal_envelope_W + 0.05

        print(f"{load:6.2f} {unconst:10.3f} {ctrl:8.3f} {thr:6.3f} "
              f"{region.name:<10} {prune_level:5d} {'YES' if ok else 'NO':>4}")

        rows.append({
            "load": load,
            "unconstrained_W": unconst,
            "controlled_W": ctrl,
            "throttle": thr,
            "region": region.name,
            "prune": prune_level,
            "ok": ok,
        })

    print("-" * 74)
    print(f"Peak unconstrained power : {peak_unconst:.3f} W")
    print(f"Peak controlled power    : {peak_ctrl:.3f} W")
    print(f"Thermal envelope         : {energy.thermal_envelope_W:.3f} W")
    print(f"Headroom under envelope  : {energy.thermal_envelope_W - peak_ctrl:.3f} W")
    print(f"Envelope respected       : "
          f"{'YES' if peak_ctrl <= energy.thermal_envelope_W + 0.05 else 'NO'}")
    print(f"Intensity-cap design pwr : {energy.power_at_full_intensity_W:.3f} W")
    print("=" * 74)
    return rows


if __name__ == "__main__":
    run_harness()
