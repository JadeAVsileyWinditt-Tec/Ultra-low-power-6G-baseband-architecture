#!/usr/bin/env python3
"""
Co-simulation harness – proves the ≤4 W story.

Mirrors RTL policy:
  - inverted logistic throttle (TBCU)
  - pruning levels (pruning_controller)
  - intensity hard-cap + approx factor (energy_model)
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import numpy as np
from power.energy_model import EnergyParams, DEFAULT_ENERGY
from tbu.core import TBUParams, boundary_measure, classify_region, Region


def rtl_throttle(power_W: float, tbu: TBUParams) -> float:
    """1 - B_δ(P)  → high power produces strong containment."""
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
        # Deliberately crosses the design point
        load_factors = list(np.concatenate([
            np.linspace(0.05, 1.0, 8),
            np.linspace(1.1, 2.8, 10),
            np.linspace(1.5, 0.2, 5),
        ]))

    print("=" * 72)
    print("TBU Co-simulation – Envelope Proof")
    print("=" * 72)
    print(energy.summary())
    print(f"TBU  S_crit={tbu.S_crit} W   δ={tbu.delta} W")
    print()
    print(f"{'Load':>6} {'Req ops/tile':>14} {'Eff ops':>12} {'Power':>8} "
          f"{'Thr':>6} {'Region':<10} {'Prune':>5} {'OK':>4}")
    print("-" * 72)

    full = energy.max_ops_per_tile
    rows = []
    peak_power = 0.0

    for load in load_factors:
        requested = load * full
        power_raw = float(energy.power_W(requested, throttle=1.0))
        thr = rtl_throttle(power_raw, tbu)
        region = classify_region(power_raw, tbu)
        approx_en, prune_level = rtl_prune(region, thr)

        eff = energy.effective_ops(requested, approx_en=approx_en, prune_level=prune_level)
        power = float(energy.power_W(eff, throttle=thr))
        peak_power = max(peak_power, power)
        ok = power <= energy.thermal_envelope_W + 0.05  # small numerical tolerance

        print(f"{load:6.2f} {requested:14.3e} {eff:12.3e} {power:8.3f} "
              f"{thr:6.3f} {region.name:<10} {prune_level:5d} {'✅' if ok else '❌':>4}")

        rows.append({
            "load": load, "power": power, "throttle": thr,
            "region": region.name, "prune": prune_level, "ok": ok,
        })

    print("-" * 72)
    print(f"Peak controlled power : {peak_power:.3f} W")
    print(f"Thermal envelope      : {energy.thermal_envelope_W:.3f} W")
    print(f"Envelope respected    : {'YES' if peak_power <= energy.thermal_envelope_W + 0.05 else 'NO'}")
    print("=" * 72)
    return rows


if __name__ == "__main__":
    run_harness()
