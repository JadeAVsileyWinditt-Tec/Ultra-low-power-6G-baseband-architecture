"""
Behavioural power / intensity model of the 2048-tile baseband fabric
under continuous Topological Boundary Unit (TBU) thermal control.

Implements the silicon pillar (Pillar C) of the TBU framework:
  - Action potential S = total power dissipation (W)
  - Critical boundary  = 4 W thermal envelope
  - Local intensity cap ≤ 700 ops / transistor
  - Target efficiency  ~0.10 pJ / op
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import List, Optional, Tuple

import numpy as np

from tbu.core import TBUParams, Region, boundary_measure, classify_region, boundary_entropy


@dataclass(frozen=True)
class FabricParams:
    """Architectural constants taken from the design specification."""
    n_tiles: int = 2048
    transistors_per_tile: int = 19_531_250          # ≈ 40e9 / 2048
    intensity_cap_ops_per_transistor: float = 700.0
    energy_per_op_J: float = 0.10e-12               # 0.10 pJ
    thermal_envelope_W: float = 4.0
    target_ops_per_s: float = 2.6e13

    # Derived
    @property
    def max_ops_per_tile(self) -> float:
        return self.transistors_per_tile * self.intensity_cap_ops_per_transistor

    @property
    def max_power_per_tile_W(self) -> float:
        # P = ops/s × energy/op
        return self.max_ops_per_tile * self.energy_per_op_J


@dataclass
class TileState:
    """Per-tile instantaneous state."""
    tile_id: int
    active_ops: float = 0.0          # ops currently in flight
    power_W: float = 0.0
    throttle: float = 1.0            # [0,1] from TBU boundary measure
    region: Region = Region.FREE

    def update_power(self, energy_per_op: float):
        self.power_W = self.active_ops * energy_per_op * self.throttle


class FabricPowerModel:
    """
    Cycle-level (or event-level) power model of the full fabric.

    The TBU controller continuously evaluates total power against the
    4 W critical boundary and applies a global (or per-tile) throttle
    derived from the smooth boundary measure B_δ.
    """

    def __init__(
        self,
        fabric: FabricParams = FabricParams(),
        tbu: TBUParams = TBUParams(S_crit=4.0, delta=0.15, K=12.0),
    ):
        self.fabric = fabric
        self.tbu = tbu
        self.tiles: List[TileState] = [
            TileState(tile_id=i) for i in range(fabric.n_tiles)
        ]
        self.history: List[dict] = []

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def set_workload(self, ops_per_tile: np.ndarray | float, respect_intensity_cap: bool = True):
        """
        Assign an instantaneous operation count to every tile.
        ops_per_tile may be a scalar (uniform) or a length-n_tiles array.

        When respect_intensity_cap is False the local 700-ops/transistor
        ceiling is ignored (useful for demonstrating TBU behaviour under
        synthetic over-subscription).
        """
        if np.isscalar(ops_per_tile):
            ops = np.full(self.fabric.n_tiles, float(ops_per_tile))
        else:
            ops = np.asarray(ops_per_tile, dtype=float)
            assert ops.shape == (self.fabric.n_tiles,)

        if respect_intensity_cap:
            ops = np.minimum(ops, self.fabric.max_ops_per_tile)

        for i, tile in enumerate(self.tiles):
            tile.active_ops = ops[i]

    def step(self) -> dict:
        """
        One evaluation of the TBU thermal boundary controller.

        Returns a snapshot dictionary containing total power, region,
        entropy, and per-tile throttle factors.
        """
        # 1. Compute unconstrained power
        for tile in self.tiles:
            tile.throttle = 1.0          # temporary
            tile.update_power(self.fabric.energy_per_op_J)

        total_P = sum(t.power_W for t in self.tiles)

        # 2. Evaluate TBU boundary measure on total power.
        # For thermal protection the natural logistic B_δ is inverted so that
        # high power (above the envelope) produces strong containment:
        #   throttle = 1 - B_δ(P)  → 1 when under, → 0 when over.
        B = boundary_measure(total_P, self.tbu)
        region = classify_region(total_P, self.tbu)
        H = boundary_entropy(total_P, self.tbu)

        # 3. Apply containment (global throttle for simplicity;
        #    a production TBCU would distribute the force spatially)
        throttle = float(1.0 - B)
        for tile in self.tiles:
            tile.throttle = throttle
            tile.update_power(self.fabric.energy_per_op_J)
            tile.region = region

        total_P_throttled = sum(t.power_W for t in self.tiles)

        snapshot = {
            "total_power_W": total_P_throttled,
            "unconstrained_power_W": total_P,
            "boundary_measure": B,
            "region": region.name,
            "entropy": H,
            "throttle": throttle,
            "n_active_tiles": sum(1 for t in self.tiles if t.active_ops > 0),
            "mean_ops_per_tile": np.mean([t.active_ops for t in self.tiles]),
        }
        self.history.append(snapshot)
        return snapshot

    def run_load_profile(
        self,
        load_profile: List[float],
        label: str = "run",
        respect_intensity_cap: bool = True,
    ) -> List[dict]:
        """
        Drive the fabric with a sequence of normalised load factors
        (0 = idle, 1 = intensity-cap full load) and record TBU response.
        """
        results = []
        full_ops = self.fabric.max_ops_per_tile
        for load in load_profile:
            self.set_workload(load * full_ops, respect_intensity_cap=respect_intensity_cap)
            snap = self.step()
            snap["load_factor"] = load
            snap["label"] = label
            results.append(snap)
        return results

    def summary(self) -> str:
        if not self.history:
            return "No simulation steps recorded."
        last = self.history[-1]
        return (
            f"Fabric snapshot\n"
            f"  Tiles          : {self.fabric.n_tiles}\n"
            f"  Total power    : {last['total_power_W']:.3f} W  "
            f"(envelope {self.fabric.thermal_envelope_W} W)\n"
            f"  Region         : {last['region']}\n"
            f"  Boundary meas. : {last['boundary_measure']:.4f}\n"
            f"  Entropy        : {last['entropy']:.4f}  (max ln2≈0.693)\n"
            f"  Global throttle: {last['throttle']:.4f}\n"
        )
